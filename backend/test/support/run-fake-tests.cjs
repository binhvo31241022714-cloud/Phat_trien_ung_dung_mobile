'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const guard = path.join(__dirname, 'fake-isolation.cjs');

// Inspect names only: list mode never imports a test or production module.
function discoverTests(directory) {
  const files = new Set();
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isSymbolicLink()) continue;
      const filename = path.join(dir, entry.name);
      if (entry.isDirectory() && entry.name !== 'support') walk(filename);
      else if (entry.isFile() && /\.test\.(?:js|cjs)$/.test(entry.name)) files.add(filename);
    }
  }
  walk(directory);
  return [...files].sort();
}
function cleanEnvironment(env) {
  const result = { ...env };
  // Never inherit preloads or cloud/emulator configuration into fake processes.
  for (const key of Object.keys(result)) {
    if (/^(?:NODE_OPTIONS|NODE_PATH|NODE_TEST_CONTEXT|GOOGLE_|GCLOUD_|FIREBASE_|FIRESTORE_)/.test(key)) delete result[key];
  }
  return result;
}
function main(args) {
  if (process.versions.node.split('.')[0] !== '24') {
    console.error('AUD-12: fake test launcher requires Node 24.x.');
    return 1;
  }
  if (args.some(arg => arg !== '--list')) {
    console.error('AUD-12: supported option: --list');
    return 1;
  }
  const files = discoverTests(path.join(root, 'test'));
  if (!files.length) { console.error('AUD-12: no fake tests discovered.'); return 1; }
  if (args.includes('--list')) {
    for (const file of files) console.log(path.relative(root, file).split(path.sep).join('/'));
    return 0;
  }
  const child = spawnSync(process.execPath, ['--require', guard, '--test', ...files], {
    cwd: root, env: cleanEnvironment(process.env), stdio: 'inherit',
  });
  if (child.error) console.error('AUD-12: test runner could not start.');
  return child.status ?? 1;
}
module.exports = { discoverTests, cleanEnvironment };
if (require.main === module) process.exitCode = main(process.argv.slice(2));
