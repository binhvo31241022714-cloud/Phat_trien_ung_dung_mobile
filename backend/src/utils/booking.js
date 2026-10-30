const { db } = require('../config/firebase');

const TIME_ZONE = 'Asia/Ho_Chi_Minh';
const SLOT_LOCK_MINUTES = 15;
const INACTIVE_APPOINTMENT_STATUSES = new Set([
  'cancelled',
  'canceled',
  'rejected',
  'declined',
  'expired',
]);

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

function asyncHandler(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch((error) => {
      if (error instanceof ApiError || Number.isInteger(error.status)) {
        return res.status(error.status).json({ message: error.message });
      }
      console.error(error);
      return res.status(500).json({ message: 'Lỗi server' });
    });
  };
}

function uniqueStringIds(value) {
  if (value == null) return [];
  if (!Array.isArray(value)) throw new ApiError(400, 'serviceIds phải là một mảng');
  const ids = value
    .filter((id) => typeof id === 'string')
    .map((id) => id.trim())
    .filter(Boolean);
  if (ids.length !== value.length) {
    throw new ApiError(400, 'serviceIds chứa mã dịch vụ không hợp lệ');
  }
  return [...new Set(ids)];
}

function readPositiveNumber(value, field, { allowZero = false } = {}) {
  const number = Number(value);
  if (!Number.isFinite(number) || (allowZero ? number < 0 : number <= 0)) {
    throw new ApiError(500, `Dữ liệu Firestore thiếu hoặc sai trường ${field}`);
  }
  return Math.round(number);
}

function getFieldNumber(data, field, label, { allowZero = false } = {}) {
  if (data[field] === undefined || data[field] === null || data[field] === '') {
    throw new ApiError(500, `${label} trên Firestore đang thiếu trường ${field}`);
  }
  return readPositiveNumber(data[field], field, { allowZero });
}

function getVietnamDateParts(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const result = {};
  for (const part of parts) {
    if (part.type !== 'literal') result[part.type] = part.value;
  }
  return result;
}

function toVietnamDateKey(value) {
  const p = getVietnamDateParts(value);
  return p ? `${p.year}-${p.month}-${p.day}` : null;
}

function toVietnamMinutes(value) {
  const p = getVietnamDateParts(value);
  return p ? Number(p.hour) * 60 + Number(p.minute) : null;
}

function parseFirestoreDate(value) {
  if (value == null) return null;
  let date;
  if (typeof value.toDate === 'function') date = value.toDate();
  else if (value instanceof Date) date = value;
  else if (typeof value === 'string' || typeof value === 'number') date = new Date(value);
  else return null;
  return Number.isNaN(date.getTime()) ? null : date;
}

function isValidDateKey(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  return parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day;
}

function parseTime(value, field = 'startTime') {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
    throw new ApiError(400, `${field} phải theo định dạng HH:mm`);
  }
  const [hour, minute] = value.split(':').map(Number);
  return hour * 60 + minute;
}

