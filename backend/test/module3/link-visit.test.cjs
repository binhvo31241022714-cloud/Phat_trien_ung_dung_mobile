const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const clone = value => value === undefined ? undefined : structuredClone(value);
let store, versions, conflicts, attempts, commitGate, failCommit;
function ref(path) {
  return { path, id: path.split('/').at(-1), collection: name => collection(`${path}/${name}`),
    get: async () => snap(path) };
}
function snap(path) {
  const value = clone(store[path]);
  return { id: path.split('/').at(-1), ref: ref(path), exists: value !== undefined, data: () => clone(value) };
}
function collection(path, filters = []) {
  const q = { path, filters, doc: id => ref(`${path}/${id}`),
    where(field, op, value) { assert.equal(op, '=='); return collection(path, [...filters, [field, value]]); },
    get: async () => ({ docs: matching(q).map(snap) }) };
  return q;
}
function matching(q) {
  return Object.keys(store).filter(p => p.slice(0, p.lastIndexOf('/')) === q.path &&
    q.filters.every(([k,v]) => store[p][k] === v)).sort();
}
function fingerprint(q) { return JSON.stringify(matching(q).map(p => [p, versions[p] || 0])); }
const db = {
  collection,
  async runTransaction(fn) {
    for (let retry = 0; retry < 5; retry++) {
      attempts++;
      const checks = [], writes = [];
      const result = await fn({
        async get(r) {
          assert.equal(writes.length, 0, 'Firestore reads must precede all writes');
          if (r.filters) {
            const before = fingerprint(r); checks.push(() => fingerprint(r) === before);
            return { docs: matching(r).map(snap) };
          }
          const before = versions[r.path] || 0;
          checks.push(() => (versions[r.path] || 0) === before);
          return snap(r.path);
        },
        update(r, data) { writes.push([r.path, clone(data)]); },
      });
      if (commitGate) await commitGate();
      // Atomic validation and commit: no await between them. Query membership
      // checks also detect links added to previously empty query results.
      if (!checks.every(check => check())) { conflicts++; continue; }
      if (failCommit) throw Object.assign(new Error('simulated transaction abort'), { code: 10 });
      for (const [path, update] of writes) {
        assert.ok(store[path]); Object.assign(store[path], update);
        versions[path] = (versions[path] || 0) + 1;
      }
      return result;
    }
    throw Object.assign(new Error('retry exhausted'), { code: 10 });
  },
};
// Replace Firebase before importing auth/routes: no credentials or network Firebase.
const firebasePath = require.resolve('../../src/config/firebase');
require.cache[firebasePath] = { id: firebasePath, filename: firebasePath, loaded: true,
  exports: { db, auth: { async verifyIdToken(value) {
    if (['A','B'].includes(value)) return { uid: value };
    throw new Error('invalid synthetic identity');
  } } } };
