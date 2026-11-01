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

// Fixed request clock, restored by node:test after each test; no scheduler is started.
beforeEach((t) => t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-11-01T00:00:00Z') }));

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
  // AUD-01 approved: no historical line-price snapshot, so use an explicit summary, not current catalog prices.
  assert.deepEqual(invoice.items, [
    { name: 'Chi phí theo giá chốt lịch hẹn (dòng tổng hợp)', quantity: 1, unitPrice: 300000, amount: 300000 },
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
  assert.match(invoice.items[0].name, /giá chốt.*tổng hợp/);
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
  // AUD-01 approved: payment method must be explicit; never default to cash.
  assert.equal((await complete('a1', { invoice: { paid: true, paymentMethod: 'card' } })).status, 200);
  assert.deepEqual([fake.store['invoices/inv_a1'].paymentStatus, fake.store['invoices/inv_a1'].paymentMethod], ['paid', 'card']);
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
  fake.store['prescriptions/rx_a1'] = { visitId: 'visit_a1', items: [{ medicineName: 'Thuốc cũ' }] };
  fake.store['invoices/inv_a1'] = { visitId: 'visit_a1', totalAmount: 123000 };
  fake.store['notifications/existing'] = { userId: 'A', isRead: true };
  const old = snapshot();
  assert.equal((await complete('a1', FULL)).status, 409);
  assert.deepEqual(fake.store, old);
});

test('AUD-02: visit khớp appointment vẫn trả 409, không tự coi là replay', async () => {
  fake.store['visits/visit_a1'] = {
    appointmentId: 'a1', accountId: 'A', patientId: 'A', status: 'completed',
    diagnosis: FULL.visit.diagnosis,
  };
  const old = snapshot();
  assert.equal((await complete('a1', FULL)).status, 409);
  assert.deepEqual(fake.store, old);
});

test('AUD-02: visit chưa tồn tại thì completion giữ response và liên kết hiện tại', async () => {
  const old = snapshot();
  const r = await complete('a1', { visit: FULL.visit });
  assert.equal(r.status, 200);
  assert.equal(r.body.id, 'a1');
  assert.equal(r.body.status, 'completed');
  assert.equal(r.body.visitId, 'visit_a1');
  assert.deepEqual(r.body.visit, { id: 'visit_a1' });
  const visit = fake.store['visits/visit_a1'];
  assert.equal(visit.appointmentId, 'a1');
  assert.equal(visit.patientId, 'A');
  assert.equal(visit.diagnosis, FULL.visit.diagnosis);
  assert.equal(fake.store['appointments/a1'].visitId, 'visit_a1');
  const notice = fake.store['notifications/a1_completed'];
  assert.deepEqual([notice.userId, notice.type, notice.refId], ['A', 'visit_result', 'visit_a1']);
  assert.deepEqual(fake.paths('visits/'), ['visits/visit_a1']);
  assert.deepEqual(fake.paths('notifications/'), ['notifications/a1_completed']);
  for (const [path, value] of Object.entries(old)) {
    if (path !== 'appointments/a1') assert.deepEqual(fake.store[path], value);
  }
});

test('AUD-02: visit xuất hiện trước commit khiến transaction retry và trả 409', async () => {
  const old = snapshot();
  const existing = { appointmentId: 'a1', patientId: 'A', diagnosis: 'Ghi bởi tác vụ khác' };
  let inserted = false;
  fake.state.beforeCommit = async () => {
    if (inserted) return;
    inserted = true;
    await fake.db.collection('visits').doc('visit_a1').set(existing);
  };
  assert.equal((await complete('a1', FULL)).status, 409);
  assert.equal(fake.state.conflicts, 1);
  assert.equal(fake.state.attempts, 2);
  assert.deepEqual(fake.store, { ...old, 'visits/visit_a1': existing });
});

test('AUD-02: lỗi commit rollback mọi thay đổi completion', async () => {
  const old = snapshot();
  fake.state.beforeCommit = async () => { throw new Error('fake completion commit failure'); };
  assert.equal((await complete('a1', FULL)).status, 500);
  assert.deepEqual(fake.store, old);
});

test('AUD-02: hai completion đồng thời chỉ ghi một visit và một notification', async () => {
  fake.interleave(2);
  const responses = await Promise.all([complete('a1'), complete('a1')]);
  assert.deepEqual(responses.map((r) => r.status).sort(), [200, 409]);
  assert.deepEqual(fake.paths('visits/'), ['visits/visit_a1']);
  assert.deepEqual(fake.paths('notifications/'), ['notifications/a1_completed']);
  assert.equal(fake.store['appointments/a1'].status, 'completed');
  assert.equal(fake.store['appointments/a1'].visitId, 'visit_a1');
});

test('AUD-01: bộ chứng từ dùng ownership và staff identity đáng tin, metadata cùng thời điểm', async () => {
  const r = await complete('a1', {
    ...FULL, accountId: 'B', patientId: 'B', doctorId: 'fake', createdBy: 'fake',
    invoice: { paid: true, paymentMethod: 'e_wallet' },
  });
  assert.equal(r.status, 200);
  for (const path of ['visits/visit_a1', 'prescriptions/rx_a1', 'invoices/inv_a1']) {
    const record = fake.store[path];
    assert.deepEqual([record.accountId, record.patientId, record.appointmentId, record.doctorId, record.createdBy], ['A', 'A', 'a1', 'doc_01', 'S']);
    assert.deepEqual(record.createdAt, fake.store['appointments/a1'].statusUpdatedAt);
  }
  for (const path of ['prescriptions/rx_a1', 'invoices/inv_a1']) {
    assert.equal(fake.store[path].visitId, 'visit_a1');
    assert.deepEqual(fake.store[path].issuedAt, fake.store[path].createdAt);
  }
  assert.deepEqual(fake.store['invoices/inv_a1'].paidAt, fake.store['invoices/inv_a1'].issuedAt);
  assert.equal(fake.store['notifications/a1_completed'].refId, 'visit_a1');
});

test('AUD-01: Rx chuẩn hóa optional fields, không đổi payload', async () => {
  const body = { prescriptions: [{ medicineName: ' A ', dosage: null, frequency: '  mỗi ngày ', instructions: null }] };
  const old = structuredClone(body);
  assert.equal((await complete('a2', body)).status, 200);
  assert.deepEqual(body, old);
  assert.deepEqual(fake.store['prescriptions/rx_a2'].items, [{ medicineName: 'A', dosage: '', frequency: 'mỗi ngày', durationDays: null, instructions: '' }]);
  assert.equal(fake.store['prescriptions/rx_a2'].patientId, 'kid');
});

for (const prescriptions of [undefined, []]) {
  test(`AUD-01: không kê thuốc (${prescriptions === undefined ? 'omitted' : 'empty'}) không tạo Rx`, async () => {
    assert.equal((await complete('a1', { prescriptions })).status, 200);
    assert.deepEqual(fake.paths('prescriptions/'), []);
    assert.equal(fake.store['invoices/inv_a1'].paymentStatus, 'unpaid');
    assert.equal(fake.store['invoices/inv_a1'].paymentMethod, null);
    assert.equal(fake.store['invoices/inv_a1'].paidAt, null);
  });
}

for (const path of ['visits/visit_a1', 'prescriptions/rx_a1', 'invoices/inv_a1']) {
  test(`AUD-01: collision ${path}, không kê thuốc vẫn giữ nguyên toàn bộ store`, async () => {
    fake.store[path] = { patientId: 'A', marker: 'historical' };
    const old = snapshot();
    assert.equal((await complete('a1')).status, 409);
    assert.deepEqual(fake.store, old);
  });
  test(`AUD-01: concurrent insert ${path} gây retry và 409, không partial writes`, async () => {
    const old = snapshot();
    const external = { patientId: 'A', marker: 'concurrent' };
    let once = false;
    fake.state.beforeCommit = async () => {
      if (once) return;
      once = true;
      await fake.db.collection(path.split('/')[0]).doc(path.split('/')[1]).set(external);
    };
    assert.equal((await complete('a1', FULL)).status, 409);
    assert.equal(fake.state.conflicts, 1);
    assert.deepEqual(fake.store, { ...old, [path]: external });
  });
}

test('AUD-01: staff items khác giá lịch, discount mặc định 0, không đổi giá appointment', async () => {
  assert.equal((await complete('a1', { invoice: { items: [{ name: ' A ', quantity: 2, unitPrice: 7 }] } })).status, 200);
  const invoice = fake.store['invoices/inv_a1'];
  assert.deepEqual([invoice.subtotal, invoice.discountAmount, invoice.totalAmount], [14, 0, 14]);
  assert.deepEqual(invoice.items, [{ name: 'A', quantity: 2, unitPrice: 7, amount: 14 }]);
  assert.equal(fake.store['appointments/a1'].totalPrice, 270000);
});

test('AUD-01: giá chốt hoạt động khi catalog đã mất, discount tường minh được dùng', async () => {
  for (const path of fake.paths('services/').concat(fake.paths('combos/'))) delete fake.store[path];
  assert.equal((await complete('a1', { invoice: { discount: 10000 } })).status, 200);
  const invoice = fake.store['invoices/inv_a1'];
  assert.deepEqual([invoice.subtotal, invoice.discountAmount, invoice.totalAmount], [300000, 10000, 290000]);
  assert.match(invoice.items[0].name, /giá chốt.*tổng hợp/);
});

for (const [label, invoice] of [
  ['discount vượt subtotal', { items: [{ name: 'A', quantity: 1, unitPrice: 1 }], discount: 2 }],
  ['overflow nhân', { items: [{ name: 'A', quantity: 2, unitPrice: Number.MAX_SAFE_INTEGER }] }],
  ['overflow cộng', { items: [{ name: 'A', quantity: 1, unitPrice: Number.MAX_SAFE_INTEGER }, { name: 'B', quantity: 1, unitPrice: 1 }] }],
  ['paid thiếu method', { paid: true }],
]) {
  test(`AUD-01: ${label} trả 400 và không ghi`, async () => {
    const old = snapshot();
    assert.equal((await complete('a1', { ...FULL, invoice })).status, 400);
    assert.deepEqual(fake.store, old);
  });
}

test('AUD-01: discount bằng subtotal cho tổng 0 và vẫn unpaid khi không gửi paid', async () => {
  assert.equal((await complete('a1', { invoice: { items: [{ name: 'A', quantity: 1, unitPrice: 10 }], discount: 10 } })).status, 200);
  assert.equal(fake.store['invoices/inv_a1'].totalAmount, 0);
  assert.equal(fake.store['invoices/inv_a1'].paymentStatus, 'unpaid');
});

test('AUD-01: legacy thiếu discount mặc định 0', async () => {
  delete fake.store['appointments/a1'].discount;
  assert.equal((await complete('a1')).status, 200);
  assert.deepEqual([fake.store['invoices/inv_a1'].subtotal, fake.store['invoices/inv_a1'].discountAmount], [270000, 0]);
});

for (const totalPrice of [undefined, null, -1, '100', 1.5, Number.MAX_SAFE_INTEGER + 1]) {
  test(`AUD-01: legacy totalPrice ${String(totalPrice)} không hợp lệ: 409, staff items vẫn dùng được`, async () => {
    fake.store['appointments/a1'].totalPrice = totalPrice;
    const old = snapshot();
    assert.equal((await complete('a1', FULL)).status, 409);
    assert.deepEqual(fake.store, old);
    assert.equal((await complete('a1', { invoice: { items: [{ name: 'A', quantity: 1, unitPrice: 5 }] } })).status, 200);
    assert.equal(fake.store['invoices/inv_a1'].totalAmount, 5);
    assert.equal(fake.store['appointments/a1'].totalPrice, totalPrice);
  });
}

test('AUD-01: tổng giá chốt cộng discount overflow trả 400, không ghi', async () => {
  fake.store['appointments/a1'].totalPrice = Number.MAX_SAFE_INTEGER;
  fake.store['appointments/a1'].discount = 1;
  const old = snapshot();
  assert.equal((await complete('a1')).status, 400);
  assert.deepEqual(fake.store, old);
});

test('AUD-01: lỗi commit rollback cả chứng từ, appointment, notification và follow-up', async () => {
  fake.store['appointments/a1'].followUpId = 'f1';
  fake.store['follow_ups/f1'] = { accountId: 'A', patientId: 'A', status: 'booked', appointmentId: 'a1' };
  const old = snapshot();
  fake.state.beforeCommit = async () => { throw new Error('fake AUD-01 commit failure'); };
  assert.equal((await complete('a1', FULL)).status, 500);
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

const AUD10_INVALID = [
  { visit: null }, { visit: [] }, { visit: false },
  { prescriptions: null }, { prescriptions: false },
  { prescriptions: [null] }, { prescriptions: [[]] },
  { prescriptions: [{ medicineName: '' }] },
  { prescriptions: [{ medicineName: '   ' }] },
  { prescriptions: [{ medicineName: 5 }] },
  ...[-1, '3', false].map(durationDays => ({ prescriptions: [{ medicineName: 'A', durationDays }] })),
  ...['dosage', 'frequency', 'instructions'].map(field => ({ prescriptions: [{ medicineName: 'A', [field]: 5 }] })),
  { invoice: null }, { invoice: false },
  ...[null, {}, 'items'].map(items => ({ invoice: { items } })),
  ...[null, [], 'item'].map(item => ({ invoice: { items: [item] } })),
  ...['', '   ', 1, null].map(name => ({ invoice: { items: [{ name, quantity: 1, unitPrice: 0 }] } })),
  ...[undefined, null, -1, 1.5, '1', true].map(quantity => ({ invoice: { items: [{ name: 'A', quantity, unitPrice: 0 }] } })),
  ...[undefined, null, 0.5, '100', true, Number.MAX_SAFE_INTEGER + 1].map(unitPrice => ({ invoice: { items: [{ name: 'A', quantity: 1, unitPrice }] } })),
  ...[null, 0.5, '100', false, Number.MAX_SAFE_INTEGER + 1].map(discount => ({ invoice: { discount } })),
  ...[null, 0, 1].map(paid => ({ invoice: { paid } })),
  ...[null, '', 'CASH', 1].map(paymentMethod => ({ invoice: { paymentMethod } })),
];
AUD10_INVALID.forEach((body, index) => {
  test(`AUD-10: invalid payload ${index + 1} trả 400 trước transaction, giữ nguyên dữ liệu`, async () => {
    fake.store['prescriptions/existing'] = { patientId: 'A', items: [] };
    fake.store['invoices/existing'] = { patientId: 'A', totalAmount: 100 };
    fake.store['notifications/existing'] = { userId: 'A', isRead: true };
    const old = snapshot();
    const r = await complete('a1', body);
    assert.equal(r.status, 400);
    assert.equal(typeof r.body.message, 'string');
    assert.equal(fake.state.attempts, 0);
    assert.deepEqual(fake.store, old);
  });
});

const AUD10_VALID = [
  {}, { visit: {} }, { prescriptions: [] }, { invoice: {} }, FULL,
  { prescriptions: [{ medicineName: 'A', durationDays: null }] },
  { prescriptions: [{ medicineName: 'A', durationDays: 1 }] },
  ...['cash', 'bank_transfer', 'card', 'e_wallet'].map(paymentMethod => ({ invoice: { paymentMethod } })),
  { invoice: { paid: false } }, { invoice: { paid: true } },
  { invoice: { items: [{ name: 'A', quantity: 1, unitPrice: 0 }], discount: 0 } },
  { invoice: { items: [{ name: 'A', quantity: 2, unitPrice: Number.MAX_SAFE_INTEGER }], discount: Number.MAX_SAFE_INTEGER } },
  // Subtotal arithmetic and discount > subtotal belong to AUD-01, not this validator.
  { invoice: { items: [{ name: 'A', quantity: 1, unitPrice: 1 }], discount: 2 } },
];
AUD10_VALID.forEach((body, index) => {
  test(`AUD-10: payload ${index + 1} theo contract AUD-01 đã duyệt`, async () => {
    const old = snapshot();
    const { parseCompletionBody } = require('../../src/utils/clinical');
    const missingPaymentMethod = body.invoice?.paid === true && body.invoice.paymentMethod === undefined;
    if (missingPaymentMethod) {
      assert.throws(() => parseCompletionBody(body), error => error.status === 400);
    } else {
      assert.doesNotThrow(() => parseCompletionBody(body));
    }
    const r = await complete('a1', body);
    // Keep the old cases: individual fields can pass AUD-10 but fail AUD-01 arithmetic.
    const arithmeticInvalid = index === 14 || index === 15;
    if (missingPaymentMethod || arithmeticInvalid) {
      assert.equal(r.status, 400);
      assert.deepEqual(fake.store, old);
      if (missingPaymentMethod) assert.equal(fake.state.attempts, 0);
      return;
    }
    assert.equal(r.status, 200);
    assert.equal(r.body.status, 'completed');
    assert.equal(r.body.visitId, 'visit_a1');
    assert.deepEqual(r.body.visit, { id: 'visit_a1' });
    assert.equal(fake.store['visits/visit_a1'].appointmentId, 'a1');
    assert.equal(fake.store['notifications/a1_completed'].refId, 'visit_a1');
  });
});

test('AUD-10: NaN và Infinity bị từ chối trực tiếp, không bị JSON đổi thành null', () => {
  const { parseCompletionBody } = require('../../src/utils/clinical');
  const old = snapshot();
  for (const value of [NaN, Infinity, -Infinity]) {
    for (const body of [
      { invoice: { items: [{ name: 'A', quantity: 1, unitPrice: value }] } },
      { invoice: { discount: value } },
      { invoice: { items: [{ name: 'A', quantity: value, unitPrice: 0 }] } },
      { prescriptions: [{ medicineName: 'A', durationDays: value }] },
    ]) {
      assert.throws(() => parseCompletionBody(body), error => error.status === 400);
    }
  }
  assert.equal(fake.state.attempts, 0);
  assert.deepEqual(fake.store, old);
});

test('AUD-10: parser không thay đổi payload hợp lệ', () => {
  const { parseCompletionBody } = require('../../src/utils/clinical');
  const body = { ...structuredClone(FULL), invoice: { paid: true, paymentMethod: 'cash' } };
  const old = structuredClone(body);
  parseCompletionBody(body);
  assert.deepEqual(body, old);
});

test('AUD-10: commit lỗi sau payload hợp lệ rollback toàn bộ dữ liệu', async () => {
  const old = snapshot();
  fake.state.beforeCommit = async () => { throw new Error('fake AUD-10 commit failure'); };
  assert.equal((await complete('a1', { ...FULL, invoice: { paid: true, paymentMethod: 'cash' } })).status, 500);
  assert.deepEqual(fake.store, old);
});

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
  // AUD-03 approved: production keeps auto-ID; locate the event by its source.
  const notice = fake.paths('notifications/').map(path => fake.store[path])
    .find(item => item.type === 'follow_up' && item.refId === r.body.id);
  assert.deepEqual([notice.type, notice.refId, notice.userId, notice.patientId], ['follow_up', r.body.id, 'A', 'kid']);
  // AUD-09 approved: production notification body is the reason, not a formatted date.
  assert.equal(notice.body, f.reason);
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

const followUp = (change = {}, token = 'staff') => call('/follow-ups', {
  method: 'POST', token,
  body: { ...FOLLOW_UP, scheduledAt: '2099-04-01T09:00:00+07:00', ...change },
});

const AUD09_VALID = [
  ['2028-02-29', '2028-02-29T02:00:00.000Z'],
  ['2000-02-29', '2000-02-29T02:00:00.000Z'],
  ['2026-04-30', '2026-04-30T02:00:00.000Z'],
  ['2026-11-01', '2026-11-01T02:00:00.000Z'],
  ['2026-11-01T09:00:00+07:00', '2026-11-01T02:00:00.000Z'],
  ['2026-11-01T09:00:00+07', '2026-11-01T02:00:00.000Z'],
  ['2026-11-01T02:00:00Z', '2026-11-01T02:00:00.000Z'],
  ['2026-11-01T02:00:00.1Z', '2026-11-01T02:00:00.100Z'],
  ['2026-11-01T02:00:00.12Z', '2026-11-01T02:00:00.120Z'],
  ['2026-11-01T02:00:00.123Z', '2026-11-01T02:00:00.123Z'],
  ['2026-11-01T00:15:00+07:00', '2026-10-31T17:15:00.000Z'],
  ['2026-10-31T23:30:00-02:00', '2026-11-01T01:30:00.000Z'],
];
for (const [value, expected] of AUD09_VALID) {
  test(`AUD-09: parser ${value} đúng instant`, () => {
    const { optionalDate } = require('../../src/utils/clinical');
    assert.equal(optionalDate(value, 'date').toISOString(), expected);
  });
}

const AUD09_INVALID = [
  '', ' ', 0, 1, false, true, {}, [], { _seconds: 1, _nanoseconds: 0 },
  '01/02/2099', '02/01/2099', 'March 1, 2099', '123456789',
  '2026-02-29', '2100-02-29', '2026-02-30', '2026-04-31',
  '2026-00-01', '2026-13-01', '2026-01-00', '2026-01-32', '2026-1-01',
  '2026-11-01T09:00:00', '2026-11-01T09:00Z',
  '2026-11-01T24:00:00Z', '2026-11-01T09:60:00Z', '2026-11-01T09:00:60Z',
  '2026-11-01T09:00:00+24:00', '2026-11-01T09:00:00+07:60',
  '2026-11-01T09:00:00+7:00', '2026-11-01T09:00:00.1234Z',
  '2026-11-01T09:00:00Zjunk',
];
AUD09_INVALID.forEach((value, index) => {
  test(`AUD-09: invalid date ${index} bị chặn trước ghi ở Treatment và Follow-up`, async () => {
    const { optionalDate } = require('../../src/utils/clinical');
    const old = snapshot();
    assert.throws(() => optionalDate(value, 'date'), error => error.status === 400);
    for (const field of ['startAt', 'endAt']) {
      const r = await call('/treatments', { method: 'POST', body: { ...TREATMENT, [field]: value } });
      assert.equal(r.status, 400);
    }
    const r = await call('/treatments', { method: 'POST', body: { ...TREATMENT, sessions: [{ scheduledAt: value }] } });
    assert.equal(r.status, 400);
    assert.equal((await followUp({ scheduledAt: value })).status, 400);
    assert.equal(fake.state.attempts, 0);
    assert.deepEqual(fake.store, old);
  });
});

for (const value of [undefined, null]) {
  test(`AUD-09: Treatment optional ${value} giữ null, Follow-up bắt buộc`, async () => {
    const r = await call('/treatments', { method: 'POST', body: { ...TREATMENT, startAt: value, endAt: value, sessions: [{ scheduledAt: value }] } });
    assert.equal(r.status, 201);
    assert.equal(r.body.startAt, null);
    assert.equal(r.body.endAt, null);
    assert.equal(r.body.sessions[0].scheduledAt, null);
    const old = snapshot();
    assert.equal((await followUp({ scheduledAt: value })).status, 400);
    assert.deepEqual(fake.store, old);
  });
}

test('AUD-09: Treatment quá khứ được phép, suy min/max và không thêm ràng buộc session', async () => {
  const r = await call('/treatments', { method: 'POST', body: { ...TREATMENT, sessions: [{ scheduledAt: '2020-02-02' }, { scheduledAt: '2020-01-01T05:00:00Z' }] } });
  assert.equal(r.status, 201);
  assert.equal(r.body.startAt, '2020-01-01T05:00:00.000Z');
  assert.equal(r.body.endAt, '2020-02-02T02:00:00.000Z');
  const explicit = await call('/treatments', { method: 'POST', body: { ...TREATMENT, startAt: '2020-03-01', endAt: '2020-03-01' } });
  assert.equal(explicit.status, 201);
  assert.equal(explicit.body.startAt, explicit.body.endAt);
  const old = snapshot();
  assert.equal((await call('/treatments', { method: 'POST', body: { ...TREATMENT, startAt: '2020-03-02', endAt: '2020-03-01' } })).status, 400);
  assert.deepEqual(fake.store, old);
});

for (const [label, now, scheduledAt, expected] of [
  ['past', '2026-11-01T00:00:00Z', '2026-10-31T23:59:59Z', 400],
  ['equal now', '2026-11-01T00:00:00Z', '2026-11-01T00:00:00Z', 400],
  ['future 1ms', '2026-11-01T00:00:00Z', '2026-11-01T00:00:00.001Z', 201],
  ['today before 09', '2026-11-01T01:59:59Z', '2026-11-01', 201],
  ['today at 09', '2026-11-01T02:00:00Z', '2026-11-01', 400],
  ['today after 09', '2026-11-01T02:00:01Z', '2026-11-01', 400],
  ['VN midnight', '2026-10-31T17:30:00Z', '2026-11-01', 201],
  ['VN yesterday', '2026-10-31T17:30:00Z', '2026-10-31', 400],
  ['future explicit today', '2026-11-01T03:00:00Z', '2026-11-01T11:00:00+07:00', 201],
]) {
  test(`AUD-09: Follow-up ${label} theo fake clock`, async (t) => {
    t.mock.timers.setTime(new Date(now).getTime());
    const old = snapshot();
    const r = await followUp({ scheduledAt });
    assert.equal(r.status, expected);
    if (expected === 400) {
      assert.deepEqual(fake.store, old);
      assert.equal(fake.state.attempts, 0);
    } else {
      const f = fake.store[`follow_ups/${r.body.id}`];
      const n = fake.paths('notifications/').map(path => fake.store[path])[0];
      assert.equal(f.createdAt.getTime(), new Date(now).getTime());
      assert.deepEqual(n.createdAt, f.createdAt);
      assert.equal(n.body, f.reason);
    }
  });
}

test('AUD-09: một now cố định dù transaction retry và clock tiến lên', async (t) => {
  const initial = Date.now();
  let once = false;
  fake.state.beforeCommit = async () => {
    if (once) return;
    once = true;
    t.mock.timers.setTime(initial + 5000);
    await fake.db.collection('users').doc('A').set({ fullName: 'Updated' });
  };
  const r = await followUp({ scheduledAt: new Date(initial + 1).toISOString() });
  assert.equal(r.status, 201);
  assert.equal(fake.state.conflicts, 1);
  assert.equal(fake.store[`follow_ups/${r.body.id}`].createdAt.getTime(), initial);
});
function sourceFixtures() {
  fake.store['visits/v_source'] = { accountId: 'A', patientId: 'kid', status: 'completed' };
  fake.store['treatments/t_source'] = { accountId: 'A', patientId: 'kid', status: 'planned' };
}

for (const [label, change] of [
  ['self', { patientId: undefined }],
  ['family active', {}],
  ['optional null', { visitId: null, treatmentId: null, serviceId: null, doctorId: null }],
  ['no sources', { visitId: undefined, treatmentId: undefined, serviceId: undefined, doctorId: undefined }],
  ['both sources', { visitId: 'v_source', treatmentId: 't_source' }],
  ...['planned', 'in_progress', 'completed'].map(status => [`treatment ${status}`, { treatmentId: 't_source', testStatus: status }]),
]) {
  test(`AUD-03: tạo hợp lệ ${label}, đúng owner và auto-ID notification`, async () => {
    sourceFixtures();
    if (change.testStatus) fake.store['treatments/t_source'].status = change.testStatus;
    const r = await followUp({ ...change, createdBy: 'client', doctorName: 'client', role: 'patient' });
    assert.equal(r.status, 201);
    const f = fake.store[`follow_ups/${r.body.id}`];
    assert.deepEqual([f.accountId, f.patientId, f.createdBy, f.status], ['A', change.patientId === undefined && label === 'self' ? 'A' : 'kid', 'S', 'suggested']);
    assert.equal(f.doctorName, f.doctorId ? 'BS. Minh' : undefined);
    const paths = fake.paths('notifications/');
    assert.equal(paths.length, 1);
    assert.notEqual(paths[0], `notifications/followup_${r.body.id}`);
    const n = fake.store[paths[0]];
    assert.deepEqual([n.userId, n.patientId, n.type, n.refId, n.body], ['A', f.patientId, 'follow_up', r.body.id, f.reason]);
    assert.deepEqual(n.createdAt, f.createdAt);
    assert.equal((await call(`/follow-ups/${r.body.id}`, { token: 'B' })).status, 403);
  });
}

for (const field of ['accountId', 'patientId', 'visitId', 'treatmentId', 'serviceId', 'doctorId']) {
  const values = ['', '   ', 42, false, [], {}, 'invalid/path'];
  if (field === 'accountId' || field === 'patientId') values.push(null);
  for (const [index, value] of values.entries()) {
    test(`AUD-03: ${field} invalid ${index} trả 400 trước transaction`, async () => {
      const old = snapshot();
      assert.equal((await followUp({ [field]: value })).status, 400);
      assert.equal(fake.state.attempts, 0);
      assert.deepEqual(fake.store, old);
    });
  }
}

const SOURCE_INVALID = [
  ['account missing self', { accountId: 'ghost', patientId: 'ghost' }, null, 400],
  ['account missing family', { accountId: 'ghost' }, null, 400],
  ['family missing', { patientId: 'missing' }, null, 400],
  ['family wrong account', { patientId: 'outsider' }, () => { fake.store['users/B/family_members/outsider'] = {}; }, 400],
  ['family archived', { patientId: 'old' }, null, 400],
  ...['visitId', 'treatmentId', 'serviceId', 'doctorId'].map(field => [`${field} missing`, { [field]: 'missing' }, null, 400]),
  ...['visits/v_source', 'treatments/t_source'].flatMap(path => {
    const field = path.startsWith('visits') ? 'visitId' : 'treatmentId';
    const input = { [field]: path.split('/')[1] };
    return [
      [`${field} wrong account`, input, () => { fake.store[path].accountId = 'B'; }, 400],
      [`${field} wrong patient`, input, () => { fake.store[path].patientId = 'A'; }, 400],
      ...['accountId', 'patientId'].map(key => [`${field} missing ${key}`, input, () => { delete fake.store[path][key]; }, 409]),
    ];
  }),
  ...[undefined, 'pending', 'in_progress'].map(status => ['visit not completed ' + status, { visitId: 'v_source' }, () => { fake.store['visits/v_source'].status = status; }, 400]),
  ...[undefined, 'cancelled', 'unknown'].map(status => ['treatment invalid status ' + status, { treatmentId: 't_source' }, () => { fake.store['treatments/t_source'].status = status; }, 409]),
  ['service inactive', {}, () => { fake.store['services/svc_01'].isActive = false; }, 400],
  ['doctor inactive', {}, () => { fake.store['doctors/doc_01'].isActive = false; }, 400],
  ['both sources wrong patient', { visitId: 'v_source', treatmentId: 't_source' }, () => { fake.store['treatments/t_source'].patientId = 'A'; }, 400],
];
for (const [label, change, mutate, status] of SOURCE_INVALID) {
  test(`AUD-03: ${label}, không partial writes`, async () => {
    sourceFixtures();
    if (mutate) mutate();
    const old = snapshot();
    assert.equal((await followUp(change)).status, status);
    assert.deepEqual(fake.store, old);
  });
}

for (const [path, changed, status] of [
  ['users/A', null, 400],
  ['users/A/family_members/kid', { isArchived: true }, 400],
  ['visits/v_source', { accountId: 'B', patientId: 'kid', status: 'completed' }, 400],
  ['visits/v_source', { accountId: 'A', patientId: 'kid', status: 'pending' }, 400],
  ['treatments/t_source', { accountId: 'A', patientId: 'kid', status: 'cancelled' }, 409],
  ['services/svc_01', { isActive: false }, 400],
  ['doctors/doc_01', null, 400],
]) {
  test(`AUD-03: retry kiểm lại nguồn ${path} thay đổi trước commit`, async () => {
    sourceFixtures();
    const old = snapshot();
    let once = false;
    fake.state.beforeCommit = async () => {
      if (once) return;
      once = true;
      if (changed === null) {
        const batch = fake.db.batch();
        batch.delete(fake.db.collection(path.slice(0, path.lastIndexOf('/'))).doc(path.split('/').at(-1)));
        await batch.commit();
      } else {
        await fake.db.collection(path.slice(0, path.lastIndexOf('/'))).doc(path.split('/').at(-1)).set(changed);
      }
    };
    assert.equal((await followUp({ visitId: 'v_source', treatmentId: 't_source' })).status, status);
    assert.equal(fake.state.conflicts, 1);
    const expected = { ...old };
    if (changed === null) delete expected[path]; else expected[path] = changed;
    assert.deepEqual(fake.store, expected);
  });
}

test('AUD-03: commit lỗi rollback follow-up và notification', async () => {
  const old = snapshot();
  fake.state.beforeCommit = async () => { throw new Error('fake AUD-03 commit failure'); };
  assert.equal((await followUp()).status, 500);
  assert.deepEqual(fake.store, old);
});

for (const [identity, status] of [[null, 401], ['invalid', 401], ['A', 403]]) {
  test(`AUD-03: middleware từ chối identity ${identity}`, async () => {
    const old = snapshot();
    assert.equal((await followUp({ role: 'staff', createdBy: 'S' }, identity)).status, status);
    assert.deepEqual(fake.store, old);
  });
}
