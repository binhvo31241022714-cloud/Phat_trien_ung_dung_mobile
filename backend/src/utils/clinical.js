// Module 3 - Hồ sơ khám: kiểm tra dữ liệu staff gửi lên và dựng document
// visit, đơn thuốc, hóa đơn. Tên trường giữ đúng dữ liệu đang có trên Firestore
// (visits.scheduledAt, visits.doctorNote, prescriptions.items[], invoices.*).
const { db, ApiError, makeVietnamDateTime, isValidDateKey } = require('./booking');

const LIMITS = {
  text: 2000,
  shortText: 200,
  medicines: 20,
  invoiceItems: 30,
  sessions: 30,
  maxPrice: 1_000_000_000,
};
const PAYMENT_METHODS = ['cash', 'bank_transfer', 'card', 'e_wallet'];

const bad = (message) => new ApiError(400, message);

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

// Chuỗi tùy chọn: undefined/null thành '', sai kiểu hoặc quá dài thì 400.
function optionalText(value, label, max = LIMITS.text) {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') throw bad(`${label} phải là chuỗi`);
  const text = value.trim();
  if (text.length > max) throw bad(`${label} tối đa ${max} ký tự`);
  return text;
}

function requiredText(value, label, max = LIMITS.shortText) {
  const text = optionalText(value, label, max);
  if (!text) throw bad(`Thiếu ${label}`);
  return text;
}

function integerIn(value, label, min, max) {
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    throw bad(`${label} phải là số nguyên từ ${min} đến ${max}`);
  }
  return value;
}

function optionalId(value, label) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !value.trim() || value.length > 200 || value.includes('/')) {
    throw bad(`${label} không hợp lệ`);
  }
  return value.trim();
}

// Ngày giờ dạng ISO 8601 ("2026-11-20T09:00:00+07:00") hoặc chỉ ngày "2026-11-20"
// (hiểu là 09:00 giờ Việt Nam).
function optionalDate(value, label) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') throw bad(`${label} phải là chuỗi ngày giờ`);
  const text = value.trim();
  const date = isValidDateKey(text)
    ? makeVietnamDateTime(text, '09:00')
    : /^\d{4}-\d{2}-\d{2}T/.test(text) ? new Date(text) : null;
  if (!date || Number.isNaN(date.getTime())) {
    throw bad(`${label} phải theo dạng YYYY-MM-DD hoặc YYYY-MM-DDTHH:mm:ss+07:00`);
  }
  return date;
}

// Body thêm khi PATCH /api/appointments/:id/status với status = "completed".
function parseCompletionBody(body) {
  const result = { visit: { diagnosis: '', result: '', notes: '' }, medicines: [], invoice: null };

  if (body.visit !== undefined && body.visit !== null) {
    if (!isPlainObject(body.visit)) throw bad('visit phải là object');
    result.visit = {
      diagnosis: optionalText(body.visit.diagnosis, 'Chẩn đoán'),
      result: optionalText(body.visit.result, 'Kết quả khám'),
      notes: optionalText(body.visit.notes, 'Ghi chú của bác sĩ'),
    };
  }

  if (body.prescriptions !== undefined && body.prescriptions !== null) {
    if (!Array.isArray(body.prescriptions)) throw bad('prescriptions phải là mảng');
    if (body.prescriptions.length > LIMITS.medicines) {
      throw bad(`Đơn thuốc tối đa ${LIMITS.medicines} loại thuốc`);
    }
    result.medicines = body.prescriptions.map((item, index) => {
      const label = `Thuốc thứ ${index + 1}`;
      if (!isPlainObject(item)) throw bad(`${label} phải là object`);
      return {
        medicineName: requiredText(item.medicineName, `tên thuốc (${label})`),
        dosage: optionalText(item.dosage, `Liều dùng (${label})`, LIMITS.shortText),
        frequency: optionalText(item.frequency, `Tần suất (${label})`, LIMITS.shortText),
        durationDays: item.durationDays === undefined || item.durationDays === null
          ? null
          : integerIn(item.durationDays, `Số ngày dùng (${label})`, 1, 365),
        instructions: optionalText(item.instructions, `Hướng dẫn (${label})`, 1000),
      };
    });
  }

  if (body.invoice !== undefined && body.invoice !== null) {
    if (!isPlainObject(body.invoice)) throw bad('invoice phải là object');
    const invoice = { items: null, discount: null, paymentMethod: null, paid: false };
    if (body.invoice.items !== undefined && body.invoice.items !== null) {
      if (!Array.isArray(body.invoice.items) || body.invoice.items.length === 0) {
        throw bad('invoice.items phải là mảng có ít nhất 1 dòng');
      }
      if (body.invoice.items.length > LIMITS.invoiceItems) {
        throw bad(`Hóa đơn tối đa ${LIMITS.invoiceItems} dòng`);
      }
      invoice.items = body.invoice.items.map((item, index) => {
        const label = `Dòng hóa đơn thứ ${index + 1}`;
        if (!isPlainObject(item)) throw bad(`${label} phải là object`);
        return invoiceLine(
          requiredText(item.name, `tên dịch vụ (${label})`),
          integerIn(item.quantity, `Số lượng (${label})`, 1, 1000),
          integerIn(item.unitPrice, `Đơn giá (${label})`, 0, LIMITS.maxPrice),
        );
      });
    }
    if (body.invoice.discount !== undefined && body.invoice.discount !== null) {
      invoice.discount = integerIn(body.invoice.discount, 'Giảm giá', 0, LIMITS.maxPrice);
    }
    if (body.invoice.paymentMethod !== undefined && body.invoice.paymentMethod !== null) {
      if (!PAYMENT_METHODS.includes(body.invoice.paymentMethod)) {
        throw bad(`paymentMethod phải là một trong: ${PAYMENT_METHODS.join(', ')}`);
      }
      invoice.paymentMethod = body.invoice.paymentMethod;
    }
    if (body.invoice.paid !== undefined && body.invoice.paid !== null) {
      if (typeof body.invoice.paid !== 'boolean') throw bad('invoice.paid phải là true hoặc false');
      invoice.paid = body.invoice.paid;
    }
    result.invoice = invoice;
  }
  return result;
}

