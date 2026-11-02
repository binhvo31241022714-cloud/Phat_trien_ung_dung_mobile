// seed-schedules: ngày và id ca tính theo giờ Việt Nam, chạy lại không tạo trùng.
// Chỉ kiểm tra hàm lập kế hoạch, không đụng Firestore.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { planSchedules } = require('../scripts/seed-schedules');

// 06:00 sáng 03/11/2026 giờ Việt Nam = 23:00 ngày 02/11/2026 giờ UTC.
const SIX_AM_VN = new Date('2026-11-03T06:00:00+07:00');

test('chạy lúc 06:00 giờ Việt Nam: ngày bắt đầu là 03/11, không lùi về ngày UTC 02/11', () => {
  const { today, toCreate } = planSchedules(['doc_01'], [], SIX_AM_VN);
  assert.equal(today, '2026-11-03');
  assert.equal(toCreate[0].id, 'doc_01_2026-11-03_am');
  assert.equal(toCreate[1].id, 'doc_01_2026-11-03_pm');
  assert.ok(!toCreate.some((item) => item.id.includes('2026-11-02')));
  // Ca sáng 08:00 đến 12:00 giờ Việt Nam.
  assert.equal(toCreate[0].data.startAt.toISOString(), '2026-11-03T01:00:00.000Z');
  assert.equal(toCreate[0].data.endAt.toISOString(), '2026-11-03T05:00:00.000Z');
  assert.equal(toCreate[1].data.startAt.toISOString(), '2026-11-03T06:30:00.000Z');
});

test('id ca khớp ngày của startAt theo giờ Việt Nam, bỏ Chủ nhật, đủ 31 ngày', () => {
  const { toCreate } = planSchedules(['doc_01'], [], SIX_AM_VN);
  const vnKey = (date) => new Date(date.getTime() + 7 * 3600 * 1000).toISOString().slice(0, 10);
  for (const item of toCreate) {
    assert.match(item.id, /^doc_01_\d{4}-\d{2}-\d{2}_(am|pm)$/);
    assert.equal(item.id.slice(7, 17), vnKey(item.data.startAt));
  }
  assert.ok(!toCreate.some((item) => item.id.includes('2026-11-08')), '08/11/2026 là Chủ nhật');
  const lastDay = toCreate[toCreate.length - 1].id.slice(7, 17);
  assert.equal(lastDay, '2026-12-03');
});

test('chạy lại: id đã có hoặc bác sĩ đã có ca trong ngày thì bỏ qua', () => {
  const first = planSchedules(['doc_01', 'doc_02'], [], SIX_AM_VN);
  const existing = first.toCreate.map((item) => ({ id: item.id, doctorId: item.data.doctorId, startAt: item.data.startAt }));
  const again = planSchedules(['doc_01', 'doc_02'], existing, SIX_AM_VN);
  assert.equal(again.toCreate.length, 0);
  assert.equal(again.skipped, first.toCreate.length);

  // Ca tự tạo tay (id khác) ngày 04/11 lúc 09:00 giờ Việt Nam: bỏ qua cả ngày đó.
  const manual = [{ id: 'tu_tao', doctorId: 'doc_01', startAt: new Date('2026-11-04T09:00:00+07:00') }];
  const plan = planSchedules(['doc_01'], manual, SIX_AM_VN);
  assert.ok(!plan.toCreate.some((item) => item.id.startsWith('doc_01_2026-11-04')));
  assert.ok(plan.toCreate.some((item) => item.id === 'doc_01_2026-11-05_am'));
});
