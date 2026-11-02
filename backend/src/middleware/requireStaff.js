const { isStaff } = require('../utils/staff');

module.exports = (req, res, next) => {
  if (isStaff(req.user)) {
    return next();
  }
  return res.status(403).json({ message: 'Chỉ nhân viên mới được thực hiện thao tác này' });
};
