const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('../module2/support/fakeFirestore.cjs');
const fake = createFakeDb();
installFakeFirebase(fake); // Isolate before importing production routes; never load real config.
let server, base;
before(async () => {
  const app = express(); app.use(express.json());
  for (const [path, name] of [['patients','patients'], ['visits','visits'], ['invoices','invoices'], ['treatments','treatments'], ['follow-ups','followUps'], ['appointments','appointments']]) {
    app.use('/api/' + path, require('../../src/routes/' + name));
  }
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise(resolve => server.close(resolve)));
beforeEach(() => {
  const store = { 'users/A': {}, 'users/B': {},
    'users/A/family_members/active': {},
    'users/A/family_members/archived': { isArchived: true },
    'users/B/family_members/other': {},
  };
  for (const patient of ['A', 'active', 'archived', 'orphan']) {
    const data = { accountId: 'A', patientId: patient, status: 'completed' };
    store[`visits/v_${patient}`] = data;
    store[`invoices/i_${patient}`] = data;
    store[`treatments/t_${patient}`] = { ...data, photos: [{ imageUrl: 'legacy' }, { accountId: 'B', imageUrl: 'foreign' }] };
    store[`follow_ups/f_${patient}`] = data;
    store[`prescriptions/r_${patient}`] = { ...data, visitId: `v_${patient}` };
    store[`treatment_sessions/s_${patient}`] = { ...data, treatmentId: `t_${patient}`, status: 'planned' };
    store[`treatment_photos/p_${patient}`] = { ...data, treatmentId: `t_${patient}`, mediaId: `m_${patient}`, createdBy: 'A' };
    store[`media/m_${patient}`] = { ownerAccountId: 'A', patientId: patient };
  }
  fake.reset(store);
});
async function request(path, { identity = 'A', method = 'GET', body } = {}) {
  const r = await fetch(base + path, { method, headers: { authorization: `Bearer ${identity}`, 'content-type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status: r.status, body: await r.json() };
}
const lists = [['visits','v'],['invoices','i'],['treatments','t'],['follow-ups','f']];
for (const patient of ['A', 'active', 'archived']) {
  for (const [collection, prefix] of lists) {
    test(`history list ${collection} for ${patient}`, async () => {
      const before = structuredClone(fake.store);
      const r = await request(`/patients/${patient}/${collection}`);
      assert.equal(r.status, 200);
      assert.deepEqual(r.body.map(x => x.id), [`${prefix}_${patient}`]);
      assert.deepEqual(fake.store, before);
    });
  }
}
for (const patient of ['missing','other','orphan']) {
  for (const [collection] of lists) {
    test(`history list ${collection} denies ${patient}`, async () => {
      assert.equal((await request(`/patients/${patient}/${collection}`)).status, 403);
    });
  }
}
for (const [collection, prefix] of lists) {
  test(`history ${collection} filters conflicting and malformed ownership`, async () => {
    for (const [id, data] of Object.entries({
      wrong: { accountId: 'B' }, conflicting: { accountId: 'A', ownerAccountId: 'B' },
      malformed: { accountId: 42 }, nullOwner: { accountId: null }, legacy: {},
    })) fake.store[`${collection === 'follow-ups' ? 'follow_ups' : collection}/${id}`] = { patientId: 'archived', ...data };
    const r = await request(`/patients/archived/${collection}`);
    assert.equal(r.status, 200);
    assert.deepEqual(r.body.map(x => x.id).sort(), [`${prefix}_archived`, 'legacy'].sort());
  });
}
for (const [route, collection, prefix] of [['visits','visits','v'],['invoices','invoices','i'],['treatments','treatments','t']]) {
  for (const patient of ['A','active','archived','orphan']) {
    test(`detail ${route} preserves owned access including ${patient}`, async () => {
      assert.equal((await request(`/${route}/${prefix}_${patient}`)).status, 200);
      assert.equal((await request(`/${route}/${prefix}_${patient}`, { identity: 'B' })).status, 403);
    });
  }
  for (const ownership of [{ accountId: 'B' }, { accountId: 'A', ownerAccountId: 'B' }, { accountId: 3 }, { ownerAccountId: [] }]) {
    test(`detail ${route} fails closed ${JSON.stringify(ownership)}`, async () => {
      fake.store[`${collection}/bad`] = { patientId: 'archived', ...ownership };
      assert.equal((await request(`/${route}/bad`)).status, 403);
    });
  }
  test(`detail ${route} legacy needs membership; missing remains 404`, async () => {
    fake.store[`${collection}/legacy`] = { patientId: 'archived' };
    assert.equal((await request(`/${route}/legacy`)).status, 200);
    fake.store[`${collection}/legacy`].patientId = 'orphan';
    assert.equal((await request(`/${route}/legacy`)).status, 403);
    fake.store[`${collection}/legacy`] = { patientId: 'orphan', ownerAccountId: 'A' };
    assert.equal((await request(`/${route}/legacy`)).status, 200);
    assert.equal((await request(`/${route}/missing`)).status, 404);
  });
  test(`detail ${route} retains explicit-owner exception without inventing patient membership`, async () => {
    fake.store[`${collection}/owned`] = { accountId: 'A' };
    assert.equal((await request(`/${route}/owned`)).status, 200);
    fake.store[`${collection}/owned`].ownerAccountId = 'B';
    assert.equal((await request(`/${route}/owned`)).status, 403);
  });
}

for (const [route, collection, parentField, parentId] of [
  ['/visits/v_archived/prescriptions','prescriptions','visitId','v_archived'],
  ['/treatments/t_archived/sessions','treatment_sessions','treatmentId','t_archived'],
  ['/treatments/t_archived/photos','treatment_photos','treatmentId','t_archived'],
]) {
  test(`children ${route} verify patient, parent and ownership`, async () => {
    for (const [id, data] of Object.entries({ wrongOwner: { accountId: 'B' }, conflict: { accountId: 'A', ownerAccountId: 'B' },
      wrongPatient: { patientId: 'active' }, wrongParent: { [parentField]: 'other' }, malformed: { accountId: false }, legacy: {},
    })) fake.store[`${collection}/${id}`] = { patientId: 'archived', [parentField]: parentId, ...data };
    const r = await request(route);
    assert.equal(r.status, 200);
    const ids = r.body.map(x => x.id);
    assert.ok(ids.includes('legacy'));
    for (const forbidden of ['wrongOwner','conflict','wrongPatient','wrongParent','malformed']) assert.ok(!ids.includes(forbidden));
    if (route.endsWith('photos')) assert.ok(!r.body.some(x => x.imageUrl === 'foreign'));
    assert.equal((await request(route, { identity: 'B' })).status, 403);
  });
}
test('follow-up detail keeps account-only/orphan/staff policy without widening legacy reads', async () => {
  assert.equal((await request('/follow-ups/f_orphan')).status, 200);
  assert.equal((await request('/follow-ups/f_archived')).status, 200);
  fake.store['follow_ups/f_archived'].ownerAccountId = 'B';
  assert.equal((await request('/follow-ups/f_archived')).status, 403);
  assert.equal((await request('/follow-ups/f_archived', { identity: 'staff' })).status, 200);
  delete fake.store['follow_ups/f_archived'].accountId;
  delete fake.store['follow_ups/f_archived'].ownerAccountId;
  assert.equal((await request('/follow-ups/f_archived')).status, 403);
  assert.equal((await request('/follow-ups/missing')).status, 404);
});
test('archived cannot link a visit; active legacy linking remains available', async () => {
  const old = structuredClone(fake.store);
  assert.equal((await request('/treatments/t_archived/sessions/link-visit', { method: 'POST', body: { visitId: 'v_archived', sessionId: 's_archived' } })).status, 403);
  assert.deepEqual(fake.store, old);
  assert.equal((await request('/treatments/t_active/sessions/link-visit', { method: 'POST', body: { visitId: 'v_active', sessionId: 's_active' } })).status, 200);
});
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
test('archived patient cannot upload or delete photos, staff operations remain available', async () => {
  const old = structuredClone(fake.store);
  assert.equal((await request('/treatments/t_archived/photos', { method: 'POST', body: { phase: 'after', image: png } })).status, 403);
  assert.deepEqual(fake.store, old);
  assert.equal((await request('/treatments/t_archived/photos/p_archived', { method: 'DELETE' })).status, 403);
  assert.deepEqual(fake.store, old);
  assert.equal((await request('/treatments/t_archived/photos', { identity: 'staff', method: 'POST', body: { phase: 'after', image: png } })).status, 201);
  assert.equal((await request('/treatments/t_archived/photos/p_archived', { identity: 'staff', method: 'DELETE' })).status, 200);
});
test('staff can complete an existing archived treatment session', async () => {
  assert.equal((await request('/treatments/t_archived/sessions/s_archived', { identity: 'staff', method: 'PATCH', body: { status: 'completed', visitId: 'v_archived' } })).status, 200);
});
test('archived create eligibility remains 400 for booking/follow-up/treatment', async () => {
  const old = structuredClone(fake.store);
  for (const [path, identity, body] of [
    ['/appointments','A',{ patientId: 'archived' }],
    ['/follow-ups','staff',{ accountId: 'A', patientId: 'archived', scheduledAt: '2099-01-01', reason: 'Check' }],
    ['/treatments','staff',{ accountId: 'A', patientId: 'archived', name: 'Plan', sessions: [{}] }],
  ]) {
    assert.equal((await request(path, { identity, method: 'POST', body })).status, 400);
    assert.deepEqual(fake.store, old);
  }
});
