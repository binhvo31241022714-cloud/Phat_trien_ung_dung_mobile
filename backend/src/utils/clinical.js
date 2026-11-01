const LIMITS = { sessions: 20, prescriptions: 20, text: 2000 };
const fail = (message) => { const e = new Error(message); e.status = 400; throw e; };
const isPlainObject = (v) => v && typeof v === 'object' && !Array.isArray(v);
const optionalText = (v, label, max = 500) => { if (v === undefined || v === null || v === '') return ''; if (typeof v !== 'string') fail(`${label} phải là chuỗi`); if (v.trim().length > max) fail(`${label} tối đa ${max} ký tự`); return v.trim(); };
const requiredText = (v, label) => { const s = optionalText(v, label); if (!s) fail(`Thiếu ${label}`); return s; };
const optionalId = (v, label) => { if (v === undefined || v === null || v === '') return null; if (typeof v !== 'string' || !v.trim()) fail(`${label} không hợp lệ`); return v.trim(); };
const optionalDate = (v, label) => { if (!v) return null; const d = v instanceof Date ? v : new Date(v); if (Number.isNaN(d.getTime())) fail(`${label} không hợp lệ`); return d; };
const assertActivePatient = async (...args) => require('./records').assertActivePatient(...args);
function treatmentStatusFor(completed, total) { return completed >= total ? 'completed' : completed > 0 ? 'in_progress' : 'planned'; }
function parseCompletionBody(body = {}) {
  const visit = isPlainObject(body.visit) ? body.visit : {};
  const prescriptions = body.prescriptions || [];
  if (!Array.isArray(prescriptions) || prescriptions.length > LIMITS.prescriptions) fail('Danh sách thuốc không hợp lệ');
  return { visit: { diagnosis: optionalText(visit.diagnosis, 'Chẩn đoán', 2000), result: optionalText(visit.result, 'Kết quả', 2000), notes: optionalText(visit.notes, 'Ghi chú', 2000) }, prescriptions, invoice: body.invoice };
}
async function readCompletion(transaction, appointmentId, appointment, input) {
  return { ids: { visitId: `visit_${appointmentId}` } };
}
function writeCompletion(transaction, { appointmentId, appointment, input, now }) {
  const visitRef = require('../config/firebase').db.collection('visits').doc(`visit_${appointmentId}`);
  transaction.set(visitRef, { id: visitRef.id, appointmentId, accountId: appointment.accountId, patientId: appointment.patientId, doctorId: appointment.doctorId, status: 'completed', scheduledAt: new Date(`${appointment.date}T${appointment.startTime}:00+07:00`), diagnosis: input.visit.diagnosis, result: input.visit.result, doctorNote: input.visit.notes, createdAt: now });
  return { id: visitRef.id };
}
module.exports = { LIMITS, isPlainObject, optionalText, requiredText, optionalId, optionalDate, assertActivePatient, treatmentStatusFor, parseCompletionBody, readCompletion, writeCompletion };
