const { db } = require('../config/firebase');

const familyMembers = (uid) =>
  db.collection('users').doc(uid).collection('family_members');

async function canAccessPatient(uid, patientId) {
  if (!uid || !patientId) return false;
  if (patientId === uid) return true;
  return (await familyMembers(uid).doc(patientId).get()).exists;
}

async function assertPatientAccess(uid, patientId) {
  if (!(await canAccessPatient(uid, patientId))) {
    const error = new Error('Bạn không có quyền xem hồ sơ này');
    error.status = 403;
    throw error;
  }
}

async function getRecordOrThrow(collection, id) {
  const snapshot = await db.collection(collection).doc(id).get();
  if (!snapshot.exists) {
    const error = new Error('Không tìm thấy hồ sơ');
    error.status = 404;
    throw error;
  }
  return { ref: snapshot.ref, id: snapshot.id, data: snapshot.data() };
}

async function assertRecordAccess(uid, record) {
  await assertPatientAccess(uid, record.data.patientId);
}

function document(record) {
  return { id: record.id, ...record.data };
}

function documents(snapshot) {
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

function asyncHandler(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch((error) => {
      if (Number.isInteger(error.status)) {
        return res.status(error.status).json({ message: error.message });
      }
      next(error);
    });
  };
}

module.exports = {
  db,
  assertPatientAccess,
  assertRecordAccess,
  getRecordOrThrow,
  document,
  documents,
  asyncHandler,
};