function invoiceLine(name, quantity, unitPrice) {
  return { name, quantity, unitPrice, amount: quantity * unitPrice };
}

// Dòng hóa đơn tự lập từ lịch hẹn: combo 1 dòng, mỗi dịch vụ tính riêng 1 dòng.
// Tổng tiền luôn theo giá đã chốt lúc đặt (totalPrice + discount); nếu giá trong
// danh mục đã đổi thì gộp thành 1 dòng để hóa đơn không lệch với lịch.
async function autoInvoiceLines(transaction, appointment) {
  const bookedSubtotal = Number(appointment.totalPrice || 0) + Number(appointment.discount || 0);
  const lines = [];
  let comboServiceIds = [];
  if (appointment.comboId) {
    const comboSnap = await transaction.get(db.collection('combos').doc(appointment.comboId));
    if (comboSnap.exists) {
      const combo = comboSnap.data();
      comboServiceIds = Array.isArray(combo.serviceIds) ? combo.serviceIds : [];
      lines.push(invoiceLine(combo.name || 'Combo dịch vụ', 1, Number(combo.price) || 0));
    }
  }
  const serviceIds = Array.isArray(appointment.serviceIds) ? appointment.serviceIds : [];
  const separate = serviceIds.filter((id) => !comboServiceIds.includes(id));
  const names = [];
  for (const id of serviceIds) {
    const snap = await transaction.get(db.collection('services').doc(String(id)));
    if (!snap.exists) continue;
    const service = snap.data();
    names.push(service.name || String(id));
    if (separate.includes(id)) {
      lines.push(invoiceLine(service.name || String(id), 1, Number(service.price) || 0));
    }
  }
  const sum = lines.reduce((total, line) => total + line.amount, 0);
  if (lines.length > 0 && sum === bookedSubtotal) return { lines, subtotal: bookedSubtotal };
  const name = names.length > 0
    ? `Dịch vụ theo lịch hẹn: ${names.join(', ')}`.slice(0, LIMITS.shortText)
    : 'Dịch vụ theo lịch hẹn';
  return { lines: [invoiceLine(name, 1, bookedSubtotal)], subtotal: bookedSubtotal };
}

// Id cố định theo lịch hẹn: gọi hoàn tất lại không thể tạo bản ghi thứ hai.
const completionIds = (appointmentId) => ({
  visitId: `visit_${appointmentId}`,
  prescriptionId: `rx_${appointmentId}`,
  invoiceId: `inv_${appointmentId}`,
});

function appointmentStart(appointment) {
  if (!isValidDateKey(appointment.date) || !/^\d{2}:\d{2}$/.test(String(appointment.startTime || ''))) {
    return null;
  }
  const date = makeVietnamDateTime(appointment.date, appointment.startTime);
  return Number.isNaN(date.getTime()) ? null : date;
}

