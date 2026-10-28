const router = require('express').Router();
const auth = require('../middleware/auth');
const {
  getRecordOrThrow,
  assertRecordAccess,
  document,
  asyncHandler,
} = require('../utils/records');

router.get('/:id', auth, asyncHandler(async (req, res) => {
  const invoice = await getRecordOrThrow('invoices', req.params.id);
  await assertRecordAccess(req.user.uid, invoice);
  res.json(document(invoice));
}));

module.exports = router;
