const router = require('express').Router();
const auth = require('../middleware/auth');
const {
  db,
  getRecordOrThrow,
  assertRecordAccess,
  document,
  documents,
  asyncHandler,
} = require('../utils/records');

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
