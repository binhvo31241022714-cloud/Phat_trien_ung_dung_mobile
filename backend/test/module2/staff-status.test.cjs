const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const clone = value => value === undefined ? undefined : structuredClone(value);
let store, autoId;
function ref(path) {
  return { path, id: path.split('/').at(-1), collection: name => collection(`${path}/${name}`),
    get: async () => snap(path) };
}
function snap(path) {
  const value = clone(store[path]);
  return { id: path.split('/').at(-1), ref: ref(path), exists: value !== undefined, data: () => clone(value) };
}
function collection(path, filters = []) {
  const q = { path, filters, doc: id => ref(`${path}/${id ?? `auto_${++autoId}`}`),
    where(field, op, value) { assert.equal(op, '=='); return collection(path, [...filters, [field, value]]); },
    get: async () => ({ docs: matching(q).map(snap) }) };
  return q;
}
function matching(q) {
  return Object.keys(store).filter(p => p.slice(0, p.lastIndexOf('/')) === q.path &&
    q.filters.every(([k, v]) => store[p][k] === v)).sort();
}
const db = {
  collection,
  async runTransaction(fn) {
    const writes = [];
    const result = await fn({
      async get(r) {
        assert.equal(writes.length, 0, 'Firestore reads must precede all writes');
        return r.filters ? { docs: matching(r).map(snap) } : snap(r.path);
      },
      set(r, data) { writes.push(() => { store[r.path] = clone(data); }); },
      update(r, data) { writes.push(() => { assert.ok(store[r.path]); Object.assign(store[r.path], clone(data)); }); },
      delete(r) { writes.push(() => { delete store[r.path]; }); },
    });
    writes.forEach(write => write());
    return result;
  },
};
// Thay Firebase trước khi nạp route: không cần khóa, không gọi mạng.
const firebasePath = require.resolve('../../src/config/firebase');
require.cache[firebasePath] = { id: firebasePath, filename: firebasePath, loaded: true,
  exports: { db, auth: { async verifyIdToken(value) {
    if (value === 'patient') return { uid: 'P' };
    if (value === 'staff') return { uid: 'S', role: 'staff' };
    throw new Error('invalid synthetic identity');
  } } } };
const { getSlotLockRefs } = require('../../src/utils/booking');

