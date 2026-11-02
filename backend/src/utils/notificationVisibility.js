const { db } = require('../config/firebase');
const { isValidDateKey, parseTime, parseFirestoreDate, toVietnamDateKey } = require('./booking');
const { appointmentReminderId, followUpReminderId } = require('../jobs/reminders');
const REMINDER = 'appointment_reminder';
// AUD-07: nhắc tái khám, nguồn là follow_ups/{refId}.
const FOLLOW_UP_REMINDER = 'follow_up_reminder';
const OPEN_FOLLOW_UP = ['suggested', 'scheduled'];
const isReminderType = (type) => type === REMINDER || type === FOLLOW_UP_REMINDER;
const CONCURRENCY = 8;

// Bound outstanding reads/transactions. On failure, stop scheduling and drain
// in-flight work before propagating the error (no background writes after 500).
async function boundedMap(items, task) {
  const results = new Array(items.length);
  let next = 0, failure;
  async function worker() {
    while (!failure && next < items.length) {
      const index = next++;
      try { results[index] = await task(items[index]); }
      catch (error) { failure ||= error; }
    }
  }
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, items.length) }, worker));
  if (failure) throw failure;
  return results;
}
function hasCurrentReminderShape(id, data) {
  if (typeof data.refId !== 'string' || !data.refId.trim() || data.refId.includes('/')) return false;
  if (data.type === FOLLOW_UP_REMINDER) {
    const prefix = `furemind_${data.refId}_`;
    return typeof id === 'string' && id.startsWith(prefix) &&
      /^\d{4}-\d{2}-\d{2}$/.test(id.slice(prefix.length));
  }
  const prefix = `${data.refId}_`;
  return typeof id === 'string' && id.startsWith(prefix) &&
    /^\d{4}-\d{2}-\d{2}_(?:[01]\d|2[0-3]):[0-5]\d$/.test(id.slice(prefix.length));
}
// Nhắc tái khám chỉ hiện khi đề xuất vẫn còn mở, đúng chủ tài khoản, đúng ngày hẹn
// hiện tại và tài khoản còn bật nhận thông báo.
function followUpReminderVisible(uid, id, data, followUp, profile) {
  if (data.userId !== uid || data.type !== FOLLOW_UP_REMINDER || !hasCurrentReminderShape(id, data)) return false;
  if (!followUp || followUp.accountId !== uid || !OPEN_FOLLOW_UP.includes(followUp.status)) return false;
  const when = parseFirestoreDate(followUp.scheduledAt);
  if (!when) return false;
  return profile?.notificationsEnabled !== false &&
    id === followUpReminderId(data.refId, toVietnamDateKey(when));
}
function sourceCollection(type) {
  return type === FOLLOW_UP_REMINDER ? 'follow_ups' : 'appointments';
}
function isVisible(uid, id, data, source, profile) {
  return data.type === FOLLOW_UP_REMINDER
    ? followUpReminderVisible(uid, id, data, source, profile)
    : reminderVisible(uid, id, data, source, profile);
}
function reminderVisible(uid, id, data, appointment, profile) {
  if (data.userId !== uid || data.type !== REMINDER || !hasCurrentReminderShape(id, data)) return false;
  if (!appointment || appointment.accountId !== uid || appointment.status !== 'confirmed') return false;
  if (!isValidDateKey(appointment.date)) return false;
  try { parseTime(appointment.startTime); } catch { return false; }
  // Creation window is NOT a display window: past/far-future confirmed sources
  // stay visible while the original schedule/owner/preference remain valid.
  return profile?.notificationsEnabled !== false &&
    id === appointmentReminderId(data.refId, appointment.date, appointment.startTime);
}
async function visibleNotificationDocs(uid, docs) {
  const owned = docs.filter(doc => doc.data().userId === uid);
  const reminders = owned.filter(doc => isReminderType(doc.data().type));
  if (!reminders.length) return owned;
  const profile = await db.collection('users').doc(uid).get();
  const user = profile.exists ? profile.data() : null;
  if (user?.notificationsEnabled === false) return owned.filter(doc => !isReminderType(doc.data().type));
  // Invalid/legacy IDs never cause source lookups. Fetch each distinct source once.
  const keys = [...new Set(reminders
    .filter(doc => hasCurrentReminderShape(doc.id, doc.data()))
    .map(doc => `${sourceCollection(doc.data().type)}/${doc.data().refId}`))];
  const sources = new Map(await boundedMap(keys, async key => {
    const [collection, id] = key.split('/');
    const snap = await db.collection(collection).doc(id).get();
    return [key, snap.exists ? snap.data() : null];
  }));
  return owned.filter(doc => {
    const data = doc.data();
    if (!isReminderType(data.type)) return true;
    const source = sources.get(`${sourceCollection(data.type)}/${data.refId}`);
    return isVisible(uid, doc.id, data, source, user);
  });
}
async function readValidReminders(uid, docs) {
  const candidates = docs.filter(doc => hasCurrentReminderShape(doc.id, doc.data()));
  const results = await boundedMap(candidates, doc => db.runTransaction(async transaction => {
    const current = await transaction.get(doc.ref);
    if (!current.exists) return 0;
    const data = current.data();
    if (data.userId !== uid || !isReminderType(data.type) || data.isRead !== false || !hasCurrentReminderShape(current.id, data)) return 0;
    const source = await transaction.get(db.collection(sourceCollection(data.type)).doc(data.refId));
    const profile = await transaction.get(db.collection('users').doc(uid));
    if (!isVisible(uid, current.id, data, source.exists ? source.data() : null, profile.exists ? profile.data() : null)) return 0;
    transaction.update(current.ref, { isRead: true });
    return 1;
  }));
  // Only count final committed attempts, not retries or already-read documents.
  return results.reduce((sum, count) => sum + count, 0);
}
module.exports = { visibleNotificationDocs, readValidReminders, isReminderType };
