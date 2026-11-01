// Giai đoạn 3: nhắc lịch tự động (A03), công tắc nhận thông báo, đặt lịch từ
// đề xuất tái khám (A08), danh sách lịch cho staff sort=newest. Firestore giả.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('../module2/support/fakeFirestore.cjs');

const fake = createFakeDb();
installFakeFirebase(fake);
const { toVietnamDateKey } = require('../../src/utils/booking');
const { runReminders, appointmentReminderId } = require('../../src/jobs/reminders');
const { readFollowUpId } = require('../../src/utils/followUps');

const HOUR = 60 * 60 * 1000;
const vn = (date, time) => new Date(`${date}T${time}:00+07:00`);
// Giờ giả cho job nhắc: 07:00 sáng 05/01/2099 giờ Việt Nam.
const NOW = vn('2099-01-05', '07:00');
const confirmed = (accountId, patientId, date, startTime, extra = {}) => ({
  accountId, patientId, doctorId: 'doc_01', doctorName: 'BS A', serviceIds: ['svc_01'],
  date, startTime, endTime: '23:59', status: 'confirmed', ...extra,
});
// Ngày đặt lịch thật cho A08 (route đặt lịch kiểm tra giờ đã qua theo đồng hồ thật).
const DAY = toVietnamDateKey(new Date(Date.now() + 7 * 24 * HOUR));
const shift = (doctorId) => ({ doctorId, startAt: vn(DAY, '08:00'), endAt: vn(DAY, '12:00'), slotMinutes: 30, isAvailable: true });

