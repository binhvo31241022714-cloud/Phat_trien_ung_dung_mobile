const router = require('express').Router();
const auth = require('../middleware/auth');
const requireStaff = require('../middleware/requireStaff');
const {
  LIMITS,
  isPlainObject,
  optionalText,
  requiredText,
  optionalId,
  optionalDate,
  assertActivePatient,
  treatmentStatusFor,
} = require('../utils/clinical');
const {
  db,
  getRecordOrThrow,
  assertRecordAccess,
  document,
  documents,
  asyncHandler,
} = require('../utils/records');

const isCompleted = (data) => String(data.status || '').toLowerCase() === 'completed';
const fail = (status, message) => Object.assign(new Error(message), { status });

// Sau khi buổi justCompletedId xong: planned → in_progress → completed theo số buổi.
function updateTreatmentStatus(transaction, treatment, sessionDocs, justCompletedId) {
  const completed = sessionDocs.filter((doc) =>
    doc.id === justCompletedId || isCompleted(doc.data())).length;
  const total = Math.max(sessionDocs.length, Number(treatment.data.totalSessions) || 0);
  const status = treatmentStatusFor(completed, total);
  if (status !== treatment.data.status) {
    transaction.update(treatment.ref, { status, updatedAt: new Date() });
  }
  return status;
}

// POST /api/treatments - staff tạo liệu trình kèm các buổi dự kiến.
// Body: { accountId, patientId?, doctorId?, name, diagnosis?, startAt?, endAt?,
//         sessions: [{ scheduledAt?, notes? }] }
router.post('/', auth, requireStaff, asyncHandler(async (req, res) => {
  const body = req.body || {};
  const accountId = optionalId(body.accountId, 'accountId');
  if (!accountId) throw fail(400, 'Thiếu accountId');
  const patientId = optionalId(body.patientId, 'patientId') || accountId;
  const doctorId = optionalId(body.doctorId, 'doctorId');
  const name = requiredText(body.name, 'tên liệu trình');
  const diagnosis = optionalText(body.diagnosis, 'Chẩn đoán');
  let startAt = optionalDate(body.startAt, 'startAt');
  let endAt = optionalDate(body.endAt, 'endAt');
  if (!Array.isArray(body.sessions) || body.sessions.length === 0) {
    throw fail(400, 'sessions phải là mảng có ít nhất 1 buổi');
  }
  if (body.sessions.length > LIMITS.sessions) {
    throw fail(400, `Liệu trình tối đa ${LIMITS.sessions} buổi`);
  }
  const plannedSessions = body.sessions.map((item, index) => {
    const label = `buổi ${index + 1}`;
    if (!isPlainObject(item)) throw fail(400, `Dữ liệu ${label} phải là object`);
    return {
      scheduledAt: optionalDate(item.scheduledAt, `Ngày ${label}`),
      notes: optionalText(item.notes, `Ghi chú ${label}`, 1000),
    };
  });
  const times = plannedSessions.filter((s) => s.scheduledAt).map((s) => s.scheduledAt.getTime());
  startAt = startAt || (times.length ? new Date(Math.min(...times)) : null);
  endAt = endAt || (times.length ? new Date(Math.max(...times)) : null);
  if (startAt && endAt && endAt < startAt) throw fail(400, 'endAt phải sau startAt');

  const treatmentRef = db.collection('treatments').doc();
  const result = await db.runTransaction(async (transaction) => {
    await assertActivePatient(transaction, accountId, patientId);
    let doctorName = '';
    if (doctorId) {
      const doctorSnap = await transaction.get(db.collection('doctors').doc(doctorId));
      if (!doctorSnap.exists) throw fail(400, 'Không tìm thấy bác sĩ');
      doctorName = doctorSnap.data().name || '';
    }
    const now = new Date();
    const treatment = {
      patientId,
      accountId,
      doctorId,
      doctorName,
      name,
      diagnosis,
      status: 'planned',
      startAt,
      endAt,
      totalSessions: plannedSessions.length,
      createdBy: req.user.uid,
      createdAt: now,
      updatedAt: now,
    };
    transaction.set(treatmentRef, treatment);
    const sessions = plannedSessions.map((planned, index) => {
      const ref = db.collection('treatment_sessions').doc(`${treatmentRef.id}_s${index + 1}`);
      const session = {
        treatmentId: treatmentRef.id,
        patientId,
        accountId,
        doctorId,
        sessionNumber: index + 1,
        scheduledAt: planned.scheduledAt,
        notes: planned.notes,
        status: 'planned',
        visitId: null,
        appointmentId: null,
        createdAt: now,
      };
      transaction.set(ref, session);
      return { id: ref.id, ...session };
    });
    return { id: treatmentRef.id, ...treatment, sessions };
  });
  res.status(201).json(result);
}));

