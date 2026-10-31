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
const { decodeImage, mediaDocument, mediaUrl } = require('../utils/media');
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

const MAX_PHOTOS_PER_TREATMENT = 30;
const PHOTO_PHASES = ['before', 'after'];
const isStaff = (req) => req.user.role === 'staff';

// Ảnh có trong media mới xóa được; người tải lên hoặc staff mới được xóa.
function photoView(doc, req) {
  const data = doc.data();
  const view = { id: doc.id, ...data };
  if (data.mediaId) {
    view.imageUrl = mediaUrl(data.mediaId);
    view.type = data.phase;
    view.canDelete = data.createdBy === req.user.uid || isStaff(req);
  } else {
    view.canDelete = false;
  }
  return view;
}

// GET /api/treatments/:id/photos - ảnh cũ (photos, treatment_photos, mảng trong
// treatment) và ảnh mới tải lên (treatment_photos có mediaId). Bệnh nhân hoặc staff.
router.get('/:id/photos', auth, asyncHandler(async (req, res) => {
  const treatment = await getRecordOrThrow('treatments', req.params.id);
  if (!isStaff(req)) await assertRecordAccess(req.user.uid, treatment);

  const [photosSnapshot, treatmentPhotosSnapshot] = await Promise.all([
    db.collection('photos').where('treatmentId', '==', req.params.id).get(),
    db.collection('treatment_photos').where('treatmentId', '==', req.params.id).get(),
  ]);
  const storedPhotos = [
    ...photosSnapshot.docs,
    ...treatmentPhotosSnapshot.docs,
  ]
    .filter((doc) => doc.data().patientId === treatment.data.patientId)
    .map((doc) => photoView(doc, req));

  const embeddedPhotos = Array.isArray(treatment.data.photos)
    ? treatment.data.photos
    : [];
  res.json([
    ...storedPhotos,
    ...embeddedPhotos.map((photo, index) => ({
      id: `${req.params.id}_photo_${index + 1}`, ...photo, canDelete: false,
    })),
  ]);
}));

// POST /api/treatments/:id/photos - body { phase: "before" | "after", sessionId?, image, mimeType?, note? }
// Chủ tài khoản (bản thân hoặc người thân còn hoạt động) hoặc staff. Tối đa 30 ảnh mỗi liệu trình.
router.post('/:id/photos', auth, asyncHandler(async (req, res) => {
  const body = req.body || {};
  if (!PHOTO_PHASES.includes(body.phase)) throw fail(400, 'phase phải là "before" hoặc "after"');
  const sessionId = optionalId(body.sessionId, 'sessionId');
  const note = optionalText(body.note, 'Ghi chú', 500);
  const image = decodeImage(body);

  const photoRef = db.collection('treatment_photos').doc();
  const mediaRef = db.collection('media').doc();
  const result = await db.runTransaction(async (transaction) => {
    const treatmentSnap = await transaction.get(db.collection('treatments').doc(req.params.id));
    if (!treatmentSnap.exists) throw fail(404, 'Không tìm thấy liệu trình');
    const treatment = treatmentSnap.data();
    const patientId = treatment.patientId;
    let ownerAccountId;
    if (isStaff(req)) {
      ownerAccountId = treatment.accountId ||
        ((await transaction.get(db.collection('users').doc(patientId))).exists ? patientId : null);
      if (!ownerAccountId) throw fail(400, 'Liệu trình chưa gắn tài khoản bệnh nhân (thiếu accountId)');
    } else {
      const uid = req.user.uid;
      if (treatment.accountId && treatment.accountId !== uid) {
        throw fail(403, 'Bạn không có quyền với liệu trình này');
      }
      if (patientId !== uid) {
        const member = await transaction.get(db.collection('users').doc(uid)
          .collection('family_members').doc(patientId));
        if (!member.exists) throw fail(403, 'Bạn không có quyền với liệu trình này');
        if (member.data().isArchived === true) {
          throw fail(403, 'Người thân đã bị xóa: chỉ xem được ảnh cũ, không tải ảnh mới');
        }
      }
      ownerAccountId = uid;
    }
    if (sessionId) {
      const session = await transaction.get(db.collection('treatment_sessions').doc(sessionId));
      if (!session.exists || session.data().treatmentId !== treatmentSnap.id) {
        throw fail(400, 'Buổi điều trị không thuộc liệu trình này');
      }
    }
    const existing = await transaction.get(db.collection('treatment_photos')
      .where('treatmentId', '==', treatmentSnap.id));
    if (existing.docs.length >= MAX_PHOTOS_PER_TREATMENT) {
      throw fail(409, `Liệu trình đã đủ ${MAX_PHOTOS_PER_TREATMENT} ảnh, hãy xóa bớt ảnh cũ`);
    }

    const now = new Date();
    transaction.set(mediaRef, mediaDocument({
      image, ownerAccountId, patientId, kind: 'treatment_photo', createdBy: req.user.uid, now,
    }));
    const photo = {
      treatmentId: treatmentSnap.id,
      patientId,
      accountId: ownerAccountId,
      phase: body.phase,
      sessionId,
      note,
      mediaId: mediaRef.id,
      mimeType: image.mimeType,
      size: image.buffer.length,
      createdBy: req.user.uid,
      createdByRole: isStaff(req) ? 'staff' : 'patient',
      createdAt: now,
    };
    transaction.set(photoRef, photo);
    return photo;
  });
  res.status(201).json({
    id: photoRef.id, ...result, imageUrl: mediaUrl(mediaRef.id), type: result.phase, canDelete: true,
  });
}));

// DELETE /api/treatments/:id/photos/:photoId - người tải lên hoặc staff. Xóa cả media.
router.delete('/:id/photos/:photoId', auth, asyncHandler(async (req, res) => {
  await db.runTransaction(async (transaction) => {
    const photoRef = db.collection('treatment_photos').doc(req.params.photoId);
    const snap = await transaction.get(photoRef);
    if (!snap.exists || snap.data().treatmentId !== req.params.id) throw fail(404, 'Không tìm thấy ảnh');
    const photo = snap.data();
    if (!photo.mediaId) throw fail(409, 'Ảnh cũ của phòng khám, không xóa được trong ứng dụng');
    if (photo.createdBy !== req.user.uid && !isStaff(req)) {
      throw fail(403, 'Chỉ người tải ảnh lên hoặc nhân viên phòng khám được xóa ảnh này');
    }
    transaction.delete(db.collection('media').doc(photo.mediaId));
    transaction.delete(photoRef);
  });
  res.json({ message: 'Đã xóa ảnh', id: req.params.photoId });
}));

module.exports = router;
