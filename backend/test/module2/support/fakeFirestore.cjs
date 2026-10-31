// Firestore giả cho test Module 2: đủ cho các route đặt lịch.
// - Document theo đường dẫn "collection/id" (hỗ trợ subcollection).
// - Query: where '==', '>=', '<' (so sánh Date theo thời điểm).
// - Transaction lạc quan giống Firestore: ghi nhận phiên bản các document/query
//   đã đọc, lúc commit thấy thay đổi thì chạy lại hàm (tối đa 5 lần).
// - beforeCommit: hook để test ép hai transaction chen nhau.
const assert = require('node:assert/strict');

const clone = (value) => (value === undefined ? undefined : structuredClone(value));
const ops = {
  '==': (a, b) => a === b,
  '>=': (a, b) => a instanceof Date && a.getTime() >= b.getTime(),
  '<': (a, b) => a instanceof Date && a.getTime() < b.getTime(),
};

function createFakeDb() {
  const state = { store: {}, versions: {}, autoId: 0, attempts: 0, conflicts: 0, beforeCommit: null };

  const parentOf = (path) => path.slice(0, path.lastIndexOf('/'));
  function ref(path) {
    return {
      path,
      id: path.split('/').at(-1),
      collection: (name) => collection(`${path}/${name}`),
      get: async () => snap(path),
      // Ghi trực tiếp ngoài transaction (ví dụ PATCH /api/users/me dùng merge).
      set: async (data, options = {}) => {
        state.store[path] = options.merge
          ? { ...(state.store[path] || {}), ...clone(data) }
          : clone(data);
        bump(path);
      },
    };
  }
  function snap(path) {
    const value = clone(state.store[path]);
    return { id: path.split('/').at(-1), ref: ref(path), exists: value !== undefined, data: () => clone(value) };
  }
  function matching(q) {
    return Object.keys(state.store)
      .filter((p) => parentOf(p) === q.path &&
        q.filters.every(([field, op, value]) => ops[op](state.store[p][field], value)))
      .sort();
  }
  function collection(path, filters = []) {
    const q = {
      path,
      filters,
      doc: (id) => ref(`${path}/${id ?? `auto_${++state.autoId}`}`),
      where(field, op, value) {
        assert.ok(ops[op], `fake firestore chưa hỗ trợ toán tử ${op}`);
        return collection(path, [...filters, [field, op, value]]);
      },
      get: async () => {
        const docs = matching(q).map(snap);
        return { docs, size: docs.length, empty: docs.length === 0 };
      },
    };
    return q;
  }
  const fingerprint = (q) => JSON.stringify(matching(q).map((p) => [p, state.versions[p] || 0]));
  function apply(writes) {
    for (const write of writes) {
      write();
    }
  }
  const bump = (path) => { state.versions[path] = (state.versions[path] || 0) + 1; };

  const db = {
    collection,
    batch() {
      const writes = [];
      return {
        set: (r, data) => writes.push(() => { state.store[r.path] = clone(data); bump(r.path); }),
        update: (r, data) => writes.push(() => { Object.assign(state.store[r.path], clone(data)); bump(r.path); }),
        delete: (r) => writes.push(() => { delete state.store[r.path]; bump(r.path); }),
        commit: async () => apply(writes),
      };
    },
    async runTransaction(fn) {
      for (let retry = 0; retry < 5; retry += 1) {
        state.attempts += 1;
        const checks = [];
        const writes = [];
        const result = await fn({
          async get(r) {
            assert.equal(writes.length, 0, 'Firestore: mọi lệnh đọc phải trước lệnh ghi');
            if (r.filters) {
              const before = fingerprint(r);
              checks.push(() => fingerprint(r) === before);
              const docs = matching(r).map(snap);
              return { docs, size: docs.length, empty: docs.length === 0 };
            }
            const before = state.versions[r.path] || 0;
            checks.push(() => (state.versions[r.path] || 0) === before);
            return snap(r.path);
          },
          set: (r, data) => writes.push(() => { state.store[r.path] = clone(data); bump(r.path); }),
          update: (r, data) => writes.push(() => {
            assert.ok(state.store[r.path], `update document không tồn tại: ${r.path}`);
            Object.assign(state.store[r.path], clone(data));
            bump(r.path);
          }),
          delete: (r) => writes.push(() => { delete state.store[r.path]; bump(r.path); }),
        });
        if (state.beforeCommit) await state.beforeCommit();
        // Kiểm tra và ghi liền nhau, không có await: giống commit nguyên tử.
        if (!checks.every((check) => check())) {
          state.conflicts += 1;
          continue;
        }
        apply(writes);
        return result;
      }
      throw Object.assign(new Error('transaction contention'), { code: 10 });
    },
  };

  return {
    db,
    state,
    get store() { return state.store; },
    reset(store) {
      state.store = clone(store);
      state.versions = {};
      state.autoId = 0;
      state.attempts = 0;
      state.conflicts = 0;
      state.beforeCommit = null;
    },
    paths: (prefix) => Object.keys(state.store).filter((p) => p.startsWith(prefix)),
    // Ép N transaction đầu tiên cùng đọc xong rồi mới commit.
    interleave(count = 2) {
      let arrived = 0;
      let release;
      const gate = new Promise((resolve) => { release = resolve; });
      state.beforeCommit = async () => {
        arrived += 1;
        if (arrived <= count) {
          if (arrived === count) release();
          await gate;
        }
      };
    },
  };
}

// Thay config/firebase bằng Firestore giả trước khi nạp route.
// Token "A", "B" là bệnh nhân; "staff" là nhân viên.
function installFakeFirebase(fake) {
  const firebasePath = require.resolve('../../../src/config/firebase');
  require.cache[firebasePath] = {
    id: firebasePath,
    filename: firebasePath,
    loaded: true,
    exports: {
      db: fake.db,
      auth: {
        async verifyIdToken(value) {
          if (value === 'A' || value === 'B') return { uid: value };
          if (value === 'staff') return { uid: 'S', role: 'staff' };
          throw new Error('invalid synthetic identity');
        },
      },
    },
  };
}

module.exports = { createFakeDb, installFakeFirebase };