// PATCH /api/treatments/:id/sessions/:sessionId - staff đánh dấu buổi đã làm.
// Body: { status: "completed", visitId, notes? }. Visit phải đã hoàn tất, cùng bệnh nhân.
router.patch('/:id/sessions/:sessionId', auth, requireStaff, asyncHandler(async (req, res) => {
  const body = req.body || {};
  if (body.status !== 'completed') throw fail(400, 'status phải là "completed"');
  const visitId = optionalId(body.visitId, 'visitId');
  if (!visitId) throw fail(400, 'Thiếu visitId');
  const notes = body.notes === undefined ? undefined : optionalText(body.notes, 'Ghi chú', 1000);

  const result = await db.runTransaction(async (transaction) => {
    const treatmentSnap = await transaction.get(db.collection('treatments').doc(req.params.id));
    if (!treatmentSnap.exists) throw fail(404, 'Không tìm thấy liệu trình');
    const treatment = { ref: treatmentSnap.ref, id: treatmentSnap.id, data: treatmentSnap.data() };
    const sessionsSnapshot = await transaction.get(db.collection('treatment_sessions')
      .where('treatmentId', '==', treatment.id));
    const sessions = sessionsSnapshot.docs
      .filter((doc) => doc.data().patientId === treatment.data.patientId);
    const target = sessions.find((doc) => doc.id === req.params.sessionId);
    if (!target) throw fail(404, 'Không tìm thấy buổi điều trị trong liệu trình này');
    if (isCompleted(target.data())) throw fail(409, 'Buổi điều trị này đã hoàn tất');

    const visitSnap = await transaction.get(db.collection('visits').doc(visitId));
    if (!visitSnap.exists) throw fail(404, 'Không tìm thấy lần khám');
    const visit = visitSnap.data();
    if (!isCompleted(visit)) throw fail(400, 'Chỉ dùng được lần khám đã hoàn tất');
    if (visit.patientId !== treatment.data.patientId) {
      throw fail(400, 'Lần khám và liệu trình không cùng bệnh nhân');
    }
    const linked = await transaction.get(db.collection('treatment_sessions')
      .where('visitId', '==', visitId));
    if (linked.docs.length > 0) throw fail(409, 'Lần khám đã được gắn vào một buổi điều trị khác');

    const update = {
      status: 'completed',
      visitId,
      appointmentId: visit.appointmentId || null,
      completedAt: new Date(),
      completedBy: req.user.uid,
    };
    if (notes !== undefined) update.notes = notes;
    transaction.update(target.ref, update);
    const treatmentStatus = updateTreatmentStatus(transaction, treatment, sessions, target.id);
    return { id: target.id, ...target.data(), ...update, treatmentStatus };
  });
  res.json(result);
}));

router.get('/:id', auth, asyncHandler(async (req, res) => {
  const treatment = await getRecordOrThrow('treatments', req.params.id);
  await assertRecordAccess(req.user.uid, treatment);
  res.json(document(treatment));
}));

router.get('/:id/sessions', auth, asyncHandler(async (req, res) => {
  const treatment = await getRecordOrThrow('treatments', req.params.id);
  await assertRecordAccess(req.user.uid, treatment);
  const snapshot = await db.collection('treatment_sessions')
    .where('treatmentId', '==', req.params.id)
    .get();
  res.json(snapshot.docs
    .filter((doc) => doc.data().patientId === treatment.data.patientId)
    .map((doc) => ({ id: doc.id, ...doc.data() })));
}));

