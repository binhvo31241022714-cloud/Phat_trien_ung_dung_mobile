const router = require('express').Router();
const { db } = require('../config/firebase');
const auth = require('../middleware/auth');

// Mục đã lưu nằm trong hồ sơ của từng user
const col = (uid) => db.collection('users').doc(uid).collection('favorites');

// Loại nội dung được phép lưu -> tên collection tương ứng
const collections = {
  service: 'services',
  combo: 'combos',
  doctor: 'doctors',
  article: 'articles',
};

// GET /api/favorites
router.get('/', auth, async (req, res) => {
  const snap = await col(req.user.uid).get();
  res.json(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
});

// POST /api/favorites
router.post('/', auth, async (req, res) => {
  const { type, itemId } = req.body;
  if (!type || !itemId) return res.status(400).json({ message: 'Thiếu type hoặc itemId' });
  if (!collections[type]) return res.status(400).json({ message: 'type không hợp lệ' });

  const item = await db.collection(collections[type]).doc(itemId).get();
  if (!item.exists) return res.status(404).json({ message: 'Không tìm thấy nội dung cần lưu' });
  if (item.data().isActive === false) {
    return res.status(400).json({ message: 'Nội dung này đã ngừng hoạt động' });
  }

  // Id cố định theo type và itemId nên lưu nhiều lần cũng không bị trùng
  const id = `${type}_${itemId}`;
  await col(req.user.uid).doc(id).set({ type, itemId, createdAt: new Date() });
  res.status(201).json({ id });
});

// DELETE /api/favorites/:id
router.delete('/:id', auth, async (req, res) => {
  const ref = col(req.user.uid).doc(req.params.id);
  if (!(await ref.get()).exists) return res.status(404).json({ message: 'Không tìm thấy' });

  await ref.delete();
  res.json({ message: 'Đã xóa' });
});

module.exports = router;
