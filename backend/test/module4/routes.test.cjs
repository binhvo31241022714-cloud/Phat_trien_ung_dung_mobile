const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
let data, batches, failReads;
const copy = v => v === undefined ? undefined : structuredClone(v);
function ref(collection, id) {
  return { collection, id, get: async () => snapshot(collection, id) };
}
function snapshot(collection, id) {
  const value = data[collection]?.[id];
  return { id, exists: value !== undefined, data: () => copy(value), ref: ref(collection, id) };
}
function query(collection, conditions = []) {
  return {
    where(field, op, value) { assert.equal(op, '=='); return query(collection, [...conditions, [field, value]]); },
    doc: id => ref(collection, id),
    async get() {
      if (failReads) throw new Error('mock database failure');
      const docs = Object.keys(data[collection] || {}).filter(id => conditions.every(([k, v]) => data[collection][id][k] === v)).map(id => snapshot(collection, id));
      return { docs, size: docs.length };
    },
  };
}
const db = {
  collection: name => query(name),
  async runTransaction(fn) {
    const writes = [];
    const result = await fn({ get: r => r.get(), update: (r, value) => writes.push([r, value]) });
    for (const [r, value] of writes) Object.assign(data[r.collection][r.id], value);
    return result;
  },
  batch() {
    const writes = [];
    return {
      update: (r, value) => writes.push([r, value]),
      async commit() {
        assert.ok(writes.length <= 450); batches.push(writes.length);
        for (const [r, value] of writes) Object.assign(data[r.collection][r.id], value);
      },
    };
  },
};
// Substitute Firebase before loading any production module: credentials are never loaded.
const firebasePath = require.resolve('../../src/config/firebase');
require.cache[firebasePath] = { id: firebasePath, filename: firebasePath, loaded: true, exports: {
  db, auth: { async verifyIdToken(token) { if (token === 'user-a' || token === 'user-b') return { uid: token }; throw new Error('invalid test token'); } },
} };
let server, base;
before(async () => {
  const app = express(); app.use(express.json());
  for (const name of ['articles', 'home', 'notifications']) app.use('/api/' + name, require('../../src/routes/' + name));
  app.use((err, req, res, next) => res.status(500).json({ message: 'Lỗi server' }));
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(async () => { await new Promise(resolve => server.close(resolve)); });
beforeEach(() => { data = { articles: {}, services: {}, doctors: {}, appointments: {}, notifications: {} }; batches = []; failReads = false; });
async function request(path, { token, method = 'GET' } = {}) {
  const res = await fetch(base + '/api/' + path, { method, headers: token ? { Authorization: 'Bearer ' + token } : {} });
  return { status: res.status, body: await res.json() };
}
const ids = items => items.map(item => item.id);
function article(extra = {}) { return { isPublished: true, publishedAt: '2026-10-01T00:00:00Z', ...extra }; }
function notice(extra = {}) { return { userId: 'user-a', isRead: false, createdAt: '2026-10-01T00:00:00Z', ...extra }; }
function appointment(extra = {}) { return { accountId: 'user-a', patientId: 'family-member', date: '2099-01-01', startTime: '09:00', status: 'booked', ...extra }; }

test('articles are public, published only and newest first', async () => {
  data.articles = { old: article(), newest: article({ publishedAt: '2026-10-02T00:00:00Z' }), draft: article({ isPublished: false }), absentFlag: {} };
  const r = await request('articles'); assert.equal(r.status, 200); assert.deepEqual(ids(r.body), ['newest', 'old']);
});
test('articles category filters and empty category results', async () => {
  data.articles = { a: article({ category: 'Care' }), b: article({ category: 'News' }) };
  assert.deepEqual(ids((await request('articles?category=Care')).body), ['a']);
  assert.deepEqual((await request('articles?category=Other')).body, []);
});
test('articles reject non-scalar category', async () => { assert.equal((await request('articles?category=a&category=b')).status, 400); });
test('empty articles returns []', async () => { assert.deepEqual((await request('articles')).body, []); });
test('published article detail is public and uses document id', async () => {
  data.articles.a = article({ id: 'untrusted' }); const r = await request('articles/a'); assert.equal(r.status, 200); assert.equal(r.body.id, 'a');
});
test('missing and draft details return 404 without draft content', async () => {
  data.articles.draft = article({ isPublished: false, content: 'draft body' });
  for (const id of ['missing', 'draft']) { const r = await request('articles/' + id); assert.equal(r.status, 404); assert.equal(r.body.content, undefined); }
});
test('missing/invalid article dates sort last with deterministic ties', async () => {
  data.articles = { z: article({ publishedAt: 'bad' }), a: article({ publishedAt: null }), valid: article() };
  assert.deepEqual(ids((await request('articles')).body), ['valid', 'a', 'z']);
});
test('Firestore Timestamp article ordering', async () => {
  const old = data.articles;
  data.articles = { a: article({ publishedAt: { seconds: 1 } }), b: article({ publishedAt: { seconds: 2 } }) };
  const original = db.collection;
  db.collection = name => name === 'articles' ? { where() { return this; }, async get() { return { docs: [1, 2].map(n => ({ id: String(n), data: () => article({ publishedAt: { toDate: () => new Date(n * 1000) } }) })) }; } } : original(name);
  try { assert.deepEqual(ids((await request('articles')).body), ['2', '1']); } finally { db.collection = original; data.articles = old; }
});
test('home requires valid token', async () => { for (const token of [undefined, 'invalid']) assert.equal((await request('home', { token })).status, 401); });
test('home filters hidden catalog, prioritizes featured and limits articles', async () => {
  data.services = { a: {}, featured: { isFeatured: true }, hidden: { isActive: false, isFeatured: true } };
  data.doctors = { active: { isActive: true }, legacy: {}, hidden: { isActive: false } };
  data.articles = Object.fromEntries([1, 2, 3, 4].map(n => [String(n), article({ publishedAt: `2026-10-0${n}T00:00:00Z` })]));
  data.articles.draft = article({ isPublished: false });
  const r = await request('home', { token: 'user-a' }); assert.equal(r.status, 200);
  assert.deepEqual(ids(r.body.featuredServices), ['featured', 'a']); assert.deepEqual(ids(r.body.featuredDoctors), ['active', 'legacy']);
  assert.deepEqual(ids(r.body.latestArticles), ['4', '3', '2']); assert.equal(r.body.upcomingAppointment, null);
});
test('home picks nearest family appointment and excludes other accounts/statuses/past/invalid dates', async () => {
  data.appointments = { nearest: appointment(), later: appointment({ date: '2099-02-01' }), other: appointment({ accountId: 'user-b', date: '2098-01-01' }), past: appointment({ date: '2000-01-01' }), bad: appointment({ date: '2099-02-30' }), badTime: appointment({ startTime: '99:99' }) };
  for (const status of ['cancelled', 'canceled', 'completed', 'rejected', 'declined', 'expired']) data.appointments[status] = appointment({ status, date: '2098-01-01' });
  const r = await request('home', { token: 'user-a' }); assert.equal(r.body.upcomingAppointment.id, 'nearest'); assert.equal(r.body.upcomingAppointment.patientId, 'family-member');
});
test('home empty collections returns four empty components', async () => {
  assert.deepEqual((await request('home', { token: 'user-a' })).body, { featuredServices: [], featuredDoctors: [], latestArticles: [], upcomingAppointment: null });
});
test('home catalog lists are capped at six', async () => {
  for (let n = 0; n < 10; n++) { data.services[n] = {}; data.doctors[n] = {}; }
  const { body } = await request('home', { token: 'user-a' }); assert.equal(body.featuredServices.length, 6); assert.equal(body.featuredDoctors.length, 6);
});
test('all notification endpoints require authentication', async () => {
  for (const [path, method] of [['notifications', 'GET'], ['notifications/unread-count', 'GET'], ['notifications/a/read', 'PATCH'], ['notifications/read-all', 'PATCH']]) {
    for (const token of [undefined, 'invalid']) assert.equal((await request(path, { method, token })).status, 401);
  }
});
test('notification list is owner scoped and sorted newest first', async () => {
  data.notifications = { old: notice(), newer: notice({ createdAt: '2026-10-02T00:00:00Z' }), other: notice({ userId: 'user-b' }), invalid: notice({ createdAt: 'invalid' }) };
  assert.deepEqual(ids((await request('notifications', { token: 'user-a' })).body), ['newer', 'old', 'invalid']);
  assert.deepEqual(ids((await request('notifications', { token: 'user-b' })).body), ['other']);
});
test('unread count uses strictly false and only current owner', async () => {
  data.notifications = { a: notice(), b: notice({ isRead: true }), c: notice({ isRead: null }), d: notice({ userId: 'user-b' }) };
  assert.deepEqual((await request('notifications/unread-count', { token: 'user-a' })).body, { count: 1 });
});
test('mark one read is idempotent', async () => {
  data.notifications.a = notice();
  for (let i = 0; i < 2; i++) { const r = await request('notifications/a/read', { token: 'user-a', method: 'PATCH' }); assert.equal(r.status, 200); assert.deepEqual(r.body, { id: 'a', isRead: true }); }
  assert.equal(data.notifications.a.isRead, true); assert.equal((await request('notifications/unread-count', { token: 'user-a' })).body.count, 0);
});
test('mark missing returns 404 and foreign notification returns 403 without mutation', async () => {
  data.notifications.other = notice({ userId: 'user-b' });
  assert.equal((await request('notifications/none/read', { token: 'user-a', method: 'PATCH' })).status, 404);
  assert.equal((await request('notifications/other/read', { token: 'user-a', method: 'PATCH' })).status, 403); assert.equal(data.notifications.other.isRead, false);
});
test('read all batches 901 documents and preserves foreign notifications', async () => {
  for (let n = 0; n < 901; n++) data.notifications[n] = notice();
  data.notifications.other = notice({ userId: 'user-b' }); data.notifications.read = notice({ isRead: true });
  const r = await request('notifications/read-all', { token: 'user-a', method: 'PATCH' }); assert.equal(r.status, 200); assert.equal(r.body.updatedCount, 901);
  assert.deepEqual(batches, [450, 450, 1]); assert.equal(data.notifications.other.isRead, false);
  assert.equal((await request('notifications/unread-count', { token: 'user-a' })).body.count, 0);
  assert.equal((await request('notifications/read-all', { token: 'user-a', method: 'PATCH' })).body.updatedCount, 0);
});
test('empty notifications list/count/read-all are safe', async () => {
  assert.deepEqual((await request('notifications', { token: 'user-a' })).body, []);
  assert.deepEqual((await request('notifications/unread-count', { token: 'user-a' })).body, { count: 0 });
  assert.deepEqual((await request('notifications/read-all', { token: 'user-a', method: 'PATCH' })).body, { updatedCount: 0 }); assert.deepEqual(batches, []);
});
test('database read failures reach the standard HTTP error handler', async () => {
  failReads = true;
  for (const path of ['articles', 'home', 'notifications', 'notifications/unread-count', 'notifications/read-all']) {
    const r = await request(path, { token: 'user-a', method: path.endsWith('read-all') ? 'PATCH' : 'GET' }); assert.equal(r.status, 500); assert.deepEqual(r.body, { message: 'Lỗi server' });
  }
});
test('home compares appointment times in Vietnam timezone at the exact boundary', async () => {
  const originalNow = Date.now;
  Date.now = () => new Date('2099-01-01T02:00:00Z').getTime(); // 09:00 Vietnam
  data.appointments = { boundary: appointment(), nextMinute: appointment({ startTime: '09:01' }) };
  try { assert.equal((await request('home', { token: 'user-a' })).body.upcomingAppointment.id, 'nextMinute'); }
  finally { Date.now = originalNow; }
});
test('read-all propagates batch failure instead of claiming success', async () => {
  data.notifications.a = notice(); const originalBatch = db.batch;
  db.batch = () => ({ update() {}, async commit() { throw new Error('mock commit failure'); } });
  try {
    assert.equal((await request('notifications/read-all', { token: 'user-a', method: 'PATCH' })).status, 500);
    assert.equal(data.notifications.a.isRead, false);
  } finally { db.batch = originalBatch; }
});
test('mark-read propagates transaction failure without mutation', async () => {
  data.notifications.a = notice(); const originalTransaction = db.runTransaction;
  db.runTransaction = async () => { throw new Error('mock transaction failure'); };
  try {
    assert.equal((await request('notifications/a/read', { token: 'user-a', method: 'PATCH' })).status, 500);
    assert.equal(data.notifications.a.isRead, false);
  } finally { db.runTransaction = originalTransaction; }
});
