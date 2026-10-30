const router = require('express').Router();
const { db } = require('../config/firebase');
const auth = require('../middleware/auth');
const { parseFirestoreDate, isValidDateKey, parseTime, isFutureAppointment, isAppointmentActive } = require('../utils/booking');

function millis(value) {
  try { return parseFirestoreDate(value)?.getTime() ?? -Infinity; }
  catch { return -Infinity; }
}
function upcoming(appointment) {
  if (!isAppointmentActive(appointment) || String(appointment.status || '').toLowerCase() === 'completed') return false;
  if (!isValidDateKey(appointment.date)) return false;
  try {
    parseTime(appointment.startTime);
    return isFutureAppointment(appointment.date, appointment.startTime);
  } catch { return false; }
}
const rows = snap => snap.docs.map(doc => ({ ...doc.data(), id: doc.id }));

router.get('/', auth, async (req, res) => {
  const [services, doctors, articles, appointments] = await Promise.all([
    db.collection('services').get(),
    db.collection('doctors').get(),
    db.collection('articles').where('isPublished', '==', true).get(),
    db.collection('appointments').where('accountId', '==', req.user.uid).get(),
  ]);
  const featuredServices = rows(services).filter(item => item.isActive !== false)
    .sort((a, b) => Number(b.isFeatured === true) - Number(a.isFeatured === true) || a.id.localeCompare(b.id)).slice(0, 6);
  const featuredDoctors = rows(doctors).filter(item => item.isActive !== false)
    .sort((a, b) => a.id.localeCompare(b.id)).slice(0, 6);
  const latestArticles = rows(articles).filter(item => item.isPublished === true)
    .sort((a, b) => millis(b.publishedAt) - millis(a.publishedAt) || a.id.localeCompare(b.id)).slice(0, 3);
  const suitable = rows(appointments).filter(item => item.accountId === req.user.uid && upcoming(item))
    .sort((a, b) => `${a.date}T${a.startTime}`.localeCompare(`${b.date}T${b.startTime}`) || a.id.localeCompare(b.id));
  res.json({ featuredServices, featuredDoctors, latestArticles, upcomingAppointment: suitable[0] ?? null });
});

module.exports = router;
