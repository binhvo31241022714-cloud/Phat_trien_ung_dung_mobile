const { db } = require('../config/firebase');
const appointmentReminderId = (id, date, start) => `${id}_${date}_${start}`;
async function runReminders() {
  const now = new Date();
  const snap = await db.collection('appointments').where('status', '==', 'confirmed').get();
  let created = 0;
  for (const doc of snap.docs) {
    const a = doc.data();
    const when = new Date(`${a.date}T${a.startTime}:00+07:00`);
    if (when < now || when.getTime() - now.getTime() > 24 * 60 * 60 * 1000) continue;
    const user = await db.collection('users').doc(a.accountId).get();
    if (user.exists && user.data().notificationsEnabled === false) continue;
    const ref = db.collection('notifications').doc(appointmentReminderId(doc.id, a.date, a.startTime));
    const existing = await ref.get();
    if (!existing.exists) { await ref.set({ userId: a.accountId, type: 'appointment_reminder', title: 'Nhắc lịch hẹn', body: `Bạn có lịch hẹn ngày ${a.date} lúc ${a.startTime}.`, refId: doc.id, isRead: false, createdAt: now }); created++; }
  }
  return { created };
}
function startReminderJob() { runReminders().catch(console.error); return setInterval(() => runReminders().catch(console.error), 10 * 60 * 1000); }
module.exports = { runReminders, startReminderJob, appointmentReminderId };
