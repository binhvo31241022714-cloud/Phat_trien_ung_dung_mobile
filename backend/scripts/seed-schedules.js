const { requireFirestore } = require('./_firestore');

const days = 30;
const slots = [
  ['08:00', '12:00', 'am'],
  ['13:30', '17:30', 'pm'],
];
const VN_OFFSET_MS = 7 * 60 * 60 * 1000;

// Ngày theo giờ Việt Nam (UTC+7), không phụ thuộc múi giờ của máy chạy script.
function vietnamDateKey(date) {
  return new Date(date.getTime() + VN_OFFSET_MS).toISOString().slice(0, 10);
}

function addDays(dateKey, offset) {
  const [year, month, day] = dateKey.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + offset)).toISOString().slice(0, 10);
}

// Thứ 2 đến thứ 7.
function isWeekday(dateKey) {
  const day = new Date(`${dateKey}T00:00:00Z`).getUTCDay();
  return day >= 1 && day <= 6;
}

function at(dateKey, value) {
  return new Date(`${dateKey}T${value}:00+07:00`);
}

// Lập kế hoạch ca, không đụng Firestore. existing: [{ id, doctorId, startAt }].
// Id đã có thì bỏ qua; bác sĩ đã có ca bất kỳ trong ngày (giờ Việt Nam) thì bỏ qua ngày đó.
function planSchedules(doctorIds, existing, now = new Date()) {
  const existingIds = new Set(existing.map((item) => item.id));
  const busyDays = new Set(existing
    .filter((item) => item.doctorId && item.startAt)
    .map((item) => `${item.doctorId}|${vietnamDateKey(item.startAt)}`));
  const today = vietnamDateKey(now);
  const toCreate = [];
  let skipped = 0;
  for (const doctorId of doctorIds) {
    for (let offset = 0; offset <= days; offset++) {
      const dateKey = addDays(today, offset);
      if (!isWeekday(dateKey)) continue;
      if (busyDays.has(`${doctorId}|${dateKey}`)) {
        skipped += slots.length;
        continue;
      }
      for (const [start, end, part] of slots) {
        const id = `${doctorId}_${dateKey}_${part}`;
        if (existingIds.has(id)) {
          skipped++;
          continue;
        }
        toCreate.push({
          id,
          data: { doctorId, startAt: at(dateKey, start), endAt: at(dateKey, end), slotMinutes: 30, isAvailable: true },
        });
      }
    }
  }
  return { today, toCreate, skipped };
}

function toDate(value) {
  if (!value) return null;
  const date = typeof value.toDate === 'function' ? value.toDate() : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

async function main() {
  const apply = process.argv.includes('--apply');
  const db = requireFirestore();
  const doctors = (await db.collection('doctors').get()).docs
    .filter((doc) => doc.data().isActive !== false);
  const todayStart = at(vietnamDateKey(new Date()), '00:00');
  const existing = (await db.collection('doctor_schedules').where('startAt', '>=', todayStart).get()).docs
    .map((doc) => ({ id: doc.id, doctorId: doc.data().doctorId, startAt: toDate(doc.data().startAt) }));
  const { today, toCreate, skipped } = planSchedules(doctors.map((doc) => doc.id), existing);
  console.log(`Hôm nay (giờ Việt Nam): ${today}. ${doctors.length} bác sĩ đang hoạt động.`);
  console.log(`Sẽ tạo ${toCreate.length} ca, bỏ qua ${skipped} ca đã có.`);
  if (!apply) {
    toCreate.slice(0, 6).forEach((item) => console.log(`  ${item.id}`));
    if (toCreate.length > 6) console.log(`  ... và ${toCreate.length - 6} ca khác`);
    console.log('DRY RUN: không ghi gì. Chạy lại với --apply để ghi doctor_schedules.');
    return;
  }
  // Firestore giới hạn 500 thao tác mỗi batch.
  for (let i = 0; i < toCreate.length; i += 400) {
    const batch = db.batch();
    for (const item of toCreate.slice(i, i + 400)) {
      batch.create(db.collection('doctor_schedules').doc(item.id), { ...item.data, updatedAt: new Date() });
    }
    await batch.commit();
  }
  console.log(`Đã ghi ${toCreate.length} ca làm việc cho ${doctors.length} bác sĩ.`);
}

module.exports = { planSchedules, vietnamDateKey };

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
