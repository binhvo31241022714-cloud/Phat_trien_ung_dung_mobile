function isOpenFollowUp(status) { return ['suggested', 'scheduled'].includes(String(status || '').toLowerCase()); }
function readFollowUpId(value) { return typeof value === 'string' && value.trim() ? value.trim() : null; }
async function readLinkedFollowUp(transaction, appointmentId, appointment) {
  if (!appointment.followUpId) return null;
  const ref = db.collection('follow_ups').doc(appointment.followUpId);
  const snap = await transaction.get(ref);
  return snap.exists ? ref : null;
}
function reopenFollowUp(transaction, ref, now) { if (ref) transaction.update(ref, { status: 'suggested', appointmentId: null, updatedAt: now }); }
function completeFollowUp(transaction, ref, now) { if (ref) transaction.update(ref, { status: 'completed', completedAt: now, updatedAt: now }); }
module.exports = { isOpenFollowUp, readFollowUpId, readLinkedFollowUp, reopenFollowUp, completeFollowUp };
const { db } = require('../config/firebase');
