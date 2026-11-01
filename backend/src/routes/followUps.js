const router = require('express').Router();
const auth = require('../middleware/auth');
const requireStaff = require('../middleware/requireStaff');
const { db } = require('../config/firebase');
const { assertPatientAccess, document, asyncHandler } = require('../utils/records');
router.get('/:id', auth, asyncHandler(async (req, res) => {
  const snap = await db.collection('follow_ups').doc(req.params.id).get();
  if (!snap.exists) return res.status(404).json({ message: 'Không tìm thấy đề xuất tái khám' });
  const staff = req.user.staff === true || req.user.role === 'staff' || req.user.admin === true;
  if (!staff && snap.data().accountId !== req.user.uid) return res.status(403).json({ message: 'Bạn không có quyền xem đề xuất này' });
  res.json(document(snap));
}));
router.post('/', auth, requireStaff, asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.accountId || !b.scheduledAt || !b.reason) return res.status(400).json({ message: 'Thiếu accountId, scheduledAt hoặc reason' });
  const patientId = b.patientId || b.accountId;
  const ref = db.collection('follow_ups').doc();
  const data = { accountId: b.accountId, patientId, scheduledAt: new Date(b.scheduledAt), reason: String(b.reason).trim(), notes: b.notes || '', doctorId: b.doctorId || null, visitId: b.visitId || null, treatmentId: b.treatmentId || null, serviceId: b.serviceId || null, status: 'suggested', createdAt: new Date(), createdBy: req.user.uid };
  if (Number.isNaN(data.scheduledAt.getTime())) return res.status(400).json({ message: 'scheduledAt không hợp lệ' });
  await db.runTransaction(async tx => { const patient = await tx.get(db.collection('users').doc(b.accountId)); if (!patient.exists && patientId === b.accountId) throw Object.assign(new Error('Không tìm thấy tài khoản'), { status: 400 }); tx.set(ref, data); const n = db.collection('notifications').doc(); tx.set(n, { userId: b.accountId, type: 'follow_up', title: 'Bác sĩ đề xuất tái khám', body: data.reason, refId: ref.id, isRead: false, createdAt: new Date() }); });
  res.status(201).json({ id: ref.id, ...data });
}));
module.exports = router;
