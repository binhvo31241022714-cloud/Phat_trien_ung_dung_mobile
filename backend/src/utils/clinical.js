const LIMITS = { sessions: 20, prescriptions: 20, text: 2000 };
const fail = (message) => { const e = new Error(message); e.status = 400; throw e; };
const isPlainObject = (v) => v && typeof v === 'object' && !Array.isArray(v);
const optionalText = (v, label, max = 500) => { if (v === undefined || v === null || v === '') return ''; if (typeof v !== 'string') fail(`${label} phải là chuỗi`); if (v.trim().length > max) fail(`${label} tối đa ${max} ký tự`); return v.trim(); };
const requiredText = (v, label) => { const s = optionalText(v, label); if (!s) fail(`Thiếu ${label}`); return s; };
const optionalId = (v, label) => { if (v === undefined || v === null || v === '') return null; if (typeof v !== 'string' || !v.trim()) fail(`${label} không hợp lệ`); return v.trim(); };
function optionalDate(value, label) {
  if (value === undefined || value === null) return null;
  const invalid = () => fail(`${label} phải là YYYY-MM-DD hoặc ISO datetime có timezone hợp lệ`);
  if (typeof value !== 'string') invalid();
  const match = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?(Z|([+-])(\d{2})(?::(\d{2}))?))?$/.exec(value);
  if (!match) invalid();
  const [, y, m, d, h, min, sec, fraction, zone, sign, zoneHour, zoneMinute] = match;
  const year = Number(y), month = Number(m), day = Number(d);
  const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month < 1 || month > 12 || day < 1 || day > days[month - 1]) invalid();
  const hour = h === undefined ? 9 : Number(h);
  const minute = Number(min || 0), second = Number(sec || 0);
  if (hour > 23 || minute > 59 || second > 59) invalid();
  let offsetMinutes = 7 * 60;
  if (zone === 'Z') offsetMinutes = 0;
  else if (zone) {
    const zh = Number(zoneHour), zm = Number(zoneMinute || 0);
    if (zh > 23 || zm > 59) invalid();
    offsetMinutes = (sign === '+' ? 1 : -1) * (zh * 60 + zm);
  }
  // Build from validated components: never let Date guess a format or normalize an invalid day.
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(hour, minute, second, Number((fraction || '').padEnd(3, '0')));
  return new Date(date.getTime() - offsetMinutes * 60 * 1000);
}
const assertActivePatient = async (...args) => require('./records').assertActivePatient(...args);
function treatmentStatusFor(completed, total) { return completed >= total ? 'completed' : completed > 0 ? 'in_progress' : 'planned'; }
function parseCompletionBody(body = {}) {
  if (body.visit !== undefined && !isPlainObject(body.visit)) fail('visit phải là object');
  const visit = body.visit === undefined ? {} : body.visit;
  const prescriptions = body.prescriptions === undefined ? [] : body.prescriptions;
  if (!Array.isArray(prescriptions) || prescriptions.length > LIMITS.prescriptions) fail('Danh sách thuốc không hợp lệ');
  for (const item of prescriptions) {
    if (!isPlainObject(item)) fail('Thuốc phải là object');
    if (typeof item.medicineName !== 'string' || !item.medicineName.trim()) fail('Thiếu tên thuốc');
    for (const field of ['dosage', 'frequency', 'instructions']) {
      if (item[field] !== undefined && item[field] !== null && typeof item[field] !== 'string') fail(`${field} phải là chuỗi`);
    }
    if (item.durationDays !== undefined && item.durationDays !== null &&
        (!Number.isInteger(item.durationDays) || item.durationDays <= 0)) fail('durationDays phải là số nguyên dương hoặc null');
  }
  if (body.invoice !== undefined) {
    const invoice = body.invoice;
    if (!isPlainObject(invoice)) fail('invoice phải là object');
    if (invoice.items !== undefined) {
      if (!Array.isArray(invoice.items) || invoice.items.length === 0) fail('invoice.items phải là mảng không rỗng');
      for (const item of invoice.items) {
        if (!isPlainObject(item)) fail('Dòng hóa đơn phải là object');
        if (typeof item.name !== 'string' || !item.name.trim()) fail('Thiếu tên dòng hóa đơn');
        if (!Number.isInteger(item.quantity) || item.quantity <= 0) fail('quantity phải là số nguyên dương');
        if (!Number.isSafeInteger(item.unitPrice) || item.unitPrice < 0) fail('unitPrice phải là số nguyên an toàn không âm');
      }
    }
    if (invoice.discount !== undefined &&
        (!Number.isSafeInteger(invoice.discount) || invoice.discount < 0)) fail('discount phải là số nguyên an toàn không âm');
    if (invoice.paid !== undefined && typeof invoice.paid !== 'boolean') fail('paid phải là boolean');
    if (invoice.paymentMethod !== undefined &&
        !['cash', 'bank_transfer', 'card', 'e_wallet'].includes(invoice.paymentMethod)) fail('paymentMethod không hợp lệ');
    if (invoice.paid === true && invoice.paymentMethod === undefined) fail('paid=true bắt buộc có paymentMethod');
  }
  return { visit: { diagnosis: optionalText(visit.diagnosis, 'Chẩn đoán', 2000), result: optionalText(visit.result, 'Kết quả', 2000), notes: optionalText(visit.notes, 'Ghi chú', 2000) }, prescriptions, invoice: body.invoice };
}
async function readCompletion(transaction, appointmentId, appointment, input) {
  const db = require('../config/firebase').db;
  const ids = { visitId: `visit_${appointmentId}`, prescriptionId: `rx_${appointmentId}`, invoiceId: `inv_${appointmentId}` };
  const refs = {
    visit: db.collection('visits').doc(ids.visitId),
    prescription: db.collection('prescriptions').doc(ids.prescriptionId),
    invoice: db.collection('invoices').doc(ids.invoiceId),
  };
  // Read every deterministic ID before any write, including Rx when no drugs are prescribed.
  const snapshots = [];
  for (const ref of Object.values(refs)) snapshots.push(await transaction.get(ref));
  if (snapshots.some(snapshot => snapshot.exists)) {
    throw Object.assign(new Error('Chứng từ khám của lịch hẹn này đã tồn tại'), { status: 409 });
  }
  const invoice = input.invoice || {};
  const money = (value) => Number.isSafeInteger(value) && value >= 0;
  const checkedMoney = (value) => {
    if (!money(value)) fail('Phép tính hóa đơn vượt miền số nguyên an toàn hoặc có giá trị âm');
    return value;
  };
  let items, subtotal, defaultDiscount;
  if (invoice.items !== undefined) {
    items = invoice.items.map(item => ({
      name: item.name.trim(), quantity: item.quantity, unitPrice: item.unitPrice,
      amount: checkedMoney(item.quantity * item.unitPrice),
    }));
    subtotal = items.reduce((sum, item) => checkedMoney(sum + item.amount), 0);
    defaultDiscount = 0;
  } else {
    defaultDiscount = appointment.discount === undefined ? 0 : appointment.discount;
    if (!money(appointment.totalPrice) || !money(defaultDiscount)) {
      throw Object.assign(new Error('Lịch hẹn chưa có dữ liệu giá chốt hợp lệ'), { status: 409 });
    }
    subtotal = checkedMoney(appointment.totalPrice + defaultDiscount);
    // Appointments currently have no historical line-price snapshot. Never reconstruct it from today's catalog.
    items = [{ name: 'Chi phí theo giá chốt lịch hẹn (dòng tổng hợp)', quantity: 1, unitPrice: subtotal, amount: subtotal }];
  }
  const discountAmount = invoice.discount === undefined ? defaultDiscount : invoice.discount;
  if (discountAmount > subtotal) fail('Giảm giá không được vượt tạm tính');
  const totalAmount = checkedMoney(subtotal - discountAmount);
  return { ids, refs, invoice: { items, subtotal, discountAmount, totalAmount } };
}
function writeCompletion(transaction, { appointmentId, appointment, input, read, staffUid, now }) {
  const common = {
    appointmentId, accountId: appointment.accountId, patientId: appointment.patientId,
    doctorId: appointment.doctorId || null, doctorName: appointment.doctorName || '',
    createdBy: staffUid, createdAt: now,
  };
  transaction.set(read.refs.visit, {
    ...common, id: read.ids.visitId, status: 'completed',
    serviceIds: appointment.serviceIds || [], chiefComplaint: appointment.note || '',
    scheduledAt: new Date(`${appointment.date}T${appointment.startTime}:00+07:00`),
    diagnosis: input.visit.diagnosis, result: input.visit.result, doctorNote: input.visit.notes,
  });
  if (input.prescriptions.length > 0) {
    transaction.set(read.refs.prescription, {
      ...common, visitId: read.ids.visitId, issuedAt: now,
      items: input.prescriptions.map(item => ({
        medicineName: item.medicineName.trim(), dosage: (item.dosage || '').trim(),
        frequency: (item.frequency || '').trim(), durationDays: item.durationDays ?? null,
        instructions: (item.instructions || '').trim(),
      })),
    });
  }
  const invoice = input.invoice || {};
  transaction.set(read.refs.invoice, {
    ...common, visitId: read.ids.visitId, issuedAt: now, ...read.invoice,
    voucherCode: appointment.voucherCode || null,
    paymentStatus: invoice.paid === true ? 'paid' : 'unpaid',
    paymentMethod: invoice.paymentMethod ?? null, paidAt: invoice.paid === true ? now : null,
  });
  return { id: read.ids.visitId };
}
module.exports = { LIMITS, isPlainObject, optionalText, requiredText, optionalId, optionalDate, assertActivePatient, treatmentStatusFor, parseCompletionBody, readCompletion, writeCompletion };
