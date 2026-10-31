// Giai đoạn 1 - Hồ sơ khám thật: staff hoàn tất lịch kèm kết quả, tạo liệu trình,
// cập nhật buổi điều trị, đề xuất tái khám. Dùng Firestore giả, không gọi mạng.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('../module2/support/fakeFirestore.cjs');

const fake = createFakeDb();
installFakeFirebase(fake);

let server, base;
before(async () => {
  const app = express();
  app.use(express.json());
  app.use('/api/appointments', require('../../src/routes/appointments'));
  app.use('/api/treatments', require('../../src/routes/treatments'));
  app.use('/api/follow-ups', require('../../src/routes/followUps'));
  app.use('/api/visits', require('../../src/routes/visits'));
  app.use('/api/invoices', require('../../src/routes/invoices'));
  app.use('/api/patients', require('../../src/routes/patients'));
  app.use((error, req, res, next) => res.status(500).json({ message: 'Lỗi server' }));
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => fake.reset({
  'users/A': { email: 'a@example.com', fullName: 'Chủ tài khoản' },
  'users/A/family_members/kid': { fullName: 'Con', isArchived: false },
  'users/A/family_members/old': { fullName: 'Đã xóa', isArchived: true },
  'users/B': { email: 'b@example.com' },
  'doctors/doc_01': { name: 'BS. Minh' },
  'services/svc_01': { name: 'Khám tổng quát', price: 100000 },
  'services/svc_02': { name: 'Cạo vôi', price: 200000 },
  'services/svc_03': { name: 'Chụp X-quang', price: 50000 },
  'combos/combo_1': { name: 'Combo sạch răng', price: 250000, serviceIds: ['svc_01', 'svc_02'] },
  'appointments/a1': {
    accountId: 'A', patientId: 'A', doctorId: 'doc_01', doctorName: 'BS. Minh',
    comboId: 'combo_1', serviceIds: ['svc_01', 'svc_02', 'svc_03'],
    date: '2099-01-05', startTime: '09:00', endTime: '10:00',
    totalPrice: 270000, discount: 30000, voucherCode: 'GIAM30', note: 'Ê buốt răng',
    status: 'confirmed',
  },
  'appointments/a2': {
    accountId: 'A', patientId: 'kid', doctorId: 'doc_01', serviceIds: ['svc_03'],
    date: '2099-01-06', startTime: '14:30', endTime: '15:00',
    totalPrice: 50000, discount: 0, status: 'confirmed',
  },
}));

async function call(path, { method = 'GET', token = 'staff', body } = {}) {
  const r = await fetch(`${base}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: r.status, body: await r.json() };
}
const complete = (id, extra = {}, token = 'staff') =>
  call(`/appointments/${id}/status`, { method: 'PATCH', token, body: { status: 'completed', ...extra } });
const snapshot = () => structuredClone(fake.store);

const FULL = {
  visit: { diagnosis: 'Viêm nướu nhẹ', result: 'Đã cạo vôi, nướu ổn', notes: 'Tái khám sau 3 tháng' },
  prescriptions: [
    { medicineName: 'Paracetamol 500mg', dosage: '1 viên/lần', frequency: '2 lần/ngày', durationDays: 3, instructions: 'Uống sau ăn' },
    { medicineName: 'Nước súc miệng' },
  ],
};

test('hoàn tất kèm kết quả: tạo visit, đơn thuốc, hóa đơn, 1 thông báo visit_result', async () => {
  const r = await complete('a1', FULL);
  assert.equal(r.status, 200);
  assert.equal(r.body.status, 'completed');
  assert.equal(r.body.visitId, 'visit_a1');
  assert.equal(r.body.visit.id, 'visit_a1');

  const visit = fake.store['visits/visit_a1'];
  assert.equal(visit.status, 'completed');
  assert.deepEqual(
    [visit.patientId, visit.accountId, visit.appointmentId, visit.doctorId, visit.createdBy],
    ['A', 'A', 'a1', 'doc_01', 'S'],
  );
  assert.deepEqual(visit.serviceIds, ['svc_01', 'svc_02', 'svc_03']);
  assert.equal(visit.scheduledAt.toISOString(), '2099-01-05T02:00:00.000Z'); // 09:00 giờ Việt Nam
  assert.equal(visit.diagnosis, 'Viêm nướu nhẹ');
  assert.equal(visit.result, 'Đã cạo vôi, nướu ổn');
  assert.equal(visit.doctorNote, 'Tái khám sau 3 tháng');
  assert.equal(visit.chiefComplaint, 'Ê buốt răng');

  const rx = fake.store['prescriptions/rx_a1'];
  assert.equal(rx.visitId, 'visit_a1');
  assert.equal(rx.patientId, 'A');
  assert.equal(rx.items.length, 2);
  assert.deepEqual(rx.items[0], FULL.prescriptions[0]);
  assert.deepEqual(rx.items[1], { medicineName: 'Nước súc miệng', dosage: '', frequency: '', durationDays: null, instructions: '' });

  const invoice = fake.store['invoices/inv_a1'];
  assert.equal(invoice.visitId, 'visit_a1');
  assert.equal(invoice.appointmentId, 'a1');
  assert.equal(fake.store['appointments/a1'].visitId, 'visit_a1');

  const notices = fake.paths('notifications/');
  assert.deepEqual(notices, ['notifications/a1_completed']);
  const notice = fake.store['notifications/a1_completed'];
  assert.deepEqual([notice.type, notice.refId, notice.userId, notice.appointmentId], ['visit_result', 'visit_a1', 'A', 'a1']);
});

test('không gửi invoice: tự lập từ combo, dịch vụ lẻ, voucher của lịch; không có thuốc thì không tạo đơn', async () => {
  assert.equal((await complete('a1')).status, 200);
  assert.equal(fake.store['prescriptions/rx_a1'], undefined);
  const visit = fake.store['visits/visit_a1'];
  assert.deepEqual([visit.diagnosis, visit.result, visit.doctorNote], ['', '', '']);
  const invoice = fake.store['invoices/inv_a1'];
  assert.deepEqual(invoice.items, [
    { name: 'Combo sạch răng', quantity: 1, unitPrice: 250000, amount: 250000 },
    { name: 'Chụp X-quang', quantity: 1, unitPrice: 50000, amount: 50000 },
  ]);
  assert.deepEqual(
    [invoice.subtotal, invoice.discountAmount, invoice.totalAmount, invoice.paymentStatus, invoice.paymentMethod, invoice.paidAt, invoice.voucherCode],
    [300000, 30000, 270000, 'unpaid', null, null, 'GIAM30'],
  );
});

test('giá danh mục đã đổi sau khi đặt: hóa đơn gộp 1 dòng theo giá đã chốt', async () => {
  fake.store['services/svc_03'].price = 80000;
  assert.equal((await complete('a1')).status, 200);
  const invoice = fake.store['invoices/inv_a1'];
  assert.equal(invoice.items.length, 1);
  assert.equal(invoice.items[0].amount, 300000);
  assert.match(invoice.items[0].name, /Khám tổng quát, Cạo vôi, Chụp X-quang/);
  assert.equal(invoice.totalAmount, 270000);
});

test('invoice gửi tay: tính lại tổng, đã thanh toán có paidAt', async () => {
  const r = await complete('a2', {
    invoice: { items: [{ name: 'Chụp X-quang', quantity: 2, unitPrice: 50000 }], discount: 10000, paymentMethod: 'bank_transfer', paid: true },
  });
  assert.equal(r.status, 200);
  const invoice = fake.store['invoices/inv_a2'];
  assert.deepEqual([invoice.subtotal, invoice.discountAmount, invoice.totalAmount], [100000, 10000, 90000]);
  assert.deepEqual([invoice.paymentStatus, invoice.paymentMethod, invoice.patientId], ['paid', 'bank_transfer', 'kid']);
  assert.ok(invoice.paidAt instanceof Date);
  // Chỉ gửi paid, không gửi items: vẫn tự lập dòng từ lịch.
  fake.store['appointments/a1'].status = 'confirmed';
  assert.equal((await complete('a1', { invoice: { paid: true } })).status, 200);
  assert.deepEqual([fake.store['invoices/inv_a1'].paymentStatus, fake.store['invoices/inv_a1'].paymentMethod], ['paid', 'cash']);
});

test('gọi hoàn tất lần 2 trả 409, không tạo thêm document', async () => {
  assert.equal((await complete('a1', FULL)).status, 200);
  const old = snapshot();
  const again = await complete('a1', FULL);
  assert.equal(again.status, 409);
  assert.deepEqual(fake.store, old);
});

test('đã có visit cùng id (dữ liệu lạ) thì 409, không ghi đè', async () => {
  fake.store['visits/visit_a1'] = { patientId: 'A', status: 'completed', diagnosis: 'cũ' };
  const old = snapshot();
  assert.equal((await complete('a1', FULL)).status, 409);
  assert.deepEqual(fake.store, old);
});

const INVALID = [
  { visit: 'text' },
  { visit: { diagnosis: 5 } },
  { visit: { result: 'x'.repeat(2001) } },
  { prescriptions: {} },
  { prescriptions: [{ dosage: '1 viên' }] },
  { prescriptions: [{ medicineName: 'A', durationDays: 0 }] },
  { prescriptions: [{ medicineName: 'A', durationDays: 2.5 }] },
  { prescriptions: Array.from({ length: 21 }, () => ({ medicineName: 'A' })) },
  { invoice: [] },
  { invoice: { items: [] } },
  { invoice: { items: [{ name: 'A', quantity: 0, unitPrice: 1 }] } },
  { invoice: { items: [{ name: 'A', quantity: 1, unitPrice: -1 }] } },
  { invoice: { items: [{ name: '', quantity: 1, unitPrice: 1 }] } },
  { invoice: { paymentMethod: 'bitcoin' } },
  { invoice: { paid: 'yes' } },
  { invoice: { discount: -5 } },
];
for (const body of INVALID) {
  test(`dữ liệu hoàn tất sai trả 400: ${JSON.stringify(body).slice(0, 60)}`, async () => {
    const old = snapshot();
    const r = await complete('a1', body);
    assert.equal(r.status, 400, r.body.message);
    assert.deepEqual(fake.store, old);
  });
}

test('kèm hồ sơ khám khi không phải completed thì 400', async () => {
  fake.store['appointments/a1'].status = 'booked';
  const old = snapshot();
  const r = await call('/appointments/a1/status', { method: 'PATCH', body: { status: 'confirmed', visit: { diagnosis: 'x' } } });
  assert.equal(r.status, 400);
  assert.deepEqual(fake.store, old);
});

test('bệnh nhân không hoàn tất được lịch, không tạo được liệu trình, tái khám, buổi điều trị', async () => {
  const old = snapshot();
  assert.equal((await complete('a1', FULL, 'A')).status, 403);
  assert.equal((await call('/treatments', { method: 'POST', token: 'A', body: { accountId: 'A', name: 'x', sessions: [{}] } })).status, 403);
  assert.equal((await call('/follow-ups', { method: 'POST', token: 'A', body: { accountId: 'A', scheduledAt: '2099-02-01', reason: 'x' } })).status, 403);
  assert.equal((await call('/treatments/t/sessions/s', { method: 'PATCH', token: 'A', body: { status: 'completed', visitId: 'v' } })).status, 403);
  assert.equal((await call('/follow-ups', { method: 'POST', token: null, body: {} })).status, 401);
  assert.deepEqual(fake.store, old);
});

test('bệnh nhân xem được visit, đơn thuốc, hóa đơn của mình; tài khoản khác 403', async () => {
  await complete('a1', FULL);
  await complete('a2');
  const visit = await call('/visits/visit_a1', { token: 'A' });
  assert.equal(visit.status, 200);
  assert.equal(visit.body.appointmentId, 'a1');
  const rx = await call('/visits/visit_a1/prescriptions', { token: 'A' });
  assert.deepEqual(rx.body.map((p) => p.id), ['rx_a1']);
  assert.equal((await call('/invoices/inv_a1', { token: 'A' })).body.visitId, 'visit_a1');
  // Hồ sơ người thân nằm theo patientId của người thân.
  const kidVisits = await call('/patients/kid/visits', { token: 'A' });
  assert.deepEqual(kidVisits.body.map((v) => v.id), ['visit_a2']);
  for (const path of ['/visits/visit_a1', '/visits/visit_a1/prescriptions', '/invoices/inv_a1', '/patients/kid/visits']) {
    assert.equal((await call(path, { token: 'B' })).status, 403, path);
  }
});

const TREATMENT = {
  accountId: 'A',
  patientId: 'kid',
  doctorId: 'doc_01',
  name: 'Niềng răng giai đoạn 1',
  diagnosis: 'Răng mọc lệch',
  sessions: [
    { scheduledAt: '2099-02-01T09:00:00+07:00', notes: 'Gắn mắc cài' },
    { scheduledAt: '2099-03-01' },
  ],
};

test('staff tạo liệu trình: liệu trình và các buổi đều "planned", đánh số buổi', async () => {
  const r = await call('/treatments', { method: 'POST', body: TREATMENT });
  assert.equal(r.status, 201);
  const t = fake.store[`treatments/${r.body.id}`];
  assert.deepEqual(
    [t.status, t.patientId, t.accountId, t.doctorName, t.totalSessions, t.createdBy],
    ['planned', 'kid', 'A', 'BS. Minh', 2, 'S'],
  );
  assert.equal(t.startAt.toISOString(), '2099-02-01T02:00:00.000Z');
  assert.equal(t.endAt.toISOString(), '2099-03-01T02:00:00.000Z');
  const sessions = fake.paths('treatment_sessions/').map((p) => fake.store[p]);
  assert.deepEqual(sessions.map((s) => [s.sessionNumber, s.status, s.treatmentId, s.patientId, s.visitId]), [
    [1, 'planned', r.body.id, 'kid', null],
    [2, 'planned', r.body.id, 'kid', null],
  ]);
  assert.equal(r.body.sessions.length, 2);
});

for (const [label, change, message] of [
  ['người thân đã xóa', { patientId: 'old' }, /đã bị xóa/],
  ['bệnh nhân của tài khoản khác', { patientId: 'B' }, /không thuộc/],
  ['tài khoản không có', { accountId: 'ghost', patientId: undefined }, /tài khoản/],
  ['thiếu tên', { name: '  ' }, /tên liệu trình/],
  ['không có buổi', { sessions: [] }, /ít nhất 1 buổi/],
  ['ngày sai', { sessions: [{ scheduledAt: '01/02/2099' }] }, /YYYY-MM-DD/],
  ['bác sĩ không có', { doctorId: 'doc_x' }, /bác sĩ/],
  ['endAt trước startAt', { startAt: '2099-05-01', endAt: '2099-04-01' }, /endAt/],
]) {
  test(`tạo liệu trình sai (${label}) trả 400, không ghi`, async () => {
    const old = snapshot();
    const r = await call('/treatments', { method: 'POST', body: { ...TREATMENT, ...change } });
    assert.equal(r.status, 400);
    assert.match(r.body.message, message);
    assert.deepEqual(fake.store, old);
  });
}

async function treatmentWithVisits() {
  const created = await call('/treatments', { method: 'POST', body: TREATMENT });
  await complete('a2'); // visit_a2 của "kid"
  fake.store['visits/visit_k2'] = { patientId: 'kid', status: 'completed', appointmentId: 'ax' };
  fake.store['visits/visit_pending'] = { patientId: 'kid', status: 'pending' };
  return { id: created.body.id, s1: `${created.body.id}_s1`, s2: `${created.body.id}_s2` };
}
const markSession = (t, s, body) =>
  call(`/treatments/${t}/sessions/${s}`, { method: 'PATCH', body: { status: 'completed', ...body } });

test('cập nhật buổi: liệu trình chuyển in_progress rồi completed', async () => {
  const t = await treatmentWithVisits();
  const first = await markSession(t.id, t.s1, { visitId: 'visit_a2', notes: 'Đã gắn mắc cài' });
  assert.equal(first.status, 200);
  assert.equal(first.body.treatmentStatus, 'in_progress');
  const session = fake.store[`treatment_sessions/${t.s1}`];
  assert.deepEqual([session.status, session.visitId, session.appointmentId, session.notes, session.completedBy], ['completed', 'visit_a2', 'a2', 'Đã gắn mắc cài', 'S']);
  assert.equal(fake.store[`treatments/${t.id}`].status, 'in_progress');
  const second = await markSession(t.id, t.s2, { visitId: 'visit_k2' });
  assert.equal(second.body.treatmentStatus, 'completed');
  assert.equal(fake.store[`treatments/${t.id}`].status, 'completed');
});

test('cập nhật buổi sai: visit chưa hoàn tất, khác bệnh nhân, đã gắn, buổi đã xong, không có', async () => {
  const t = await treatmentWithVisits();
  fake.store['visits/visit_other'] = { patientId: 'A', status: 'completed' };
  const old = snapshot();
  assert.equal((await markSession(t.id, t.s1, { visitId: 'visit_pending' })).status, 400);
  assert.equal((await markSession(t.id, t.s1, { visitId: 'visit_other' })).status, 400);
  assert.equal((await markSession(t.id, t.s1, { visitId: 'nope' })).status, 404);
  assert.equal((await markSession(t.id, 'nope', { visitId: 'visit_a2' })).status, 404);
  assert.equal((await markSession('nope', t.s1, { visitId: 'visit_a2' })).status, 404);
  assert.equal((await markSession(t.id, t.s1, {})).status, 400);
  assert.equal((await call(`/treatments/${t.id}/sessions/${t.s1}`, { method: 'PATCH', body: { status: 'planned', visitId: 'visit_a2' } })).status, 400);
  assert.deepEqual(fake.store, old);

  assert.equal((await markSession(t.id, t.s1, { visitId: 'visit_a2' })).status, 200);
  assert.equal((await markSession(t.id, t.s1, { visitId: 'visit_k2' })).status, 409); // buổi đã xong
  assert.equal((await markSession(t.id, t.s2, { visitId: 'visit_a2' })).status, 409); // visit đã gắn
});

test('A10: bệnh nhân link-visit với visit tạo từ hoàn tất lịch được, visit chưa xong bị chặn', async () => {
  const t = await treatmentWithVisits();
  const link = (visitId, sessionId) => call(`/treatments/${t.id}/sessions/link-visit`, { method: 'POST', token: 'A', body: { visitId, sessionId } });
  assert.equal((await link('visit_pending', t.s1)).status, 400);
  const ok = await link('visit_a2', t.s1);
  assert.equal(ok.status, 200);
  assert.equal(fake.store[`treatments/${t.id}`].status, 'in_progress');
});

const FOLLOW_UP = {
  accountId: 'A', patientId: 'kid', doctorId: 'doc_01', scheduledAt: '2099-04-01',
  reason: 'Kiểm tra mắc cài', serviceId: 'svc_01',
};

test('staff đề xuất tái khám: status "suggested", ngày ở scheduledAt, thông báo follow_up', async () => {
  await complete('a2');
  const r = await call('/follow-ups', { method: 'POST', body: { ...FOLLOW_UP, visitId: 'visit_a2', notes: 'Mang theo hàm duy trì' } });
  assert.equal(r.status, 201);
  const f = fake.store[`follow_ups/${r.body.id}`];
  assert.deepEqual([f.status, f.patientId, f.accountId, f.visitId, f.serviceId, f.doctorName, f.reason], ['suggested', 'kid', 'A', 'visit_a2', 'svc_01', 'BS. Minh', 'Kiểm tra mắc cài']);
  assert.equal(f.scheduledAt.toISOString(), '2099-04-01T02:00:00.000Z');
  const notice = fake.store[`notifications/followup_${r.body.id}`];
  assert.deepEqual([notice.type, notice.refId, notice.userId, notice.patientId], ['follow_up', r.body.id, 'A', 'kid']);
  assert.match(notice.body, /01\/04\/2099/);
  const list = await call('/patients/kid/follow-ups', { token: 'A' });
  assert.deepEqual(list.body.map((x) => x.id), [r.body.id]);
});

for (const [label, change] of [
  ['ngày đã qua', { scheduledAt: '2020-01-01' }],
  ['thiếu ngày', { scheduledAt: undefined }],
  ['thiếu lý do', { reason: '' }],
  ['người thân đã xóa', { patientId: 'old' }],
  ['visit của bệnh nhân khác', { visitId: 'visit_a1' }],
  ['dịch vụ không có', { serviceId: 'svc_x' }],
  ['liệu trình không có', { treatmentId: 'tx' }],
]) {
  test(`đề xuất tái khám sai (${label}) trả 400, không ghi`, async () => {
    await complete('a1');
    const old = snapshot();
    const r = await call('/follow-ups', { method: 'POST', body: { ...FOLLOW_UP, ...change } });
    assert.equal(r.status, 400, r.body.message);
    assert.deepEqual(fake.store, old);
  });
}