function toTimeString(minutes) {
  if (!Number.isInteger(minutes) || minutes < 0 || minutes >= 24 * 60) {
    throw new ApiError(400, 'Thời gian đặt lịch không hợp lệ');
  }
  const hour = Math.floor(minutes / 60);
  const minute = minutes % 60;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function makeVietnamDateTime(dateKey, time) {
  return new Date(`${dateKey}T${time}:00+07:00`);
}

function isFutureAppointment(dateKey, startTime) {
  return makeVietnamDateTime(dateKey, startTime).getTime() > Date.now();
}

function scheduleInterval(scheduleData, dateKey) {
  const startAt = parseFirestoreDate(scheduleData.startAt);
  const endAt = parseFirestoreDate(scheduleData.endAt);
  if (!startAt || !endAt) return null;
  if (toVietnamDateKey(startAt) !== dateKey || toVietnamDateKey(endAt) !== dateKey) return null;

  const startMinute = toVietnamMinutes(startAt);
  const endMinute = toVietnamMinutes(endAt);
  if (startMinute === null || endMinute === null || endMinute <= startMinute) return null;

  const rawSlotMinutes = Number(scheduleData.slotMinutes);
  const slotMinutes = Number.isInteger(rawSlotMinutes) && rawSlotMinutes > 0
    ? rawSlotMinutes
    : 30;
  return { startMinute, endMinute, slotMinutes };
}

function scheduleCanCover(scheduleData, dateKey, startMinute, durationMinutes) {
  if (scheduleData.isAvailable === false) return false;
  const interval = scheduleInterval(scheduleData, dateKey);
  if (!interval) return false;
  const endMinute = startMinute + durationMinutes;
  return startMinute >= interval.startMinute &&
    endMinute <= interval.endMinute &&
    endMinute <= 24 * 60 &&
    (startMinute - interval.startMinute) % interval.slotMinutes === 0;
}

function isAppointmentActive(data) {
  return !INACTIVE_APPOINTMENT_STATUSES.has(String(data.status || '').toLowerCase());
}

function intervalsOverlap(startA, endA, startB, endB) {
  return startA < endB && startB < endA;
}

function getSlotBucketStarts(startMinute, endMinute) {
  const result = [];
  let cursor = Math.floor(startMinute / SLOT_LOCK_MINUTES) * SLOT_LOCK_MINUTES;
  while (cursor < endMinute) {
    result.push(cursor);
    cursor += SLOT_LOCK_MINUTES;
  }
  return result;
}

function makeSlotLockId(doctorId, dateKey, bucketMinute) {
  const { createHash } = require('crypto');
  const hash = createHash('sha256')
    .update(`${doctorId}|${dateKey}|${bucketMinute}`)
    .digest('hex');
  return `slot_${hash}`;
}

function getSlotLockRefs(doctorId, dateKey, startMinute, endMinute) {
  return getSlotBucketStarts(startMinute, endMinute).map((bucketMinute) => ({
    bucketMinute,
    ref: db.collection('appointment_slots').doc(
      makeSlotLockId(doctorId, dateKey, bucketMinute),
    ),
  }));
}

async function readDoc(ref, transaction) {
  return transaction ? transaction.get(ref) : ref.get();
}

async function buildBookingQuote(input, transaction = null) {
  const requestedServiceIds = uniqueStringIds(input.serviceIds || []);
  const comboId = typeof input.comboId === 'string' && input.comboId.trim()
    ? input.comboId.trim()
    : null;
  if (requestedServiceIds.length === 0 && !comboId) {
    throw new ApiError(400, 'Chọn ít nhất một dịch vụ hoặc một combo');
  }

  let combo = null;
  let comboServiceIds = [];
  if (comboId) {
    const comboSnap = await readDoc(db.collection('combos').doc(comboId), transaction);
    if (!comboSnap.exists) throw new ApiError(404, 'Không tìm thấy combo');
    combo = { id: comboSnap.id, ...comboSnap.data() };
    if (combo.isActive === false) throw new ApiError(400, 'Combo này đã ngừng hoạt động');
    if (!Array.isArray(combo.serviceIds) || combo.serviceIds.length === 0) {
      throw new ApiError(500, `Combo ${comboId} trên Firestore thiếu danh sách serviceIds`);
    }
    comboServiceIds = uniqueStringIds(combo.serviceIds);
  }

  const allServiceIds = [...new Set([...comboServiceIds, ...requestedServiceIds])];
  const serviceDocs = new Map();
  for (const serviceId of allServiceIds) {
    const snap = await readDoc(db.collection('services').doc(serviceId), transaction);
    if (!snap.exists) throw new ApiError(404, `Không tìm thấy dịch vụ ${serviceId}`);
    const data = snap.data();
    if (data.isActive === false) throw new ApiError(400, `Dịch vụ ${serviceId} đã ngừng hoạt động`);
    getFieldNumber(data, 'price', `Dịch vụ ${serviceId}`, { allowZero: true });
    getFieldNumber(data, 'durationMinutes', `Dịch vụ ${serviceId}`);
    serviceDocs.set(serviceId, { id: snap.id, ...data });
  }

  let subtotal = 0;
  let durationMinutes = 0;
  if (combo) {
    subtotal += getFieldNumber(combo, 'price', `Combo ${comboId}`, { allowZero: true });
    durationMinutes += getFieldNumber(combo, 'durationMinutes', `Combo ${comboId}`);
  }

  // Khi gửi combo kèm danh sách dịch vụ của combo, không tính giá/thời gian hai lần.
  const included = new Set(comboServiceIds);
  const separatelyChargedServiceIds = combo
    ? requestedServiceIds.filter((id) => !included.has(id))
    : requestedServiceIds;
  for (const serviceId of separatelyChargedServiceIds) {
    const service = serviceDocs.get(serviceId);
    subtotal += getFieldNumber(service, 'price', `Dịch vụ ${serviceId}`, { allowZero: true });
    durationMinutes += getFieldNumber(service, 'durationMinutes', `Dịch vụ ${serviceId}`);
  }

  if (!Number.isSafeInteger(subtotal) || subtotal < 0) {
    throw new ApiError(500, 'Tổng giá trị dịch vụ trên Firestore không hợp lệ');
  }
  if (!Number.isSafeInteger(durationMinutes) || durationMinutes <= 0) {
    throw new ApiError(500, 'Tổng thời lượng dịch vụ trên Firestore không hợp lệ');
  }

  return {
    serviceIds: allServiceIds,
    comboId,
    subtotal,
    durationMinutes,
    comboServiceIds,
  };
}

async function findVoucherRef(code) {
  const normalized = String(code || '').trim().toUpperCase();
  if (!normalized) return null;

  const directRef = db.collection('vouchers').doc(normalized);
  const directSnap = await directRef.get();
  if (directSnap.exists) {
    const storedCode = String(directSnap.data().code || directSnap.id).trim().toUpperCase();
    if (storedCode === normalized) return directRef;
  }

  const snap = await db.collection('vouchers').get();
  const match = snap.docs.find((doc) =>
    String(doc.data().code || doc.id).trim().toUpperCase() === normalized,
  );
  return match ? match.ref : null;
}

function validateVoucherSnapshot(snapshot, subtotal, now = new Date()) {
  if (!snapshot || !snapshot.exists) throw new ApiError(400, 'Mã giảm giá không tồn tại');
  const data = snapshot.data();
  const code = String(data.code || snapshot.id).trim().toUpperCase();

  if (data.isActive === false) throw new ApiError(400, 'Mã giảm giá đã bị tắt');

  const startsAt = parseFirestoreDate(data.startsAt);
  const endsAt = parseFirestoreDate(data.endsAt);
  if (!startsAt || !endsAt) {
    throw new ApiError(500, `Voucher ${code} trên Firestore thiếu startsAt hoặc endsAt`);
  }
  if (now.getTime() < startsAt.getTime()) throw new ApiError(400, 'Mã giảm giá chưa đến thời gian sử dụng');
  if (now.getTime() > endsAt.getTime()) throw new ApiError(400, 'Mã giảm giá đã hết hạn');

  const usageLimit = getFieldNumber(data, 'usageLimit', `Voucher ${code}`);
  const usedCount = data.usedCount === undefined ? 0 : Number(data.usedCount);
  if (!Number.isFinite(usedCount) || usedCount < 0) {
    throw new ApiError(500, `Voucher ${code} có usedCount không hợp lệ trên Firestore`);
  }
  if (usedCount >= usageLimit) throw new ApiError(400, 'Mã giảm giá đã hết lượt sử dụng');

  const minOrderAmount = data.minOrderAmount === undefined || data.minOrderAmount === null
    ? 0
    : Number(data.minOrderAmount);
  if (!Number.isFinite(minOrderAmount) || minOrderAmount < 0) {
    throw new ApiError(500, `Voucher ${code} có minOrderAmount không hợp lệ trên Firestore`);
  }
  if (subtotal < minOrderAmount) {
    throw new ApiError(400, `Đơn hàng cần tối thiểu ${minOrderAmount.toLocaleString('vi-VN')}đ để dùng mã này`);
  }

  const discountType = String(data.discountType || '').trim().toLowerCase();
  const discountValue = getFieldNumber(data, 'discountValue', `Voucher ${code}`, { allowZero: true });
  let discount;
  if (discountType === 'percent' || discountType === 'percentage') {
    if (discountValue > 100) throw new ApiError(500, `Voucher ${code} có discountValue vượt quá 100%`);
    discount = Math.floor((subtotal * discountValue) / 100);
  } else if (discountType === 'fixed' || discountType === 'amount') {
    discount = discountValue;
  } else {
    throw new ApiError(500, `Voucher ${code} có discountType không được hỗ trợ`);
  }
  discount = Math.min(subtotal, discount);

  return {
    code,
    discountType,
    discountValue,
    discount,
    totalPrice: Math.max(0, subtotal - discount),
    usageLimit,
    usedCount,
  };
}

async function buildQuoteWithVoucher(input, transaction = null, knownVoucherRef = undefined) {
  const quote = await buildBookingQuote(input, transaction);
  const code = String(input.voucherCode || input.code || '').trim();
  if (!code) {
    return { ...quote, discount: 0, totalPrice: quote.subtotal, voucherCode: null };
  }

  const voucherRef = knownVoucherRef === undefined ? await findVoucherRef(code) : knownVoucherRef;
  if (!voucherRef) throw new ApiError(400, 'Mã giảm giá không tồn tại');
  const voucherSnap = await readDoc(voucherRef, transaction);
  const voucher = validateVoucherSnapshot(voucherSnap, quote.subtotal);
  return {
    ...quote,
    discount: voucher.discount,
    totalPrice: voucher.totalPrice,
    voucherCode: voucher.code,
    voucherRef,
    voucherUsedCount: voucher.usedCount,
  };
}

// Chỉ đọc lịch làm việc, lịch hẹn, slot của đúng ngày dateKey (giờ Việt Nam).
// Ca lỗi định dạng bị bỏ qua kèm cảnh báo, không làm hỏng cả ngày.
async function loadSchedulingData(dateKey) {
  if (!isValidDateKey(dateKey)) throw new ApiError(400, 'date phải theo định dạng YYYY-MM-DD');
  const dayStart = makeVietnamDateTime(dateKey, '00:00');
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
  const [scheduleSnap, doctorSnap, appointmentSnap, lockSnap] = await Promise.all([
    db.collection('doctor_schedules')
      .where('startAt', '>=', dayStart)
      .where('startAt', '<', dayEnd)
      .get(),
    db.collection('doctors').get(),
    db.collection('appointments').where('date', '==', dateKey).get(),
    db.collection('appointment_slots').where('date', '==', dateKey).get(),
  ]);
  const schedules = [];
  for (const doc of scheduleSnap.docs) {
    const schedule = { id: doc.id, ref: doc.ref, ...doc.data() };
    const missing = [];
    if (!schedule.doctorId) missing.push('doctorId');
    if (!parseFirestoreDate(schedule.startAt)) missing.push('startAt');
    if (!parseFirestoreDate(schedule.endAt)) missing.push('endAt');
    if (!Number.isInteger(Number(schedule.slotMinutes)) || Number(schedule.slotMinutes) <= 0) {
      missing.push('slotMinutes');
    }
    if (typeof schedule.isAvailable !== 'boolean') missing.push('isAvailable');
    if (missing.length > 0) {
      console.warn(`Bỏ qua doctor_schedules/${schedule.id}: thiếu/sai trường ${missing.join(', ')}`);
      continue;
    }
    schedules.push(schedule);
  }

  return {
    schedules,
    doctors: doctorSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    appointments: appointmentSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    locks: lockSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
  };
}

function doctorProvidesServices(doctor, requiredServiceIds) {
  if (doctor.isActive === false) return false;
  if (!Array.isArray(doctor.serviceIds)) {
    if (requiredServiceIds.length > 0) {
      throw new ApiError(500, `Bác sĩ ${doctor.id} trên Firestore thiếu trường serviceIds`);
    }
    return true;
  }
  return requiredServiceIds.every((id) => doctor.serviceIds.includes(id));
}

function appointmentConflicts(appointments, doctorId, dateKey, startMinute, endMinute) {
  return appointments.some((appointment) => {
    if (appointment.doctorId !== doctorId || appointment.date !== dateKey || !isAppointmentActive(appointment)) {
      return false;
    }
    try {
      const bookedStart = parseTime(appointment.startTime, 'startTime');
      const bookedEnd = parseTime(appointment.endTime, 'endTime');
      return intervalsOverlap(startMinute, endMinute, bookedStart, bookedEnd);
    } catch (_) {
      // Bản ghi cũ thiếu giờ không thể dùng để đối chiếu khung cụ thể.
      return false;
    }
  });
}

function slotConflicts(locks, doctorId, dateKey, startMinute, endMinute) {
  const wantedBuckets = new Set(getSlotBucketStarts(startMinute, endMinute));
  return locks.some((lock) =>
    lock.doctorId === doctorId &&
    lock.date === dateKey &&
    wantedBuckets.has(Number(lock.bucketMinute)),
  );
}

function getCandidateSchedules(schedules, doctorId, dateKey, startMinute, durationMinutes) {
  return schedules.filter((schedule) =>
    schedule.doctorId === doctorId &&
    scheduleCanCover(schedule, dateKey, startMinute, durationMinutes),
  );
}

function shuffle(items) {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

module.exports = {
  ApiError,
  asyncHandler,
  db,
  buildBookingQuote,
  buildQuoteWithVoucher,
  findVoucherRef,
  validateVoucherSnapshot,
  loadSchedulingData,
  doctorProvidesServices,
  appointmentConflicts,
  slotConflicts,
  getCandidateSchedules,
  getSlotLockRefs,
  parseFirestoreDate,
  isValidDateKey,
  parseTime,
  toTimeString,
  toVietnamDateKey,
  toVietnamMinutes,
  scheduleInterval,
  scheduleCanCover,
  isFutureAppointment,
  isAppointmentActive,
  getSlotBucketStarts,
  shuffle,
};
