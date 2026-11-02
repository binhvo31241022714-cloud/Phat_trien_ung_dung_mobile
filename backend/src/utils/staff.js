// AUD-14: một chính sách nhân viên duy nhất cho mọi endpoint.
// Nhân viên khi custom claim có role "staff" hoặc "admin", hoặc staff/admin là true.
// scripts/set-staff.js gán role: "staff".
function isStaff(claims) {
  if (!claims || typeof claims !== 'object') return false;
  return claims.role === 'staff' || claims.role === 'admin' ||
    claims.staff === true || claims.admin === true;
}

module.exports = { isStaff };
