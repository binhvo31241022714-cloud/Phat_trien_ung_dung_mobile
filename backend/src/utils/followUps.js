// A08 - Liên kết đề xuất tái khám với lịch hẹn.
// suggested (hoặc "scheduled" cũ) → booked khi đặt lịch; lịch hủy/từ chối → suggested;
// lịch hoàn tất → completed.
const { db, ApiError } = require('./booking');

const OPEN_FOLLOW_UP_STATUSES = ['suggested', 'scheduled'];
const isOpenFollowUp = (status) => OPEN_FOLLOW_UP_STATUSES.includes(String(status || '').toLowerCase());

function readFollowUpId(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !value.trim() || value.length > 200 || value.includes('/')) {
    throw new ApiError(400, 'followUpId không hợp lệ');
  }
  return value.trim();
}

// Đọc (trong transaction) follow-up đang trỏ đúng lịch này, để đổi trạng thái theo lịch.
async function readLinkedFollowUp(transaction, appointmentId, appointment) {
  if (!appointment.followUpId) return null;
  const ref = db.collection('follow_ups').doc(appointment.followUpId);
  const snap = await transaction.get(ref);
  if (!snap.exists || snap.data().appointmentId !== appointmentId ||
      String(snap.data().status || '').toLowerCase() !== 'booked') return null;
  return ref;
}

function reopenFollowUp(transaction, ref, now) {
  if (ref) transaction.update(ref, { status: 'suggested', appointmentId: null, updatedAt: now });
}

function completeFollowUp(transaction, ref, now) {
  if (ref) transaction.update(ref, { status: 'completed', completedAt: now, updatedAt: now });
}

module.exports = {
  OPEN_FOLLOW_UP_STATUSES,
  isOpenFollowUp,
  readFollowUpId,
  readLinkedFollowUp,
  reopenFollowUp,
  completeFollowUp,
};
