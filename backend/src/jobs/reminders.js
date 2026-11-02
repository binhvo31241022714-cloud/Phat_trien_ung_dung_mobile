const { db } = require('../config/firebase');
const { isValidDateKey, parseTime, parseFirestoreDate, toVietnamDateKey } = require('../utils/booking');
const appointmentReminderId = (id, date, start) => `${id}_${date}_${start}`;
// AUD-07: nhắc tái khám, id cố định theo đề xuất và ngày hẹn (giờ Việt Nam).
const followUpReminderId = (id, dateKey) => `furemind_${id}_${dateKey}`;
const OPEN_FOLLOW_UP = ['suggested', 'scheduled'];
const FOLLOW_UP_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;

function vietnamDate(date) {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh', day: '2-digit', month: '2-digit', year: 'numeric',
  }).format(date);
}

// Nhắc lịch hẹn: giữ nguyên hợp đồng trả về { created } (AUD-05).
async function runReminders() {
  const snap = await db.collection('appointments').where('status', '==', 'confirmed').get();
  let created = 0;
  for (const doc of snap.docs) {
    // Query snapshots are candidates only. Re-read all sources on every retry.
    const didCreate = await db.runTransaction(async transaction => {
      const appointment = await transaction.get(doc.ref);
      if (!appointment.exists) return false;
      const a = appointment.data();
      if (a.status !== 'confirmed' || typeof a.accountId !== 'string' || !a.accountId.trim()) return false;
      if (!isValidDateKey(a.date)) return false;
      try { parseTime(a.startTime); } catch { return false; }
      const when = new Date(`${a.date}T${a.startTime}:00+07:00`);
      const user = await transaction.get(db.collection('users').doc(a.accountId));
      const ref = db.collection('notifications').doc(appointmentReminderId(doc.id, a.date, a.startTime));
      const existing = await transaction.get(ref);
      // Preserve the current policy: a missing profile does not disable reminders.
      if (existing.exists || (user.exists && user.data().notificationsEnabled === false)) return false;
      const now = new Date();
      if (when < now || when.getTime() - now.getTime() > 24 * 60 * 60 * 1000) return false;
      transaction.set(ref, { userId: a.accountId, type: 'appointment_reminder', title: 'Nhắc lịch hẹn', body: `Bạn có lịch hẹn ngày ${a.date} lúc ${a.startTime}.`, refId: doc.id, isRead: false, createdAt: now });
      return true;
    });
    // Count only the successfully committed attempt, never callback invocations.
    if (didCreate) created++;
  }
  return { created };
}

// Đề xuất tái khám "suggested" (hoặc "scheduled" cũ) có scheduledAt trong 3 ngày tới.
// Cùng kiểu với nhắc lịch hẹn: đọc lại nguồn trong transaction, không ghi đè thông báo
// đã có, tôn trọng notificationsEnabled. Không suy đoán chủ sở hữu khi thiếu accountId.
async function runFollowUpReminders() {
  let created = 0;
  for (const status of OPEN_FOLLOW_UP) {
    const snap = await db.collection('follow_ups').where('status', '==', status).get();
    for (const doc of snap.docs) {
      const didCreate = await db.runTransaction(async transaction => {
        const current = await transaction.get(doc.ref);
        if (!current.exists) return false;
        const f = current.data();
        if (!OPEN_FOLLOW_UP.includes(f.status)) return false;
        if (typeof f.accountId !== 'string' || !f.accountId.trim()) return false;
        const when = parseFirestoreDate(f.scheduledAt);
        const now = new Date();
        if (!when || when <= now || when.getTime() - now.getTime() > FOLLOW_UP_WINDOW_MS) return false;
        const user = await transaction.get(db.collection('users').doc(f.accountId));
        const ref = db.collection('notifications').doc(followUpReminderId(doc.id, toVietnamDateKey(when)));
        const existing = await transaction.get(ref);
        if (existing.exists || (user.exists && user.data().notificationsEnabled === false)) return false;
        let who = '';
        if (typeof f.patientId === 'string' && f.patientId && f.patientId !== f.accountId) {
          const member = await transaction.get(db.collection('users').doc(f.accountId)
            .collection('family_members').doc(f.patientId));
          if (member.exists && member.data().fullName) who = ` cho ${member.data().fullName}`;
        }
        transaction.set(ref, {
          userId: f.accountId,
          type: 'follow_up_reminder',
          title: 'Nhắc lịch tái khám',
          body: `Bác sĩ đề xuất tái khám${who} ngày ${vietnamDate(when)}${f.reason ? `. Lý do: ${f.reason}` : ''}. Hãy đặt lịch nếu chưa đặt.`,
          refId: doc.id,
          patientId: f.patientId || null,
          isRead: false,
          createdAt: now,
        });
        return true;
      });
      if (didCreate) created++;
    }
  }
  return { followUpReminders: created };
}

// Chạy cả hai loại nhắc: dùng cho job 10 phút và POST /api/notifications/run-reminders.
async function runAllReminders() {
  const { created } = await runReminders();
  const { followUpReminders } = await runFollowUpReminders();
  return { created, followUpReminders };
}
function startReminderJob() { runAllReminders().catch(console.error); return setInterval(() => runAllReminders().catch(console.error), 10 * 60 * 1000); }
module.exports = { runReminders, runFollowUpReminders, runAllReminders, startReminderJob, appointmentReminderId, followUpReminderId };
