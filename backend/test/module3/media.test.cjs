// Giai đoạn 2 - Ảnh đại diện và ảnh trước, sau điều trị lưu base64 trong Firestore.
// Dùng Firestore giả, không gọi mạng.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createFakeDb, installFakeFirebase } = require('../module2/support/fakeFirestore.cjs');

const fake = createFakeDb();
installFakeFirebase(fake);
const { jsonBody, MAX_IMAGE_BYTES } = require('../../src/utils/media');

const JSON_LIMIT_BYTES = 1024 * 1024;
const jsonBytes = value => Buffer.byteLength(JSON.stringify(value), 'utf8');

const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
const jpeg = (size) => {
  const buffer = Buffer.alloc(size, 0x11);
  buffer.set([0xff, 0xd8, 0xff, 0xe0]);
  return buffer.toString('base64');
};
const JPEG = jpeg(64);
const GIF = Buffer.from('GIF89a\x01\x00\x01\x00\x00\x00\x00', 'latin1').toString('base64');

let server, base;
let routedRequests = 0;
before(async () => {
  const app = express();
  app.use(jsonBody);
  // Reached only after parsing succeeds; proves transport rejection precedes routes.
  app.use((req, res, next) => { routedRequests++; next(); });
  app.use('/api/users', require('../../src/routes/users'));
  app.use('/api/family-members', require('../../src/routes/familyMembers'));
  app.use('/api/media', require('../../src/routes/media'));
  app.use('/api/treatments', require('../../src/routes/treatments'));
  // Giống bộ bắt lỗi trong server.js
  app.use((err, req, res, next) => {
    if (err.type === 'entity.too.large') return res.status(413).json({ message: 'quá lớn' });
    res.status(500).json({ message: 'Lỗi server' });
  });
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api`;
});
after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => fake.reset({
  'users/A': { email: 'a@example.com', fullName: 'A' },
  'users/A/family_members/kid': { fullName: 'Con', isArchived: false },
  'users/A/family_members/old': { fullName: 'Đã xóa', isArchived: true },
  'users/B': { email: 'b@example.com' },
  'treatments/t1': { patientId: 'A', accountId: 'A', name: 'Niềng răng' },
  'treatments/tkid': { patientId: 'kid', accountId: 'A', name: 'Trám răng' },
  'treatments/told': { patientId: 'old', accountId: 'A', name: 'Liệu trình cũ' },
  'treatments/tlegacy': { patientId: 'A', name: 'Dữ liệu cũ', photos: [{ imageUrl: 'https://x/1.jpg', type: 'before' }] },
  'treatment_sessions/t1_s1': { treatmentId: 't1', patientId: 'A', sessionNumber: 1 },
  'treatment_sessions/tkid_s1': { treatmentId: 'tkid', patientId: 'kid', sessionNumber: 1 },
  'treatment_photos/legacy1': { treatmentId: 't1', patientId: 'A', imageUrl: 'https://x/old.jpg', type: 'after' },
}));

async function call(path, { method = 'GET', token = 'A', body, raw = false } = {}) {
  const r = await fetch(`${base}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    ...(body !== undefined ? { body: typeof body === 'string' ? body : JSON.stringify(body) } : {}),
  });
  if (raw) return { status: r.status, type: r.headers.get('content-type'), bytes: Buffer.from(await r.arrayBuffer()) };
  return { status: r.status, body: await r.json() };
}
const media = () => fake.paths('media/');
const snapshot = () => structuredClone(fake.store);

