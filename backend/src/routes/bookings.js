const router = require('express').Router();
const {
  asyncHandler,
  buildQuoteWithVoucher,
} = require('../utils/booking');

// POST /api/bookings/quote
// Body: { serviceIds?: string[], comboId?: string, voucherCode?: string }
router.post('/quote', asyncHandler(async (req, res) => {
  const quote = await buildQuoteWithVoucher(req.body || {});
  res.json({
    serviceIds: quote.serviceIds,
    comboId: quote.comboId,
    subtotal: quote.subtotal,
    discount: quote.discount,
    totalPrice: quote.totalPrice,
    durationMinutes: quote.durationMinutes,
    voucherCode: quote.voucherCode,
  });
}));

module.exports = router;
