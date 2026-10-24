const router = require('express').Router();
const { db } = require('../config/firebase');
const auth = require('../middleware/auth');
const { readHealth, withHealthDefaults, DEFAULTS } = require('../utils/health');

// Người thân lưu bên trong hồ sơ của từng user, nên người khác không xem được
const col = (uid) => db.collection('users').doc(uid).collection('family_members');

// GET /api/family-members
router.get('/', auth, async (req, res) => {
  const snap = await col(req.user.uid).get();
  res.json(snap.docs.map((d) => ({ id: d.id, ...withHealthDefaults(d.data()) })));
});

// POST /api/family-members
router.post('/', auth, async (req, res) => {
  const { fullName, relationship, birthday, phone } = req.body;
  if (!fullName) return res.status(400).json({ message: 'Thiếu họ tên' });

  // Giới tính và thông tin sức khỏe (xem utils/health.js), thiếu thì lưu mặc định
  const { data: health, error } = readHealth(req.body);
  if (error) return res.status(400).json({ message: error });

  const ref = await col(req.user.uid).add({
    fullName,
    relationship: relationship || '',
    birthday: birthday || '',
    phone: phone || '',
    ...DEFAULTS,
    ...health,
    createdAt: new Date(),
  });
  res.status(201).json({ id: ref.id });
});

// PATCH /api/family-members/:id
router.patch('/:id', auth, async (req, res) => {
  const ref = col(req.user.uid).doc(req.params.id);
  if (!(await ref.get()).exists) return res.status(404).json({ message: 'Không tìm thấy' });

  const { data: health, error } = readHealth(req.body);
  if (error) return res.status(400).json({ message: error });

  const allowed = ['fullName', 'relationship', 'birthday', 'phone'];
  const updates = { ...health };
  allowed.forEach((k) => {
    if (req.body[k] !== undefined) updates[k] = req.body[k];
  });

  if (Object.keys(updates).length > 0) await ref.update(updates);
  res.json({ message: 'Cập nhật thành công' });
});

// DELETE /api/family-members/:id
router.delete('/:id', auth, async (req, res) => {
  const ref = col(req.user.uid).doc(req.params.id);
  if (!(await ref.get()).exists) return res.status(404).json({ message: 'Không tìm thấy' });

  await ref.delete();
  res.json({ message: 'Đã xóa' });
});

module.exports = router;