test('PUT avatar: lưu media base64, gắn avatarMediaId; GET /api/media trả đúng ảnh và Content-Type', async () => {
  const r = await call('/users/me/avatar', { method: 'PUT', body: { image: PNG, mimeType: 'image/png' } });
  assert.equal(r.status, 200);
  const id = r.body.avatarMediaId;
  // Approved contract: avatarMediaId only; image bytes are fetched by ID.
  assert.equal(typeof id, 'string');
  assert.match(id, /^[^/]+$/);
  assert.deepEqual(r.body, { avatarMediaId: id });
  assert.equal(fake.store['users/A'].avatarMediaId, id);
  const doc = fake.store[`media/${id}`];
  assert.deepEqual([doc.ownerAccountId, doc.patientId, doc.kind, doc.mimeType, doc.createdBy, doc.data],
    ['A', 'A', 'avatar', 'image/png', 'A', PNG]);
  assert.equal(doc.size, Buffer.from(PNG, 'base64').length);

  const img = await call(`/media/${id}`, { raw: true });
  assert.equal(img.status, 200);
  assert.equal(img.type, 'image/png');
  assert.deepEqual(img.bytes, Buffer.from(PNG, 'base64'));
  // Staff xem được; tài khoản khác 403; chưa đăng nhập 401; không có 404.
  assert.equal((await call(`/media/${id}`, { token: 'staff', raw: true })).status, 200);
  assert.equal((await call(`/media/${id}`, { token: 'B' })).status, 403);
  assert.equal((await call(`/media/${id}`, { token: null })).status, 401);
  assert.equal((await call('/media/nope')).status, 404);
});

test('thay avatar xóa ảnh cũ, DELETE gỡ ảnh; data URL JPEG được nhận', async () => {
  const first = await call('/users/me/avatar', { method: 'PUT', body: { image: PNG } });
  const second = await call('/users/me/avatar', { method: 'PUT', body: { image: `data:image/jpeg;base64,${JPEG}` } });
  assert.equal(second.status, 200);
  assert.deepEqual(media(), [`media/${second.body.avatarMediaId}`]);
  assert.equal(fake.store[`media/${second.body.avatarMediaId}`].mimeType, 'image/jpeg');
  assert.notEqual(first.body.avatarMediaId, second.body.avatarMediaId);
  const removed = await call('/users/me/avatar', { method: 'DELETE' });
  // Approved DELETE response remains a message, with actual deletion checked below.
  assert.equal(removed.status, 200);
  assert.deepEqual(removed.body, { message: 'Đã gỡ ảnh' });
  assert.equal(fake.store['users/A'].avatarMediaId, null);
  assert.deepEqual(media(), []);
  assert.equal((await call(`/media/${first.body.avatarMediaId}`)).status, 404);
  assert.equal((await call(`/media/${second.body.avatarMediaId}`)).status, 404);
});

test('avatar người thân: còn hoạt động thì được, đã xóa hoặc không phải của mình thì 404', async () => {
  const r = await call('/family-members/kid/avatar', { method: 'PUT', body: { image: PNG } });
  assert.equal(r.status, 200);
  assert.equal(fake.store['users/A/family_members/kid'].avatarMediaId, r.body.avatarMediaId);
  assert.equal(fake.store[`media/${r.body.avatarMediaId}`].patientId, 'kid');
  const old = snapshot();
  assert.equal((await call('/family-members/old/avatar', { method: 'PUT', body: { image: PNG } })).status, 404);
  assert.equal((await call('/family-members/kid/avatar', { method: 'PUT', token: 'B', body: { image: PNG } })).status, 404);
  assert.equal((await call('/family-members/old/avatar', { method: 'DELETE' })).status, 404);
  assert.deepEqual(fake.store, old);
  // Ảnh người thân chỉ chủ tài khoản xem được.
  assert.equal((await call(`/media/${r.body.avatarMediaId}`, { token: 'B' })).status, 403);
  assert.equal((await call('/family-members/kid/avatar', { method: 'DELETE' })).status, 200);
  assert.deepEqual(media(), []);
});

const BAD_IMAGES = [
  ['thiếu ảnh', {}, 400],
  ['ảnh GIF', { image: GIF }, 400],
  ['base64 hỏng', { image: 'không phải base64!' }, 400],
  ['văn bản đổi đuôi', { image: Buffer.from('hello world, not an image').toString('base64'), mimeType: 'image/png' }, 400],
  ['bytes GIF giả khai báo PNG', { image: GIF, mimeType: 'image/png' }, 400],
  ['quá 716800 bytes sau giải mã', { image: jpeg(MAX_IMAGE_BYTES + 1) }, 413],
  ['body quá 1 MiB', { image: jpeg(800 * 1024) }, 413],
];
for (const [label, body, status] of BAD_IMAGES) {
  test(`ảnh sai (${label}) trả ${status}, không ghi gì`, async () => {
    const old = snapshot();
    for (const payload of [body, { phase: 'before', ...body }]) {
      if (label === 'quá 716800 bytes sau giải mã') {
        assert.ok(jsonBytes(payload) < JSON_LIMIT_BYTES);
        assert.equal(Buffer.from(payload.image, 'base64').length, MAX_IMAGE_BYTES + 1);
      }
      if (label === 'body quá 1 MiB') {
        assert.ok(jsonBytes(payload) > JSON_LIMIT_BYTES);
      }
    }
    assert.equal((await call('/users/me/avatar', { method: 'PUT', body })).status, status);
    assert.equal((await call('/family-members/kid/avatar', { method: 'PUT', body })).status, status);
    assert.equal((await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'before', ...body } })).status, status);
    assert.deepEqual(fake.store, old);
  });
}

