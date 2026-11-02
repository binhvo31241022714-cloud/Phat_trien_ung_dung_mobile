// Kiểm tra trước giờ demo. CHỈ ĐỌC: không ghi Firestore, không đổi quyền tài khoản.
// Chạy: cd backend && node scripts/preflight-demo.js
// Kết quả: bảng OK / CẢNH BÁO / LỖI; có LỖI thì mã thoát 1.
const fs = require('fs');
const path = require('path');
const { readEnvFile } = require('./_env');
const { vietnamDateKey } = require('./seed-schedules');

const STAFF_EMAIL = 'staff@nhakhoa.com';
const SCHEDULE_DAYS = 7;
const rows = [];
const add = (status, item, detail) => rows.push({ status, item, detail });

function addDays(dateKey, offset) {
  const [year, month, day] = dateKey.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + offset)).toISOString().slice(0, 10);
}

function toDate(value) {
  if (!value) return null;
  const date = typeof value.toDate === 'function' ? value.toDate() : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function checkEnv() {
  const example = readEnvFile('.env.example') || {};
  const env = readEnvFile('.env');
  if (!env) {
    add('LỖI', '.env', 'Không có backend/.env (tạo theo .env.example)');
  } else {
    const missingSecrets = [];
    const missingOptional = [];
    for (const [name, sample] of Object.entries(example)) {
      if (env[name]) continue;
      // Biến có giá trị mẫu (HOST, PORT) là tùy chọn; biến để trống trong mẫu là mật khẩu bắt buộc.
      (sample ? missingOptional : missingSecrets).push(name);
    }
    if (missingSecrets.length) add('LỖI', '.env', `Thiếu hoặc rỗng: ${missingSecrets.join(', ')}`);
    else add('OK', '.env', `Đủ biến bắt buộc: ${Object.keys(example).filter((n) => !example[n]).join(', ')}`);
    if (missingOptional.length) {
      add('OK', '.env', `Không có ${missingOptional.join(', ')}: không bắt buộc, server chưa đọc, dùng cổng 3000 cố định`);
    }
  }
  const key = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(key)) {
    add('OK', 'serviceAccountKey.json', 'Có file khóa Firebase');
    return true;
  }
  add('LỖI', 'serviceAccountKey.json', 'Không có file, không kiểm tra được Firestore');
  return false;
}

async function checkStaff(auth) {
  const { isStaff } = require('../src/utils/staff');
  try {
    const user = await auth.getUserByEmail(STAFF_EMAIL);
    if (isStaff(user.customClaims)) add('OK', 'Quyền staff', `${STAFF_EMAIL} có claim staff`);
    else add('LỖI', 'Quyền staff', `${STAFF_EMAIL} chưa có claim staff: chạy node scripts/set-staff.js ${STAFF_EMAIL} rồi đăng nhập lại`);
    if (user.disabled) add('LỖI', 'Quyền staff', `${STAFF_EMAIL} đang bị khóa`);
  } catch (error) {
    add('LỖI', 'Quyền staff', error.code === 'auth/user-not-found' ? `Không có tài khoản ${STAFF_EMAIL}` : error.message);
  }
}

function checkSchedules(doctors, schedules) {
  const today = vietnamDateKey(new Date());
  const days = [];
  for (let offset = 0; offset <= SCHEDULE_DAYS; offset++) {
    const dateKey = addDays(today, offset);
    // Phòng khám nghỉ Chủ nhật (seed-schedules không tạo ca Chủ nhật).
    if (new Date(`${dateKey}T00:00:00Z`).getUTCDay() !== 0) days.push(dateKey);
  }
  const covered = new Set();
  for (const doc of schedules) {
    const data = doc.data();
    const startAt = toDate(data.startAt);
    if (data.isAvailable === false || !startAt || !data.doctorId) continue;
    covered.add(`${data.doctorId}|${vietnamDateKey(startAt)}`);
  }
  let ok = true;
  for (const doctor of doctors) {
    const missing = days.filter((day) => !covered.has(`${doctor.id}|${day}`));
    if (missing.length) {
      ok = false;
      add('LỖI', 'Lịch bác sĩ', `${doctor.id} thiếu ca ngày ${missing.join(', ')}: chạy node scripts/seed-schedules.js --apply`);
    }
  }
  if (ok) add('OK', 'Lịch bác sĩ', `${doctors.length} bác sĩ có ca từ ${days[0]} đến ${days[days.length - 1]} (trừ Chủ nhật)`);
}

function checkServices(doctors, services) {
  let ok = true;
  for (const service of services) {
    const able = doctors.filter((d) => Array.isArray(d.serviceIds) && d.serviceIds.includes(service.id));
    if (!able.length) {
      ok = false;
      add('LỖI', 'Dịch vụ', `${service.id} (${service.name || ''}) không có bác sĩ nào làm được`);
    }
  }
  if (ok) add('OK', 'Dịch vụ', `${services.length} dịch vụ đều có ít nhất 1 bác sĩ`);
}

