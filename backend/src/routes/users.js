const router = require('express').Router();
const { db } = require('../config/firebase');
const auth = require('../middleware/auth');

// POST /api/users/sync
router.post('/sync', auth, async (req, res) => {
  const { uid, email } = req.user;
  const ref = db.collection('users').doc(uid);
  const doc = await ref.get();

  if (!doc.exists) {
    await ref.set({
      email,
      fullName: req.body.fullName || '',
      phone: req.body.phone || '',
      createdAt: new Date(),
    });
  }
  const data = (await ref.get()).data();
  res.json({ id: uid, ...data });
});

// GET /api/users/me
router.get('/me', auth, async (req, res) => {
  const doc = await db.collection('users').doc(req.user.uid).get();
  if (!doc.exists) return res.status(404).json({ message: 'Chưa có hồ sơ' });
  res.json({ id: doc.id, ...doc.data() });
});

// PATCH /api/users/me
router.patch('/me', auth, async (req, res) => {
  const allowed = ['fullName', 'phone', 'birthday', 'gender', 'address'];
  const updates = {};
  allowed.forEach((k) => {
    if (req.body[k] !== undefined) updates[k] = req.body[k];
  });

  await db.collection('users').doc(req.user.uid).set(updates, { merge: true });
  res.json({ message: 'Cập nhật thành công', ...updates });
});

module.exports = router;