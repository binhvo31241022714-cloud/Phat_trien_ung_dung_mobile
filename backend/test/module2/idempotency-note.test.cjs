const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('./support/fakeFirestore.cjs');

const fake = createFakeDb();
installFakeFirebase(fake);
const { toVietnamDateKey } = require('../../src/utils/booking');

const DAY = toVietnamDateKey(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
const vn = (time) => new Date(`${DAY}T${time}:00+07:00`);
const KEY = 'a1b2c3d4-0000-4000-8000-123456789abc';

let server, base;
before(async () => {
  const app = express(); app.use(express.json());
  app.use('/api/appointments', require('../../src/routes/appointments'));
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/appointments`;
});
after(() => new Promise((resolve) => server.close(resolve)));
beforeEach(() => fake.reset({
  'doctors/doc_01': { name: 'BS A', isActive: true, serviceIds: ['svc_01'] },
  'services/svc_01': { name: 'Khám', price: 100000, durationMinutes: 30 },
  'users/A': { fullName: 'A' },
  'users/B': { fullName: 'B' },
  'vouchers/GIAM10': { code: 'GIAM10', discountType: 'percent', discountValue: 10, usageLimit: 5, usedCount: 0,
    startsAt: new Date('2020-01-01'), endsAt: new Date('2099-01-01') },
  'doctor_schedules/s1': { doctorId: 'doc_01', startAt: vn('08:00'), endAt: vn('12:00'), slotMinutes: 30, isAvailable: true },
}));

async function book(body = {}, { key, token = 'A' } = {}) {
  const r = await fetch(base, { method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}`,
      ...(key !== undefined ? { 'idempotency-key': key } : {}) },
    body: JSON.stringify({ serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00', ...body }) });
  return { status: r.status, body: await r.json() };
}
const count = (prefix) => fake.paths(prefix).length;

test('A13: ghi chú được cắt khoảng trắng, lưu và trả về; không gửi thì rỗng', async () => {
  const r = await book({ note: '  Tôi hay ê buốt răng  ' });
  assert.equal(r.status, 201);
  assert.equal(r.body.note, 'Tôi hay ê buốt răng');
  assert.equal(fake.store[`appointments/${r.body.id}`].note, 'Tôi hay ê buốt răng');
  const empty = await book({ startTime: '10:00' });
  assert.equal(empty.body.note, '');
  const nul = await book({ startTime: '10:30', note: null });
  assert.equal(nul.body.note, '');
  const get = await fetch(`${base}/${r.body.id}`, { headers: { authorization: 'Bearer A' } });
  assert.equal((await get.json()).note, 'Tôi hay ê buốt răng');
});

test('A13: ghi chú sai kiểu hoặc quá 500 ký tự trả 400, không tạo lịch', async () => {
  for (const note of [123, ['a'], { a: 1 }, 'x'.repeat(501)]) {
    const r = await book({ note });
    assert.equal(r.status, 400, JSON.stringify(note).slice(0, 20));
  }
  assert.equal((await book({ note: `  ${'x'.repeat(500)}  ` })).status, 201);
  assert.equal(count('appointments/'), 1);
});

test('A13: staff xem lịch chờ thấy ghi chú', async () => {
  await book({ note: 'Đến muộn 10 phút' });
  const r = await fetch(`${base}/staff?date=${DAY}`, { headers: { authorization: 'Bearer staff' } });
  assert.equal((await r.json())[0].note, 'Đến muộn 10 phút');
});

test('A11: gửi lại cùng key trả 201 cùng lịch, không tạo thêm lịch, thông báo, lượt voucher', async () => {
  const first = await book({ voucherCode: 'GIAM10', note: 'n' }, { key: KEY });
  assert.equal(first.status, 201);
  const again = await book({ voucherCode: 'GIAM10', note: 'n' }, { key: KEY });
  assert.equal(again.status, 201);
  assert.equal(again.body.id, first.body.id);
  assert.equal(again.body.note, 'n');
  assert.equal(again.body.voucherCode, 'GIAM10');
  assert.equal(count('appointments/'), 1);
  assert.equal(count('notifications/'), 1);
  assert.equal(fake.store['vouchers/GIAM10'].usedCount, 1);
  const request = fake.store[`appointment_requests/A_${KEY}`];
  assert.equal(request.appointmentId, first.body.id);
  assert.equal(request.accountId, 'A');
});

test('A11: hai lần gửi cùng key chạy đồng thời chỉ tạo 1 lịch', async () => {
  fake.interleave(2);
  const [x, y] = await Promise.all([book({}, { key: KEY }), book({}, { key: KEY })]);
  assert.deepEqual([x.status, y.status], [201, 201]);
  assert.equal(x.body.id, y.body.id);
  assert.equal(count('appointments/'), 1);
  assert.equal(count('notifications/'), 1);
  assert.ok(fake.state.conflicts >= 1);
});

test('A11: cùng key khác nội dung trả 409, không tạo lịch mới', async () => {
  await book({}, { key: KEY });
  for (const change of [{ startTime: '10:00' }, { note: 'khác' }, { doctorId: '' }]) {
    const r = await book(change, { key: KEY });
    assert.equal(r.status, 409);
    assert.equal(r.body.message, 'Mã yêu cầu đã dùng cho một lịch khác');
  }
  assert.equal(count('appointments/'), 1);
});

test('A11: key của tài khoản khác không đụng nhau', async () => {
  const a = await book({}, { key: KEY });
  const b = await book({ startTime: '10:00' }, { key: KEY, token: 'B' });
  assert.equal(b.status, 201);
  assert.notEqual(a.body.id, b.body.id);
});

test('A11: key không hợp lệ trả 400; không gửi key thì chạy như cũ', async () => {
  for (const key of ['', 'short', 'a'.repeat(101), 'abc.defgh', 'abc%defgh', 'abc/defgh', 'abc defgh']) {
    assert.equal((await book({}, { key })).status, 400, key);
  }
  assert.equal(count('appointments/'), 0);
  const first = await book();
  assert.equal(first.status, 201);
  assert.equal((await book()).status, 409);
  assert.equal(count('appointment_requests/'), 0);
});

test('A11: thất bại thì không ghi yêu cầu, gửi lại cùng key sau khi sửa được lỗi vẫn tạo được', async () => {
  fake.store['doctor_schedules/s1'].isAvailable = false;
  assert.equal((await book({}, { key: KEY })).status, 409);
  assert.equal(count('appointment_requests/'), 0);
  fake.store['doctor_schedules/s1'].isAvailable = true;
  assert.equal((await book({}, { key: KEY })).status, 201);
});