const lockIds = getSlotLockRefs('doc_01', '2099-01-05', 9 * 60, 9 * 60 + 30).map(lock => lock.ref.id);
let server, base;
before(async () => {
  const app = express(); app.use(express.json());
  app.use('/api/appointments', require('../../src/routes/appointments'));
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/appointments`;
});
after(() => new Promise(resolve => server.close(resolve)));
beforeEach(() => {
  autoId = 0;
  store = {
    'appointments/a1': { accountId: 'P', patientId: 'P', doctorId: 'doc_01', date: '2099-01-05',
      startTime: '09:00', endTime: '09:30', status: 'booked', voucherCode: 'GIAM10' },
    'appointments/a2': { accountId: 'P', patientId: 'P', doctorId: 'doc_02', date: '2099-01-06',
      startTime: '10:00', endTime: '10:30', status: 'booked' },
    'appointments/a3': { accountId: 'Q', patientId: 'Q', doctorId: 'doc_02', date: '2099-01-05',
      startTime: '08:00', endTime: '08:30', status: 'confirmed' },
    'vouchers/GIAM10': { code: 'GIAM10', usedCount: 3 },
    'appointment_slots/other': { appointmentId: 'zzz' },
  };
  for (const id of lockIds) store[`appointment_slots/${id}`] = { appointmentId: 'a1', doctorId: 'doc_01', date: '2099-01-05' };
});
async function call(path, { method = 'PATCH', token = 'staff', body } = {}) {
  const r = await fetch(`${base}${path}`, { method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status: r.status, body: await r.json() };
}
const notifications = () => Object.entries(store).filter(([p]) => p.startsWith('notifications/')).sort();

test('A01: bệnh nhân tự xác nhận bị 403, không ghi gì', async () => {
  const before = clone(store);
  assert.equal((await call('/a1/status', { token: 'patient', body: { status: 'confirmed' } })).status, 403);
  assert.equal((await call('/a1/status', { token: null, body: { status: 'confirmed' } })).status, 401);
  assert.equal((await call('/staff', { method: 'GET', token: 'patient' })).status, 403);
  assert.deepEqual(store, before);
});

test('A01: xác nhận rồi hoàn tất, mỗi bước đúng 1 thông báo cho chủ tài khoản', async () => {
  const confirmed = await call('/a1/status', { body: { status: 'confirmed' } });
  assert.equal(confirmed.status, 200);
  assert.equal(store['appointments/a1'].status, 'confirmed');
  assert.equal(store['appointments/a1'].statusUpdatedBy, 'S');
  assert.ok(store['appointments/a1'].statusUpdatedAt);
  const again = await call('/a1/status', { body: { status: 'confirmed' } });
  assert.equal(again.status, 409);
  const done = await call('/a1/status', { body: { status: 'completed' } });
  assert.equal(done.status, 200);
  assert.deepEqual(notifications().map(([p, n]) => [p, n.type, n.userId, n.refId, n.isRead]), [
    // Hoàn tất tạo 1 thông báo kết quả khám, refId là visitId.
    ['notifications/a1_completed', 'visit_result', 'P', 'visit_a1', false],
    ['notifications/a1_confirmed', 'appointment_confirmed', 'P', 'a1', false],
  ]);
  // Xác nhận không giải phóng slot, không đổi voucher.
  assert.ok(lockIds.every(id => store[`appointment_slots/${id}`]));
  assert.equal(store['vouchers/GIAM10'].usedCount, 3);
});

test('A01: từ chối thiếu lý do 400; có lý do thì giải phóng slot, trả lượt voucher', async () => {
  for (const body of [{ status: 'rejected' }, { status: 'rejected', reason: '   ' }, { status: 'rejected', reason: 5 }]) {
    assert.equal((await call('/a1/status', { body })).status, 400);
  }
  assert.equal(notifications().length, 0);
  const r = await call('/a1/status', { body: { status: 'rejected', reason: ' Bác sĩ nghỉ đột xuất ' } });
  assert.equal(r.status, 200);
  assert.equal(store['appointments/a1'].status, 'rejected');
  assert.equal(store['appointments/a1'].statusReason, 'Bác sĩ nghỉ đột xuất');
  assert.ok(lockIds.every(id => !store[`appointment_slots/${id}`]));
  assert.ok(store['appointment_slots/other']);
  assert.equal(store['vouchers/GIAM10'].usedCount, 2);
  const [[, n]] = notifications();
  assert.equal(n.type, 'appointment_rejected');
  assert.match(n.body, /Bác sĩ nghỉ đột xuất/);
  // Gọi lại: 409, không trả voucher lần hai, không thêm thông báo.
  assert.equal((await call('/a1/status', { body: { status: 'rejected', reason: 'x' } })).status, 409);
  assert.equal(store['vouchers/GIAM10'].usedCount, 2);
  assert.equal(notifications().length, 1);
});

test('A01: chuyển sai trả 409, status lạ trả 400, lịch không có trả 404', async () => {
  assert.equal((await call('/a2/status', { body: { status: 'completed' } })).status, 409);
  assert.equal((await call('/a3/status', { body: { status: 'rejected', reason: 'x' } })).status, 409);
  store['appointments/a2'].status = 'cancelled';
  assert.equal((await call('/a2/status', { body: { status: 'confirmed' } })).status, 409);
  assert.equal((await call('/a1/status', { body: { status: 'cancelled' } })).status, 400);
  assert.equal((await call('/a1/status', { body: { status: 'booked' } })).status, 400);
  assert.equal((await call('/khong_co/status', { body: { status: 'confirmed' } })).status, 404);
  assert.equal(store['appointments/a1'].status, 'booked');
  assert.equal(notifications().length, 0);
});

test('A01: staff xem lịch chờ, lọc theo ngày, sắp xếp theo giờ', async () => {
  const all = await call('/staff', { method: 'GET' });
  assert.equal(all.status, 200);
  assert.deepEqual(all.body.map(a => a.id), ['a1', 'a2']);
  const day = await call('/staff?status=booked&date=2099-01-05', { method: 'GET' });
  assert.deepEqual(day.body.map(a => a.id), ['a1']);
  const confirmed = await call('/staff?status=confirmed', { method: 'GET' });
  assert.deepEqual(confirmed.body.map(a => a.id), ['a3']);
  assert.equal((await call('/staff?status=abc', { method: 'GET' })).status, 400);
  assert.equal((await call('/staff?date=05-01-2099', { method: 'GET' })).status, 400);
});

test('Hủy của bệnh nhân vẫn chạy như cũ sau khi tách hàm giải phóng', async () => {
  const r = await call('/a1/cancel', { token: 'patient' });
  assert.equal(r.status, 200);
  assert.equal(store['appointments/a1'].status, 'cancelled');
  assert.ok(lockIds.every(id => !store[`appointment_slots/${id}`]));
  assert.equal(store['vouchers/GIAM10'].usedCount, 2);
  assert.equal(notifications()[0][1].type, 'appointment_cancelled');
});
