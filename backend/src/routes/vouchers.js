const router = require('express').Router();
const {
  asyncHandler,
  buildBookingQuote,
  findVoucherRef,
  validateVoucherSnapshot,
} = require('../utils/booking');

// POST /api/vouchers/validate
// Body: { code, serviceIds?: string[], comboId?: string }
// Ưu tiên tính giá từ Firestore dựa trên serviceIds/comboId; có thể truyền subtotal nếu kiểm tra nhanh.
router.post('/validate', asyncHandler(async (req, res) => {
  const code = String((req.body || {}).code || (req.body || {}).voucherCode || '').trim();
  if (!code) return res.status(400).json({ message: 'Vui lòng nhập mã giảm giá' });

  let subtotal;
  if ((Array.isArray(req.body?.serviceIds) && req.body.serviceIds.length > 0) || req.body?.comboId) {
    const quote = await buildBookingQuote(req.body || {});
    subtotal = quote.subtotal;
  } else if (Number.isFinite(Number(req.body?.subtotal)) && Number(req.body.subtotal) >= 0) {
    subtotal = Number(req.body.subtotal);
  } else if (Number.isFinite(Number(req.body?.amount)) && Number(req.body.amount) >= 0) {
    subtotal = Number(req.body.amount);
  } else {
    return res.status(400).json({ message: 'Chọn ít nhất một dịch vụ hoặc một combo' });
  }

  const voucherRef = await findVoucherRef(code);
  if (!voucherRef) return res.status(400).json({ message: 'Mã giảm giá không tồn tại' });
  const voucherSnap = await voucherRef.get();
  const voucher = validateVoucherSnapshot(voucherSnap, subtotal);

  res.json({
    valid: true,
    code: voucher.code,
    discountType: voucher.discountType,
    discountValue: voucher.discountValue,
    subtotal,
    discount: voucher.discount,
    totalPrice: voucher.totalPrice,
  });
}));

module.exports = router;
