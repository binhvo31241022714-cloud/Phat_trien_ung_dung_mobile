const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('./support/fakeFirestore.cjs');
const fake = createFakeDb();
installFakeFirebase(fake); // Replace config before routes import; no real Firebase initialization.
let server, base;
before(async () => {
  const app = express();
  app.use(express.json());
  app.use('/api/family-members', require('../../src/routes/familyMembers'));
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/family-members`;
});
after(() => new Promise(resolve => server.close(resolve)));
beforeEach(() => fake.reset({
  'users/A/family_members/active': { fullName: 'Active', isArchived: false },
  'users/A/family_members/archived': { fullName: 'Archived', isArchived: true },
  'users/A/family_members/legacy': { fullName: 'Legacy' },
  'users/B/family_members/private': { fullName: 'Other', isArchived: true },
}));
async function request(query = '', identity = 'A') {
  const r = await fetch(base + query, { headers: identity ? { authorization: `Bearer ${identity}` } : {} });
  return { status: r.status, body: await r.json() };
}
for (const query of ['', '?includeArchived=false', '?includeArchived=true']) {
  test(`family GET ${query || 'default'} preserves owner/order`, async () => {
    const before = structuredClone(fake.store);
    const r = await request(query);
    assert.equal(r.status, 200);
    assert.deepEqual(r.body.map(x => x.id), query.endsWith('true') ? ['active', 'archived', 'legacy'] : ['active', 'legacy']);
    assert.deepEqual(fake.store, before);
  });
}
for (const query of ['?includeArchived=', '?includeArchived=1', '?includeArchived=TRUE', '?includeArchived=null', '?includeArchived=true&includeArchived=false', '?includeArchived[]=true']) {
  test(`invalid query ${query} returns compatible 400`, async () => {
    const r = await request(query);
    assert.equal(r.status, 400);
    assert.equal(typeof r.body.message, 'string');
  });
}
test('includeArchived does not trust accountId and remains authenticated', async () => {
  const a = await request('?includeArchived=true&accountId=B');
  assert.deepEqual(a.body.map(x => x.id), ['active', 'archived', 'legacy']);
  const b = await request('?includeArchived=true&accountId=A', 'B');
  assert.deepEqual(b.body.map(x => x.id), ['private']);
  assert.equal((await request('?includeArchived=true', null)).status, 401);
});
test('archive still hides active entry and history retains it', async () => {
  const r = await fetch(base + '/active', { method: 'DELETE', headers: { authorization: 'Bearer A' } });
  assert.equal(r.status, 200);
  assert.deepEqual((await request()).body.map(x => x.id), ['legacy']);
  assert.deepEqual((await request('?includeArchived=true')).body.map(x => x.id), ['active', 'archived', 'legacy']);
});
