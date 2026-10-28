const router = require('express').Router();
const auth = require('../middleware/auth');
const {
  db,
  assertPatientAccess,
  documents,
  asyncHandler,
} = require('../utils/records');

router.get('/:id/visits', auth, asyncHandler(async (req, res) => {
  await assertPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('visits')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot));
}));

router.get('/:id/invoices', auth, asyncHandler(async (req, res) => {
  await assertPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('invoices')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot));
}));

router.get('/:id/treatments', auth, asyncHandler(async (req, res) => {
  await assertPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('treatments')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot));
}));

router.get('/:id/follow-ups', auth, asyncHandler(async (req, res) => {
  await assertPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('follow_ups')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot));
}));

module.exports = router;