// Approved policy: contradictory client metadata cannot replace the detected byte MIME.
// Preserve both former failure cases, checking avatar AND treatment-photo paths.
for (const [label, body] of [
  ['mimeType không khớp nội dung', { image: PNG, mimeType: 'image/jpeg' }],
  ['data URL khai báo GIF', { image: `data:image/gif;base64,${PNG}` }],
]) {
  test(`${label}: bytes PNG quyết định MIME lưu và Content-Type, không đổi nội dung`, async () => {
    for (const [endpoint, method, payload] of [
      ['/users/me/avatar', 'PUT', body],
      ['/treatments/t1/photos', 'POST', { phase: 'before', ...body }],
    ]) {
      const uploaded = await call(endpoint, { method, body: payload });
      assert.equal(uploaded.status, method === 'PUT' ? 200 : 201);
      const id = method === 'PUT' ? uploaded.body.avatarMediaId : uploaded.body.mediaId;
      assert.equal(typeof id, 'string');
      assert.match(id, /^[^/]+$/);
      const stored = fake.store[`media/${id}`];
      assert.equal(stored.mimeType, 'image/png');
      assert.equal(stored.data, PNG);
      assert.equal(stored.size, Buffer.from(PNG, 'base64').length);
      const image = await call(`/media/${id}`, { raw: true });
      assert.equal(image.status, 200);
      assert.equal(image.type, 'image/png');
      assert.deepEqual(image.bytes, Buffer.from(PNG, 'base64'));
    }
  });
}

test('ảnh đúng 716800 bytes vẫn nhận khi JSON dưới 1 MiB', async () => {
  assert.equal(MAX_IMAGE_BYTES, 716800);
  const body = { image: jpeg(MAX_IMAGE_BYTES) };
  assert.ok(jsonBytes(body) < JSON_LIMIT_BYTES);
  for (const [path, method, payload] of [
    ['/users/me/avatar', 'PUT', body],
    ['/family-members/kid/avatar', 'PUT', body],
    ['/treatments/t1/photos', 'POST', { phase: 'before', ...body }],
  ]) {
    assert.ok(jsonBytes(payload) < JSON_LIMIT_BYTES);
    const r = await call(path, { method, body: payload });
    assert.equal(r.status, method === 'POST' ? 201 : 200);
    const id = method === 'POST' ? r.body.mediaId : r.body.avatarMediaId;
    assert.equal(fake.store[`media/${id}`].size, MAX_IMAGE_BYTES);
    const image = await call(`/media/${id}`, { raw: true });
    assert.equal(image.status, 200);
    assert.deepEqual(image.bytes, Buffer.from(body.image, 'base64'));
  }
});

test('JSON dưới 1 MiB nhưng address sai: field validation 400, không ghi', async () => {
  const body = { address: 'x'.repeat(150 * 1024) };
  assert.ok(jsonBytes(body) > 100 * 1024);
  assert.ok(jsonBytes(body) < JSON_LIMIT_BYTES);
  const old = snapshot(), beforeRoutes = routedRequests;
  const r = await call('/users/me', { method: 'PATCH', body });
  assert.equal(r.status, 400);
  assert.equal(r.body.message, 'address tối đa 200 ký tự');
  assert.equal(routedRequests, beforeRoutes + 1);
  assert.deepEqual(fake.store, old);
});