let server, base;
before(async () => {
  const app = express();
  app.use(express.json());
  app.use('/api/appointments', require('../../src/routes/appointments'));
  app.use('/api/notifications', require('../../src/routes/notifications'));
  app.use('/api/users', require('../../src/routes/users'));
  app.use('/api/follow-ups', require('../../src/routes/followUps'));
  app.use((err, req, res, next) => res.status(500).json({ message: 'Lỗi server' }));
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => fake.reset({
  'users/A': { fullName: 'Chủ A' },
  'users/A/family_members/kid': { fullName: 'Bé Na' },
  'users/B': { fullName: 'Người B', notificationsEnabled: false },
  'doctors/doc_01': { name: 'BS A', isActive: true, serviceIds: ['svc_01', 'svc_02'] },
  'services/svc_01': { name: 'Khám', price: 100000, durationMinutes: 30 },
  'services/svc_02': { name: 'Lấy cao răng', price: 300000, durationMinutes: 60 },
  'doctor_schedules/s1': shift('doc_01'),
  // Lịch cho job nhắc (ngày 05-06/01/2099)
  'appointments/r_2h': confirmed('A', 'A', '2099-01-05', '09:00'),
  'appointments/r_23h30': confirmed('A', 'A', '2099-01-06', '06:30'),
  'appointments/r_25h': confirmed('A', 'A', '2099-01-06', '08:00'),
  'appointments/r_booked': confirmed('A', 'A', '2099-01-05', '10:00', { status: 'booked' }),
  'appointments/r_cancelled': confirmed('A', 'A', '2099-01-05', '10:30', { status: 'cancelled' }),
  'appointments/r_rejected': confirmed('A', 'A', '2099-01-05', '11:30', { status: 'rejected' }),
  'appointments/r_past': confirmed('A', 'A', '2099-01-05', '06:00'),
  'appointments/r_kid': confirmed('A', 'kid', '2099-01-05', '11:00'),
  'appointments/r_off': confirmed('B', 'B', '2099-01-05', '12:00'),
  // Đề xuất tái khám cho job nhắc
  'follow_ups/f_2d': { accountId: 'A', patientId: 'A', status: 'suggested', scheduledAt: new Date(NOW.getTime() + 48 * HOUR), reason: 'Kiểm tra trám' },
  'follow_ups/f_legacy': { patientId: 'A', status: 'scheduled', scheduledAt: new Date(NOW.getTime() + 24 * HOUR), reason: 'Dữ liệu cũ' },
  'follow_ups/f_4d': { accountId: 'A', patientId: 'A', status: 'suggested', scheduledAt: new Date(NOW.getTime() + 96 * HOUR) },
  'follow_ups/f_booked': { accountId: 'A', patientId: 'A', status: 'booked', scheduledAt: new Date(NOW.getTime() + 24 * HOUR) },
  'follow_ups/f_off': { accountId: 'B', patientId: 'B', status: 'suggested', scheduledAt: new Date(NOW.getTime() + 24 * HOUR) },
  'follow_ups/f_kid': { accountId: 'A', patientId: 'kid', status: 'suggested', scheduledAt: new Date(NOW.getTime() + 60 * HOUR), reason: 'Niềng' },
  // Đề xuất cho A08
  'follow_ups/fu': { accountId: 'A', patientId: 'A', status: 'suggested', serviceId: 'svc_01', scheduledAt: vn(DAY, '09:00') },
  'follow_ups/fu_kid': { accountId: 'A', patientId: 'kid', status: 'scheduled', scheduledAt: vn(DAY, '09:00') },
}));

async function call(method, path, { token = 'A', body } = {}) {
  const r = await fetch(`${base}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: r.status, body: await r.json() };
}
const notices = (type) => fake.paths('notifications/')
  .map((p) => ({ id: p.split('/')[1], ...fake.store[p] }))
  .filter((n) => !type || n.type === type);

// ---------------- A03: nhắc lịch
test('nhắc lịch confirmed trong 24 giờ tới; bỏ qua lịch chưa xác nhận, đã hủy, từ chối, đã qua, quá 24 giờ', async t => {
  // AUD-05 preserves the worker's new Date() clock and existing wire contract.
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  fake.store['appointments/r_24h'] = confirmed('A', 'A', '2099-01-06', '07:00');
  fake.store['appointments/r_over24h'] = confirmed('A', 'A', '2099-01-06', '07:01');
  fake.store['appointments/r_completed'] = confirmed('A', 'A', '2099-01-05', '10:00', { status: 'completed' });
  const result = await runReminders();
  const reminders = notices('appointment_reminder');
  assert.deepEqual(reminders.map((n) => n.refId).sort(), ['r_23h30', 'r_24h', 'r_2h', 'r_kid']);
  assert.deepEqual(result, { created: 4 });
  for (const [id, date, time] of [
    ['r_2h', '2099-01-05', '09:00'], ['r_23h30', '2099-01-06', '06:30'],
    ['r_24h', '2099-01-06', '07:00'], ['r_kid', '2099-01-05', '11:00'],
  ]) {
    const expectedId = `${id}_${date}_${time}`;
    assert.equal(appointmentReminderId(id, date, time), expectedId);
    assert.deepEqual(reminders.find(n => n.refId === id), {
      id: expectedId, userId: 'A', type: 'appointment_reminder', title: 'Nhắc lịch hẹn',
      body: `Bạn có lịch hẹn ngày ${date} lúc ${time}.`, refId: id,
      isRead: false, createdAt: NOW,
    });
  }
  assert.equal(notices().filter(n => n.userId === 'B').length, 0);
});

// AUD-07 is deferred, not implemented. Keep the callback/assertions executable.
// Owners: Nhi (M4), Phương (M2), Ngân (M3); excluded from the demo by agreement.
// Reopen after owners approve reminder timing/eligibility and a separate implementation;
// validate the fixed clock/acceptance criteria and remove TODO before claiming coverage.
test('nhắc tái khám "suggested"/"scheduled" trong 3 ngày; bỏ qua đã đặt, quá 3 ngày, tài khoản tắt thông báo', {
  todo: 'AUD-07 DEFERRED (out of demo scope); owners Nhi/Phương/Ngân; reopen after timing/eligibility approval and implementation',
}, async () => {
  const result = await runReminders({ now: NOW });
  const reminders = notices('follow_up_reminder');
  assert.deepEqual(reminders.map((n) => n.refId).sort(), ['f_2d', 'f_kid', 'f_legacy']);
  const f = reminders.find((n) => n.refId === 'f_2d');
  assert.equal(f.id, 'furemind_f_2d_2099-01-07');
  assert.match(f.body, /07\/01\/2099. Lý do: Kiểm tra trám/);
  assert.equal(reminders.find((n) => n.refId === 'f_legacy').userId, 'A');
  assert.match(reminders.find((n) => n.refId === 'f_kid').body, /cho Bé Na/);
  assert.equal(result.followUpReminders, 3);
  // Tài khoản B tắt "Nhận thông báo": không có nhắc nào.
  assert.equal(notices().filter((n) => n.userId === 'B').length, 0);
});

test('chạy lại không tạo trùng; lịch đổi giờ thì có nhắc mới theo giờ mới', async t => {
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  assert.deepEqual(await runReminders(), { created: 3 });
  const oldId = appointmentReminderId('r_2h', '2099-01-05', '09:00');
  assert.equal((await call('PATCH', `/notifications/${oldId}/read`)).status, 200);
  assert.equal(fake.store[`notifications/${oldId}`].isRead, true);
  const saved = structuredClone(notices());
  const later = new Date(NOW.getTime() + 10 * 60 * 1000);
  t.mock.timers.setTime(later.getTime());
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.deepEqual(notices(), saved); // Entire body, createdAt and read-state.
  const batch = fake.db.batch();
  batch.update(fake.db.collection('appointments').doc('r_2h'), { startTime: '10:15' });
  await batch.commit();
  assert.deepEqual(await runReminders(), { created: 1 });
  const newId = appointmentReminderId('r_2h', '2099-01-05', '10:15');
  assert.equal(newId, 'r_2h_2099-01-05_10:15');
  assert.deepEqual(fake.store[`notifications/${newId}`], {
    userId: 'A', type: 'appointment_reminder', title: 'Nhắc lịch hẹn',
    body: 'Bạn có lịch hẹn ngày 2099-01-05 lúc 10:15.', refId: 'r_2h',
    isRead: false, createdAt: later,
  });
  for (const notice of saved) {
    const { id, ...data } = notice;
    assert.deepEqual(fake.store[`notifications/${id}`], data);
  }
  assert.equal(notices().length, saved.length + 1);
  const rescheduled = structuredClone(notices());
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.deepEqual(notices(), rescheduled);
});

test('lịch bị hủy đúng lúc job đang ghi: transaction đọc lại và không nhắc', async t => {
  // AUD-05: clock is an actual fake Date; only the target is a query candidate.
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  fake.reset({ 'users/A': { fullName: 'Chủ A' },
    'appointments/r_2h': confirmed('A', 'A', '2099-01-05', '09:00') });
  let once = false;
  fake.state.beforeCommit = async () => {
    if (once) return;
    once = true;
    const batch = fake.db.batch();
    batch.update(fake.db.collection('appointments').doc('r_2h'), { status: 'cancelled' });
    await batch.commit();
  };
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.equal(fake.store[`notifications/${appointmentReminderId('r_2h', '2099-01-05', '09:00')}`], undefined);
  assert.deepEqual(fake.paths('notifications/'), []);
  assert.ok(fake.state.conflicts > 0);
  assert.ok(fake.state.attempts >= 2);
});

test('GET danh sách thông báo không tạo nhắc; POST run-reminders chỉ cho staff', async () => {
  assert.equal((await call('GET', '/notifications')).status, 200);
  assert.equal(notices().length, 0);
  assert.equal((await call('POST', '/notifications/run-reminders')).status, 403);
  const r = await call('POST', '/notifications/run-reminders', { token: 'staff' });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { created: 0 });
});

// ---------------- Công tắc nhận thông báo
test('notificationsEnabled: mặc định true, PATCH false lưu lại, sai kiểu 400', async () => {
  assert.equal((await call('GET', '/users/me')).body.notificationsEnabled, true);
  assert.equal((await call('PATCH', '/users/me', { body: { notificationsEnabled: 'no' } })).status, 400);
  assert.equal((await call('PATCH', '/users/me', { body: { notificationsEnabled: false } })).status, 200);
  assert.equal(fake.store['users/A'].notificationsEnabled, false);
  assert.equal((await call('GET', '/users/me')).body.notificationsEnabled, false);
  await runReminders({ now: NOW });
  assert.equal(notices('appointment_reminder').length, 0);
  assert.equal(notices('follow_up_reminder').length, 0);
});

// ---------------- Cleanup current IDs; legacy visibility follows AUD-08.
test('hủy hoặc từ chối lịch: xóa thông báo nhắc đã gửi với ID hiện hành', async () => {
  const a = await call('POST', '/appointments', { body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00' } });
  const b = await call('POST', '/appointments', { body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '10:00' } });
  assert.equal(a.status, 201);
  assert.equal(b.status, 201);
  const aId = appointmentReminderId(a.body.id, DAY, '09:00');
  const bId = appointmentReminderId(b.body.id, DAY, '10:00');
  for (const [id, appointmentId] of [[aId, a.body.id], [bId, b.body.id]]) {
    fake.store[`notifications/${id}`] = { userId: 'A', type: 'appointment_reminder', refId: appointmentId };
  }
  const bBefore = structuredClone(fake.store[`notifications/${bId}`]);
  assert.equal((await call('PATCH', `/appointments/${a.body.id}/cancel`)).status, 200);
  assert.equal(fake.store[`notifications/${aId}`], undefined);
  assert.deepEqual(fake.store[`notifications/${bId}`], bBefore);
  assert.equal((await call('PATCH', `/appointments/${b.body.id}/status`, { token: 'staff', body: { status: 'rejected', reason: 'Bác sĩ nghỉ' } })).status, 200);
  assert.equal(fake.store[`notifications/${bId}`], undefined);
  assert.equal(notices('appointment_cancelled').length, 1);
  assert.equal(notices('appointment_rejected').length, 1);
});

test('legacy reminder thiếu bằng chứng lịch: giữ document, ẩn list/count/read-all trước và sau cancel/reject', async () => {
  const appointments = [];
  for (const startTime of ['09:00', '10:00']) {
    const booked = await call('POST', '/appointments', { body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime } });
    assert.equal(booked.status, 201);
    const id = booked.body.id;
    // Cancel supports confirmed; reject must remain booked under Module 2 policy.
    if (startTime === '09:00') {
      assert.equal((await call('PATCH', `/appointments/${id}/status`, { token: 'staff', body: { status: 'confirmed' } })).status, 200);
    }
    const legacyId = `remind_${id}_${DAY}_${startTime.replace(':', '')}`;
    const legacy = { userId: 'A', type: 'appointment_reminder', refId: id,
      isRead: false, createdAt: new Date('2026-01-01'), body: 'Legacy reminder' };
    fake.store[`notifications/${legacyId}`] = structuredClone(legacy);
    appointments.push({ id, legacyId, legacy });
  }
  async function assertHidden() {
    const list = await call('GET', '/notifications');
    assert.equal(list.status, 200);
    const events = notices().filter(n => n.type !== 'appointment_reminder');
    assert.deepEqual(list.body.map(n => n.id).sort(), events.map(n => n.id).sort());
    const unread = events.filter(n => n.isRead === false).length;
    assert.deepEqual(await call('GET', '/notifications/unread-count'), { status: 200, body: { count: unread } });
    assert.deepEqual(await call('PATCH', '/notifications/read-all'), { status: 200, body: { updatedCount: unread } });
    assert.deepEqual(await call('GET', '/notifications/unread-count'), { status: 200, body: { count: 0 } });
    for (const { legacyId, legacy } of appointments) {
      assert.deepEqual(fake.store[`notifications/${legacyId}`], legacy);
    }
  }
  await assertHidden(); // The confirmed source also proves invalid legacy shape is hidden.
  assert.equal((await call('PATCH', `/appointments/${appointments[0].id}/cancel`)).status, 200);
  assert.equal((await call('PATCH', `/appointments/${appointments[1].id}/status`, { token: 'staff', body: { status: 'rejected', reason: 'Bác sĩ nghỉ' } })).status, 200);
  await assertHidden();
  assert.equal(notices('appointment_cancelled').length, 1);
  assert.equal(notices('appointment_rejected').length, 1);
});

// ---------------- A08: đặt lịch từ đề xuất tái khám
const bookFollowUp = (body = {}, token = 'A') => call('POST', '/appointments', {
  token, body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00', followUpId: 'fu', ...body },
});

for (const followUpId of ['a/b', '/a', 'a/']) {
  test(`followUpId ${followUpId}: 400 trước truy cập follow-up/transaction, không ghi`, async t => {
    const before = structuredClone(fake.store);
    const collections = [];
    const original = fake.db.collection;
    t.mock.method(fake.db, 'collection', function(path, ...args) {
      collections.push(path);
      return original.call(this, path, ...args);
    });
    const transaction = t.mock.method(fake.db, 'runTransaction');
    const result = await bookFollowUp({ followUpId });
    assert.equal(result.status, 400);
    assert.equal(result.body.message, 'followUpId không được chứa dấu /');
    // The route constructs a self-patient reference first; it does not read it.
    assert.deepEqual(collections, ['users']);
    assert.equal(transaction.mock.callCount(), 0);
    assert.deepEqual(fake.store, before);
  });
}

test('followUpId hợp lệ nhưng không tồn tại: 404 và không ghi', async () => {
  const before = structuredClone(fake.store);
  const result = await bookFollowUp({ followUpId: 'missing-followup' });
  assert.equal(result.status, 404);
  assert.equal(result.body.message, 'Không tìm thấy đề xuất tái khám');
  assert.deepEqual(fake.store, before);
});

test('followUpId hợp lệ có trim vẫn book và liên kết hai chiều', async () => {
  const result = await bookFollowUp({ followUpId: '  fu  ' });
  assert.equal(result.status, 201);
  assert.equal(result.body.followUpId, 'fu');
  assert.equal(fake.store[`appointments/${result.body.id}`].followUpId, 'fu');
  assert.equal(fake.store['follow_ups/fu'].appointmentId, result.body.id);
  assert.equal(fake.store['follow_ups/fu'].status, 'booked');
});

test('readFollowUpId giữ compatibility type/null/blank/trim', () => {
  for (const value of [undefined, null, false, true, 0, 42, {}, [], '', '   ', '\t\n']) {
    assert.equal(readFollowUpId(value), null);
  }
  assert.equal(readFollowUpId(' fu '), 'fu');
  assert.equal(readFollowUpId('missing-followup'), 'missing-followup');
});

test('A08: đặt từ đề xuất lưu followUpId, đề xuất chuyển "booked" kèm appointmentId', async () => {
  const r = await bookFollowUp();
  assert.equal(r.status, 201);
  assert.equal(r.body.followUpId, 'fu');
  assert.equal(fake.store[`appointments/${r.body.id}`].followUpId, 'fu');
  const f = fake.store['follow_ups/fu'];
  assert.deepEqual([f.status, f.appointmentId], ['booked', r.body.id]);
  // Đặt lần 2 cùng đề xuất: 409, không giữ thêm slot.
  const slots = fake.paths('appointment_slots/').length;
  const again = await bookFollowUp({ startTime: '10:00' });
  assert.equal(again.status, 409);
  assert.equal(again.body.message, 'Đề xuất tái khám này đã được đặt lịch');
  assert.equal(fake.paths('appointment_slots/').length, slots);
  // Đề xuất cũ "scheduled" của người thân cũng đặt được.
  const kid = await bookFollowUp({ patientId: 'kid', followUpId: 'fu_kid', startTime: '11:00' });
  assert.equal(kid.status, 201);
  assert.equal(fake.store['follow_ups/fu_kid'].status, 'booked');
});

test('A08: đề xuất sai người, sai tài khoản, không có, thiếu dịch vụ đề xuất thì không tạo lịch', async () => {
  fake.store['follow_ups/fu_B'] = { accountId: 'B', patientId: 'B', status: 'suggested' };
  fake.store['follow_ups/fu_done'] = { accountId: 'A', patientId: 'A', status: 'completed' };
  const old = structuredClone(fake.store);
  assert.equal((await bookFollowUp({ patientId: 'kid' })).status, 400); // fu là của A
  assert.equal((await bookFollowUp({ followUpId: 'fu_B' })).status, 403);
  assert.equal((await bookFollowUp({ followUpId: 'nope' })).status, 404);
  assert.equal((await bookFollowUp({ followUpId: 'a/b' })).status, 400);
  assert.equal((await bookFollowUp({ serviceIds: ['svc_02'] })).status, 400);
  const done = await bookFollowUp({ followUpId: 'fu_done' });
  assert.equal(done.status, 409);
  assert.equal(done.body.message, 'Đề xuất tái khám này không còn hiệu lực');
  assert.deepEqual(fake.store, old);
});

test('A08: cùng Idempotency-Key nhưng đổi followUpId thì 409', async () => {
  const key = 'followup-key-001';
  const first = await fetch(`${base}/appointments`, { method: 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer A', 'idempotency-key': key },
    body: JSON.stringify({ serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00' }) });
  assert.equal(first.status, 201);
  const second = await fetch(`${base}/appointments`, { method: 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer A', 'idempotency-key': key },
    body: JSON.stringify({ serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00', followUpId: 'fu' }) });
  assert.equal(second.status, 409);
  assert.equal(fake.store['follow_ups/fu'].status, 'suggested');
});

test('A08: hủy hoặc từ chối đưa đề xuất về "suggested" và đặt lại được; hoàn tất thì "completed"', async () => {
  const first = await bookFollowUp();
  assert.equal((await call('PATCH', `/appointments/${first.body.id}/cancel`)).status, 200);
  assert.deepEqual([fake.store['follow_ups/fu'].status, fake.store['follow_ups/fu'].appointmentId], ['suggested', null]);

  const second = await bookFollowUp({ startTime: '10:00' });
  assert.equal(second.status, 201);
  assert.equal((await call('PATCH', `/appointments/${second.body.id}/status`, { token: 'staff', body: { status: 'rejected', reason: 'Bận' } })).status, 200);
  assert.equal(fake.store['follow_ups/fu'].status, 'suggested');

  const third = await bookFollowUp({ startTime: '11:00' });
  await call('PATCH', `/appointments/${third.body.id}/status`, { token: 'staff', body: { status: 'confirmed' } });
  assert.equal(fake.store['follow_ups/fu'].status, 'booked'); // xác nhận không đổi đề xuất
  assert.equal((await call('PATCH', `/appointments/${third.body.id}/status`, { token: 'staff', body: { status: 'completed' } })).status, 200);
  assert.equal(fake.store['follow_ups/fu'].status, 'completed');
});

test('A08: lịch không còn trỏ tới đề xuất thì hủy lịch không động vào đề xuất', async () => {
  const r = await bookFollowUp();
  fake.store['follow_ups/fu'].appointmentId = 'other';
  const old = structuredClone(fake.store['follow_ups/fu']);
  assert.equal((await call('PATCH', `/appointments/${r.body.id}/cancel`)).status, 200);
  assert.deepEqual(fake.store['follow_ups/fu'], old);
  assert.equal(fake.store[`appointments/${r.body.id}`].status, 'cancelled');
});

async function aud04Appointment(action) {
  const r = await bookFollowUp();
  assert.equal(r.status, 201);
  if (action === 'completed') {
    assert.equal((await call('PATCH', `/appointments/${r.body.id}/status`, { token: 'staff', body: { status: 'confirmed' } })).status, 200);
  }
  return r.body.id;
}
function aud04Transition(id, action) {
  return action === 'cancelled'
    ? call('PATCH', `/appointments/${id}/cancel`)
    : call('PATCH', `/appointments/${id}/status`, { token: 'staff', body: { status: action, reason: 'Test reason' } });
}

for (const action of ['cancelled', 'rejected', 'completed']) {
  test(`AUD-04: ${action} đúng backlink cập nhật F, giữ bookedAt`, async () => {
    const id = await aud04Appointment(action);
    const bookedAt = structuredClone(fake.store['follow_ups/fu'].bookedAt);
    assert.equal((await aud04Transition(id, action)).status, 200);
    const f = fake.store['follow_ups/fu'];
    assert.equal(fake.store[`appointments/${id}`].status, action);
    assert.equal(f.status, action === 'completed' ? 'completed' : 'suggested');
    assert.equal(f.appointmentId, action === 'completed' ? id : null);
    assert.deepEqual(f.bookedAt, bookedAt);
    assert.ok(f.updatedAt instanceof Date);
    if (action === 'completed') {
      assert.ok(f.completedAt instanceof Date);
      assert.equal(fake.store[`notifications/${id}_completed`].refId, `visit_${id}`);
      assert.ok(fake.store[`invoices/inv_${id}`]);
    }
  });
  for (const mode of ['stale', 'missing', 'no backlink', 'null backlink', 'no account', 'no patient', 'suggested', 'scheduled', 'completed']) {
    test(`AUD-04: ${action} skip ${mode}, F/B không bị sửa`, async () => {
      const id = await aud04Appointment(action);
      fake.store['appointments/B_link'] = { accountId: 'A', patientId: 'A', status: 'confirmed', followUpId: 'fu' };
      fake.store['notifications/B_reminder'] = { userId: 'A', refId: 'B_link', isRead: false };
      const f = fake.store['follow_ups/fu'];
      if (mode === 'stale') f.appointmentId = 'B_link';
      if (mode === 'missing') delete fake.store['follow_ups/fu'];
      if (mode === 'no backlink') delete f.appointmentId;
      if (mode === 'null backlink') f.appointmentId = null;
      if (mode === 'no account') { delete f.accountId; f.patientId = 'other'; }
      if (mode === 'no patient') { delete f.patientId; f.accountId = 'other'; }
      if (['suggested', 'scheduled', 'completed'].includes(mode)) f.status = mode;
      const before = structuredClone(fake.store);
      assert.equal((await aud04Transition(id, action)).status, 200);
      assert.equal(fake.store[`appointments/${id}`].status, action);
      for (const path of ['follow_ups/fu', 'appointments/B_link', 'notifications/B_reminder']) {
        assert.deepEqual(fake.store[path], before[path]);
      }
      const added = fake.paths('notifications/').filter(path => !before[path]);
      assert.equal(added.length, 1);
      assert.equal(fake.store[added[0]].refId, action === 'completed' ? `visit_${id}` : id);
    });
  }
  for (const field of ['accountId', 'patientId']) {
    test(`AUD-04: ${action} ${field} mismatch trước stale/status skip trả 409, rollback`, async () => {
      const id = await aud04Appointment(action);
      Object.assign(fake.store['follow_ups/fu'], { [field]: 'other', appointmentId: 'B_link', status: 'suggested' });
      const old = structuredClone(fake.store);
      assert.equal((await aud04Transition(id, action)).status, 409);
      assert.deepEqual(fake.store, old);
    });
  }
  test(`AUD-04: ${action} retry khi F chuyển sang B không sửa F/B`, async () => {
    const id = await aud04Appointment(action);
    const replacement = { ...fake.store['follow_ups/fu'], appointmentId: 'B_link' };
    fake.store['appointments/B_link'] = { accountId: 'A', patientId: 'A', status: 'booked', followUpId: 'fu' };
    const b = structuredClone(fake.store['appointments/B_link']);
    let once = false;
    fake.state.beforeCommit = async () => {
      if (once) return;
      once = true;
      await fake.db.collection('follow_ups').doc('fu').set(replacement);
    };
    assert.equal((await aud04Transition(id, action)).status, 200);
    assert.ok(fake.state.conflicts > 0);
    assert.deepEqual(fake.store['follow_ups/fu'], replacement);
    assert.deepEqual(fake.store['appointments/B_link'], b);
  });
  test(`AUD-04: ${action} commit failure không partial writes`, async () => {
    const id = await aud04Appointment(action);
    const old = structuredClone(fake.store);
    fake.state.beforeCommit = async () => { throw new Error('fake AUD-04 commit abort'); };
    assert.equal((await aud04Transition(id, action)).status, 500);
    assert.deepEqual(fake.store, old);
  });
  test(`AUD-04: ${action} không followUpId giữ flow thông thường`, async () => {
    const id = await aud04Appointment(action);
    delete fake.store[`appointments/${id}`].followUpId;
    const f = structuredClone(fake.store['follow_ups/fu']);
    assert.equal((await aud04Transition(id, action)).status, 200);
    assert.deepEqual(fake.store['follow_ups/fu'], f);
  });
}

for (const status of ['suggested', 'scheduled']) {
  test(`AUD-04: booking ${status} còn backlink trả 409 không side effects`, async () => {
    Object.assign(fake.store['follow_ups/fu'], { status, appointmentId: 'B_link' });
    const old = structuredClone(fake.store);
    assert.equal((await bookFollowUp()).status, 409);
    assert.deepEqual(fake.store, old);
  });
}

test('AUD-04: hai booking khác giờ cùng F chỉ một backlink thắng', async () => {
  fake.interleave(2);
  const responses = await Promise.all([bookFollowUp(), bookFollowUp({ startTime: '10:00' })]);
  assert.deepEqual(responses.map(r => r.status).sort(), [201, 409]);
  const winner = responses.find(r => r.status === 201).body;
  assert.equal(fake.store['follow_ups/fu'].appointmentId, winner.id);
  assert.equal(fake.store['follow_ups/fu'].status, 'booked');
  assert.equal(fake.paths('appointments/').filter(path => fake.store[path].followUpId === 'fu').length, 1);
  assert.equal(fake.paths('notifications/').length, 1);
});

test('AUD-04: cancel/rebook đồng thời không làm mất liên kết mới', async () => {
  const first = await bookFollowUp();
  const [cancel, booking] = await Promise.all([
    aud04Transition(first.body.id, 'cancelled'), bookFollowUp({ startTime: '10:00' }),
  ]);
  assert.equal(cancel.status, 200);
  assert.ok([201, 409].includes(booking.status));
  const fresh = booking.status === 201 ? booking : await bookFollowUp({ startTime: '10:00' });
  assert.equal(fresh.status, 201);
  assert.equal(fake.store['follow_ups/fu'].appointmentId, fresh.body.id);
  assert.equal(fake.store['follow_ups/fu'].status, 'booked');
  assert.equal(fake.store[`appointments/${first.body.id}`].status, 'cancelled');
  assert.equal(fake.store[`appointments/${fresh.body.id}`].followUpId, 'fu');
});

test('AUD-04: idempotency replay không relink F', async () => {
  const request = () => fetch(`${base}/appointments`, {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer A', 'idempotency-key': 'aud04-replay-001' },
    body: JSON.stringify({ serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00', followUpId: 'fu' }),
  });
  const first = await request();
  assert.equal(first.status, 201);
  const a = await first.json();
  fake.store['follow_ups/fu'].appointmentId = 'B_link';
  const old = structuredClone(fake.store);
  const replay = await request();
  assert.equal(replay.status, 201);
  assert.equal((await replay.json()).id, a.id);
  assert.deepEqual(fake.store, old);
});

test('GET /api/follow-ups/:id: chủ tài khoản và staff xem được, người khác 403', async () => {
  assert.equal((await call('GET', '/follow-ups/fu')).body.status, 'suggested');
  assert.equal((await call('GET', '/follow-ups/f_kid')).status, 200);
  assert.equal((await call('GET', '/follow-ups/fu', { token: 'staff' })).status, 200);
  assert.equal((await call('GET', '/follow-ups/fu', { token: 'B' })).status, 403);
  assert.equal((await call('GET', '/follow-ups/nope')).status, 404);
});

// ---------------- Danh sách lịch cho staff
test('staff: sort=newest xếp lịch mới đặt/mới đổi trạng thái lên trước, có patientName', async () => {
  fake.store['appointments/old'] = confirmed('A', 'kid', DAY, '08:00', { status: 'booked', createdAt: new Date('2099-01-01') });
  fake.store['appointments/new'] = confirmed('A', 'A', DAY, '11:00', { status: 'booked', createdAt: new Date('2099-01-03') });
  fake.store['appointments/mid'] = confirmed('B', 'B', DAY, '09:00', { status: 'booked', createdAt: new Date('2099-01-02') });
  const newest = await call('GET', '/appointments/staff?status=booked&sort=newest', { token: 'staff' });
  assert.deepEqual(newest.body.filter((a) => ['old', 'new', 'mid'].includes(a.id)).map((a) => a.id), ['new', 'mid', 'old']);
  assert.deepEqual(newest.body.filter((a) => ['old', 'new', 'mid'].includes(a.id)).map((a) => a.patientName), ['Chủ A', 'Người B', 'Bé Na']);
  const schedule = await call('GET', `/appointments/staff?status=booked&date=${DAY}`, { token: 'staff' });
  assert.deepEqual(schedule.body.map((a) => a.id), ['old', 'mid', 'new']);
  // Lịch vừa xác nhận lên đầu danh sách confirmed khi sort=newest.
  await call('PATCH', '/appointments/old/status', { token: 'staff', body: { status: 'confirmed' } });
  const confirmedNewest = await call('GET', '/appointments/staff?status=confirmed&sort=newest', { token: 'staff' });
  assert.equal(confirmedNewest.body[0].id, 'old');
  assert.equal((await call('GET', '/appointments/staff?sort=random', { token: 'staff' })).status, 400);
});

// AUD-05: fixed clock and versioned fake commits; never start a scheduler.
const AUD05_NOW = new Date('2099-01-05T00:00:00Z');
const AUD05_PATH = 'notifications/aud05_2099-01-05_09:00';
function aud05Fixture(t, extra = {}) {
  t.mock.timers.enable({ apis: ['Date'], now: AUD05_NOW });
  fake.reset({ 'users/A': { notificationsEnabled: true },
    'appointments/aud05': { accountId: 'A', patientId: 'A', status: 'confirmed', date: '2099-01-05', startTime: '09:00' }, ...extra });
}
function aud05BeforeCommit(action) {
  let once = false;
  fake.state.beforeCommit = async () => { if (!once) { once = true; await action(); } };
}
async function aud05Update(path, data) {
  const batch = fake.db.batch();
  batch.update(fake.db.collection(path.split('/')[0]).doc(path.split('/')[1]), data);
  await batch.commit();
}

test('AUD-05: legacy ID, fields, 24h window, response and sequential replay stay compatible', async t => {
  aud05Fixture(t);
  assert.equal(appointmentReminderId('aud05', '2099-01-05', '09:00'), 'aud05_2099-01-05_09:00');
  assert.deepEqual(await runReminders(), { created: 1 });
  const saved = structuredClone(fake.store[AUD05_PATH]);
  assert.deepEqual(saved, { userId: 'A', type: 'appointment_reminder', title: 'Nhắc lịch hẹn',
    body: 'Bạn có lịch hẹn ngày 2099-01-05 lúc 09:00.', refId: 'aud05', isRead: false, createdAt: AUD05_NOW });
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.deepEqual(fake.store[AUD05_PATH], saved);
});
test('AUD-05: concurrent workers finish reads before either commit; conflict/retry creates exactly once', async t => {
  aud05Fixture(t);
  fake.interleave(2);
  const results = await Promise.all([runReminders(), runReminders()]);
  assert.deepEqual(results.map(r => r.created).sort(), [0, 1]);
  assert.equal(fake.paths('notifications/').length, 1);
  assert.ok(fake.state.conflicts >= 1);
  assert.ok(fake.state.attempts >= 3);
});
for (const isRead of [false, true]) {
  test(`AUD-05: existing notification isRead=${isRead} is never overwritten`, async t => {
    aud05Fixture(t, { [AUD05_PATH]: { userId: 'A', isRead, createdAt: new Date('2099-01-04'), body: 'Original', extra: 'keep' } });
    const before = structuredClone(fake.store);
    assert.deepEqual(await runReminders(), { created: 0 });
    assert.deepEqual(fake.store, before);
  });
}
for (const status of ['cancelled', 'rejected', 'completed']) {
  test(`AUD-05: ${status} at commit conflicts, retries and skips`, async t => {
    aud05Fixture(t);
    aud05BeforeCommit(() => aud05Update('appointments/aud05', { status }));
    assert.deepEqual(await runReminders(), { created: 0 });
    assert.equal(fake.store[AUD05_PATH], undefined);
    assert.equal(fake.store['appointments/aud05'].status, status);
    assert.ok(fake.state.conflicts >= 1);
    assert.ok(fake.state.attempts >= 2);
  });
}
test('AUD-05: preference turns off at commit; retry skips', async t => {
  aud05Fixture(t);
  aud05BeforeCommit(() => aud05Update('users/A', { notificationsEnabled: false }));
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.equal(fake.store[AUD05_PATH], undefined);
  assert.equal(fake.store['users/A'].notificationsEnabled, false);
  assert.ok(fake.state.conflicts > 0);
});
test('AUD-05: another creator/read wins at commit; preserve entire read notification', async t => {
  aud05Fixture(t);
  const read = { userId: 'A', type: 'appointment_reminder', refId: 'aud05', isRead: true,
    createdAt: new Date('2099-01-04'), body: 'Other worker', extra: 'preserve' };
  aud05BeforeCommit(() => fake.db.collection('notifications').doc(appointmentReminderId('aud05', '2099-01-05', '09:00')).set(read));
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.deepEqual(fake.store[AUD05_PATH], read);
  assert.ok(fake.state.conflicts > 0);
});
test('AUD-05: mark-read races with worker; retry keeps it read', async t => {
  const notice = { userId: 'A', isRead: false, body: 'Original', createdAt: new Date('2099-01-04') };
  aud05Fixture(t, { [AUD05_PATH]: notice });
  aud05BeforeCommit(() => aud05Update(AUD05_PATH, { isRead: true }));
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.deepEqual(fake.store[AUD05_PATH], { ...notice, isRead: true });
  assert.ok(fake.state.conflicts > 0);
});
test('AUD-05: reschedule at commit retries using current time and ID', async t => {
  aud05Fixture(t);
  aud05BeforeCommit(() => aud05Update('appointments/aud05', { startTime: '12:00' }));
  assert.deepEqual(await runReminders(), { created: 1 });
  assert.equal(fake.store[AUD05_PATH], undefined);
  assert.match(fake.store['notifications/aud05_2099-01-05_12:00'].body, /12:00/);
  assert.ok(fake.state.conflicts > 0);
});
test('AUD-05: appointment deletion at commit retries and creates no orphan reminder', async t => {
  aud05Fixture(t);
  aud05BeforeCommit(async () => {
    const batch = fake.db.batch(); batch.delete(fake.db.collection('appointments').doc('aud05')); await batch.commit();
  });
  assert.deepEqual(await runReminders(), { created: 0 });
  assert.deepEqual(fake.paths('notifications/'), []);
  assert.ok(fake.state.conflicts > 0);
});
test('AUD-05: cancelled after query but before transaction is not sent', async t => {
  aud05Fixture(t);
  const collection = fake.db.collection;
  fake.db.collection = name => {
    const result = collection(name);
    if (name === 'appointments') {
      const where = result.where;
      result.where = (...args) => {
        const query = where(...args), get = query.get;
        query.get = async () => {
          const snapshot = await get();
          await aud05Update('appointments/aud05', { status: 'cancelled' });
          return snapshot;
        };
        return query;
      };
    }
    return result;
  };
  try {
    assert.deepEqual(await runReminders(), { created: 0 });
    assert.deepEqual(fake.paths('notifications/'), []);
  } finally { fake.db.collection = collection; }
});
test('AUD-05: commit failure leaves no partial writes', async t => {
  aud05Fixture(t);
  const before = structuredClone(fake.store);
  fake.state.beforeCommit = async () => { throw new Error('AUD05 synthetic commit failure'); };
  await assert.rejects(runReminders(), /AUD05 synthetic commit failure/);
  assert.deepEqual(fake.store, before);
});
for (const profile of [undefined, {}, { notificationsEnabled: true }, { notificationsEnabled: false }]) {
  test(`AUD-05: unchanged profile policy ${JSON.stringify(profile)}`, async t => {
    aud05Fixture(t);
    if (profile === undefined) delete fake.store['users/A'];
    else fake.store['users/A'] = profile;
    assert.deepEqual(await runReminders(), { created: profile?.notificationsEnabled === false ? 0 : 1 });
  });
}
for (const [label, date, startTime, expected] of [
  ['past', '2099-01-05', '06:59', 0],
  ['exact start (legacy boundary)', '2099-01-05', '07:00', 1],
  ['exact 24h', '2099-01-06', '07:00', 1],
  ['beyond 24h', '2099-01-06', '07:01', 0],
  ['invalid date', '2099-02-30', '09:00', 0],
  ['invalid time', '2099-01-05', '25:00', 0],
]) {
  test(`AUD-05: eligibility ${label}`, async t => {
    aud05Fixture(t);
    Object.assign(fake.store['appointments/aud05'], { date, startTime });
    assert.deepEqual(await runReminders(), { created: expected });
    assert.equal(fake.paths('notifications/').length, expected);
  });
}

// AUD-08: source validity is independent of the worker's creation-time window.
const AUD08_ID = appointmentReminderId('aud08', '2099-01-05', '09:00');
const AUD08_PATH = `notifications/${AUD08_ID}`;
function aud08Fixture(t) {
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  fake.reset({
    'users/A': { notificationsEnabled: true },
    'users/B': { notificationsEnabled: true },
    'appointments/aud08': confirmed('A', 'kid', '2099-01-05', '09:00'),
    [AUD08_PATH]: { userId: 'A', type: 'appointment_reminder', refId: 'aud08', isRead: false,
      createdAt: new Date('2099-01-04'), title: 'Reminder', body: 'Do not infer dates from this text' },
  });
}
async function aud08List(token = 'A') {
  const response = await call('GET', '/notifications', { token });
  assert.equal(response.status, 200);
  return response.body;
}
async function aud08Count(token = 'A') {
  const response = await call('GET', '/notifications/unread-count', { token });
  assert.equal(response.status, 200);
  return response.body.count;
}
function aud08Events() {
  const types = ['appointment_booked', 'appointment_confirmed', 'appointment_cancelled', 'appointment_rejected', 'visit_result'];
  for (const type of types) fake.store[`notifications/event_${type}`] = {
    userId: 'A', type, refId: 'deleted-source', isRead: false, createdAt: NOW,
  };
  return types;
}

test('AUD-08: valid reminder keeps data; list/count/read-all agree and individual mark-read stays idempotent', async t => {
  aud08Fixture(t);
  const original = structuredClone(fake.store[AUD08_PATH]);
  assert.deepEqual((await aud08List()).map(n => n.id), [AUD08_ID]);
  assert.equal(await aud08Count(), 1);
  assert.deepEqual(fake.store[AUD08_PATH], original);
  const read = await call('PATCH', '/notifications/read-all');
  assert.deepEqual([read.status, read.body], [200, { updatedCount: 1 }]);
  assert.equal(await aud08Count(), 0);
  assert.equal((await aud08List())[0].isRead, true);
  assert.deepEqual(fake.store[AUD08_PATH], { ...original, isRead: true });
  assert.equal((await call('PATCH', '/notifications/read-all')).body.updatedCount, 0);
  assert.equal((await call('PATCH', `/notifications/${AUD08_ID}/read`)).status, 200);
});

for (const [label, change] of [
  ...['cancelled', 'rejected', 'completed', 'booked'].map(status => [status, () => { fake.store['appointments/aud08'].status = status; }]),
  ['missing appointment', () => { delete fake.store['appointments/aud08']; }],
  ['foreign account', () => { fake.store['appointments/aud08'].accountId = 'B'; }],
  ['missing account', () => { delete fake.store['appointments/aud08'].accountId; }],
  ['date changed', () => { fake.store['appointments/aud08'].date = '2099-01-06'; }],
  ['time changed', () => { fake.store['appointments/aud08'].startTime = '10:00'; }],
  ['invalid date', () => { fake.store['appointments/aud08'].date = '2099-02-30'; }],
  ['invalid time', () => { fake.store['appointments/aud08'].startTime = '25:00'; }],
  ['preference disabled', () => { fake.store['users/A'].notificationsEnabled = false; }],
]) {
  test(`AUD-08: hide ${label}, preserve reminders and all historical event types`, async t => {
    aud08Fixture(t); change();
    const types = aud08Events();
    const original = structuredClone(fake.store[AUD08_PATH]);
    assert.deepEqual((await aud08List()).map(n => n.type).sort(), types.sort());
    assert.equal(await aud08Count(), types.length);
    const read = await call('PATCH', '/notifications/read-all');
    assert.deepEqual([read.status, read.body], [200, { updatedCount: types.length }]);
    assert.equal(await aud08Count(), 0);
    assert.deepEqual(fake.store[AUD08_PATH], original);
    assert.equal((await aud08List()).length, types.length);
  });
}

for (const [label, date, startTime] of [
  ['past', '2020-01-05', '09:00'],
  ['exact start', '2099-01-05', '07:00'],
  ['farther than 24 hours', '2200-01-05', '09:00'],
]) {
  test(`AUD-08: ${label} is still visible when confirmed and schedule matches`, async t => {
    aud08Fixture(t);
    delete fake.store[AUD08_PATH];
    Object.assign(fake.store['appointments/aud08'], { date, startTime });
    const id = appointmentReminderId('aud08', date, startTime);
    fake.store[`notifications/${id}`] = { userId: 'A', type: 'appointment_reminder', refId: 'aud08', isRead: false, createdAt: new Date('2019-01-01') };
    assert.deepEqual((await aud08List()).map(n => n.id), [id]);
    assert.equal(await aud08Count(), 1);
    assert.equal((await call('PATCH', '/notifications/read-all')).body.updatedCount, 1);
  });
}

for (const [label, id, changes] of [
  ['legacy prefix', 'remind_aud08_2099-01-05_0900', {}],
  ['legacy opaque ID', 'old-reminder', {}],
  ['missing refId', AUD08_ID, { refId: undefined }],
  ['invalid ref path', AUD08_ID, { refId: 'a/b' }],
  ['refId does not match ID', AUD08_ID, { refId: 'other' }],
]) {
  test(`AUD-08: ${label} hidden without guessing from body and never marked by read-all`, async t => {
    aud08Fixture(t);
    const notice = { ...fake.store[AUD08_PATH], ...changes };
    delete fake.store[AUD08_PATH];
    fake.store[`notifications/${id}`] = notice;
    const original = structuredClone(fake.store);
    assert.deepEqual(await aud08List(), []);
    assert.equal(await aud08Count(), 0);
    assert.equal((await call('PATCH', '/notifications/read-all')).body.updatedCount, 0);
    assert.deepEqual(fake.store, original);
  });
}

for (const read of [false, true]) {
  test(`AUD-08: preference off/on preserves notification isRead=${read} and createdAt`, async t => {
    aud08Fixture(t);
    fake.store[AUD08_PATH].isRead = read;
    const original = structuredClone(fake.store[AUD08_PATH]);
    fake.store['users/A'].notificationsEnabled = false;
    assert.deepEqual(await aud08List(), []);
    assert.equal(await aud08Count(), 0);
    assert.equal((await call('PATCH', '/notifications/read-all')).body.updatedCount, 0);
    fake.store['users/A'].notificationsEnabled = true;
    assert.equal((await aud08List())[0].isRead, read);
    assert.equal(await aud08Count(), read ? 0 : 1);
    assert.deepEqual(fake.store[AUD08_PATH], original);
    assert.deepEqual(await runReminders(), { created: 0 }); // AUD-05 dedup marker remains.
  });
}
for (const missing of ['profile', 'flag']) {
  test(`AUD-08: missing ${missing} retains AUD-05 preference default`, async t => {
    aud08Fixture(t);
    if (missing === 'profile') delete fake.store['users/A'];
    else fake.store['users/A'] = {};
    assert.equal((await aud08List()).length, 1);
    assert.equal(await aud08Count(), 1);
    assert.equal((await call('PATCH', '/notifications/read-all')).body.updatedCount, 1);
  });
}
test('AUD-08: hidden single-item read retains owner 200, foreign 403 and missing 404', async t => {
  aud08Fixture(t);
  fake.store['appointments/aud08'].status = 'completed';
  assert.equal((await call('PATCH', `/notifications/${AUD08_ID}/read`, { token: 'B' })).status, 403);
  assert.equal(fake.store[AUD08_PATH].isRead, false);
  assert.equal((await call('PATCH', `/notifications/${AUD08_ID}/read`)).status, 200);
  assert.equal(fake.store[AUD08_PATH].isRead, true);
  assert.deepEqual(await aud08List(), []);
  assert.equal((await call('PATCH', '/notifications/nope/read')).status, 404);
});
test('AUD-08: account switching cannot expose source data or leak request caches', async t => {
  aud08Fixture(t);
  assert.equal((await aud08List()).length, 1);
  assert.deepEqual(await aud08List('B'), []);
  assert.equal(await aud08Count('B'), 0);
  assert.equal((await call('PATCH', '/notifications/read-all', { token: 'B' })).body.updatedCount, 0);
  fake.store['appointments/aud08'].accountId = 'B';
  assert.deepEqual(await aud08List(), []);
  assert.deepEqual(await aud08List('B'), []); // Notification itself still belongs to A.
});

for (const [path, patch] of [
  ['appointments/aud08', { status: 'cancelled' }],
  ['appointments/aud08', { status: 'rejected' }],
  ['appointments/aud08', { status: 'completed' }],
  ['appointments/aud08', { startTime: '11:00' }],
  ['appointments/aud08', { accountId: 'B' }],
  ['users/A', { notificationsEnabled: false }],
  [AUD08_PATH, { userId: 'B' }],
]) {
  test(`AUD-08: read-all retries ${path} ${JSON.stringify(patch)} before write`, async t => {
    aud08Fixture(t);
    const original = structuredClone(fake.store[AUD08_PATH]);
    aud05BeforeCommit(() => aud05Update(path, patch));
    const result = await call('PATCH', '/notifications/read-all');
    assert.deepEqual([result.status, result.body], [200, { updatedCount: 0 }]);
    assert.equal(fake.store[AUD08_PATH].isRead, false);
    assert.deepEqual(fake.store[AUD08_PATH].createdAt, original.createdAt);
    assert.ok(fake.state.conflicts > 0);
    assert.ok(fake.state.attempts >= 2);
  });
}
test('AUD-08: two concurrent read-all calls only count one committed update', async t => {
  aud08Fixture(t);
  fake.interleave(2);
  const results = await Promise.all([call('PATCH', '/notifications/read-all'), call('PATCH', '/notifications/read-all')]);
  assert.deepEqual(results.map(r => r.body.updatedCount).sort(), [0, 1]);
  assert.ok(results.every(r => r.status === 200));
  assert.ok(fake.state.conflicts > 0);
  assert.equal(fake.store[AUD08_PATH].isRead, true);
});
test('AUD-08: read-all commit failure propagates 500 with no partial reminder write', async t => {
  aud08Fixture(t);
  const original = structuredClone(fake.store);
  fake.state.beforeCommit = async () => { throw new Error('AUD08 synthetic commit failure'); };
  assert.equal((await call('PATCH', '/notifications/read-all')).status, 500);
  assert.deepEqual(fake.store, original);
});
test('AUD-08: partial failure preserves committed events, reports 500, retry counts remaining reminders', async t => {
  aud08Fixture(t); aud08Events();
  fake.state.beforeCommit = async () => { throw new Error('AUD08 synthetic reminder failure'); };
  assert.equal((await call('PATCH', '/notifications/read-all')).status, 500);
  assert.equal(fake.store[AUD08_PATH].isRead, false);
  assert.ok(fake.paths('notifications/event_').every(p => fake.store[p].isRead));
  fake.state.beforeCommit = null;
  assert.equal((await call('PATCH', '/notifications/read-all')).body.updatedCount, 1);
});

test('AUD-08: list deduplicates source reads and skips unprovable legacy lookups', async t => {
  aud08Fixture(t);
  for (let i = 1; i < 30; i++) {
    const id = appointmentReminderId('aud08', '2099-01-05', `09:${String(i).padStart(2, '0')}`);
    fake.store[`notifications/${id}`] = { ...fake.store[AUD08_PATH] };
    fake.store[`notifications/legacy_${i}`] = { ...fake.store[AUD08_PATH], refId: `unknown_${i}` };
  }
  const original = fake.db.collection;
  const reads = {};
  fake.db.collection = name => {
    const result = original(name), doc = result.doc;
    result.doc = id => {
      const ref = doc(id), get = ref.get;
      ref.get = async () => { reads[`${name}/${id}`] = (reads[`${name}/${id}`] || 0) + 1; return get(); };
      return ref;
    };
    return result;
  };
  try {
    assert.deepEqual((await aud08List()).map(n => n.id), [AUD08_ID]);
    assert.deepEqual(reads, { 'users/A': 1, 'appointments/aud08': 1 });
  } finally { fake.db.collection = original; }
});

test('AUD-08: many reminders use bounded transactions and events retain 450-write batches', async t => {
  aud08Fixture(t);
  for (let i = 0; i < 451; i++) {
    const refId = `many_${i}`, id = appointmentReminderId(refId, '2099-01-05', '09:00');
    fake.store[`appointments/${refId}`] = { ...fake.store['appointments/aud08'] };
    fake.store[`notifications/${id}`] = { ...fake.store[AUD08_PATH], refId };
    fake.store[`notifications/event_${i}`] = { userId: 'A', type: 'appointment_confirmed', isRead: false };
  }
  const transaction = fake.db.runTransaction, batch = fake.db.batch;
  let active = 0, peak = 0;
  const batches = [];
  fake.db.runTransaction = async fn => {
    active++; peak = Math.max(peak, active);
    try { return await transaction(async tx => {
      let reads = 0, writes = 0;
      const result = await fn({
        get: ref => { reads++; return tx.get(ref); },
        update: (ref, value) => { writes++; tx.update(ref, value); },
      });
      assert.ok(reads <= 3); assert.ok(writes <= 1);
      return result;
    }); } finally { active--; }
  };
  fake.db.batch = () => {
    const result = batch(), update = result.update, commit = result.commit;
    let writes = 0;
    result.update = (...args) => { writes++; update(...args); };
    result.commit = async () => { batches.push(writes); await commit(); };
    return result;
  };
  try {
    const result = await call('PATCH', '/notifications/read-all');
    assert.deepEqual([result.status, result.body], [200, { updatedCount: 903 }]);
    assert.deepEqual(batches, [450, 1]);
    assert.ok(peak <= 8); assert.ok(peak > 1);
    assert.equal(await aud08Count(), 0);
  } finally { fake.db.runTransaction = transaction; fake.db.batch = batch; }
});

test('AUD-08: distinct inbox sources have bounded concurrency and one read each', async t => {
  aud08Fixture(t);
  for (let i = 0; i < 80; i++) {
    const refId = `inbox_${i}`, id = appointmentReminderId(refId, '2099-01-05', '09:00');
    fake.store[`appointments/${refId}`] = { ...fake.store['appointments/aud08'] };
    fake.store[`notifications/${id}`] = { ...fake.store[AUD08_PATH], refId };
  }
  const collection = fake.db.collection;
  let active = 0, peak = 0, reads = 0;
  fake.db.collection = name => {
    const result = collection(name);
    if (name === 'appointments') {
      const doc = result.doc;
      result.doc = id => {
        const ref = doc(id), get = ref.get;
        ref.get = async () => {
          active++; reads++; peak = Math.max(peak, active);
          try { await new Promise(resolve => setImmediate(resolve)); return await get(); }
          finally { active--; }
        };
        return ref;
      };
    }
    return result;
  };
  try {
    assert.equal((await aud08List()).length, 81);
    assert.equal(reads, 81);
    assert.ok(peak <= 8); assert.ok(peak > 1); assert.equal(active, 0);
  } finally { fake.db.collection = collection; }
});
for (const failingCollection of ['users', 'appointments']) {
  test(`AUD-08: ${failingCollection} read failure is 500, never a false empty inbox/count/read-all success`, async t => {
    aud08Fixture(t);
    const before = structuredClone(fake.store);
    const collection = fake.db.collection, transaction = fake.db.runTransaction;
    fake.db.collection = name => {
      const result = collection(name);
      if (name === failingCollection) {
        const doc = result.doc;
        result.doc = id => { const ref = doc(id); ref.get = async () => { throw new Error('AUD08 synthetic source failure'); }; return ref; };
      }
      return result;
    };
    fake.db.runTransaction = fn => transaction(tx => {
      const get = tx.get;
      tx.get = async ref => {
        if (ref.path.startsWith(failingCollection + '/')) throw new Error('AUD08 synthetic source failure');
        return get(ref);
      };
      return fn(tx);
    });
    try {
      for (const [method, path] of [['GET', '/notifications'], ['GET', '/notifications/unread-count'], ['PATCH', '/notifications/read-all']]) {
        assert.equal((await call(method, path)).status, 500);
      }
      assert.deepEqual(fake.store, before);
    } finally { fake.db.collection = collection; fake.db.runTransaction = transaction; }
  });
}

test('AUD-08: read-all drains in-flight transactions before reporting partial failure', async t => {
  aud08Fixture(t);
  const secondId = appointmentReminderId('second', '2099-01-05', '09:00');
  fake.store['appointments/second'] = { ...fake.store['appointments/aud08'] };
  fake.store[`notifications/${secondId}`] = { ...fake.store[AUD08_PATH], refId: 'second' };
  let release, started;
  const gate = new Promise(resolve => { release = resolve; });
  const ready = new Promise(resolve => { started = resolve; });
  let commits = 0, settled = false;
  fake.state.beforeCommit = async () => {
    commits++;
    if (commits === 1) throw new Error('AUD08 synthetic first commit failure');
    started(); await gate;
  };
  const response = call('PATCH', '/notifications/read-all').then(value => { settled = true; return value; });
  await ready;
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(settled, false, 'Do not return while a transaction can still write');
  release();
  const result = await response;
  assert.equal(result.status, 500);
  assert.equal(result.body.updatedCount, undefined);
  assert.equal(fake.paths('notifications/').filter(p => fake.store[p].isRead).length, 1);
  fake.state.beforeCommit = null;
  assert.equal((await call('PATCH', '/notifications/read-all')).body.updatedCount, 1);
});
