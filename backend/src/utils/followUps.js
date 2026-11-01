function isOpenFollowUp(status) { return ['suggested', 'scheduled'].includes(String(status || '').toLowerCase()); }
function readFollowUpId(value) {
  if (typeof value === 'string' && value.includes('/')) {
    throw Object.assign(new Error('followUpId không được chứa dấu /'), { status: 400 });
  }
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}
async function readLinkedFollowUp(transaction, appointmentId, appointment) {
  if (!appointment.followUpId) return null;
  const ref = db.collection('follow_ups').doc(appointment.followUpId);
  const snap = await transaction.get(ref);
  if (!snap.exists) return null;
  const followUp = snap.data();
  // Incomplete legacy ownership is never inferred or backfilled.
  if (typeof followUp.accountId !== 'string' || !followUp.accountId.trim() ||
      typeof followUp.patientId !== 'string' || !followUp.patientId.trim()) return null;
  // Check explicit ownership before skipping a stale backlink or status.
  if (followUp.accountId !== appointment.accountId || followUp.patientId !== appointment.patientId) {
    throw Object.assign(new Error('Liên kết tái khám không khớp tài khoản hoặc người khám'), { status: 409 });
  }
  if (followUp.appointmentId !== appointmentId || followUp.status !== 'booked') return null;
  return ref;
}
function reopenFollowUp(transaction, ref, now) { if (ref) transaction.update(ref, { status: 'suggested', appointmentId: null, updatedAt: now }); }
function completeFollowUp(transaction, ref, now) { if (ref) transaction.update(ref, { status: 'completed', completedAt: now, updatedAt: now }); }
module.exports = { isOpenFollowUp, readFollowUpId, readLinkedFollowUp, reopenFollowUp, completeFollowUp };
const { db } = require('../config/firebase');
