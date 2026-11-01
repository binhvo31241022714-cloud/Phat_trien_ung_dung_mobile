module.exports = (req, res, next) => {
  const claims = req.user || {};
  if (claims.staff === true || claims.admin === true || claims.role === 'staff' || claims.role === 'admin') {
    return next();
  }
  return res.status(403).json({ message: 'Chỉ nhân viên mới được thực hiện thao tác này' });
};
