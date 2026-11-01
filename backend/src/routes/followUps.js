const router = require('express').Router();
const auth = require('../middleware/auth');
const requireStaff = require('../middleware/requireStaff');
const { db } = require('../config/firebase');
const { document, asyncHandler, historyOwnershipMatches } = require('../utils/records');
const { optionalDate } = require('../utils/clinical');
router.get('/:id', auth, asyncHandler(async (req, res) => {
  const snap = await db.collection('follow_ups').doc(req.params.id).get();
  if (!snap.exists) return res.status(404).json({ message: 'Không tìm thấy đề xuất tái khám' });
  const staff = req.user.staff === true || req.user.role === 'staff' || req.user.admin === true;
  if (!staff && (snap.data().accountId !== req.user.uid || !historyOwnershipMatches(req.user.uid, snap.data()))) return res.status(403).json({ message: 'Bạn không có quyền xem đề xuất này' });
  res.json(document(snap));
}));
router.post('/', auth, requireStaff, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };
  const id = (value, field, optional = false) => {
    if (optional && (value === undefined || value === null)) return null;
    if (typeof value !== 'string' || !value.trim() || value.includes('/')) fail(400, `${field} không hợp lệ`);
    return value.trim();
  };
  const accountId = id(b.accountId, 'accountId');
  const patientId = b.patientId === undefined ? accountId : id(b.patientId, 'patientId');
  const visitId = id(b.visitId, 'visitId', true);
  const treatmentId = id(b.treatmentId, 'treatmentId', true);
  const serviceId = id(b.serviceId, 'serviceId', true);
  const doctorId = id(b.doctorId, 'doctorId', true);
  if (!b.scheduledAt || !b.reason) return res.status(400).json({ message: 'Thiếu scheduledAt hoặc reason' });
  const now = new Date();
  const scheduledAt = optionalDate(b.scheduledAt, 'scheduledAt');
  if (!scheduledAt || scheduledAt.getTime() <= now.getTime()) fail(400, 'scheduledAt phải lớn hơn thời điểm hiện tại');
  const ref = db.collection('follow_ups').doc();
  const data = { accountId, patientId, scheduledAt, reason: String(b.reason).trim(), notes: b.notes || '', doctorId, visitId, treatmentId, serviceId, status: 'suggested', createdAt: now, createdBy: req.user.uid };
  const notificationRef = db.collection('notifications').doc();
  await db.runTransaction(async tx => {
    const account = await tx.get(db.collection('users').doc(accountId));
    if (!account.exists) fail(400, 'Không tìm thấy tài khoản');
    if (patientId !== accountId) {
      const member = await tx.get(db.collection('users').doc(accountId).collection('family_members').doc(patientId));
      if (!member.exists || member.data().isArchived === true) fail(400, 'Người khám không thuộc tài khoản hoặc đã bị xóa');
    }
    const clinicalSource = async (collection, sourceId) => {
      const snap = await tx.get(db.collection(collection).doc(sourceId));
      if (!snap.exists) fail(400, `Không tìm thấy nguồn ${collection}`);
      const source = snap.data();
      // Reject explicit mismatches even if another ownership field is missing.
      for (const [field, expected] of [['accountId', accountId], ['patientId', patientId]]) {
        if (typeof source[field] === 'string' && source[field].trim() && source[field] !== expected) fail(400, 'Nguồn không thuộc tài khoản hoặc người khám');
      }
      if (typeof source.accountId !== 'string' || !source.accountId.trim() ||
          typeof source.patientId !== 'string' || !source.patientId.trim()) fail(409, 'Nguồn thiếu thông tin ownership');
      return source;
    };
    if (visitId) {
      const visit = await clinicalSource('visits', visitId);
      if (String(visit.status || '').toLowerCase() !== 'completed') fail(400, 'Chỉ dùng lần khám đã hoàn tất');
    }
    if (treatmentId) {
      const treatment = await clinicalSource('treatments', treatmentId);
      if (!['planned', 'in_progress', 'completed'].includes(treatment.status)) fail(409, 'Trạng thái liệu trình không hợp lệ');
    }
    for (const [collection, sourceId] of [['services', serviceId], ['doctors', doctorId]]) {
      if (!sourceId) continue;
      const snap = await tx.get(db.collection(collection).doc(sourceId));
      if (!snap.exists || snap.data().isActive === false) fail(400, `Nguồn ${collection} không tồn tại hoặc ngừng hoạt động`);
      if (collection === 'doctors') data.doctorName = snap.data().name || '';
    }
    tx.set(ref, data);
    tx.set(notificationRef, { userId: accountId, patientId, type: 'follow_up', title: 'Bác sĩ đề xuất tái khám', body: data.reason, refId: ref.id, isRead: false, createdAt: data.createdAt });
  });
  res.status(201).json({ id: ref.id, ...data });
}));
module.exports = router;
