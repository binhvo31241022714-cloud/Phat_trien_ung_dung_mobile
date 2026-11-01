const router = require('express').Router();
const auth = require('../middleware/auth');
const {
  db,
  assertHistoryPatientAccess,
  historyOwnershipMatches,
  documents,
  asyncHandler,
} = require('../utils/records');

router.get('/:id/visits', auth, asyncHandler(async (req, res) => {
  await assertHistoryPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('visits')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot).filter(row => row.patientId === req.params.id && historyOwnershipMatches(req.user.uid, row)));
}));

router.get('/:id/invoices', auth, asyncHandler(async (req, res) => {
  await assertHistoryPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('invoices')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot).filter(row => row.patientId === req.params.id && historyOwnershipMatches(req.user.uid, row)));
}));

router.get('/:id/treatments', auth, asyncHandler(async (req, res) => {
  await assertHistoryPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('treatments')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot).filter(row => row.patientId === req.params.id && historyOwnershipMatches(req.user.uid, row)));
}));

router.get('/:id/follow-ups', auth, asyncHandler(async (req, res) => {
  await assertHistoryPatientAccess(req.user.uid, req.params.id);
  const snapshot = await db.collection('follow_ups')
    .where('patientId', '==', req.params.id)
    .get();
  res.json(documents(snapshot).filter(row => row.patientId === req.params.id && historyOwnershipMatches(req.user.uid, row)));
}));

module.exports = router;
