// Dùng sau auth: chỉ cho tài khoản có custom claim { role: "staff" } đi tiếp.
// Gán quyền bằng scripts/set-staff.js; người được gán phải đăng nhập lại.
module.exports = (req, res, next) => {
  if (req.user?.role !== 'staff') {
    return res.status(403).json({ message: 'Chỉ nhân viên phòng khám được thực hiện thao tác này' });
  }
  next();
};
