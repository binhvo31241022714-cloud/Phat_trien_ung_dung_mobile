// Kiểm thử đầu cuối CHẠY THẬT qua API localhost và Firestore thật (yoursmile-49379).
// Cần: backend đang chạy (npm start), backend/.env có TEST_PASSWORD, STAFF_PASSWORD.
// Chạy: cd backend && node scripts/e2e-smoke.js
//
// Luồng: đặt lịch -> staff xác nhận -> nhắc lịch -> hoàn tất kèm kết quả khám -> bệnh nhân đọc
// visit, đơn thuốc, hóa đơn -> liệu trình, buổi 1 -> đề xuất tái khám -> nhắc tái khám ->
// đặt lịch từ tái khám -> hủy -> tải ảnh trước/sau -> xóa ảnh.
// Cuối script luôn dọn dữ liệu, CHỈ xóa đúng các id do script tạo (kiểm tra chủ sở hữu là test123).
// Không dùng voucher, không gửi Idempotency-Key. Không in mật khẩu, token.
const { readEnvFile } = require('./_env');
const { vietnamDateKey } = require('./seed-schedules');

const BASE = 'http://localhost:3000';
// Khóa web công khai của Firebase (giống backend/api-test.http), không phải khóa quản trị.
const API_KEY = 'AIzaSyDtSTRsa8uvBs4UcT6xaeiNA-AByjCJ9ps';
const PATIENT_EMAIL = 'test123@gmail.com';
const STAFF_EMAIL = 'staff@nhakhoa.com';
const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
const DAY_MS = 24 * 60 * 60 * 1000;

// Id do script tạo, dùng cho bước dọn dẹp.
const created = {
  appointments: new Set(), visits: new Set(), prescriptions: new Set(), invoices: new Set(),
  treatments: new Set(), follow_ups: new Set(), treatment_photos: new Set(), media: new Set(),
};
const results = [];
const ctx = {};

class Skip { constructor(reason) { this.reason = reason; } }

function addDays(dateKey, offset) {
  const [year, month, day] = dateKey.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + offset)).toISOString().slice(0, 10);
}

async function signIn(email, password) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`Đăng nhập ${email} thất bại: ${body.error?.message || response.status}`);
  return { token: body.idToken, uid: body.localId };
}

async function api(token, method, path, body, expected = [200, 201]) {
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let data = text;
  try { data = JSON.parse(text); } catch { /* giữ dạng chuỗi */ }
  if (!expected.includes(response.status)) {
    throw new Error(`${method} ${path} trả ${response.status}: ${data?.message || text.slice(0, 120)}`);
  }
  return data;
}

function check(condition, message) {
  if (!condition) throw new Error(message);
}

async function step(name, fn) {
  try {
    const note = await fn();
    results.push({ status: 'PASS', name, note: note || '' });
  } catch (error) {
    if (error instanceof Skip) {
      results.push({ status: 'BỎ QUA', name, note: error.reason });
      return;
    }
    results.push({ status: 'FAIL', name, note: error.message });
    throw error;
  }
}

async function notifications() {
  return api(ctx.patient.token, 'GET', '/api/notifications');
}

// Tìm giờ trống: within24h = true thì chỉ nhận giờ bắt đầu sau ít nhất 15 phút và trong 24 giờ tới.
async function findSlot(serviceId, fromDateKey, { within24h = false, minLeadMs = 3 * 60 * 60 * 1000 } = {}) {
  const now = Date.now();
  for (let offset = 0; offset <= 7; offset++) {
    const date = addDays(fromDateKey, offset);
    const data = await api(null, 'GET', `/api/availability?date=${date}&serviceIds=${serviceId}`);
    for (const slot of data.slots || []) {
      const at = new Date(`${date}T${slot.startTime}:00+07:00`).getTime();
      if (at - now < minLeadMs) continue;
      if (within24h && at - now > DAY_MS) return null;
      return slot;
    }
    if (within24h && new Date(`${date}T00:00:00+07:00`).getTime() - now > DAY_MS) return null;
  }
  return null;
}