test('JSON đúng 1 MiB đi qua parser, field validation vẫn trả 400 và không ghi', async () => {
  const overhead = jsonBytes({ address: '' });
  const body = { address: 'x'.repeat(JSON_LIMIT_BYTES - overhead) };
  assert.equal(jsonBytes(body), JSON_LIMIT_BYTES);
  const old = snapshot(), beforeRoutes = routedRequests;
  const r = await call('/users/me', { method: 'PATCH', body });
  assert.equal(r.status, 400);
  assert.equal(r.body.message, 'address tối đa 200 ký tự');
  assert.equal(routedRequests, beforeRoutes + 1);
  assert.deepEqual(fake.store, old);
});

for (const [path, method] of [
  ['/users/me', 'PATCH'], ['/users/me/avatar', 'PUT'],
  ['/family-members/kid/avatar', 'PUT'], ['/treatments/t1/photos', 'POST'],
]) {
  test(`JSON vượt 1 MiB: ${method} ${path} trả 413 trước route, không ghi`, async () => {
    const overhead = jsonBytes({ address: '' });
    const body = { address: 'x'.repeat(JSON_LIMIT_BYTES + 1 - overhead) };
    assert.equal(jsonBytes(body), JSON_LIMIT_BYTES + 1);
    const serialized = JSON.stringify(body);
    assert.equal(Buffer.byteLength(serialized, 'utf8'), JSON_LIMIT_BYTES + 1);
    const old = snapshot(), beforeRoutes = routedRequests;
    const r = await call(path, { method, body: serialized });
    assert.equal(r.status, 413);
    assert.deepEqual(r.body, { message: 'quá lớn' });
    assert.equal(routedRequests, beforeRoutes);
    assert.deepEqual(fake.store, old);
  });
}

test('bệnh nhân tải ảnh trước/sau, GET trả ảnh cũ và mới, chỉ ảnh mới có canDelete', async () => {
  const up = await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'before', image: JPEG, sessionId: 't1_s1', note: ' Trước khi niềng ' } });
  assert.equal(up.status, 201);
  assert.deepEqual([up.body.phase, up.body.sessionId, up.body.note, up.body.createdBy, up.body.createdByRole, up.body.canDelete],
    ['before', 't1_s1', 'Trước khi niềng', 'A', 'patient', true]);
  const m = fake.store[`media/${up.body.mediaId}`];
  assert.deepEqual([m.kind, m.ownerAccountId, m.patientId], ['treatment_photo', 'A', 'A']);

  const list = await call('/treatments/t1/photos');
  assert.equal(list.status, 200);
  const mine = list.body.find((p) => p.id === up.body.id);
  assert.equal(mine.imageUrl, `/api/media/${up.body.mediaId}`);
  assert.equal(mine.type, 'before');
  assert.equal(mine.canDelete, true);
  assert.equal(list.body.find((p) => p.id === 'legacy1').canDelete, false);
  // Mảng ảnh trong treatment cũ vẫn trả về.
  const legacy = await call('/treatments/tlegacy/photos');
  assert.deepEqual(legacy.body.map((p) => [p.imageUrl, p.canDelete]), [['https://x/1.jpg', false]]);
  // Staff xem được danh sách và ảnh; tài khoản khác 403.
  assert.equal((await call('/treatments/t1/photos', { token: 'staff' })).status, 200);
  assert.equal((await call('/treatments/t1/photos', { token: 'B' })).status, 403);
  assert.equal((await call(`/media/${up.body.mediaId}`, { token: 'B' })).status, 403);
});

test('ảnh người thân: còn hoạt động thì tải được; đã xóa chỉ xem ảnh cũ, không tải mới', async () => {
  const ok = await call('/treatments/tkid/photos', { method: 'POST', body: { phase: 'after', image: PNG } });
  assert.equal(ok.status, 201);
  assert.equal(fake.store[`media/${ok.body.mediaId}`].patientId, 'kid');
  fake.store['treatment_photos/oldphoto'] = { treatmentId: 'told', patientId: 'old', imageUrl: 'https://x/o.jpg' };
  const old = snapshot();
  const denied = await call('/treatments/told/photos', { method: 'POST', body: { phase: 'after', image: PNG } });
  assert.equal(denied.status, 403);
  // AUD-06 keeps the generic 403 guard; verify the complete write/read boundary.
  assert.deepEqual(denied.body, { message: 'Bạn không có quyền truy cập hồ sơ này' });
  assert.deepEqual(fake.store, old);
  assert.deepEqual(fake.store['treatments/told'], old['treatments/told']);
  assert.deepEqual(media(), Object.keys(old).filter(path => path.startsWith('media/')).sort());
  const history = await call('/treatments/told/photos');
  assert.equal(history.status, 200);
  assert.equal(history.body.length, 1);
  assert.equal(history.body[0].id, 'oldphoto');
  assert.equal(history.body[0].imageUrl, 'https://x/o.jpg');
  assert.equal(history.body[0].canDelete, false);
  assert.equal((await call('/treatments/told/photos', { token: 'B' })).status, 403);
  assert.deepEqual(fake.store, old);
});

