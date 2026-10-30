// A12: test luồng đặt lịch đầy đủ trên Firestore giả (không ghi Firestore thật).
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('./support/fakeFirestore.cjs');

const fake = createFakeDb();
installFakeFirebase(fake);
const { toVietnamDateKey, getSlotLockRefs } = require('../../src/utils/booking');

const dayAfter = (n) => toVietnamDateKey(new Date(Date.now() + n * 24 * 60 * 60 * 1000));
const DAY = dayAfter(7);
const NO_SCHEDULE_DAY = dayAfter(8);
const vn = (date, time) => new Date(`${date}T${time}:00+07:00`);
const shift = (doctorId, extra = {}) => ({ doctorId, startAt: vn(DAY, '08:00'), endAt: vn(DAY, '12:00'),
  slotMinutes: 30, isAvailable: true, ...extra });
const voucher = (extra = {}) => ({ discountType: 'percent', discountValue: 10, usageLimit: 5, usedCount: 0,
  minOrderAmount: 0, startsAt: new Date('2020-01-01'), endsAt: new Date('2099-01-01'), ...extra });

let server, base;
before(async () => {
  const app = express(); app.use(express.json());
  app.use('/api/appointments', require('../../src/routes/appointments'));
  app.use('/api/vouchers', require('../../src/routes/vouchers'));
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise((resolve) => server.close(resolve)));
beforeEach(() => fake.reset({
  'doctors/doc_01': { name: 'BS A', isActive: true, serviceIds: ['svc_01', 'svc_02'] },
  'doctors/doc_02': { name: 'BS B', isActive: true, serviceIds: ['svc_01'] },
  'services/svc_01': { name: 'Khám', price: 100000, durationMinutes: 30 },
  'services/svc_02': { name: 'Lấy cao răng', price: 300000, durationMinutes: 60 },
  'users/A': { fullName: 'A' },
  'users/B': { fullName: 'B' },
  'doctor_schedules/s1': shift('doc_01'),
  'doctor_schedules/s2': shift('doc_02'),
  'vouchers/GIAM10': { code: 'GIAM10', ...voucher() },
  'vouchers/HETHAN': { code: 'HETHAN', ...voucher({ endsAt: new Date('2021-01-01') }) },
  'vouchers/CHUATOI': { code: 'CHUATOI', ...voucher({ startsAt: new Date('2099-01-01'), endsAt: new Date('2099-12-31') }) },
  'vouchers/HETLUOT': { code: 'HETLUOT', ...voucher({ usageLimit: 3, usedCount: 3 }) },
  'vouchers/TOITHIEU': { code: 'TOITHIEU', ...voucher({ minOrderAmount: 500000 }) },
  'vouchers/MOTLAN': { code: 'MOTLAN', ...voucher({ usageLimit: 1 }) },
}));

async function call(method, path, { token = 'A', body } = {}) {
  const r = await fetch(`${base}${path}`, { method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status: r.status, body: await r.json() };
}
const book = (body = {}, opts = {}) => call('POST', '/appointments', { ...opts,
  body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00', ...body } });
const count = (prefix) => fake.paths(prefix).length;
const lockIds = (doctorId, start, end) => getSlotLockRefs(doctorId, DAY, start, end).map((l) => `appointment_slots/${l.ref.id}`);
const usedCount = (code) => fake.store[`vouchers/${code}`].usedCount;

test('tạo lịch thành công: lưu đủ trường, giữ slot 15 phút, tạo 1 thông báo', async () => {
  const r = await book({ note: 'n' });
  assert.equal(r.status, 201);
  const saved = fake.store[`appointments/${r.body.id}`];
  assert.deepEqual(
    { ...saved, createdAt: undefined, slotKeys: undefined },
    { accountId: 'A', patientId: 'A', doctorId: 'doc_01', doctorName: 'BS A', serviceIds: ['svc_01'],
      comboId: null, date: DAY, startTime: '09:00', endTime: '09:30', durationMinutes: 30,
      totalPrice: 100000, discount: 0, voucherCode: null, note: 'n', status: 'booked',
      createdAt: undefined, slotKeys: undefined },
  );
  assert.ok(saved.createdAt instanceof Date);
  const locks = lockIds('doc_01', 540, 570);
  assert.equal(locks.length, 2);
  assert.ok(locks.every((p) => fake.store[p]?.appointmentId === r.body.id));
  const notices = fake.paths('notifications/').map((p) => fake.store[p]);
  assert.equal(notices.length, 1);
  assert.equal(notices[0].type, 'appointment_booked');
  assert.equal(notices[0].userId, 'A');
  assert.equal(notices[0].refId, r.body.id);
});

test('không chọn bác sĩ: hệ thống chọn bác sĩ còn trống làm được dịch vụ', async () => {
  await book();
  const r = await book({ doctorId: undefined }, { token: 'B' });
  assert.equal(r.status, 201);
  assert.equal(r.body.doctorId, 'doc_02');
  // Dịch vụ chỉ doc_01 làm được mà doc_01 đã bận: 409.
  assert.equal((await book({ doctorId: undefined, serviceIds: ['svc_02'], startTime: '08:30' })).status, 409);
});

test('thiếu hoặc sai dữ liệu: 400/401/404, không ghi gì', async () => {
  const cases = [
    [{ serviceIds: [] }, 400],
    [{ serviceIds: 'svc_01' }, 400],
    [{ date: '' }, 400],
    [{ date: '2026-02-30' }, 400],
    [{ startTime: '' }, 400],
    [{ startTime: '9h' }, 400],
    [{ date: '2020-01-01' }, 400],
    [{ serviceIds: ['khong_co'] }, 404],
    [{ doctorId: 'khong_co' }, 404],
    [{ serviceIds: ['svc_02'], doctorId: 'doc_02' }, 400],
  ];
  for (const [body, status] of cases) {
    const r = await book(body);
    assert.equal(r.status, status, JSON.stringify(body));
    assert.equal(typeof r.body.message, 'string');
  }
  assert.equal((await book({}, { token: null })).status, 401);
  assert.equal(count('appointments/'), 0);
  assert.equal(count('appointment_slots/'), 0);
  assert.equal(count('notifications/'), 0);
});

test('ngoài lịch làm việc: 409', async () => {
  const cases = [
    { startTime: '07:30' }, // trước ca
    { startTime: '13:00' }, // sau ca
    { startTime: '11:30', serviceIds: ['svc_02'] }, // 60 phút vượt quá 12:00
    { startTime: '09:10' }, // lệch bước 30 phút
    { date: NO_SCHEDULE_DAY }, // ngày không có ca
  ];
  for (const body of cases) {
    assert.equal((await book(body)).status, 409, JSON.stringify(body));
  }
  fake.store['doctor_schedules/s1'].isAvailable = false;
  assert.equal((await book()).status, 409, 'ca đã tắt');
  assert.equal(count('appointments/'), 0);
});

test('trùng giờ: 409, kể cả lịch dài chồng một phần và tài khoản khác', async () => {
  assert.equal((await book()).status, 201);
  assert.equal((await book()).status, 409);
  assert.equal((await book({}, { token: 'B' })).status, 409);
  assert.equal((await book({ serviceIds: ['svc_02'], startTime: '08:30' })).status, 409);
  assert.equal((await book({ startTime: '09:30' })).status, 201, 'khung kế tiếp vẫn trống');
  assert.equal(count('appointments/'), 2);
});

test('hai yêu cầu cùng khung giờ chạy đồng thời: chỉ một thành công', async () => {
  fake.interleave(2);
  const results = await Promise.all([book({}, { token: 'A' }), book({}, { token: 'B' })]);
  assert.deepEqual(results.map((r) => r.status).sort(), [201, 409]);
  assert.ok(fake.state.conflicts >= 1, 'transaction thua phải bị chạy lại');
  assert.equal(count('appointments/'), 1);
  assert.equal(count('notifications/'), 1);
  const winner = results.find((r) => r.status === 201).body.id;
  assert.ok(lockIds('doc_01', 540, 570).every((p) => fake.store[p].appointmentId === winner));
});

test('hai yêu cầu đồng thời dùng lượt voucher cuối: chỉ một được giảm giá', async () => {
  fake.interleave(2);
  const results = await Promise.all([
    book({ voucherCode: 'MOTLAN' }),
    book({ voucherCode: 'MOTLAN', startTime: '10:00' }, { token: 'B' }),
  ]);
  assert.deepEqual(results.map((r) => r.status).sort(), [201, 400]);
  assert.match(results.find((r) => r.status === 400).body.message, /hết lượt/);
  assert.equal(usedCount('MOTLAN'), 1);
  assert.equal(count('appointments/'), 1);
});

test('hủy lịch: giải phóng slot, người khác đặt lại được; không phải chủ thì 403', async () => {
  const r = await book();
  assert.equal((await call('PATCH', `/appointments/${r.body.id}/cancel`, { token: 'B' })).status, 403);
  const cancel = await call('PATCH', `/appointments/${r.body.id}/cancel`);
  assert.equal(cancel.status, 200);
  assert.equal(fake.store[`appointments/${r.body.id}`].status, 'cancelled');
  assert.ok(lockIds('doc_01', 540, 570).every((p) => !fake.store[p]));
  assert.equal((await call('PATCH', `/appointments/${r.body.id}/cancel`)).status, 400, 'hủy lần hai');
  const again = await book({}, { token: 'B' });
  assert.equal(again.status, 201);
  assert.ok(lockIds('doc_01', 540, 570).every((p) => fake.store[p].appointmentId === again.body.id));
});

test('voucher hợp lệ: giảm giá đúng, tăng 1 lượt; kiểm tra trước bằng /vouchers/validate', async () => {
  const check = await call('POST', '/vouchers/validate', { token: null, body: { code: 'giam10', serviceIds: ['svc_01'] } });
  assert.equal(check.status, 200);
  assert.deepEqual([check.body.discount, check.body.totalPrice], [10000, 90000]);
  assert.equal(usedCount('GIAM10'), 0, 'validate không trừ lượt');
  const r = await book({ voucherCode: 'giam10' });
  assert.equal(r.status, 201);
  assert.deepEqual([r.body.voucherCode, r.body.discount, r.body.totalPrice], ['GIAM10', 10000, 90000]);
  assert.equal(usedCount('GIAM10'), 1);
});

test('voucher không dùng được: 400, không tạo lịch, không đổi lượt', async () => {
  const cases = [
    ['HETHAN', /hết hạn/],
    ['CHUATOI', /chưa đến thời gian/],
    ['HETLUOT', /hết lượt/],
    ['TOITHIEU', /tối thiểu/],
    ['KHONGCO', /không tồn tại/],
  ];
  for (const [code, message] of cases) {
    const viaValidate = await call('POST', '/vouchers/validate', { token: null, body: { code, serviceIds: ['svc_01'] } });
    assert.equal(viaValidate.status, 400, code);
    const r = await book({ voucherCode: code });
    assert.equal(r.status, 400, code);
    assert.match(r.body.message, message, code);
  }
  assert.equal(usedCount('HETLUOT'), 3);
  assert.equal(count('appointments/'), 0);
  assert.equal(count('appointment_slots/'), 0);
});

test('trả lượt voucher khi bệnh nhân hủy và khi phòng khám từ chối', async () => {
  const a = await book({ voucherCode: 'GIAM10' });
  const b = await book({ voucherCode: 'GIAM10', startTime: '10:00' });
  assert.equal(usedCount('GIAM10'), 2);
  assert.equal((await call('PATCH', `/appointments/${a.body.id}/cancel`)).status, 200);
  assert.equal(usedCount('GIAM10'), 1);
  const reject = await call('PATCH', `/appointments/${b.body.id}/status`,
    { token: 'staff', body: { status: 'rejected', reason: 'Bác sĩ nghỉ' } });
  assert.equal(reject.status, 200);
  assert.equal(usedCount('GIAM10'), 0);
  assert.ok(lockIds('doc_01', 600, 630).every((p) => !fake.store[p]), 'từ chối cũng giải phóng slot');
  // Đã hủy/từ chối rồi thì không trả thêm lượt.
  await call('PATCH', `/appointments/${a.body.id}/cancel`);
  await call('PATCH', `/appointments/${b.body.id}/status`, { token: 'staff', body: { status: 'rejected', reason: 'x' } });
  assert.equal(usedCount('GIAM10'), 0);
});

test('hủy lịch không dùng voucher không đụng tới voucher nào', async () => {
  const r = await book();
  await call('PATCH', `/appointments/${r.body.id}/cancel`);
  assert.equal(usedCount('GIAM10'), 0);
  assert.equal(usedCount('HETLUOT'), 3);
});