async function run() {
  const env = readEnvFile('.env');
  check(env && env.TEST_PASSWORD && env.STAFF_PASSWORD, 'backend/.env thiếu TEST_PASSWORD hoặc STAFF_PASSWORD');

  await step('0. Backend đang chạy tại localhost:3000', async () => {
    try { await api(null, 'GET', '/'); } catch (error) {
      throw new Error(`Không gọi được ${BASE} (bật backend trước: npm start). ${error.message}`);
    }
  });

  await step('1. Đăng nhập test123 và staff', async () => {
    ctx.patient = await signIn(PATIENT_EMAIL, env.TEST_PASSWORD);
    ctx.staff = await signIn(STAFF_EMAIL, env.STAFF_PASSWORD);
  });

  await step('2. Bệnh nhân đặt lịch', async () => {
    const services = await api(null, 'GET', '/api/services');
    check(Array.isArray(services) && services.length, 'Không có dịch vụ nào');
    ctx.serviceId = services[0].id;
    const today = vietnamDateKey(new Date());
    // Ưu tiên giờ trong 24 giờ tới để kiểm tra được appointment_reminder.
    let slot = await findSlot(ctx.serviceId, today, { within24h: true, minLeadMs: 15 * 60 * 1000 });
    ctx.reminderPossible = Boolean(slot);
    if (!slot) slot = await findSlot(ctx.serviceId, today);
    check(slot, `Không còn giờ trống cho ${ctx.serviceId} trong 7 ngày tới`);
    const appointment = await api(ctx.patient.token, 'POST', '/api/appointments', {
      patientId: ctx.patient.uid, serviceIds: [ctx.serviceId], date: slot.date, startTime: slot.startTime,
      note: 'E2E smoke test, sẽ tự xóa',
    });
    created.appointments.add(appointment.id);
    ctx.appointment = appointment;
    check(appointment.status === 'booked', `status ${appointment.status}`);
    return `${appointment.id} ngày ${slot.date} ${slot.startTime}, bác sĩ ${appointment.doctorId}`;
  });

  await step('3. Staff xác nhận lịch', async () => {
    const result = await api(ctx.staff.token, 'PATCH', `/api/appointments/${ctx.appointment.id}/status`, { status: 'confirmed' });
    check(result.status === 'confirmed', `status ${result.status}`);
    const list = await notifications();
    check(list.some((n) => n.type === 'appointment_confirmed' && n.refId === ctx.appointment.id), 'Không có thông báo appointment_confirmed');
  });

  await step('4. Chạy nhắc lịch (appointment_reminder nếu lịch trong 24 giờ)', async () => {
    const result = await api(ctx.staff.token, 'POST', '/api/notifications/run-reminders');
    if (!ctx.reminderPossible) throw new Skip(`Không có giờ trống trong 24 giờ tới; run-reminders trả ${JSON.stringify(result)}`);
    const list = await notifications();
    check(list.some((n) => n.type === 'appointment_reminder' && n.refId === ctx.appointment.id), 'Không thấy appointment_reminder cho lịch vừa xác nhận');
    return `run-reminders: ${JSON.stringify(result)}`;
  });

  await step('5. Staff hoàn tất kèm kết quả khám, 2 thuốc', async () => {
    const result = await api(ctx.staff.token, 'PATCH', `/api/appointments/${ctx.appointment.id}/status`, {
      status: 'completed',
      visit: { diagnosis: 'E2E: viêm nướu nhẹ', result: 'E2E: đã lấy cao răng', notes: 'E2E ghi chú' },
      prescriptions: [
        { medicineName: 'E2E Chlorhexidine 0,12%', dosage: '15 ml/lần', frequency: '2 lần/ngày', durationDays: 7, instructions: 'Súc 30 giây' },
        { medicineName: 'E2E Paracetamol 500mg', dosage: '1 viên', frequency: 'Khi đau', durationDays: 3, instructions: 'Uống sau ăn' },
      ],
    });
    check(result.status === 'completed' && result.visitId, 'Không có visitId sau khi hoàn tất');
    ctx.visitId = result.visitId;
    created.visits.add(result.visitId);
    created.prescriptions.add(`rx_${ctx.appointment.id}`);
    created.invoices.add(`inv_${ctx.appointment.id}`);
    return `visit ${result.visitId}`;
  });

  await step('6. Bệnh nhân đọc visit, đơn thuốc, hóa đơn', async () => {
    const visit = await api(ctx.patient.token, 'GET', `/api/visits/${ctx.visitId}`);
    check(visit.status === 'completed', `visit status ${visit.status}`);
    const prescriptions = await api(ctx.patient.token, 'GET', `/api/visits/${ctx.visitId}/prescriptions`);
    const prescriptionList = Array.isArray(prescriptions) ? prescriptions : [prescriptions];
    prescriptionList.forEach((p) => p && p.id && created.prescriptions.add(p.id));
    check(JSON.stringify(prescriptions).includes('E2E Paracetamol'), 'Đơn thuốc không có thuốc vừa kê');
    const invoices = await api(ctx.patient.token, 'GET', `/api/patients/${ctx.patient.uid}/invoices`);
    const invoice = invoices.find((i) => i.appointmentId === ctx.appointment.id || i.visitId === ctx.visitId);
    check(invoice, 'Không thấy hóa đơn của lịch');
    created.invoices.add(invoice.id);
    await api(ctx.patient.token, 'GET', `/api/invoices/${invoice.id}`);
    const list = await notifications();
    check(list.some((n) => n.type === 'visit_result' && n.refId === ctx.visitId), 'Không có thông báo visit_result');
    return `hóa đơn ${invoice.id}`;
  });

  await step('7. Staff tạo liệu trình 3 buổi, đánh dấu buổi 1', async () => {
    const today = vietnamDateKey(new Date());
    const treatment = await api(ctx.staff.token, 'POST', '/api/treatments', {
      accountId: ctx.patient.uid, patientId: ctx.patient.uid, doctorId: ctx.appointment.doctorId,
      name: 'E2E liệu trình', diagnosis: 'E2E',
      sessions: [0, 7, 14].map((d) => ({ scheduledAt: `${addDays(today, d)}T09:00:00+07:00`, notes: `E2E buổi +${d}` })),
    });
    created.treatments.add(treatment.id);
    ctx.treatment = treatment;
    check(Array.isArray(treatment.sessions) && treatment.sessions.length === 3, 'Liệu trình không có 3 buổi');
    await api(ctx.staff.token, 'PATCH', `/api/treatments/${treatment.id}/sessions/${treatment.sessions[0].id}`, {
      status: 'completed', visitId: ctx.visitId, notes: 'E2E buổi 1',
    });
    const detail = await api(ctx.patient.token, 'GET', `/api/treatments/${treatment.id}`);
    check(detail.status === 'in_progress', `Liệu trình status ${detail.status}, mong đợi in_progress`);
    return treatment.id;
  });

  await step('8. Staff đề xuất tái khám 2 ngày sau', async () => {
    ctx.followUpDate = addDays(vietnamDateKey(new Date()), 2);
    const followUp = await api(ctx.staff.token, 'POST', '/api/follow-ups', {
      accountId: ctx.patient.uid, patientId: ctx.patient.uid, doctorId: ctx.appointment.doctorId,
      scheduledAt: ctx.followUpDate, reason: 'E2E kiểm tra nướu', visitId: ctx.visitId,
      treatmentId: ctx.treatment.id, serviceId: ctx.serviceId,
    });
    created.follow_ups.add(followUp.id);
    ctx.followUp = followUp;
    check(followUp.status === 'suggested', `status ${followUp.status}`);
    const list = await notifications();
    check(list.some((n) => n.type === 'follow_up' && n.refId === followUp.id), 'Không có thông báo follow_up');
    return `${followUp.id} ngày ${ctx.followUpDate}`;
  });

  await step('9. Chạy nhắc tái khám (follow_up_reminder)', async () => {
    const result = await api(ctx.staff.token, 'POST', '/api/notifications/run-reminders');
    const list = await notifications();
    check(list.some((n) => n.type === 'follow_up_reminder' && n.refId === ctx.followUp.id), 'Không thấy follow_up_reminder');
    return `run-reminders: ${JSON.stringify(result)}`;
  });

  await step('10. Bệnh nhân đặt lịch từ đề xuất tái khám', async () => {
    const slot = await findSlot(ctx.serviceId, ctx.followUpDate);
    check(slot, 'Không còn giờ trống quanh ngày tái khám');
    const appointment = await api(ctx.patient.token, 'POST', '/api/appointments', {
      patientId: ctx.patient.uid, serviceIds: [ctx.serviceId], date: slot.date, startTime: slot.startTime,
      followUpId: ctx.followUp.id, note: 'E2E đặt từ tái khám',
    });
    created.appointments.add(appointment.id);
    ctx.followUpAppointment = appointment;
    check(appointment.followUpId === ctx.followUp.id, 'Lịch không lưu followUpId');
    const followUp = await api(ctx.patient.token, 'GET', `/api/follow-ups/${ctx.followUp.id}`);
    check(followUp.status === 'booked', `Đề xuất status ${followUp.status}, mong đợi booked`);
    return `${appointment.id} ngày ${slot.date} ${slot.startTime}`;
  });

  await step('11. Bệnh nhân hủy lịch tái khám', async () => {
    await api(ctx.patient.token, 'PATCH', `/api/appointments/${ctx.followUpAppointment.id}/cancel`);
    const appointment = await api(ctx.patient.token, 'GET', `/api/appointments/${ctx.followUpAppointment.id}`);
    check(appointment.status === 'cancelled', `status ${appointment.status}`);
    const followUp = await api(ctx.patient.token, 'GET', `/api/follow-ups/${ctx.followUp.id}`);
    check(followUp.status === 'suggested', `Đề xuất status ${followUp.status}, mong đợi suggested`);
  });

  await step('12. Bệnh nhân tải ảnh trước và sau', async () => {
    for (const phase of ['before', 'after']) {
      const photo = await api(ctx.patient.token, 'POST', `/api/treatments/${ctx.treatment.id}/photos`, {
        phase, image: PNG, mimeType: 'image/png', note: `E2E ${phase}`,
      });
      created.treatment_photos.add(photo.id);
      if (photo.mediaId) created.media.add(photo.mediaId);
      await api(ctx.patient.token, 'GET', photo.imageUrl);
    }
    const photos = await api(ctx.patient.token, 'GET', `/api/treatments/${ctx.treatment.id}/photos`);
    const mine = photos.filter((p) => created.treatment_photos.has(p.id));
    check(mine.length === 2, `Thấy ${mine.length}/2 ảnh vừa tải`);
  });

  await step('13. Bệnh nhân xóa ảnh', async () => {
    for (const id of created.treatment_photos) {
      await api(ctx.patient.token, 'DELETE', `/api/treatments/${ctx.treatment.id}/photos/${id}`);
    }
    const photos = await api(ctx.patient.token, 'GET', `/api/treatments/${ctx.treatment.id}/photos`);
    check(!photos.some((p) => created.treatment_photos.has(p.id)), 'Ảnh vẫn còn sau khi xóa');
  });
}

