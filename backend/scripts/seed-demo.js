const { requireFirestore } = require('./_firestore');
const { writeCompletion } = require('../src/utils/clinical');

const positional = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const email = positional[0];
const apply = process.argv.includes('--apply');

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
  const now = new Date();
  const dateKey = (date) => date.toISOString().slice(0, 10);
  const makeAppointment = (date, status) => ({
    accountId: uid,
    patientId: uid,
    doctorId: doctor.id,
    doctorName: doctor.data().name || '',
    serviceIds: [service.id],
    comboId: null,
    date: dateKey(date),
    startTime: `${String(date.getHours()).padStart(2, '0')}:00`,
    endTime: `${String(date.getHours() + 1).padStart(2, '0')}:00`,
    durationMinutes: 60,
    totalPrice: Number(service.data().price) || 0,
    discount: 0,
    voucherCode: null,
    note: 'Dữ liệu demo thuyết trình',
    status,
    slotKeys: [],
    createdAt: now,
  });
  const pastDates = [new Date(now.getTime() - 14 * 86400000), new Date(now.getTime() - 7 * 86400000)];
  const upcoming = new Date(now.getTime() + 7 * 86400000);
  const batch = db.batch();
  const completed = [];
  for (const date of pastDates) {
    const ref = db.collection('appointments').doc();
    const appointment = makeAppointment(date, 'completed');
    batch.set(ref, appointment);
    completed.push({ ref, appointment });
  }
  const upcomingRef = db.collection('appointments').doc();
  batch.set(upcomingRef, makeAppointment(upcoming, 'confirmed'));
  const treatmentRef = db.collection('treatments').doc();
  batch.set(treatmentRef, {
    accountId: uid, patientId: uid, doctorId: doctor.id, doctorName: doctor.data().name || '',
    name: 'Điều trị chăm sóc nướu', diagnosis: 'Theo dõi định kỳ', status: 'in_progress',
    totalSessions: 3, startAt: pastDates[0], endAt: upcoming, createdBy: uid, createdAt: now, updatedAt: now,
  });
  for (let index = 1; index <= 3; index++) {
    const sessionRef = db.collection('treatment_sessions').doc(`${treatmentRef.id}_s${index}`);
    batch.set(sessionRef, {
      treatmentId: treatmentRef.id, accountId: uid, patientId: uid, doctorId: doctor.id,
      sessionNumber: index, scheduledAt: new Date(now.getTime() + (index - 2) * 7 * 86400000),
      status: index === 1 ? 'completed' : 'planned', visitId: null, appointmentId: null, createdAt: now,
    });
  }
  const followUpRef = db.collection('follow_ups').doc();
  batch.set(followUpRef, {
    accountId: uid, patientId: uid, doctorId: doctor.id, serviceId: service.id,
    scheduledAt: new Date(now.getTime() + 21 * 86400000), reason: 'Tái khám sau liệu trình',
    notes: 'Dữ liệu demo', status: 'suggested', createdAt: now, createdBy: uid,
  });
  for (const { ref, appointment } of completed) {
    writeCompletion({
      set: (target, data) => batch.set(target, data),
    }, {
      appointmentId: ref.id,
      appointment,
      input: { visit: { diagnosis: 'Răng và nướu ổn định', result: 'Đáp ứng tốt', notes: 'Tiếp tục chăm sóc tại nhà.' } },
      now,
    });
    const prescriptionRef = db.collection('prescriptions').doc(`rx_${ref.id}`);
    batch.set(prescriptionRef, {
      appointmentId: ref.id, visitId: `visit_${ref.id}`, accountId: uid, patientId: uid,
      items: [{ medicineName: 'Nước súc miệng', dosage: '10ml', frequency: '2 lần/ngày', durationDays: 7 }],
      instructions: 'Dùng sau khi vệ sinh răng.', createdAt: now,
    });
    const invoiceRef = db.collection('invoices').doc(`inv_${ref.id}`);
    batch.set(invoiceRef, {
      appointmentId: ref.id, visitId: `visit_${ref.id}`, accountId: uid, patientId: uid,
      items: [{ name: service.data().name || 'Khám nha khoa', quantity: 1, unitPrice: Number(service.data().price) || 0 }],
      total: Number(service.data().price) || 0, paid: true, paymentMethod: 'cash', createdAt: now,
    });
  }
  batch.set(db.collection('notifications').doc(), {
    userId: uid, type: 'follow_up', title: 'Bác sĩ đề xuất tái khám',
    body: 'Tái khám sau liệu trình', refId: followUpRef.id, isRead: false, createdAt: now,
  });
  await batch.commit();
  console.log(`Đã tạo dữ liệu demo cho ${email}: 3 lịch, 2 visit, đơn thuốc, hóa đơn, liệu trình và tái khám.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
