const router = require('express').Router();
const auth = require('../middleware/auth');
const requireStaff = require('../middleware/requireStaff');
const { db, asyncHandler, getRecordOrThrow, assertRecordAccess, document } = require('../utils/records');
const {
  optionalText,
  requiredText,
  optionalId,
  optionalDate,
  assertActivePatient,
} = require('../utils/clinical');

const fail = (status, message) => Object.assign(new Error(message), { status });

function vietnamDateText(date) {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);
}

// POST /api/follow-ups - staff đề xuất tái khám, tạo thông báo "follow_up".
// Body: { accountId, patientId?, scheduledAt, reason, notes?, doctorId?,
//         visitId?, treatmentId?, serviceId? }
// Ngày hẹn lưu ở scheduledAt (giữ tên trường cũ), trạng thái "suggested".
router.post('/', auth, requireStaff, asyncHandler(async (req, res) => {
  const body = req.body || {};
  const accountId = optionalId(body.accountId, 'accountId');
  if (!accountId) throw fail(400, 'Thiếu accountId');
  const patientId = optionalId(body.patientId, 'patientId') || accountId;
  const scheduledAt = optionalDate(body.scheduledAt, 'scheduledAt');
  if (!scheduledAt) throw fail(400, 'Thiếu scheduledAt (ngày hẹn tái khám)');
  if (scheduledAt.getTime() <= Date.now()) throw fail(400, 'Ngày hẹn tái khám phải ở tương lai');
  const reason = requiredText(body.reason, 'lý do tái khám', 500);
  const notes = optionalText(body.notes, 'Ghi chú', 1000);
  const ids = {
    doctorId: optionalId(body.doctorId, 'doctorId'),
    visitId: optionalId(body.visitId, 'visitId'),
    treatmentId: optionalId(body.treatmentId, 'treatmentId'),
    serviceId: optionalId(body.serviceId, 'serviceId'),
  };

  const followUpRef = db.collection('follow_ups').doc();
  const notificationRef = db.collection('notifications').doc(`followup_${followUpRef.id}`);
  const result = await db.runTransaction(async (transaction) => {
    await assertActivePatient(transaction, accountId, patientId);
    let doctorName = '';
    if (ids.doctorId) {
      const snap = await transaction.get(db.collection('doctors').doc(ids.doctorId));
      if (!snap.exists) throw fail(400, 'Không tìm thấy bác sĩ');
      doctorName = snap.data().name || '';
    }
    for (const [collection, id, label] of [
      ['visits', ids.visitId, 'lần khám'],
      ['treatments', ids.treatmentId, 'liệu trình'],
    ]) {
      if (!id) continue;
      const snap = await transaction.get(db.collection(collection).doc(id));
      if (!snap.exists) throw fail(400, `Không tìm thấy ${label}`);
      if (snap.data().patientId !== patientId) throw fail(400, `${label} không thuộc bệnh nhân này`);
    }
    if (ids.serviceId) {
      const snap = await transaction.get(db.collection('services').doc(ids.serviceId));
      if (!snap.exists) throw fail(400, 'Không tìm thấy dịch vụ');
    }

    const now = new Date();
    const followUp = {
      patientId,
      accountId,
      ...ids,
      doctorName,
      scheduledAt,
      reason,
      notes,
      status: 'suggested',
      createdBy: req.user.uid,
      createdAt: now,
    };
    transaction.set(followUpRef, followUp);
    transaction.set(notificationRef, {
      userId: accountId,
      title: 'Bác sĩ đề xuất tái khám',
      body: `Bạn được đề xuất tái khám ngày ${vietnamDateText(scheduledAt)}. Lý do: ${reason}`,
      type: 'follow_up',
      refId: followUpRef.id,
      patientId,
      isRead: false,
      createdAt: now,
    });
    return { id: followUpRef.id, ...followUp };
  });
  res.status(201).json(result);
}));

// GET /api/follow-ups/:id - chi tiết đề xuất tái khám (chủ tài khoản hoặc staff).
// App dùng khi bấm thông báo follow_up mà chưa có dữ liệu trong máy.
router.get('/:id', auth, asyncHandler(async (req, res) => {
  const followUp = await getRecordOrThrow('follow_ups', req.params.id);
  if (req.user.role !== 'staff') await assertRecordAccess(req.user.uid, followUp);
  res.json(document(followUp));
}));

module.exports = router;