// Dọn dữ liệu bằng Firebase Admin. Chỉ xóa document do script tạo và thuộc test123.
async function cleanup() {
  const uid = ctx.patient && ctx.patient.uid;
  if (!uid) return { note: 'Chưa đăng nhập được, không có gì để dọn' };
  const { db } = require('../src/config/firebase');
  const counts = {};
  const skipped = [];
  const owned = (data) => {
    const owner = data.accountId ?? data.userId ?? data.ownerAccountId;
    return owner === undefined || owner === uid;
  };
  async function remove(collection, ids) {
    for (const id of ids) {
      const ref = db.collection(collection).doc(id);
      const snap = await ref.get();
      if (!snap.exists) continue;
      if (!owned(snap.data())) { skipped.push(`${collection}/${id}`); continue; }
      await ref.delete();
      counts[collection] = (counts[collection] || 0) + 1;
    }
  }
  async function removeWhere(collection, field, value, extra = () => true) {
    const snap = await db.collection(collection).where(field, '==', value).get();
    const ids = snap.docs.filter((doc) => extra({ id: doc.id, ...doc.data() })).map((doc) => doc.id);
    await remove(collection, ids);
  }

  const refIds = new Set([...created.appointments, ...created.visits, ...created.follow_ups, ...created.treatments]);
  await removeWhere('notifications', 'userId', uid, (n) => refIds.has(n.refId));
  for (const appointmentId of created.appointments) {
    await removeWhere('appointment_slots', 'appointmentId', appointmentId);
  }
  for (const treatmentId of created.treatments) {
    await removeWhere('treatment_sessions', 'treatmentId', treatmentId);
    await removeWhere('treatment_photos', 'treatmentId', treatmentId, (p) => created.treatment_photos.has(p.id) || (p.note || '').startsWith('E2E'));
  }
  await remove('treatment_photos', created.treatment_photos);
  await remove('media', created.media);
  await remove('follow_ups', created.follow_ups);
  await remove('treatments', created.treatments);
  await remove('prescriptions', created.prescriptions);
  await remove('invoices', created.invoices);
  await remove('visits', created.visits);
  await remove('appointments', created.appointments);
  return { counts, skipped };
}

