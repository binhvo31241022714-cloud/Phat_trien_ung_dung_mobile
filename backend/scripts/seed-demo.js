const { requireFirestore } = require('./_firestore');

// Tạo bộ dữ liệu demo cho 1 tài khoản: 2 lần khám đã hoàn tất (kèm đơn thuốc, hóa đơn),
// 1 lịch đã xác nhận 7 ngày sau, 1 liệu trình 3 buổi, 1 đề xuất tái khám 21 ngày sau.
// Giờ hẹn cố định trong giờ làm việc (09:00, 14:00, 10:00) theo giờ Việt Nam,
// nên chạy lúc nào trong ngày cũng được. Định dạng visit/rx/inv giống backend thật.

const positional = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const email = positional[0];
const apply = process.argv.includes('--apply');

const DAY = 86400000;
function vietnamDateKey(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(date);
}
function addHour(time) {
  const [h, m] = time.split(':').map(Number);
  return `${String(h + 1).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

async function main() {
  if (!email || !email.includes('@')) {
    throw new Error('Cách dùng: node scripts/seed-demo.js <email> [--apply]');
  }
  if (!apply) {
    console.log(`DRY RUN: sẽ chuẩn bị bộ dữ liệu demo cho ${email}.`);
    console.log('Không xóa dữ liệu có sẵn và chưa ghi Firestore.');
    console.log('Dùng --apply sau khi đã chạy cleanup/seed-schedules và kiểm tra đúng tài khoản.');
    return;
  }
  const db = requireFirestore();
  const account = (await db.collection('users').where('email', '==', email).limit(1).get()).docs[0];
  if (!account) throw new Error('Không tìm thấy tài khoản. Hãy đăng nhập app để tạo profile trước.');
  const uid = account.id;
  const [doctorSnap, serviceSnap] = await Promise.all([
    db.collection('doctors').where('isActive', '!=', false).limit(1).get(),
    db.collection('services').limit(1).get(),
  ]);
  if (doctorSnap.empty || serviceSnap.empty) {
    throw new Error('Cần có ít nhất một bác sĩ và một dịch vụ dùng chung trước khi seed demo.');
  }
  const doctor = doctorSnap.docs[0];
  const service = serviceSnap.docs[0];
  const doctorName = doctor.data().name || '';
  const price = Number(service.data().price) || 0;
  const serviceName = service.data().name || 'Khám nha khoa';
  const now = new Date();

  const makeAppointment = (date, startTime, status, extra = {}) => ({
    accountId: uid,
    patientId: uid,
    doctorId: doctor.id,
    doctorName,
    serviceIds: [service.id],
    comboId: null,
    date: vietnamDateKey(date),
    startTime,
    endTime: addHour(startTime),
    durationMinutes: 60,
    totalPrice: price,
    discount: 0,
    voucherCode: null,
    note: 'Dữ liệu demo thuyết trình',
    followUpId: null,
    status,
    slotKeys: [],
    createdAt: now,
    ...extra,
  });

  const batch = db.batch();
  const past = [
    { date: new Date(now.getTime() - 14 * DAY), time: '09:00', diagnosis: 'Viêm nướu nhẹ', result: 'Đã lấy cao răng toàn hàm' },
    { date: new Date(now.getTime() - 7 * DAY), time: '14:00', diagnosis: 'Răng và nướu ổn định', result: 'Đáp ứng tốt sau điều trị' },
  ];
  const visitIds = [];
  for (const item of past) {
    const ref = db.collection('appointments').doc();
    const visitId = `visit_${ref.id}`;
    visitIds.push(visitId);
    const appointment = makeAppointment(item.date, item.time, 'completed', {
      visitId, statusUpdatedAt: now, statusUpdatedBy: uid,
    });
    batch.set(ref, appointment);
    const common = {
      appointmentId: ref.id, accountId: uid, patientId: uid,
      doctorId: doctor.id, doctorName, createdBy: uid, createdAt: now,
    };
    batch.set(db.collection('visits').doc(visitId), {
      ...common, id: visitId, status: 'completed',
      serviceIds: [service.id], chiefComplaint: appointment.note,
      scheduledAt: new Date(`${appointment.date}T${appointment.startTime}:00+07:00`),
      diagnosis: item.diagnosis, result: item.result, doctorNote: 'Tiếp tục chăm sóc tại nhà.',
    });
    batch.set(db.collection('prescriptions').doc(`rx_${ref.id}`), {
      ...common, visitId, issuedAt: now,
      items: [{ medicineName: 'Nước súc miệng Chlorhexidine 0,12%', dosage: '10 ml/lần', frequency: '2 lần/ngày', durationDays: 7, instructions: 'Dùng sau khi vệ sinh răng.' }],
    });
    batch.set(db.collection('invoices').doc(`inv_${ref.id}`), {
      ...common, visitId, issuedAt: now,
      items: [{ name: serviceName, quantity: 1, unitPrice: price, amount: price }],
      subtotal: price, discountAmount: 0, totalAmount: price,
      voucherCode: null, paymentStatus: 'paid', paymentMethod: 'cash', paidAt: now,
    });
  }

  batch.set(db.collection('appointments').doc(),
    makeAppointment(new Date(now.getTime() + 7 * DAY), '10:00', 'confirmed', { statusUpdatedAt: now, statusUpdatedBy: uid }));

  const treatmentRef = db.collection('treatments').doc();
  batch.set(treatmentRef, {
    accountId: uid, patientId: uid, doctorId: doctor.id, doctorName,
    name: 'Điều trị chăm sóc nướu', diagnosis: 'Theo dõi định kỳ', status: 'in_progress',
    totalSessions: 3, startAt: past[0].date, endAt: new Date(now.getTime() + 7 * DAY),
    createdBy: uid, createdAt: now, updatedAt: now,
  });
  for (let index = 1; index <= 3; index++) {
    batch.set(db.collection('treatment_sessions').doc(`${treatmentRef.id}_s${index}`), {
      treatmentId: treatmentRef.id, accountId: uid, patientId: uid, doctorId: doctor.id,
      sessionNumber: index, scheduledAt: new Date(`${vietnamDateKey(new Date(now.getTime() + (index - 2) * 7 * DAY))}T09:00:00+07:00`),
      status: index === 1 ? 'completed' : 'planned', visitId: index === 1 ? visitIds[1] : null,
      appointmentId: null, createdAt: now,
    });
  }

  const followUpRef = db.collection('follow_ups').doc();
  batch.set(followUpRef, {
    accountId: uid, patientId: uid, doctorId: doctor.id, doctorName, serviceId: service.id,
    visitId: visitIds[1], treatmentId: treatmentRef.id,
    scheduledAt: new Date(`${vietnamDateKey(new Date(now.getTime() + 21 * DAY))}T09:00:00+07:00`),
    reason: 'Tái khám sau liệu trình', notes: 'Dữ liệu demo', status: 'suggested',
    createdAt: now, createdBy: uid,
  });
  batch.set(db.collection('notifications').doc(), {
    userId: uid, patientId: uid, type: 'follow_up', title: 'Bác sĩ đề xuất tái khám',
    body: 'Tái khám sau liệu trình', refId: followUpRef.id, isRead: false, createdAt: now,
  });

  await batch.commit();
  console.log(`Đã tạo dữ liệu demo cho ${email}: 3 lịch, 2 lần khám, đơn thuốc, hóa đơn, liệu trình và tái khám.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});