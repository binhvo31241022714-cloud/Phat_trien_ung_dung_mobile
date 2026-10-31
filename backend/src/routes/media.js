const router = require('express').Router();
const auth = require('../middleware/auth');
const { db, asyncHandler } = require('../utils/records');

// GET /api/media/:id - trả ảnh nhị phân. Chỉ chủ tài khoản (ownerAccountId) hoặc staff.
router.get('/:id', auth, asyncHandler(async (req, res) => {
  const snap = await db.collection('media').doc(req.params.id).get();
  if (!snap.exists) return res.status(404).json({ message: 'Không tìm thấy ảnh' });
  const media = snap.data();
  if (media.ownerAccountId !== req.user.uid && req.user.role !== 'staff') {
    return res.status(403).json({ message: 'Bạn không có quyền xem ảnh này' });
  }
  const buffer = Buffer.from(String(media.data || ''), 'base64');
  res.set({
    'Content-Type': media.mimeType,
    'Content-Length': String(buffer.length),
    'Cache-Control': 'private, max-age=86400',
    'X-Content-Type-Options': 'nosniff',
  });
  res.send(buffer);
}));

module.exports = router;
