// A03 - Nhắc lịch tự động trong hộp thư của app (không phải thông báo đẩy).
// - "appointment_reminder": lịch confirmed bắt đầu trong 24 giờ tới.
// - "follow_up_reminder": đề xuất tái khám "suggested" (hoặc "scheduled" cũ) có
//   scheduledAt trong 3 ngày tới.
// Id thông báo cố định nên chạy lại không trùng; mỗi thông báo tạo trong một
// transaction đọc lại trạng thái, giờ và công tắc nhận thông báo ngay trước khi ghi.
// server.js gọi startReminderJob(); test gọi thẳng runReminders({ now }).
const { db } = require('../config/firebase');
const { makeVietnamDateTime, toVietnamDateKey, parseFirestoreDate } = require('../utils/booking');

const HOUR = 60 * 60 * 1000;
const APPOINTMENT_WINDOW_MS = 24 * HOUR;
const FOLLOW_UP_WINDOW_MS = 3 * 24 * HOUR;
const INTERVAL_MS = 10 * 60 * 1000;
const OPEN_FOLLOW_UP = ['suggested', 'scheduled'];

const appointmentReminderId = (appointmentId, date, startTime) =>
  `remind_${appointmentId}_${date}_${String(startTime || '').replace(':', '')}`;
const followUpReminderId = (followUpId, dateKey) => `furemind_${followUpId}_${dateKey}`;

function vietnamDate(date) {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh', day: '2-digit', month: '2-digit', year: 'numeric',
  }).format(date);
}

function appointmentStart(appointment) {
  if (!appointment.date || !/^\d{2}:\d{2}$/.test(String(appointment.startTime || ''))) return null;
  const start = makeVietnamDateTime(appointment.date, appointment.startTime);
  return Number.isNaN(start.getTime()) ? null : start;
}

const inWindow = (time, now, windowMs) =>
  time !== null && time.getTime() > now.getTime() && time.getTime() - now.getTime() <= windowMs;

// Đọc trong transaction: tài khoản còn bật nhận thông báo và tên người khám.
async function readRecipient(transaction, accountId, patientId) {
  const userSnap = await transaction.get(db.collection('users').doc(accountId));
  if (!userSnap.exists) return null;
  const user = userSnap.data();
  if (user.notificationsEnabled === false) return { disabled: true };
  let patientName = user.fullName || '';
  if (patientId && patientId !== accountId) {
    const member = await transaction.get(db.collection('users').doc(accountId)
      .collection('family_members').doc(patientId));
    patientName = member.exists ? member.data().fullName || '' : '';
  }
  return { disabled: false, patientName };
}

async function remindAppointment(appointmentId, expected, now) {
  const ref = db.collection('appointments').doc(appointmentId);
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) return 'skipped';
    const a = snap.data();
    // Đổi giờ, hủy, từ chối, hoàn tất giữa lúc quét và lúc ghi thì không nhắc.
    if (String(a.status || '').toLowerCase() !== 'confirmed' ||
        a.date !== expected.date || a.startTime !== expected.startTime) return 'skipped';
    const start = appointmentStart(a);
    if (!inWindow(start, now, APPOINTMENT_WINDOW_MS) || !a.accountId) return 'skipped';
    const noticeRef = db.collection('notifications').doc(appointmentReminderId(appointmentId, a.date, a.startTime));
    if ((await transaction.get(noticeRef)).exists) return 'skipped';
    const recipient = await readRecipient(transaction, a.accountId, a.patientId);
    if (!recipient || recipient.disabled) return 'skipped';
    const who = a.patientId && a.patientId !== a.accountId && recipient.patientName
      ? ` của ${recipient.patientName}` : '';
    const doctor = a.doctorName ? ` với ${a.doctorName}` : '';
    transaction.set(noticeRef, {
      userId: a.accountId,
      title: 'Nhắc lịch hẹn',
      body: `Lịch hẹn${who} lúc ${a.startTime} ngày ${vietnamDate(start)}${doctor}. Vui lòng đến trước 10 phút.`,
      type: 'appointment_reminder',
      refId: appointmentId,
      patientId: a.patientId || null,
      isRead: false,
      createdAt: now,
    });
    return 'created';
  });
}

