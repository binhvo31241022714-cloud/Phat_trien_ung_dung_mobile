function requireFirestore() {
  return require('../src/config/firebase').db;
}

async function deleteQuery(db, collection, field, value, apply) {
  const snapshot = await db.collection(collection).where(field, '==', value).get();
  if (!apply) return snapshot.size;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  if (!snapshot.empty) await batch.commit();
  return snapshot.size;
}

module.exports = { requireFirestore, deleteQuery };
