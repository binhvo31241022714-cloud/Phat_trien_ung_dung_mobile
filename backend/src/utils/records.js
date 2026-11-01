const { db } = require('../config/firebase');

const asyncHandler = (handler) => (req, res, next) =>
  Promise.resolve(handler(req, res, next)).catch((error) => {
    if (Number.isInteger(error.status)) return res.status(error.status).json({ message: error.message });
    console.error(error);
    return res.status(500).json({ message: 'Lỗi server' });
  });
// Accept both Firestore snapshots and records returned by getRecordOrThrow.
const document = (record) => ({
  id: record.id,
  ...(typeof record.data === 'function' ? record.data() : record.data),
});
const documents = (snapshot) => snapshot.docs.map(document);
async function getRecordOrThrow(collection, id) {
  const snap = await db.collection(collection).doc(id).get();
  if (!snap.exists) { const e = new Error('Không tìm thấy dữ liệu'); e.status = 404; throw e; }
  return { id: snap.id, ref: snap.ref, data: snap.data() };
}
async function assertPatientAccess(uid, patientId) {
  if (patientId === uid) return;
  const snap = await db.collection('users').doc(uid).collection('family_members').doc(patientId).get();
  if (!snap.exists || snap.data().isArchived === true) { const e = new Error('Bạn không có quyền truy cập hồ sơ này'); e.status = 403; throw e; }
}
async function assertRecordAccess(uid, record) {
  if (!historyOwnershipMatches(uid, record.data)) denyHistory();
  // Preserve the existing owned-orphan exception for these detail readers only.
  if (record.data.accountId === uid || record.data.ownerAccountId === uid) return;
  await assertHistoryPatientAccess(uid, record.data.patientId);
}
function denyHistory() {
  throw Object.assign(new Error('Bạn không có quyền truy cập hồ sơ này'), { status: 403 });
}
function historyOwnershipMatches(uid, data) {
  return ['accountId', 'ownerAccountId'].every(field =>
    data[field] === undefined || (typeof data[field] === 'string' && data[field] === uid));
}
async function assertHistoryPatientAccess(uid, patientId) {
  if (typeof patientId !== 'string' || !patientId.trim() || patientId.includes('/')) denyHistory();
  if (patientId === uid) return;
  const member = await db.collection('users').doc(uid).collection('family_members').doc(patientId).get();
  if (!member.exists) denyHistory();
}
function historyChildMatches(uid, parent, child, field, parentId) {
  return child[field] === parentId && typeof parent.patientId === 'string' &&
    child.patientId === parent.patientId && historyOwnershipMatches(uid, child);
}
async function assertPatientClinicalWrite(transaction, uid, data) {
  if (!historyOwnershipMatches(uid, data)) denyHistory();
  const patientId = data.patientId;
  if (typeof patientId !== 'string' || !patientId.trim() || patientId.includes('/')) denyHistory();
  if (patientId === uid) return;
  const member = await transaction.get(db.collection('users').doc(uid).collection('family_members').doc(patientId));
  if (!member.exists || member.data().isArchived === true) denyHistory();
}
async function assertActivePatient(transaction, accountId, patientId) {
  const ref = patientId === accountId
    ? db.collection('users').doc(accountId)
    : db.collection('users').doc(accountId).collection('family_members').doc(patientId);
  const snap = await transaction.get(ref);
  if (!snap.exists || snap.data().isArchived === true) { const e = new Error('Người khám không thuộc tài khoản hoặc đã bị xóa'); e.status = 400; throw e; }
}
module.exports = { db, asyncHandler, document, documents, getRecordOrThrow, assertPatientAccess, assertRecordAccess, assertActivePatient,
  assertHistoryPatientAccess, historyOwnershipMatches, historyChildMatches, assertPatientClinicalWrite };
