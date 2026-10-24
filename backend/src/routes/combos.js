const router = require('express').Router();
const { db } = require('../config/firebase');

// GET /api/combos
// Ẩn mục isActive = false; mục không có trường isActive coi như đang bật
router.get('/', async (req, res) => {
  const snap = await db.collection('combos').get();
  res.json(
    snap.docs
      .filter((d) => d.data().isActive !== false)
      .map((d) => ({ id: d.id, ...d.data() }))
  );
});

// GET /api/combos/:id
// Vẫn trả mục đã tắt để xem lại được từ yêu thích hoặc lịch sử
router.get('/:id', async (req, res) => {
  const doc = await db.collection('combos').doc(req.params.id).get();
  if (!doc.exists) return res.status(404).json({ message: 'Không tìm thấy combo' });
  res.json({ id: doc.id, ...doc.data() });
});

module.exports = router;