test('staff tải ảnh cho bệnh nhân: media thuộc tài khoản bệnh nhân, bệnh nhân xem được', async () => {
  const up = await call('/treatments/tkid/photos', { method: 'POST', token: 'staff', body: { phase: 'after', image: PNG } });
  assert.equal(up.status, 201);
  assert.equal(up.body.createdByRole, 'staff');
  assert.equal(fake.store[`media/${up.body.mediaId}`].ownerAccountId, 'A');
  assert.equal((await call(`/media/${up.body.mediaId}`, { raw: true })).status, 200);
  // Bệnh nhân không xóa được ảnh staff tải lên.
  const list = await call('/treatments/tkid/photos');
  assert.equal(list.body[0].canDelete, false);
  assert.equal((await call(`/treatments/tkid/photos/${up.body.id}`, { method: 'DELETE' })).status, 403);
  // Liệu trình cũ không có accountId: staff dùng patientId nếu là tài khoản.
  assert.equal((await call('/treatments/tlegacy/photos', { method: 'POST', token: 'staff', body: { phase: 'before', image: PNG } })).status, 201);
});

test('tải ảnh sai: phase, buổi khác liệu trình, liệu trình không có, của người khác', async () => {
  const old = snapshot();
  assert.equal((await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'middle', image: PNG } })).status, 400);
  assert.equal((await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'before', image: PNG, sessionId: 'tkid_s1' } })).status, 400);
  assert.equal((await call('/treatments/nope/photos', { method: 'POST', body: { phase: 'before', image: PNG } })).status, 404);
  assert.equal((await call('/treatments/t1/photos', { method: 'POST', token: 'B', body: { phase: 'before', image: PNG } })).status, 403);
  assert.equal((await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'before', image: PNG, note: 'x'.repeat(501) } })).status, 400);
  assert.deepEqual(fake.store, old);
});

test('tối đa 30 ảnh mỗi liệu trình (tính cả ảnh cũ)', async () => {
  for (let i = 0; i < 29; i += 1) {
    fake.store[`treatment_photos/p${i}`] = { treatmentId: 't1', patientId: 'A', imageUrl: 'x' };
  }
  // legacy1 + 29 = 30
  const r = await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'before', image: PNG } });
  assert.equal(r.status, 409);
  assert.match(r.body.message, /30 ảnh/);
  assert.deepEqual(media(), []);
});

test('xóa ảnh: người tải lên hoặc staff; xóa cả media; ảnh cũ 409; sai liệu trình 404', async () => {
  const mine = await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'before', image: PNG } });
  const second = await call('/treatments/t1/photos', { method: 'POST', body: { phase: 'after', image: PNG } });
  assert.equal((await call(`/treatments/t1/photos/${mine.body.id}`, { method: 'DELETE', token: 'B' })).status, 403);
  assert.equal((await call(`/treatments/tkid/photos/${mine.body.id}`, { method: 'DELETE' })).status, 404);
  assert.equal((await call('/treatments/t1/photos/legacy1', { method: 'DELETE', token: 'staff' })).status, 409);
  const del = await call(`/treatments/t1/photos/${mine.body.id}`, { method: 'DELETE' });
  assert.equal(del.status, 200);
  assert.equal(fake.store[`treatment_photos/${mine.body.id}`], undefined);
  assert.equal(fake.store[`media/${mine.body.mediaId}`], undefined);
  assert.equal((await call(`/treatments/t1/photos/${second.body.id}`, { method: 'DELETE', token: 'staff' })).status, 200);
  assert.deepEqual(media(), []);
  assert.ok(fake.store['treatment_photos/legacy1']);
});
