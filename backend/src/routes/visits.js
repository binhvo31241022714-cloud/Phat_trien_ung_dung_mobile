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
  const visit = await getRecordOrThrow('visits', req.params.id);
  await assertRecordAccess(req.user.uid, visit);
  res.json(document(visit));
}));

router.get('/:id/prescriptions', auth, asyncHandler(async (req, res) => {
  const visit = await getRecordOrThrow('visits', req.params.id);
  await assertRecordAccess(req.user.uid, visit);
  const snapshot = await db.collection('prescriptions')
    .where('visitId', '==', req.params.id)
    .get();
  res.json(snapshot.docs
    .filter((doc) => doc.data().patientId === visit.data.patientId)
    .map((doc) => ({ id: doc.id, ...doc.data() })));
}));

module.exports = router;
