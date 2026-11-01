const { test } = require('node:test');
const assert = require('node:assert/strict');

// No credentials or live database are needed to check record serialization.
const firebasePath = require.resolve('../src/config/firebase');
const snapshot = {
  id: 'visit_1',
  exists: true,
  ref: { path: 'visits/visit_1' },
  data: () => ({ patientId: 'patient_1', diagnosis: 'Khám định kỳ' }),
};
require.cache[firebasePath] = {
  id: firebasePath,
  filename: firebasePath,
  loaded: true,
  exports: {
    db: { collection: () => ({ doc: () => ({ get: async () => snapshot }) }) },
  },
};
const { document, documents, getRecordOrThrow } = require('../src/utils/records');

test('detail records serialize the data object returned by getRecordOrThrow', async () => {
  for (const collection of ['visits', 'invoices', 'treatments']) {
    const record = await getRecordOrThrow(collection, snapshot.id);
    assert.deepEqual(document(record), { id: snapshot.id, ...snapshot.data() });
    assert.equal(document(record).ref, undefined);
  }
});

test('Firestore snapshots still serialize for lists and follow-up details', () => {
  const expected = { id: snapshot.id, ...snapshot.data() };
  assert.deepEqual(document(snapshot), expected);
  assert.deepEqual(documents({ docs: [snapshot] }), [expected]);
});