async function remindFollowUp(followUpId, now) {
  const ref = db.collection('follow_ups').doc(followUpId);
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) return 'skipped';
    const f = snap.data();
    if (!OPEN_FOLLOW_UP.includes(String(f.status || '').toLowerCase())) return 'skipped';
    const date = parseFirestoreDate(f.scheduledAt);
    if (!inWindow(date, now, FOLLOW_UP_WINDOW_MS)) return 'skipped';
    // Dữ liệu cũ không có accountId: chỉ nhắc khi patientId là chính một tài khoản.
    const accountId = f.accountId || f.patientId;
    if (!accountId) return 'skipped';
    const noticeRef = db.collection('notifications').doc(followUpReminderId(followUpId, toVietnamDateKey(date)));
    if ((await transaction.get(noticeRef)).exists) return 'skipped';
    const recipient = await readRecipient(transaction, accountId, f.patientId);
    if (!recipient || recipient.disabled) return 'skipped';
    const who = f.patientId && f.patientId !== accountId && recipient.patientName
      ? ` cho ${recipient.patientName}` : '';
    transaction.set(noticeRef, {
      userId: accountId,
      title: 'Nhắc lịch tái khám',
      body: `Bác sĩ đề xuất tái khám${who} ngày ${vietnamDate(date)}${f.reason ? `. Lý do: ${f.reason}` : ''}. Hãy đặt lịch nếu chưa đặt.`,
      type: 'follow_up_reminder',
      refId: followUpId,
      patientId: f.patientId || null,
      isRead: false,
      createdAt: now,
    });
    return 'created';
  });
}

// Quét và tạo nhắc. Lỗi của từng lịch được đếm, không làm dừng cả lượt.
async function runReminders({ now = new Date() } = {}) {
  const result = { appointmentReminders: 0, followUpReminders: 0, skipped: 0, errors: 0 };
  const count = (kind, outcome) => {
    if (outcome === 'created') result[kind] += 1;
    else result.skipped += 1;
  };

  // Lọc theo ngày rồi lọc trạng thái trong code: không cần chỉ mục ghép trên Firestore.
  const dates = [...new Set([toVietnamDateKey(now), toVietnamDateKey(new Date(now.getTime() + APPOINTMENT_WINDOW_MS))])];
  for (const date of dates) {
    const snapshot = await db.collection('appointments').where('date', '==', date).get();
    for (const doc of snapshot.docs) {
      const a = doc.data();
      if (String(a.status || '').toLowerCase() !== 'confirmed' ||
          !inWindow(appointmentStart(a), now, APPOINTMENT_WINDOW_MS)) continue;
      try {
        count('appointmentReminders', await remindAppointment(doc.id, a, now));
      } catch (error) {
        result.errors += 1;
        console.warn(`[reminders] lịch ${doc.id}: ${error.message}`);
      }
    }
  }

  for (const status of OPEN_FOLLOW_UP) {
    const snapshot = await db.collection('follow_ups').where('status', '==', status).get();
    for (const doc of snapshot.docs) {
      if (!inWindow(parseFirestoreDate(doc.data().scheduledAt), now, FOLLOW_UP_WINDOW_MS)) continue;
      try {
        count('followUpReminders', await remindFollowUp(doc.id, now));
      } catch (error) {
        result.errors += 1;
        console.warn(`[reminders] tái khám ${doc.id}: ${error.message}`);
      }
    }
  }
  return result;
}

// Chạy khi server khởi động và mỗi 10 phút; lượt trước chưa xong thì bỏ qua lượt sau.
function startReminderJob({ intervalMs = INTERVAL_MS } = {}) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const r = await runReminders();
      if (r.appointmentReminders || r.followUpReminders || r.errors) {
        console.log(`[reminders] nhắc lịch ${r.appointmentReminders}, nhắc tái khám ${r.followUpReminders}, lỗi ${r.errors}`);
      }
    } catch (error) {
      console.warn(`[reminders] lỗi khi quét: ${error.message}`);
    } finally {
      running = false;
    }
  };
  tick();
  return setInterval(tick, intervalMs);
}

module.exports = {
  APPOINTMENT_WINDOW_MS,
  FOLLOW_UP_WINDOW_MS,
  appointmentReminderId,
  followUpReminderId,
  runReminders,
  startReminderJob,
};
