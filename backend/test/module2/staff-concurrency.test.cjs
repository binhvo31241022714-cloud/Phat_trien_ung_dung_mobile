// Isolated HTTP routes with in-memory Firebase; never initializes real Firebase.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('./support/fakeFirestore.cjs');
const fake = createFakeDb();
installFakeFirebase(fake);
let server, base;
before(async () => {
  const app = express();
  app.use(express.json());
  app.use('/api/appointments', require('../../src/routes/appointments'));
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/appointments`;
});
after(() => new Promise(resolve => server.close(resolve)));
beforeEach(() => fake.reset({
  'appointments/a': { accountId: 'A', patientId: 'A', doctorId: 'doctor',
    date: '2099-01-01', startTime: '09:00', endTime: '09:30', status: 'booked' },
}));
async function transition(status, identity = 'staff', extra = {}) {
  const response = await fetch(`${base}/a/status`, {
    method: 'PATCH', headers: { 'content-type': 'application/json', authorization: `Bearer ${identity}` },
    body: JSON.stringify({ status, reason: 'Synthetic test reason', ...extra }),
  });
  return { status: response.status, body: await response.json() };
}
function notices() { return fake.paths('notifications/').map(path => fake.store[path]); }

test('two concurrent confirmations commit one transition and one notification', async () => {
  fake.interleave();
  const results = await Promise.all([transition('confirmed'), transition('confirmed')]);
  assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
  assert.ok(fake.state.conflicts > 0, 'must exercise a transaction retry');
  assert.equal(fake.store['appointments/a'].status, 'confirmed');
  assert.equal(notices().length, 1);
  assert.equal(notices()[0].type, 'appointment_confirmed');
  assert.equal(notices()[0].userId, 'A');
});

test('concurrent confirm versus reject cannot commit conflicting final states or notices', async () => {
  fake.interleave();
  const results = await Promise.all([transition('confirmed'), transition('rejected')]);
  assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
  assert.ok(fake.state.conflicts > 0);
  const saved = fake.store['appointments/a'];
  const winner = results.find(r => r.status === 200).body;
  assert.equal(saved.status, winner.status);
  assert.equal(notices().length, 1);
  assert.equal(notices()[0].type, `appointment_${saved.status}`);
  assert.equal(notices()[0].refId, 'a');
});

test('patient cannot complete an appointment by supplying staff fields in request body', async () => {
  fake.store['appointments/a'].status = 'confirmed';
  const original = structuredClone(fake.store);
  const response = await transition('completed', 'A', { role: 'staff', accountId: 'staff' });
  assert.equal(response.status, 403);
  assert.deepEqual(fake.store, original);
  assert.equal(fake.state.attempts, 0);
});