let server, base;
before(async () => {
  const app = express(); app.use(express.json());
  app.use('/api/treatments', require('../../src/routes/treatments'));
  app.use((error, req, res, next) => res.status(500).json({ message: 'Lỗi server' }));
  server = app.listen(0,'127.0.0.1');
  await new Promise(resolve => server.once('listening',resolve));
  base = `http://127.0.0.1:${server.address().port}/api/treatments`;
});
after(() => new Promise(resolve => server.close(resolve)));
beforeEach(() => {
  conflicts = attempts = 0; versions = {}; commitGate = null; failCommit = false;
  store = {
    'treatments/t1': { patientId:'A', name:'plan', photos:[{ imageUrl:'embedded' }] },
    'treatments/t2': { patientId:'A', name:'other' },
    'visits/v1': { patientId:'A', appointmentId:'a1', status:'completed' },
    'visits/v2': { patientId:'A', appointmentId:'a2', status:'completed' },
    'treatment_sessions/s1': { treatmentId:'t1', patientId:'A', sessionNumber:1, status:'pending', note:'preserve' },
    'treatment_sessions/s2': { treatmentId:'t1', patientId:'A', sessionNumber:2, status:'pending' },
    'treatment_sessions/s3': { treatmentId:'t2', patientId:'A', sessionNumber:1, status:'pending' },
  };
});
async function request({ treatment='t1', visit='v1', session='s1', token='A', method='POST', suffix } = {}) {
  const r = await fetch(`${base}/${treatment}/${suffix ?? 'sessions/link-visit'}`, {
    method, headers: { 'content-type':'application/json', ...(token ? { authorization:`Bearer ${token}` } : {}) },
    ...(method === 'POST' ? { body: JSON.stringify({ visitId:visit, sessionId:session }) } : {}),
  });
  return { status:r.status, body:await r.json() };
}
function interleaveFirstTwo() {
  let arrived = 0, release;
  const gate = new Promise(resolve => { release = resolve; });
  commitGate = async () => { if (++arrived <= 2) { if (arrived === 2) release(); await gate; } };
}
function linked() { return Object.entries(store).filter(([p,v]) => p.startsWith('treatment_sessions/') && v.visitId); }
test('success preserves session fields, JSON contract and unrelated documents', async () => {
  const before = clone(store); const r = await request();
  assert.equal(r.status,200); assert.equal(r.body.id,'s1'); assert.equal(r.body.visitId,'v1');
  assert.equal(r.body.appointmentId,'a1'); assert.equal(r.body.status,'completed');
  assert.equal(r.body.note,'preserve'); assert.ok(!Number.isNaN(Date.parse(r.body.completedAt)));
  // Liệu trình 2 buổi, xong 1 buổi: tự chuyển in_progress, các trường khác giữ nguyên.
  assert.equal(store['treatments/t1'].status,'in_progress');
  assert.ok(store['treatments/t1'].updatedAt);
  delete before['treatment_sessions/s1']; const after = clone(store); delete after['treatment_sessions/s1'];
  const { status, updatedAt, ...t1 } = after['treatments/t1']; after['treatments/t1'] = t1;
  assert.deepEqual(after,before);
});
for (const status of [undefined,'pending','in_progress']) test(`A10: visit status ${status} cannot be linked`, async () => {
  if (status === undefined) delete store['visits/v1'].status; else store['visits/v1'].status = status;
  const old = clone(store); const r = await request();
  assert.equal(r.status,400); assert.equal(r.body.message,'Chỉ thêm được lần khám đã hoàn tất');
  assert.deepEqual(store,old);
});
for (const token of [null,'invalid']) test(`auth rejects ${token}`, async () => {
  assert.equal((await request({token})).status,401); assert.equal(attempts,0);
});
test('non-owner denied with no writes', async () => {
  const old=clone(store); assert.equal((await request({token:'B'})).status,403); assert.deepEqual(store,old);
});
for (const [key,value] of [['treatment','missing'],['visit','missing']]) test(`missing ${key} returns 404`, async () => {
  assert.equal((await request({[key]:value})).status,404); assert.equal(linked().length,0);
});
test('visit of another account denied', async () => {
  store['visits/v1'].patientId='B'; assert.equal((await request()).status,403); assert.equal(linked().length,0);
});
test('different accessible patients rejected', async () => {
  store['users/A/family_members/child']={}; store['visits/v1'].patientId='child';
  assert.equal((await request()).status,400);
});
test('relative access checked inside transaction', async () => {
  for (const p of ['treatments/t1','visits/v1','treatment_sessions/s1']) store[p].patientId='child';
  store['users/A/family_members/child']={}; assert.equal((await request()).status,200);
});
for (const change of ['missing','other-treatment','wrong-patient','occupied','completed']) test(`invalid session ${change}`, async () => {
  let session='s1';
  if(change==='missing') session='absent';
  if(change==='other-treatment') session='s3';
  if(change==='wrong-patient') store['treatment_sessions/s1'].patientId='B';
  if(change==='occupied') store['treatment_sessions/s1'].visitId='v2';
  if(change==='completed') store['treatment_sessions/s1'].status='COMPLETED';
  const old=clone(store); assert.equal((await request({session})).status,400); assert.deepEqual(store,old);
});
for (const session of ['s2','s3']) test(`existing link ${session} returns 409`, async () => {
  store[`treatment_sessions/${session}`].visitId='v1'; assert.equal((await request()).status,409);
});
for (const body of [{visit:''},{visit:42},{session:' '},{session:null}]) test(`invalid body ${JSON.stringify(body)}`, async () => {
  assert.equal((await request(body)).status,400); assert.equal(attempts,0);
});
test('same visit / different sessions interleave and conflict; one link only', async () => {
  interleaveFirstTwo(); const r=await Promise.all([request(),request({session:'s2'})]);
  assert.deepEqual(r.map(x=>x.status).sort(),[200,409]); assert.equal(linked().length,1);
  assert.equal(conflicts,1); assert.equal(attempts,3);
});
test('different visits / same session retry without overwriting winner', async () => {
  interleaveFirstTwo(); const r=await Promise.all([request(),request({visit:'v2'})]);
  assert.deepEqual(r.map(x=>x.status).sort(),[200,400]); assert.equal(linked().length,1);
  const success=r.find(x=>x.status===200); assert.equal(store['treatment_sessions/s1'].visitId,success.body.visitId);
  assert.equal(conflicts,1); assert.equal(attempts,3);
});
test('same visit / different treatments detects query membership conflict', async () => {
  interleaveFirstTwo(); const r=await Promise.all([request(),request({treatment:'t2',session:'s3'})]);
  assert.deepEqual(r.map(x=>x.status).sort(),[200,409]); assert.equal(linked().length,1);
  assert.equal(conflicts,1); assert.equal(attempts,3);
});
test('different visits and sessions on same treatment survive retry: no lost update', async () => {
  interleaveFirstTwo(); const r=await Promise.all([request(),request({visit:'v2',session:'s2'})]);
  assert.deepEqual(r.map(x=>x.status),[200,200]); assert.equal(linked().length,2);
  assert.equal(conflicts,1); assert.equal(attempts,3); assert.equal(store['treatment_sessions/s1'].note,'preserve');
});
test('revoked family access between read and commit forces retry and 403', async () => {
  for(const p of ['treatments/t1','visits/v1','treatment_sessions/s1']) store[p].patientId='child';
  const path='users/A/family_members/child'; store[path]={};
  let once=false; commitGate=async()=>{ if(!once) {once=true; delete store[path]; versions[path]=1;} };
  assert.equal((await request()).status,403); assert.equal(conflicts,1); assert.equal(linked().length,0);
});
test('commit failure leaves all documents unchanged and uses existing 500 handler', async () => {
  failCommit=true; const old=clone(store); assert.equal((await request()).status,500); assert.deepEqual(store,old);
});
test('GET treatment, sessions and photos retain existing contracts and ownership', async () => {
  const detail=await fetch(`${base}/t1`,{headers:{authorization:'Bearer A'}});
  assert.equal(detail.status,200); assert.equal((await detail.json()).id,'t1');
  const sessions=await request({method:'GET',suffix:'sessions'}); assert.equal(sessions.status,200); assert.equal(sessions.body.length,2);
  const photos=await request({method:'GET',suffix:'photos'}); assert.equal(photos.status,200); assert.equal(photos.body[0].imageUrl,'embedded');
  assert.equal((await request({method:'GET',suffix:'sessions',token:'B'})).status,403);
});
test('identical concurrent requests commit once and return duplicate 409 on retry', async () => {
  interleaveFirstTwo(); const results=await Promise.all([request(),request()]);
  assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
  assert.equal(conflicts,1); assert.equal(attempts,3); assert.equal(linked().length,1);
});
test('ownership changing before commit is rechecked on retry', async () => {
  let once=false; commitGate=async()=>{if(!once){once=true;store['treatments/t1'].patientId='B';versions['treatments/t1']=1;}};
  assert.equal((await request()).status,403); assert.equal(conflicts,1); assert.equal(linked().length,0);
});
test('contention exhaustion returns existing 500 with no partial session writes', async () => {
  commitGate=async()=>{versions['visits/v1']=(versions['visits/v1']||0)+1;};
  const old=clone(store); assert.equal((await request()).status,500);
  assert.equal(attempts,5); assert.equal(conflicts,5); assert.deepEqual(store,old);
});