// Đọc mọi thứ cần cho hoàn tất (gọi trong transaction, trước mọi lệnh ghi).
async function readCompletion(transaction, appointmentId, appointment, input) {
  const ids = completionIds(appointmentId);
  const refs = {
    visit: db.collection('visits').doc(ids.visitId),
    prescription: db.collection('prescriptions').doc(ids.prescriptionId),
    invoice: db.collection('invoices').doc(ids.invoiceId),
  };
  for (const ref of Object.values(refs)) {
    if ((await transaction.get(ref)).exists) {
      throw new ApiError(409, 'Lịch hẹn này đã có hồ sơ khám');
    }
  }
  const auto = input.invoice?.items ? null : await autoInvoiceLines(transaction, appointment);
  return { ids, refs, auto };
}

// Ghi visit, đơn thuốc (nếu có), hóa đơn. Trả về visit đã tạo.
function writeCompletion(transaction, { appointmentId, appointment, input, read, staffUid, now }) {
  const { ids, refs, auto } = read;
  const base = {
    patientId: appointment.patientId,
    accountId: appointment.accountId,
    appointmentId,
    doctorId: appointment.doctorId || null,
  };
  const visit = {
    ...base,
    doctorName: appointment.doctorName || '',
    serviceIds: Array.isArray(appointment.serviceIds) ? appointment.serviceIds : [],
    comboId: appointment.comboId || null,
    scheduledAt: appointmentStart(appointment),
    status: 'completed',
    chiefComplaint: appointment.note || '',
    diagnosis: input.visit.diagnosis,
    result: input.visit.result,
    doctorNote: input.visit.notes,
    createdBy: staffUid,
    createdAt: now,
    updatedAt: now,
  };
  transaction.set(refs.visit, visit);

  if (input.medicines.length > 0) {
    transaction.set(refs.prescription, {
      ...base,
      visitId: ids.visitId,
      doctorName: appointment.doctorName || '',
      issuedAt: now,
      note: '',
      items: input.medicines,
      createdBy: staffUid,
    });
  }

  const lines = input.invoice?.items || auto.lines;
  const subtotal = input.invoice?.items
    ? lines.reduce((total, line) => total + line.amount, 0)
    : auto.subtotal;
  const requestedDiscount = input.invoice?.discount ?? Number(appointment.discount || 0);
  const discount = Math.min(Math.max(requestedDiscount, 0), subtotal);
  const paid = input.invoice?.paid === true;
  transaction.set(refs.invoice, {
    ...base,
    visitId: ids.visitId,
    items: lines,
    subtotal,
    discountAmount: discount,
    totalAmount: subtotal - discount,
    voucherCode: appointment.voucherCode || null,
    paymentStatus: paid ? 'paid' : 'unpaid',
    paymentMethod: input.invoice?.paymentMethod || (paid ? 'cash' : null),
    issuedAt: now,
    paidAt: paid ? now : null,
    createdBy: staffUid,
  });
  return { id: ids.visitId, ...visit, prescriptionId: input.medicines.length ? ids.prescriptionId : null, invoiceId: ids.invoiceId };
}

// Bệnh nhân thuộc tài khoản: chính chủ (users/{accountId} có thật) hoặc người
// thân còn hoạt động. Gọi trong transaction.
async function assertActivePatient(transaction, accountId, patientId) {
  const ref = patientId === accountId
    ? db.collection('users').doc(accountId)
    : db.collection('users').doc(accountId).collection('family_members').doc(patientId);
  const snap = await transaction.get(ref);
  if (!snap.exists) {
    throw bad(patientId === accountId
      ? 'Không tìm thấy tài khoản bệnh nhân'
      : 'Bệnh nhân không thuộc danh sách người thân của tài khoản này');
  }
  if (patientId !== accountId && snap.data().isArchived === true) {
    throw bad('Người thân này đã bị xóa khỏi danh sách');
  }
}

// Trạng thái liệu trình theo số buổi đã hoàn tất.
function treatmentStatusFor(completed, total) {
  if (total > 0 && completed >= total) return 'completed';
  return completed > 0 ? 'in_progress' : 'planned';
}

module.exports = {
  LIMITS,
  PAYMENT_METHODS,
  isPlainObject,
  optionalText,
  requiredText,
  integerIn,
  optionalId,
  optionalDate,
  parseCompletionBody,
  completionIds,
  readCompletion,
  writeCompletion,
  assertActivePatient,
  treatmentStatusFor,
};
