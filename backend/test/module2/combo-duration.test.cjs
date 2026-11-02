// Combo có durationMinutes khác tổng thời lượng dịch vụ: không lỗi 500, dùng thời
// lượng của combo làm chuẩn và chỉ cảnh báo. Firestore giả.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('./support/fakeFirestore.cjs');

const fake = createFakeDb();
installFakeFirebase(fake);
const { buildBookingQuote } = require('../../src/utils/booking');

let server, base;
before(async () => {
  const app = express();
  app.use(express.json());
  app.use('/api/bookings', require('../../src/routes/bookings'));
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise((resolve) => server.close(resolve)));
beforeEach(() => fake.reset({
  'services/svc_01': { name: 'Khám', price: 100000, durationMinutes: 30 },
  'services/svc_02': { name: 'Cạo vôi', price: 200000, durationMinutes: 30 },
  // Lệch: combo 45 phút nhưng tổng dịch vụ 60 phút.
  'combos/combo_lech': { name: 'Combo lệch', price: 250000, durationMinutes: 45, serviceIds: ['svc_01', 'svc_02'] },
  'combos/combo_khop': { name: 'Combo khớp', price: 250000, durationMinutes: 60, serviceIds: ['svc_01', 'svc_02'] },
}));

test('combo lệch thời lượng: dùng durationMinutes của combo, chỉ console.warn, không ném lỗi', async (t) => {
  const warn = t.mock.method(console, 'warn', () => {});
  const quote = await buildBookingQuote({ comboId: 'combo_lech' });
  assert.equal(quote.durationMinutes, 45);
  assert.equal(quote.subtotal, 250000);
  assert.equal(warn.mock.callCount(), 1);
  assert.match(warn.mock.calls[0].arguments[0], /combo_lech.*45.*60/);
});

test('combo khớp thời lượng: không cảnh báo', async (t) => {
  const warn = t.mock.method(console, 'warn', () => {});
  const quote = await buildBookingQuote({ comboId: 'combo_khop' });
  assert.equal(quote.durationMinutes, 60);
  assert.equal(warn.mock.callCount(), 0);
});

test('combo lệch kèm dịch vụ lẻ ngoài combo: cộng thêm thời lượng dịch vụ lẻ', async (t) => {
  t.mock.method(console, 'warn', () => {});
  fake.store['services/svc_03'] = { name: 'Chụp X-quang', price: 50000, durationMinutes: 15 };
  const quote = await buildBookingQuote({ comboId: 'combo_lech', serviceIds: ['svc_03'] });
  assert.equal(quote.durationMinutes, 60);
  assert.equal(quote.subtotal, 300000);
});

test('POST /api/bookings/quote với combo lệch trả 200 thay vì 500', async (t) => {
  t.mock.method(console, 'warn', () => {});
  const r = await fetch(`${base}/bookings/quote`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ comboId: 'combo_lech' }),
  });
  assert.equal(r.status, 200);
  assert.equal((await r.json()).durationMinutes, 45);
});
