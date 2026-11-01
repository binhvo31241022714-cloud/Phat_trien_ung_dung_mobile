const { db } = require('../config/firebase');
const { isValidDateKey, parseTime } = require('../utils/booking');
const appointmentReminderId = (id, date, start) => `${id}_${date}_${start}`;
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
function startReminderJob() { runReminders().catch(console.error); return setInterval(() => runReminders().catch(console.error), 10 * 60 * 1000); }
module.exports = { runReminders, startReminderJob, appointmentReminderId };
