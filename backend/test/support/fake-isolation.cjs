'use strict';
// Preloaded in both the Node test runner and every isolated test process.
// This guards accidental I/O; it is not a sandbox for hostile JavaScript.
const Module = require('node:module');
const path = require('node:path');
const { fileURLToPath } = require('node:url');
const net = require('node:net');
const { AsyncLocalStorage } = require('node:async_hooks');
const httpConnection = new AsyncLocalStorage();
const tls = require('node:tls');
const http = require('node:http');
const https = require('node:https');
const dns = require('node:dns');
const dgram = require('node:dgram');
const childProcess = require('node:child_process');
const workers = require('node:worker_threads');
const root = path.resolve(__dirname, '../..');
const config = path.join(root, 'src/config/firebase.js');
const server = path.join(root, 'src/server.js');
const reminders = path.join(root, 'src/jobs/reminders.js');
const originalLoad = Module._load;
const originalSpawn = childProcess.spawn;
const originalSpawnSync = childProcess.spawnSync;
function blocked(what) {
  const error = new Error(`AUD-12 fake isolation blocked: ${what}`);
  error.code = 'ERR_FAKE_ISOLATION';
  throw error;
}
function prohibited(filename) {
  return filename === config || filename === server ||
    /[/\\]node_modules[/\\]firebase-admin(?:[/\\]|$)/.test(filename) ||
    /(?:^|[/\\])(?:\.env(?:\..*)?|serviceAccountKey\.json)$/.test(filename);
}
Module._load = function(request, parent, isMain) {
  if (/^firebase-admin(?:\/|$)/.test(request)) blocked('Firebase Admin import');
  const filename = Module._resolveFilename(request, parent, isMain);
  if (filename === config) {
    const cached = require.cache[filename];
    if (!cached?.loaded || !cached.exports?.db) blocked('real Firebase config');
    return cached.exports; // Respect deliberate in-memory cache injection.
  }
  if (prohibited(filename)) blocked('production entrypoint or credential module');
  const result = originalLoad.apply(this, arguments);
  if (filename === reminders) {
    result.startReminderJob = () => blocked('real reminder scheduler');
  }
  return result;
};
// Covers ESM imports and direct module loading as well as CommonJS _load.
// Resolution remains permitted, including require.resolve(config).
Module.registerHooks({
  load(url, context, nextLoad) {
    if (url.startsWith('file:') && prohibited(fileURLToPath(url))) blocked('real module execution');
    return nextLoad(url, context);
  },
});
const loopback = host => host === '127.0.0.1' || host === '::1' || host === '[::1]';
function checkHttp(input, options) {
  let target;
  if (typeof input === 'string' || input instanceof URL) {
    const url = new URL(input);
    target = { protocol: url.protocol, hostname: url.hostname, ...options };
  } else target = input || {};
  if (target.protocol && target.protocol !== 'http:') blocked('non-HTTP network');
  if (target.socketPath || !loopback(target.hostname || target.host)) blocked('non-loopback HTTP');
}
for (const name of ['request', 'get']) {
  const original = http[name];
  http[name] = function(input, options, ...rest) {
    checkHttp(input, typeof options === 'object' ? options : undefined);
    return httpConnection.run(true, () => original.call(this, input, options, ...rest));
  };
  https[name] = () => blocked('TLS/HTTPS network');
}
const originalFetch = globalThis.fetch;
globalThis.fetch = function(input, options) {
  checkHttp(typeof input === 'object' && !(input instanceof URL) ? input.url : input);
  return httpConnection.run(true, () => originalFetch(input, options));
};
const originalConnect = net.Socket.prototype.connect;
net.Socket.prototype.connect = function(...args) {
  const normalized = Array.isArray(args[0]) ? args[0] : args;
  const first = normalized[0];
  const options = first && typeof first === 'object' ? first : { port: first, host: normalized[1] };
  if (!httpConnection.getStore() || options.path || !loopback(options.host || options.hostname)) blocked('non-loopback or non-HTTP socket');
  return originalConnect.apply(this, args);
};
const originalListen = net.Server.prototype.listen;
net.Server.prototype.listen = function(...args) {
  const first = args[0];
  const options = first && typeof first === 'object' ? first : { port: first, host: args[1] };
  if (options.port !== 0 || !loopback(options.host)) blocked('non-ephemeral or non-loopback listener');
  return originalListen.apply(this, args);
};
tls.connect = () => blocked('TLS network');
tls.TLSSocket.prototype.connect = () => blocked('TLS network');
dgram.createSocket = () => blocked('UDP network');
// Resolve literal loopback addresses locally, without invoking system DNS.
dns.lookup = function(host, options, callback) {
  if (!loopback(host)) blocked('DNS network');
  if (typeof options === 'function') { callback = options; options = {}; }
  const address = host === '[::1]' ? '::1' : host;
  const family = net.isIP(address);
  process.nextTick(() => options?.all ? callback(null, [{ address, family }]) : callback(null, address, family));
};
for (const name of Object.keys(dns)) {
  if (name !== 'lookup' && typeof dns[name] === 'function' && /^(?:lookup|resolve|reverse)/.test(name)) dns[name] = () => blocked('DNS network');
}
for (const name of Object.keys(dns.promises)) {
  if (typeof dns.promises[name] === 'function') dns.promises[name] = async () => blocked('DNS network');
}
dns.promises.lookup = async function(host, options) {
  if (!loopback(host)) blocked('DNS network');
  const address = host === '[::1]' ? '::1' : host;
  const result = { address, family: net.isIP(address) };
  return options?.all ? [result] : result;
};
dns.Resolver = class { constructor() { blocked('DNS resolver'); } };
dns.promises.Resolver = class { constructor() { blocked('DNS resolver'); } };
workers.Worker = class { constructor() { blocked('unguarded worker'); } };
// Prevent accidental external programs or unguarded child Node processes.
// Node's test runner itself spawns guarded Node processes through this path.
function guardedChild(command, args, options) {
  if (command !== process.execPath || !Array.isArray(args)) blocked('external child process');
  const env = { ...(options?.env || process.env) };
  delete env.NODE_OPTIONS;
  delete env.NODE_PATH;
  return [command, ['--require', __filename, ...args], { ...options, env, shell: false }];
}
childProcess.spawn = function(command, args, options) { return originalSpawn(...guardedChild(command, args, options)); };
childProcess.spawnSync = function(command, args, options) { return originalSpawnSync(...guardedChild(command, args, options)); };
for (const name of ['exec', 'execSync', 'execFile', 'execFileSync', 'fork']) childProcess[name] = () => blocked('unguarded child process');
Module.syncBuiltinESMExports();