function checkCombos(doctors, combos, serviceById) {
  let ok = true;
  for (const combo of combos) {
    const ids = Array.isArray(combo.serviceIds) ? combo.serviceIds : [];
    if (!ids.length) {
      ok = false;
      add('LỖI', 'Combo', `${combo.id} thiếu danh sách serviceIds`);
      continue;
    }
    const able = doctors.filter((d) => Array.isArray(d.serviceIds) && ids.every((id) => d.serviceIds.includes(id)));
    if (!able.length) {
      ok = false;
      add('LỖI', 'Combo', `${combo.id} (${combo.name || ''}) không có bác sĩ nào làm đủ ${ids.join(', ')}`);
    }
    const missing = ids.filter((id) => !serviceById.has(id));
    if (missing.length) {
      ok = false;
      add('LỖI', 'Combo', `${combo.id} có dịch vụ không tồn tại hoặc đã tắt: ${missing.join(', ')}`);
      continue;
    }
    const total = ids.reduce((sum, id) => sum + Number(serviceById.get(id).durationMinutes || 0), 0);
    if (Number(combo.durationMinutes) !== total) {
      ok = false;
      add('CẢNH BÁO', 'Combo', `${combo.id}: thời lượng ${combo.durationMinutes} phút khác tổng dịch vụ ${total} phút (đặt lịch vẫn chạy, dùng thời lượng combo)`);
    }
  }
  if (ok) add('OK', 'Combo', `${combos.length} combo có bác sĩ làm đủ, thời lượng khớp`);
}

function checkVouchers(vouchers) {
  if (!vouchers.length) {
    add('OK', 'Voucher', 'Không có voucher nào (không bắt buộc)');
    return;
  }
  const now = new Date();
  const usable = [];
  for (const voucher of vouchers) {
    const code = String(voucher.code || voucher.id).toUpperCase();
    const startsAt = toDate(voucher.startsAt);
    const endsAt = toDate(voucher.endsAt);
    const used = Number(voucher.usedCount || 0);
    const limit = Number(voucher.usageLimit);
    let reason = '';
    if (voucher.isActive === false) reason = 'đã tắt';
    else if (!startsAt || !endsAt) reason = 'thiếu startsAt/endsAt';
    else if (now < startsAt) reason = `chưa tới ngày ${vietnamDateKey(startsAt)}`;
    else if (now > endsAt) reason = `hết hạn ${vietnamDateKey(endsAt)}`;
    else if (!Number.isFinite(limit) || used >= limit) reason = `hết lượt (${used}/${voucher.usageLimit})`;
    if (reason) add('CẢNH BÁO', 'Voucher', `${code} không dùng được: ${reason}`);
    else usable.push(`${code} (còn ${limit - used} lượt, hạn ${vietnamDateKey(endsAt)})`);
  }
  if (usable.length) add('OK', 'Voucher', `Dùng được: ${usable.join('; ')}`);
  else add('CẢNH BÁO', 'Voucher', 'Không có voucher nào đang dùng được');
}

function printTable() {
  const width = Math.max(...rows.map((r) => r.item.length), 4);
  console.log(`\n${'KẾT QUẢ'.padEnd(9)} | ${'MỤC'.padEnd(width)} | CHI TIẾT`);
  console.log(`${'-'.repeat(9)}-+-${'-'.repeat(width)}-+-${'-'.repeat(40)}`);
  for (const row of rows) console.log(`${row.status.padEnd(9)} | ${row.item.padEnd(width)} | ${row.detail}`);
  const errors = rows.filter((r) => r.status === 'LỖI').length;
  const warnings = rows.filter((r) => r.status === 'CẢNH BÁO').length;
  console.log(`\nTổng: ${errors} lỗi, ${warnings} cảnh báo. ${errors ? 'CHƯA SẴN SÀNG demo.' : 'Sẵn sàng demo.'}`);
  return errors;
}

async function main() {
  if (checkEnv()) {
    const { db, auth } = require('../src/config/firebase');
    await checkStaff(auth);
    const active = (snap) => snap.docs.filter((d) => d.data().isActive !== false).map((d) => ({ id: d.id, ...d.data() }));
    const todayStart = new Date(`${vietnamDateKey(new Date())}T00:00:00+07:00`);
    const until = new Date(todayStart.getTime() + (SCHEDULE_DAYS + 1) * 24 * 60 * 60 * 1000);
    const [doctorSnap, serviceSnap, comboSnap, voucherSnap, scheduleSnap] = await Promise.all([
      db.collection('doctors').get(),
      db.collection('services').get(),
      db.collection('combos').get(),
      db.collection('vouchers').get(),
      db.collection('doctor_schedules').where('startAt', '>=', todayStart).where('startAt', '<', until).get(),
    ]);
    const doctors = active(doctorSnap);
    const services = active(serviceSnap);
    if (!doctors.length) add('LỖI', 'Bác sĩ', 'Không có bác sĩ nào đang hoạt động');
    checkSchedules(doctors, scheduleSnap.docs);
    checkServices(doctors, services);
    checkCombos(doctors, active(comboSnap), new Map(services.map((s) => [s.id, s])));
    checkVouchers(voucherSnap.docs.map((d) => ({ id: d.id, ...d.data() })));
  }
  return printTable();
}

main()
  .then((errors) => process.exit(errors ? 1 : 0))
  .catch((error) => {
    console.error(`Không chạy được preflight: ${error.message}`);
    process.exit(1);
  });
