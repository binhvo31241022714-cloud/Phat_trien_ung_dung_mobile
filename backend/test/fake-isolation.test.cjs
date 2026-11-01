'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const { pathToFileURL } = require('node:url');
const { spawnSync } = require('node:child_process');
const Module = require('node:module');
const { cleanEnvironment } = require('./support/run-fake-tests.cjs');
const guard = path.resolve(__dirname, 'support/fake-isolation.cjs');
const config = path.resolve(__dirname, '../src/config/firebase.js');
const server = path.resolve(__dirname, '../src/server.js');
const blocked = { code: 'ERR_FAKE_ISOLATION' };

// Every probe has the preload, including when this test is run as a child file.
function probe(source) {
  const result = spawnSync(process.execPath, ['--require', guard, '-e', source], { encoding: 'utf8', timeout: 15000 });
  assert.equal(result.status, 0, result.stderr);
}
for (const [label, filename] of [['Firebase config', config], ['server', server]]) {
  test(`isolation: CommonJS ${label} blocked before execution; resolve stays available`, () => {
    assert.equal(require.resolve(filename), filename);
    assert.throws(() => require(filename), blocked);
  });
  test(`isolation: ESM ${label} blocked before execution`, async () => {
    await assert.rejects(import(pathToFileURL(filename).href), blocked);
  });
}
test('isolation: Firebase Admin package and subpath blocked in CJS and ESM', async () => {
  for (const name of ['firebase-admin', 'firebase-admin/app', 'firebase-admin/firestore', 'firebase-admin/auth']) {
    assert.equal(typeof require.resolve(name), 'string');
    assert.throws(() => require(name), blocked);
    await assert.rejects(import(name), blocked);
  }
});
test('isolation: createRequire cannot bypass module guard', () => {
  assert.throws(() => Module.createRequire(__filename)(config), blocked);
});
test('isolation: early failed import cannot poison later fake injection; cache deletion fails closed', () => {
  probe(`const a=require('node:assert/strict');
    const config=${JSON.stringify(config)};
    a.throws(()=>require(config),{code:'ERR_FAKE_ISOLATION'});
    const booking=${JSON.stringify(path.resolve(__dirname, '../src/utils/booking.js'))};
    a.throws(()=>require(booking),{code:'ERR_FAKE_ISOLATION'});
    const {createFakeDb,installFakeFirebase}=require(${JSON.stringify(path.resolve(__dirname, 'module2/support/fakeFirestore.cjs'))});
    const fake=createFakeDb(); installFakeFirebase(fake);
    a.strictEqual(require(config).db,fake.db);
    a.equal(require(booking).parseTime('09:30'),570);
    delete require.cache[config];
    a.throws(()=>require(config),{code:'ERR_FAKE_ISOLATION'});`);
});
test('isolation: fake Firestore and synthetic auth remain usable', async () => {
  const { createFakeDb, installFakeFirebase } = require('./module2/support/fakeFirestore.cjs');
  const fake = createFakeDb(); installFakeFirebase(fake);
  fake.reset({ 'users/A': { fullName: 'Synthetic' } });
  assert.equal((await require(config).db.collection('users').doc('A').get()).data().fullName, 'Synthetic');
  assert.deepEqual(await require(config).auth.verifyIdToken('A'), { uid: 'A' });
  delete require.cache[config];
});
test('isolation: scheduler cannot start even after fake installation', () => {
  probe(`const a=require('node:assert/strict');
    const h=require(${JSON.stringify(path.resolve(__dirname, 'module2/support/fakeFirestore.cjs'))});
    h.installFakeFirebase(h.createFakeDb());
    const job=require(${JSON.stringify(path.resolve(__dirname, '../src/jobs/reminders.js'))});
    a.throws(()=>job.startReminderJob(),{code:'ERR_FAKE_ISOLATION'});`);
});
test('isolation: external HTTP, HTTPS, fetch, raw sockets, DNS and UDP blocked', () => {
  assert.throws(() => require('node:http').get('http://203.0.113.1/'), blocked);
  assert.throws(() => require('node:https').get('https://203.0.113.1/'), blocked);
  assert.throws(() => fetch('http://203.0.113.1/'), blocked);
  assert.throws(() => require('node:net').connect(443, '203.0.113.1'), blocked);
  assert.throws(() => new (require('node:net').Socket)().connect({ host: '203.0.113.1', port: 80 }), blocked);
  assert.throws(() => require('node:tls').connect(443, '203.0.113.1'), blocked);
  assert.throws(() => new (require('node:tls').TLSSocket)().connect({port:443,host:'203.0.113.1'}), blocked);
  assert.throws(() => require('node:net').connect(80, '127.0.0.1'), blocked);
  assert.throws(() => require('node:net').createServer().listen(0, '0.0.0.0'), blocked);
  assert.throws(() => new (require('node:dns').Resolver)(), blocked);
  assert.throws(() => require('node:dns').lookup('example.invalid', () => {}), blocked);
  assert.throws(() => require('node:dgram').createSocket('udp4'), blocked);
});
test('isolation: ESM builtin imports retain network guards', async () => {
  const { get } = await import('node:http');
  const { connect } = await import('node:net');
  assert.throws(() => get('http://203.0.113.1/'), blocked);
  assert.throws(() => connect(80, '203.0.113.1'), blocked);
});
test('isolation: loopback HTTP works; redirect cannot connect externally', async () => {
  const http = require('node:http');
  const local = http.createServer((req, res) => {
    if (req.url === '/redirect') { res.writeHead(302, { location: 'http://203.0.113.1/' }); res.end(); }
    else res.end('fake');
  });
  await new Promise(resolve => local.listen(0, '127.0.0.1', resolve));
  try {
    const base = `http://127.0.0.1:${local.address().port}`;
    assert.equal(await (await fetch(base)).text(), 'fake');
    assert.equal(await new Promise((resolve, reject) => http.get(base, res => {
      let text=''; res.on('data', chunk=>text+=chunk); res.on('end',()=>resolve(text));
    }).on('error',reject)), 'fake');
    await assert.rejects(fetch(base + '/redirect'), error => error.cause?.code === 'ERR_FAKE_ISOLATION');
  } finally { await new Promise(resolve => local.close(resolve)); }
});
test('isolation: external commands, fork and unguarded workers are rejected', () => {
  assert.throws(() => spawnSync('/bin/sh', ['-c', 'exit 0']), blocked);
  assert.throws(() => require('node:child_process').fork(__filename), blocked);
  assert.throws(() => new (require('node:worker_threads').Worker)('0', { eval: true }), blocked);
});
test('isolation: guard is inherited by a separately spawned Node process', () => {
  probe(`require('node:assert/strict').throws(()=>require('firebase-admin/app'),{code:'ERR_FAKE_ISOLATION'});`);
});
test('isolation: assertion and load failures propagate nonzero through isolated runner', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'aud12-exit-'));
  try {
    for (const [name, source] of [
      ['assert', "require('node:test')('intentional failure',()=>require('node:assert/strict').fail('synthetic assertion'));"],
      ['load', "throw new Error('synthetic load failure');"],
      ['guard', "require('firebase-admin/app');"],
    ]) {
      const filename=path.join(directory, name+'.test.cjs'); fs.writeFileSync(filename,source);
      const result=spawnSync(process.execPath,['--require',guard,'--test',filename],{encoding:'utf8',timeout:15000,env:cleanEnvironment(process.env)});
      assert.equal(result.status,1,result.stderr);
      if (name==='guard') assert.match(result.stdout+result.stderr,/AUD-12 fake isolation blocked/);
    }
  } finally { fs.rmSync(directory,{recursive:true,force:true}); }
});
