// Gán hoặc gỡ quyền nhân viên (custom claim role: "staff") cho một tài khoản.
//
// Gán:  node scripts/set-staff.js staff@nhakhoa.com
// Gỡ:   node scripts/set-staff.js staff@nhakhoa.com --remove
//
// Người được gán/gỡ phải đăng nhập lại thì token mới có quyền mới.
const { auth } = require('../src/config/firebase');

const email = process.argv.slice(2).find((arg) => !arg.startsWith('--'));
const remove = process.argv.includes('--remove');

async function main() {
  if (!email) {
    console.log('Cách dùng: node scripts/set-staff.js <email> [--remove]');
    process.exitCode = 1;
    return;
  }
  const user = await auth.getUserByEmail(email);
  const claims = { ...(user.customClaims || {}) };
  if (remove) delete claims.role;
  else claims.role = 'staff';
  await auth.setCustomUserClaims(user.uid, claims);

  const updated = await auth.getUser(user.uid);
  console.log(`${remove ? 'Đã gỡ' : 'Đã gán'} quyền staff cho ${email} (uid ${user.uid})`);
  console.log('Claim hiện tại:', JSON.stringify(updated.customClaims || {}));
  console.log('Lưu ý: tài khoản này cần đăng nhập lại để nhận quyền mới.');
}

main()
  .then(() => process.exit(process.exitCode || 0))
  .catch((error) => {
    console.error(error.code === 'auth/user-not-found' ? `Không tìm thấy tài khoản ${email}` : error);
    process.exit(1);
  });
