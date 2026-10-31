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
test('nhắc lịch confirmed trong 24 giờ tới; bỏ qua lịch chưa xác nhận, đã hủy, từ chối, đã qua, quá 24 giờ', async () => {
  const result = await runReminders({ now: NOW });
  const reminders = notices('appointment_reminder');
  assert.deepEqual(reminders.map((n) => n.refId).sort(), ['r_23h30', 'r_2h', 'r_kid']);
  const first = reminders.find((n) => n.refId === 'r_2h');
  assert.equal(first.id, appointmentReminderId('r_2h', '2099-01-05', '09:00'));
  assert.equal(first.id, 'remind_r_2h_2099-01-05_0900');
  assert.deepEqual([first.userId, first.title, first.isRead], ['A', 'Nhắc lịch hẹn', false]);
  assert.match(first.body, /09:00 ngày 05\/01\/2099 với BS A/);
  assert.match(reminders.find((n) => n.refId === 'r_kid').body, /của Bé Na/);
  assert.equal(result.appointmentReminders, 3);
});

test('nhắc tái khám "suggested"/"scheduled" trong 3 ngày; bỏ qua đã đặt, quá 3 ngày, tài khoản tắt thông báo', async () => {
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

test('chạy lại không tạo trùng; lịch đổi giờ thì có nhắc mới theo giờ mới', async () => {
  await runReminders({ now: NOW });
  const before = notices().length;
  const again = await runReminders({ now: new Date(NOW.getTime() + 10 * 60 * 1000) });
  assert.deepEqual([again.appointmentReminders, again.followUpReminders], [0, 0]);
  assert.equal(notices().length, before);
  fake.store['appointments/r_2h'].startTime = '10:15';
  await runReminders({ now: NOW });
  assert.ok(fake.store['notifications/remind_r_2h_2099-01-05_1015']);
});

test('lịch bị hủy đúng lúc job đang ghi: transaction đọc lại và không nhắc', async () => {
  let once = false;
  fake.state.beforeCommit = async () => {
    if (once) return;
    once = true;
    const batch = fake.db.batch();
    batch.update(fake.db.collection('appointments').doc('r_2h'), { status: 'cancelled' });
    await batch.commit();
  };
  await runReminders({ now: NOW });
  assert.equal(fake.store['notifications/remind_r_2h_2099-01-05_0900'], undefined);
  assert.ok(fake.state.conflicts > 0);
});

test('GET danh sách thông báo không tạo nhắc; POST run-reminders chỉ cho staff', async () => {
  assert.equal((await call('GET', '/notifications')).status, 200);
  assert.equal(notices().length, 0);
  assert.equal((await call('POST', '/notifications/run-reminders')).status, 403);
  const r = await call('POST', '/notifications/run-reminders', { token: 'staff' });
  assert.equal(r.status, 200);
  assert.deepEqual(Object.keys(r.body).sort(), ['appointmentReminders', 'errors', 'followUpReminders', 'skipped']);
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

// ---------------- Hủy/từ chối xóa nhắc cũ
test('hủy hoặc từ chối lịch: xóa thông báo nhắc đã gửi', async () => {
  const a = await call('POST', '/appointments', { body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00' } });
  const b = await call('POST', '/appointments', { body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '10:00' } });
  for (const [id, time] of [[a.body.id, '0900'], [b.body.id, '1000']]) {
    fake.store[`notifications/remind_${id}_${DAY}_${time}`] = { userId: 'A', type: 'appointment_reminder', refId: id };
  }
  assert.equal((await call('PATCH', `/appointments/${a.body.id}/cancel`)).status, 200);
  assert.equal(fake.store[`notifications/remind_${a.body.id}_${DAY}_0900`], undefined);
  assert.equal((await call('PATCH', `/appointments/${b.body.id}/status`, { token: 'staff', body: { status: 'rejected', reason: 'Bác sĩ nghỉ' } })).status, 200);
  assert.equal(fake.store[`notifications/remind_${b.body.id}_${DAY}_1000`], undefined);
});

// ---------------- A08: đặt lịch từ đề xuất tái khám
const bookFollowUp = (body = {}, token = 'A') => call('POST', '/appointments', {
  token, body: { serviceIds: ['svc_01'], doctorId: 'doc_01', date: DAY, startTime: '09:00', followUpId: 'fu', ...body },
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
  await call('PATCH', `/appointments/${r.body.id}/cancel`);
  assert.equal(fake.store['follow_ups/fu'].status, 'booked');
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
