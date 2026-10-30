const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const clone = value => value === undefined ? undefined : structuredClone(value);
let store;
function ref(path) {
  return { path, id: path.split('/').at(-1), collection: name => collection(`${path}/${name}`),
    get: async () => snap(path) };
}
function snap(path) {
  const value = clone(store[path]);
  return { id: path.split('/').at(-1), ref: ref(path), exists: value !== undefined, data: () => clone(value) };
}
const ops = {
  '==': (a, b) => a === b,
  '>=': (a, b) => a instanceof Date && a.getTime() >= b.getTime(),
  '<': (a, b) => a instanceof Date && a.getTime() < b.getTime(),
};
function collection(path, filters = []) {
  const q = { path, filters, doc: id => ref(`${path}/${id}`),
    where(field, op, value) { assert.ok(ops[op], `op ${op}`); return collection(path, [...filters, [field, op, value]]); },
    get: async () => ({ docs: matching(q).map(snap) }) };
  return q;
}
function matching(q) {
  return Object.keys(store).filter(p => p.slice(0, p.lastIndexOf('/')) === q.path &&
    q.filters.every(([k, op, v]) => ops[op](store[p][k], v))).sort();
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
      update(r, data) { writes.push(() => Object.assign(store[r.path], clone(data))); },
      delete(r) { writes.push(() => { delete store[r.path]; }); },
    });
    writes.forEach(write => write());
    return result;
  },
};
let autoId = 0;
const realCollection = db.collection;
db.collection = (name) => {
  const q = realCollection(name);
  const doc = q.doc;
  q.doc = id => doc(id ?? `auto_${++autoId}`);
  return q;
};
// Thay Firebase trước khi nạp route: không cần khóa, không gọi mạng.
const firebasePath = require.resolve('../../src/config/firebase');
require.cache[firebasePath] = { id: firebasePath, filename: firebasePath, loaded: true,
  exports: { db, auth: { async verifyIdToken(value) {
    if (value === 'A') return { uid: 'A', email: 'a@test.vn' };
    throw new Error('invalid synthetic identity');
  } } } };
const { toVietnamDateKey } = require('../../src/utils/booking');

const DAY = toVietnamDateKey(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
const OTHER_DAY = toVietnamDateKey(new Date(Date.now() + 9 * 24 * 60 * 60 * 1000));
const vn = (dateKey, time) => new Date(`${dateKey}T${time}:00+07:00`);
const shift = (doctorId, dateKey, extra = {}) => ({ doctorId, startAt: vn(dateKey, '08:00'),
  endAt: vn(dateKey, '12:00'), slotMinutes: 30, isAvailable: true, ...extra });

let server, base;
before(async () => {
  const app = express(); app.use(express.json());
  app.use('/api/availability', require('../../src/routes/availability'));
  app.use('/api/appointments', require('../../src/routes/appointments'));
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise(resolve => server.close(resolve)));
beforeEach(() => {
  store = {
    'doctors/doc_01': { name: 'BS A', isActive: true, serviceIds: ['svc_01'] },
    'doctors/doc_02': { name: 'BS B', isActive: true, serviceIds: ['svc_01'] },
    'services/svc_01': { name: 'Khám', price: 100000, durationMinutes: 30 },
    'users/A': { fullName: 'A' },
    'users/A/family_members/live': { fullName: 'Còn' },
    'users/A/family_members/gone': { fullName: 'Đã xóa', isArchived: true },
    [`doctor_schedules/doc_01_${DAY}_am`]: shift('doc_01', DAY),
  };
});
async function availability(date = DAY) {
  const r = await fetch(`${base}/availability?date=${date}&serviceIds=svc_01`);
  return { status: r.status, body: await r.json() };
}
async function book(body) {
  const r = await fetch(`${base}/appointments`, { method: 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer A' },
    body: JSON.stringify({ serviceIds: ['svc_01'], date: DAY, startTime: '09:00', ...body }) });
  return { status: r.status, body: await r.json() };
}

test('A20: ca lỗi ở ngày khác không làm hỏng ngày đang hỏi', async () => {
  store['doctor_schedules/bad_other_day'] = shift('doc_02', OTHER_DAY, { endAt: null, isAvailable: 'yes' });
  const r = await availability();
  assert.equal(r.status, 200);
  assert.equal(r.body.slots.length, 8);
  assert.ok(r.body.slots.every(slot => slot.doctorId === 'doc_01'));
});

test('A20: ca lỗi trong ngày đang hỏi bị bỏ qua, bác sĩ khác vẫn đặt được', async () => {
  store['doctor_schedules/bad_same_day'] = shift('doc_02', DAY, { slotMinutes: 0 });
  const warn = console.warn; const warnings = [];
  console.warn = message => warnings.push(message);
  try {
    const r = await availability();
    assert.equal(r.status, 200);
    assert.equal(r.body.slots.length, 8);
    assert.ok(warnings.some(message => message.includes('bad_same_day')));
  } finally { console.warn = warn; }
});

test('A20: ngày không có ca trả danh sách rỗng', async () => {
  const r = await availability(OTHER_DAY);
  assert.equal(r.status, 200);
  assert.equal(r.body.count, 0);
});

test('A20: lịch hẹn ngày khác không chặn khung giờ ngày đang hỏi', async () => {
  store['appointments/old'] = { doctorId: 'doc_01', date: OTHER_DAY, startTime: '09:00', endTime: '09:30', status: 'booked' };
  store['appointments/same'] = { doctorId: 'doc_01', date: DAY, startTime: '08:00', endTime: '08:30', status: 'booked' };
  const r = await availability();
  assert.equal(r.body.slots.length, 7);
  assert.ok(!r.body.slots.some(slot => slot.startTime === '08:00'));
  assert.ok(r.body.slots.some(slot => slot.startTime === '09:00'));
});

test('A05-10: người thân đã xóa luôn bị 400, kể cả ngày không có lịch làm việc', async () => {
  for (const date of [DAY, OTHER_DAY]) {
    const r = await book({ patientId: 'gone', date });
    assert.equal(r.status, 400);
    assert.match(r.body.message, /đã bị xóa/);
  }
  const notMine = await book({ patientId: 'nobody', date: OTHER_DAY });
  assert.equal(notMine.status, 400);
  assert.ok(!Object.keys(store).some(path => path.startsWith('appointments/')));
});

test('Đặt lịch thành công cho người thân còn hoạt động trong ca của ngày đang hỏi', async () => {
  const r = await book({ patientId: 'live' });
  assert.equal(r.status, 201);
  assert.equal(r.body.doctorId, 'doc_01');
  assert.equal(r.body.status, 'booked');
  assert.equal(store[`appointments/${r.body.id}`].patientId, 'live');
  const again = await book({ patientId: 'live' });
  assert.equal(again.status, 409);
});
