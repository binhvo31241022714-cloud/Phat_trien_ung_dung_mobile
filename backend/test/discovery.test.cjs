'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { discoverTests, cleanEnvironment } = require('./support/run-fake-tests.cjs');
const root=path.resolve(__dirname,'..');
const launcher=path.join(__dirname,'support/run-fake-tests.cjs');
const existing=[
  'booking-safeguards.test.js','records-serialization.test.js',
  ...['booking-flow','family-history','idempotency-note','scheduling','staff-concurrency','staff-status'].map(n=>`module2/${n}.test.cjs`),
  ...['clinical-history','clinical-records','link-visit','media','reminders-followup'].map(n=>`module3/${n}.test.cjs`),
  'module4/routes.test.cjs',
];
test('discovery: includes all 14 original files plus harness tests, sorted without duplicates',()=>{
  const files=discoverTests(__dirname).map(f=>path.relative(__dirname,f).split(path.sep).join('/'));
  for(const file of existing) assert.ok(files.includes(file),file);
  assert.equal(files.length,existing.length+2);
  assert.deepEqual(files,[...new Set(files)].sort());
  assert.ok(files.every(f=>!f.split('/').includes('support')));
});
test('discovery: recursive names only; helpers, support, symlinks and near matches excluded',()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'aud12-discovery-'));
  try {
    fs.mkdirSync(path.join(dir,'nested/deep'),{recursive:true});
    fs.mkdirSync(path.join(dir,'support'));
    for(const file of ['z.test.js','nested/deep/a.test.cjs','helper.cjs','almost.test.cjs.txt','support/not-an-entry.test.cjs'])
      fs.writeFileSync(path.join(dir,file),"throw new Error('must not execute during discovery');");
    fs.symlinkSync(path.join(dir,'z.test.js'),path.join(dir,'alias.test.js'));
    assert.deepEqual(discoverTests(dir).map(f=>path.relative(dir,f)),['nested/deep/a.test.cjs','z.test.js']);
  } finally {fs.rmSync(dir,{recursive:true,force:true});}
});
test('discovery: launcher list-only matches recursive discovery and never loads unsafe entries',()=>{
  const result=spawnSync(process.execPath,[launcher,'--list'],{cwd:root,encoding:'utf8',timeout:15000});
  assert.equal(result.status,0,result.stderr);
  assert.deepEqual(result.stdout.trim().split('\n'),discoverTests(__dirname).map(f=>path.relative(root,f).split(path.sep).join('/')));
});
test('discovery: launcher rejects arbitrary Node flags rather than disabling isolation',()=>{
  const result=spawnSync(process.execPath,[launcher,'--test-isolation=none'],{encoding:'utf8',timeout:15000});
  assert.equal(result.status,1);
  assert.match(result.stderr,/supported option/);
});
test('discovery: environment cleanup strips preloads and cloud configuration without reading credentials',()=>{
  const cleaned=cleanEnvironment({PATH:'synthetic',TZ:'UTC',NODE_OPTIONS:'synthetic',NODE_PATH:'synthetic',
    NODE_TEST_CONTEXT:'synthetic',GOOGLE_APPLICATION_CREDENTIALS:'synthetic',FIREBASE_CONFIG:'synthetic',FIRESTORE_EMULATOR_HOST:'synthetic'});
  assert.deepEqual(cleaned,{PATH:'synthetic',TZ:'UTC'});
});
