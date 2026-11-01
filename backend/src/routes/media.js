const router = require('express').Router();
const auth = require('../middleware/auth');
const requireStaff = require('../middleware/requireStaff');
const { db } = require('../config/firebase');
router.get('/:id', auth, async (req, res) => {
  const snap = await db.collection('media').doc(req.params.id).get();
  if (!snap.exists) return res.status(404).json({ message: 'Không tìm thấy ảnh' });
  const data = snap.data();
  const staff = req.user.staff === true || req.user.admin === true || req.user.role === 'staff' || req.user.role === 'admin';
  if (!staff && data.ownerAccountId !== req.user.uid) return res.status(403).json({ message: 'Bạn không có quyền xem ảnh này' });
  res.type(data.mimeType || 'application/octet-stream').send(Buffer.from(data.data, 'base64'));
});
module.exports = router;
