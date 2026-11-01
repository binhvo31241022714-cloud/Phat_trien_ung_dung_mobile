const test = require('node:test');
const assert = require('node:assert/strict');
const { createFakeDb, installFakeFirebase } = require('./module2/support/fakeFirestore.cjs');
installFakeFirebase(createFakeDb());
const {
  canTransition,
  isAppointmentActive,
  parseTime,
} = require('../src/utils/booking');

test('appointment status helpers keep cancelled slots inactive', () => {
  assert.equal(isAppointmentActive({ status: 'cancelled' }), false);
  assert.equal(isAppointmentActive({ status: 'confirmed' }), true);
  assert.equal(canTransition('booked', 'cancelled'), true);
  assert.equal(canTransition('confirmed', 'confirmed'), false);
});

test('time parser accepts only valid HH:mm values', () => {
  assert.equal(parseTime('09:30'), 570);
  assert.throws(() => parseTime('9:30'), /HH:mm/);
  assert.throws(() => parseTime('24:00'), /HH:mm/);
});
