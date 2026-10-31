const router = require('express').Router();
const { db } = require('../config/firebase');
const auth = require('../middleware/auth');
const requireStaff = require('../middleware/requireStaff');
const { runReminders } = require('../jobs/reminders');

router.use(auth);
const owned = uid => db.collection('notifications').where('userId', '==', uid);
function millis(value) {
  try {
    const date = value && typeof value.toDate === 'function' ? value.toDate() :
      value instanceof Date ? value :
      typeof value === 'string' || typeof value === 'number' ? new Date(value) : null;
    const time = date ? date.getTime() : NaN;
    return Number.isFinite(time) ? time : -Infinity;
  } catch { return -Infinity; }
}

router.get('/', async (req, res) => {
  const snap = await owned(req.user.uid).get();
  const notifications = snap.docs.map(doc => ({ ...doc.data(), id: doc.id }))
    .filter(item => item.userId === req.user.uid);
  notifications.sort((a, b) => millis(b.createdAt) - millis(a.createdAt) || a.id.localeCompare(b.id));
  res.json(notifications);
});

router.get('/unread-count', async (req, res) => {
  const snap = await owned(req.user.uid).get();
  res.json({ count: snap.docs.filter(doc => doc.data().userId === req.user.uid && doc.data().isRead === false).length });
});

router.patch('/read-all', async (req, res) => {
  const snap = await owned(req.user.uid).get();
  const unread = snap.docs.filter(doc => doc.data().userId === req.user.uid && doc.data().isRead === false);
  // Stay below the Firestore write batch limit. Each batch is atomic; retries are idempotent.
  for (let offset = 0; offset < unread.length; offset += 450) {
    const batch = db.batch();
    for (const doc of unread.slice(offset, offset + 450)) batch.update(doc.ref, { isRead: true });
    await batch.commit();
  }
  res.json({ updatedCount: unread.length });
});

// POST /api/notifications/run-reminders - staff chạy nhắc lịch ngay (demo).
// Bình thường server tự chạy mỗi 10 phút (src/jobs/reminders.js).
router.post('/run-reminders', requireStaff, async (req, res, next) => {
  try {
    res.json(await runReminders());
  } catch (error) {
    next(error);
  }
});

router.patch('/:id/read', async (req, res) => {
  const ref = db.collection('notifications').doc(req.params.id);
  const result = await db.runTransaction(async transaction => {
    const doc = await transaction.get(ref);
    if (!doc.exists) return { status: 404, body: { message: 'Không tìm thấy thông báo' } };
    if (doc.data().userId !== req.user.uid) return { status: 403, body: { message: 'Bạn không có quyền sửa thông báo này' } };
    if (doc.data().isRead !== true) transaction.update(ref, { isRead: true });
    return { status: 200, body: { id: doc.id, isRead: true } };
  });
  res.status(result.status).json(result.body);
});

module.exports = router;