router.post('/:id/sessions/link-visit', auth, asyncHandler(async (req, res) => {
  const { visitId, sessionId } = req.body || {};
  if (typeof visitId !== 'string' || !visitId.trim()) {
    const error = new Error('Thiếu visitId');
    error.status = 400;
    throw error;
  }
  if (typeof sessionId !== 'string' || !sessionId.trim()) {
    const error = new Error('Thiếu sessionId');
    error.status = 400;
    throw error;
  }

  const result = await db.runTransaction(async (transaction) => {
    // All authorization and invariant reads participate in the transaction.
    const readRecord = async (collection, id) => {
      const snapshot = await transaction.get(db.collection(collection).doc(id));
      if (!snapshot.exists) {
        const error = new Error('Không tìm thấy hồ sơ');
        error.status = 404;
        throw error;
      }
      return { ref: snapshot.ref, id: snapshot.id, data: snapshot.data() };
    };
    const assertAccess = async (record) => {
      const patientId = record.data.patientId;
      const allowed = patientId && (patientId === req.user.uid ||
        (await transaction.get(db.collection('users').doc(req.user.uid)
          .collection('family_members').doc(patientId))).exists);
      if (!allowed) {
        const error = new Error('Bạn không có quyền xem hồ sơ này');
        error.status = 403;
        throw error;
      }
    };
    const treatment = await readRecord('treatments', req.params.id);
    const visit = await readRecord('visits', visitId.trim());
    await assertAccess(treatment);
    await assertAccess(visit);

    if (treatment.data.patientId !== visit.data.patientId) {
      const error = new Error('Lần khám và liệu trình không cùng bệnh nhân');
      error.status = 400;
      throw error;
    }
    // A10: chỉ lần khám đã hoàn tất mới được tính là một buổi điều trị.
    if (!isCompleted(visit.data)) {
      const error = new Error('Chỉ thêm được lần khám đã hoàn tất');
      error.status = 400;
      throw error;
    }

    const sessionsSnapshot = await transaction.get(db.collection('treatment_sessions')
      .where('treatmentId', '==', treatment.id));
    const sessions = sessionsSnapshot.docs
      .filter((doc) => doc.data().patientId === treatment.data.patientId)
      .sort((left, right) =>
        Number(left.data().sessionNumber || 0) -
        Number(right.data().sessionNumber || 0));

    if (sessions.some((doc) => doc.data().visitId === visit.id)) {
      const error = new Error('Lần khám đã được thêm vào liệu trình này');
      error.status = 409;
      throw error;
    }

    const linkedElsewhere = await transaction.get(db.collection('treatment_sessions')
      .where('visitId', '==', visit.id));
    if (linkedElsewhere.docs.some((doc) =>
      doc.data().patientId === visit.data.patientId &&
      doc.data().treatmentId !== treatment.id)) {
      const error = new Error('Lần khám đã được thêm vào một liệu trình khác');
      error.status = 409;
      throw error;
    }

    const target = sessions.find((doc) => doc.id === sessionId.trim());
    if (!target || target.data().visitId ||
        String(target.data().status || '').toLowerCase() === 'completed') {
      const error = new Error('Buổi đã chọn không còn trống để thêm lần khám');
      error.status = 400;
      throw error;
    }

    const update = {
      visitId: visit.id,
      appointmentId: visit.data.appointmentId || null,
      status: 'completed',
      completedAt: new Date(),
    };
    transaction.update(target.ref, update);
    updateTreatmentStatus(transaction, treatment, sessions, target.id);
    return { id: target.id, ...target.data(), ...update };
  });
  res.json(result);
}));

router.get('/:id/photos', auth, asyncHandler(async (req, res) => {
  const treatment = await getRecordOrThrow('treatments', req.params.id);
  await assertRecordAccess(req.user.uid, treatment);

  const [photosSnapshot, treatmentPhotosSnapshot] = await Promise.all([
    db.collection('photos').where('treatmentId', '==', req.params.id).get(),
    db.collection('treatment_photos').where('treatmentId', '==', req.params.id).get(),
  ]);
  const storedPhotos = [
    ...photosSnapshot.docs,
    ...treatmentPhotosSnapshot.docs,
  ]
    .filter((doc) => doc.data().patientId === treatment.data.patientId)
    .map((doc) => ({ id: doc.id, ...doc.data() }));

  const embeddedPhotos = Array.isArray(treatment.data.photos)
    ? treatment.data.photos
    : [];
  res.json([
    ...storedPhotos,
    ...embeddedPhotos.map((photo, index) => ({ id: `${req.params.id}_photo_${index + 1}`, ...photo })),
  ]);
}));

module.exports = router;
