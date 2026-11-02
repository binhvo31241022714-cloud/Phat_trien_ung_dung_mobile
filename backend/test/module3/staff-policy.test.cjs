// AUD-14: một chính sách nhân viên cho mọi endpoint (utils/staff.js isStaff).
// Mỗi kiểu claim nhân viên được nhận ở requireStaff, follow-up, media, ảnh liệu trình;
// tài khoản thường bị 403. Firestore giả.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('../module2/support/fakeFirestore.cjs');

const fake = createFakeDb();
installFakeFirebase(fake);
// Thêm token cho từng kiểu claim (Firestore giả mặc định chỉ có A, B, staff).
const CLAIMS = {
  'role-staff': { uid: 'S1', role: 'staff' },
  'role-admin': { uid: 'S2', role: 'admin' },
  'flag-staff': { uid: 'S3', staff: true },
  'flag-admin': { uid: 'S4', admin: true },
  patient: { uid: 'B' },
  'fake-role': { uid: 'B', role: 'Staff', staff: 'true', admin: 1 },
};
const firebase = require.cache[require.resolve('../../src/config/firebase')].exports;
firebase.auth = {
  async verifyIdToken(token) {
    if (token === 'A') return { uid: 'A' };
    if (CLAIMS[token]) return { ...CLAIMS[token] };
    throw new Error('invalid synthetic identity');
  },
};
const { isStaff } = require('../../src/utils/staff');
const { jsonBody } = require('../../src/utils/media');

const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
const STAFF_TOKENS = ['role-staff', 'role-admin', 'flag-staff', 'flag-admin'];
const NON_STAFF_TOKENS = ['patient', 'fake-role'];

let server, base;
before(async () => {
  const app = express();
  app.use(jsonBody);
  app.use('/api/appointments', require('../../src/routes/appointments'));
  app.use('/api/follow-ups', require('../../src/routes/followUps'));
  app.use('/api/media', require('../../src/routes/media'));
  app.use('/api/treatments', require('../../src/routes/treatments'));
  app.use((err, req, res, next) => res.status(500).json({ message: 'Lỗi server' }));
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => fake.reset({
  'users/A': { fullName: 'Chủ A' },
  'treatments/t1': { patientId: 'A', accountId: 'A', name: 'Niềng răng' },
  'follow_ups/f1': { accountId: 'A', patientId: 'A', status: 'suggested', scheduledAt: new Date('2099-01-07T02:00:00Z') },
  'media/m1': { ownerAccountId: 'A', patientId: 'A', kind: 'avatar', mimeType: 'image/png', data: PNG, size: 70 },
}));

async function call(path, { method = 'GET', token, body } = {}) {
  const r = await fetch(`${base}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* ảnh nhị phân */ }
  return { status: r.status, body: json };
}

test('isStaff: nhận đúng 4 kiểu claim, không nhận giá trị gần giống', () => {
  for (const token of STAFF_TOKENS) assert.equal(isStaff(CLAIMS[token]), true, token);
  for (const claims of [null, undefined, {}, { uid: 'B' }, { role: 'Staff' }, { role: 'doctor' },
    { staff: 'true' }, { admin: 1 }, { staff: false, admin: false }, 'staff']) {
    assert.equal(isStaff(claims), false, JSON.stringify(claims));
  }
});

for (const token of STAFF_TOKENS) {
  test(`${token}: được qua requireStaff, xem follow-up, media, ảnh liệu trình; tải và xóa ảnh như staff`, async () => {
    assert.equal((await call('/appointments/staff', { token })).status, 200);
    assert.equal((await call('/follow-ups/f1', { token })).status, 200);
    assert.equal((await call('/media/m1', { token })).status, 200);
    assert.equal((await call('/treatments/t1/photos', { token })).status, 200);
    const up = await call('/treatments/t1/photos', { method: 'POST', token, body: { phase: 'after', image: PNG } });
    assert.equal(up.status, 201);
    assert.equal(up.body.createdByRole, 'staff');
    // Ảnh của nhân viên thuộc tài khoản bệnh nhân.
    assert.equal(fake.store[`media/${up.body.mediaId}`].ownerAccountId, 'A');
    assert.equal((await call(`/treatments/t1/photos/${up.body.id}`, { method: 'DELETE', token })).status, 200);
  });
}

for (const token of NON_STAFF_TOKENS) {
  test(`${token}: tài khoản thường bị 403 ở mọi chỗ dành cho nhân viên, không ghi gì`, async () => {
    const old = structuredClone(fake.store);
    assert.equal((await call('/appointments/staff', { token })).status, 403);
    assert.equal((await call('/follow-ups/f1', { token })).status, 403);
    assert.equal((await call('/media/m1', { token })).status, 403);
    assert.equal((await call('/treatments/t1/photos', { token })).status, 403);
    assert.equal((await call('/treatments/t1/photos', { method: 'POST', token, body: { phase: 'after', image: PNG } })).status, 403);
    assert.equal((await call('/follow-ups', { method: 'POST', token, body: { accountId: 'A', scheduledAt: '2099-02-01', reason: 'x' } })).status, 403);
    assert.deepEqual(fake.store, old);
  });
}

test('bệnh nhân không xóa được ảnh nhân viên tải lên; nhân viên xóa được ảnh bệnh nhân', async () => {
  const staffPhoto = await call('/treatments/t1/photos', { method: 'POST', token: 'flag-admin', body: { phase: 'after', image: PNG } });
  assert.equal((await call(`/treatments/t1/photos/${staffPhoto.body.id}`, { method: 'DELETE', token: 'A' })).status, 403);
  const own = await call('/treatments/t1/photos', { method: 'POST', token: 'A', body: { phase: 'before', image: PNG } });
  assert.equal(own.status, 201);
  assert.equal(own.body.createdByRole, 'patient');
  assert.equal((await call(`/treatments/t1/photos/${own.body.id}`, { method: 'DELETE', token: 'role-admin' })).status, 200);
});