function printResults() {
  console.log('\nKẾT QUẢ | BƯỚC');
  console.log('--------+------------------------------------------------------------');
  for (const r of results) console.log(`${r.status.padEnd(7)} | ${r.name}${r.note ? `\n        |   ${r.note}` : ''}`);
}

async function main() {
  let failed = false;
  try {
    await run();
  } catch (error) {
    failed = true;
    if (!results.some((r) => r.status === 'FAIL')) results.push({ status: 'FAIL', name: 'Chuẩn bị', note: error.message });
  }
  printResults();
  try {
    const { counts, skipped, note } = await cleanup();
    console.log(`\nDỌN DẸP: ${note || `đã xóa ${JSON.stringify(counts)}`}`);
    if (skipped && skipped.length) console.log(`KHÔNG xóa (không thuộc test123): ${skipped.join(', ')}`);
  } catch (error) {
    failed = true;
    console.error(`\nDỌN DẸP LỖI: ${error.message}. Id đã tạo: ${JSON.stringify(Object.fromEntries(Object.entries(created).map(([k, v]) => [k, [...v]])))}`);
  }
  const passed = results.filter((r) => r.status === 'PASS').length;
  console.log(`\nTổng: ${passed} PASS, ${results.filter((r) => r.status === 'FAIL').length} FAIL, ${results.filter((r) => r.status === 'BỎ QUA').length} BỎ QUA.`);
  process.exit(failed ? 1 : 0);
}

main();
