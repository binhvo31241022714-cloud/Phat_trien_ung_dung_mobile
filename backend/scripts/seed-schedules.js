// Tạo lịch làm việc (doctor_schedules) cho mọi bác sĩ đang hoạt động,
// từ hôm nay tới 30 ngày sau, thứ 2 đến thứ 7, 2 ca/ngày (giờ Việt Nam).
//
// Chạy thử (chỉ in ra, không ghi):  node scripts/seed-schedules.js
// Chạy thật (ghi Firestore):          node scripts/seed-schedules.js --apply
//
// Không xóa, không ghi đè lịch cũ:
// - Id đã tồn tại thì bỏ qua.
// - Bác sĩ đã có ca bất kỳ trong ngày (kể cả ca cũ khác dạng id) thì bỏ qua ngày đó.
const { db } = require('../src/config/firebase');
const { parseFirestoreDate, toVietnamDateKey } = require('../src/utils/booking');

const DAYS_AHEAD = 30;
const SHIFTS = [
  { suffix: 'am', start: '08:00', end: '12:00', note: 'Ca sáng' },
  { suffix: 'pm', start: '13:30', end: '17:30', note: 'Ca chiều' },
];
const BATCH_SIZE = 400;
const apply = process.argv.includes('--apply');

const vnTime = (dateKey, time) => new Date(`${dateKey}T${time}:00+07:00`);

function addDays(dateKey, days) {
  const [y, m, d] = dateKey.split('-').map(Number);
  const date = new Date(Date.UTC(y, m - 1, d + days));
  return { key: date.toISOString().slice(0, 10), weekday: date.getUTCDay() };
}

async function main() {
  const today = toVietnamDateKey(new Date());
  const days = [];
  for (let i = 0; i <= DAYS_AHEAD; i += 1) days.push(addDays(today, i));
  const workDays = days.filter((day) => day.weekday !== 0); // bỏ Chủ nhật

  const doctorSnap = await db.collection('doctors').get();
  const doctors = doctorSnap.docs
    .filter((doc) => doc.data().isActive !== false)
    .map((doc) => ({ id: doc.id, name: doc.data().name || '' }));

  // Các ngày bác sĩ đã có ca (đọc theo khoảng startAt, giống loadSchedulingData).
  const rangeStart = vnTime(days[0].key, '00:00');
  const rangeEnd = vnTime(addDays(days[days.length - 1].key, 1).key, '00:00');
  const existingSnap = await db.collection('doctor_schedules')
    .where('startAt', '>=', rangeStart)
    .where('startAt', '<', rangeEnd)
    .get();
  const busyDays = new Map(); // `${doctorId}|${dateKey}` -> [id ca cũ]
  for (const doc of existingSnap.docs) {
    const startAt = parseFirestoreDate(doc.data().startAt);
    if (!startAt) continue;
    const key = `${doc.data().doctorId}|${toVietnamDateKey(startAt)}`;
    busyDays.set(key, [...(busyDays.get(key) || []), doc.id]);
  }

  const planned = [];
  const skippedDays = [];
  for (const doctor of doctors) {
    for (const day of workDays) {
      const existing = busyDays.get(`${doctor.id}|${day.key}`);
      if (existing) {
        skippedDays.push(`${doctor.id} ${day.key} (đã có: ${existing.join(', ')})`);
        continue;
      }
      for (const shift of SHIFTS) {
        planned.push({
          id: `${doctor.id}_${day.key}_${shift.suffix}`,
          data: {
            doctorId: doctor.id,
            startAt: vnTime(day.key, shift.start),
            endAt: vnTime(day.key, shift.end),
            slotMinutes: 30,
            isAvailable: true,
            note: shift.note,
            createdAt: new Date(),
          },
          label: `${doctor.id} ${day.key} ${shift.start}-${shift.end}`,
        });
      }
    }
  }

  // Id đã tồn tại ở bất kỳ ngày nào thì bỏ qua, không ghi đè.
  const skippedIds = [];
  const toCreate = [];
  for (let i = 0; i < planned.length; i += 100) {
    const chunk = planned.slice(i, i + 100);
    const snaps = await db.getAll(...chunk.map((item) => db.collection('doctor_schedules').doc(item.id)));
    snaps.forEach((snap, index) => {
      if (snap.exists) skippedIds.push(chunk[index].id);
      else toCreate.push(chunk[index]);
    });
  }

  console.log(`Chế độ: ${apply ? 'CHẠY THẬT (--apply)' : 'CHẠY THỬ (không ghi)'}`);
  console.log(`Khoảng ngày: ${days[0].key} đến ${days[days.length - 1].key}, ${workDays.length} ngày làm việc (bỏ Chủ nhật)`);
  console.log(`Bác sĩ đang hoạt động: ${doctors.map((d) => d.id).join(', ')}`);
  console.log(`Số ca sẽ tạo: ${toCreate.length}`);
  console.log('Vài dòng mẫu:');
  toCreate.slice(0, 6).forEach((item) => console.log(`  ${item.id}  ${item.label}`));
  if (toCreate.length > 6) console.log(`  ... và ${toCreate.length - 6} ca nữa`);
  console.log(`Ngày bị bỏ qua vì bác sĩ đã có ca: ${skippedDays.length}`);
  skippedDays.forEach((line) => console.log(`  ${line}`));
  console.log(`Id đã tồn tại, bỏ qua: ${skippedIds.length}`);
  skippedIds.forEach((id) => console.log(`  ${id}`));

  if (!apply) {
    console.log('\nChưa ghi gì. Thêm --apply để ghi thật.');
    return;
  }

  for (let i = 0; i < toCreate.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const item of toCreate.slice(i, i + BATCH_SIZE)) {
      // create() báo lỗi nếu id vừa được ai đó tạo, không ghi đè.
      batch.create(db.collection('doctor_schedules').doc(item.id), item.data);
    }
    await batch.commit();
  }
  console.log(`\nĐã tạo ${toCreate.length} ca.`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
