const { requireFirestore } = require('./_firestore');

const apply = process.argv.includes('--apply');
const days = 30;
const now = new Date();
const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
const slots = [
  ['08:00', '12:00', 'am'],
  ['13:30', '17:30', 'pm'],
];

function isWeekday(date) {
  const day = date.getDay();
  return day >= 1 && day <= 6;
}

function at(date, value) {
  const [hour, minute] = value.split(':').map(Number);
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), hour, minute);
}

async function main() {
  if (!apply) {
    console.log(`DRY RUN: sẽ tạo ca cho bác sĩ active trong ${days + 1} ngày tới.`);
    console.log('Chạy lại với --apply để ghi doctor_schedules.');
    return;
  }
  const db = requireFirestore();
  const doctors = (await db.collection('doctors').get()).docs
    .filter((doc) => doc.data().isActive !== false);
  const batch = db.batch();
  let count = 0;
  for (const doctor of doctors) {
    for (let offset = 0; offset <= days; offset++) {
      const date = new Date(dayStart);
      date.setDate(dayStart.getDate() + offset);
      if (!isWeekday(date)) continue;
      for (const [start, end, part] of slots) {
        const id = `${doctor.id}_${date.toISOString().slice(0, 10)}_${part}`;
        batch.set(db.collection('doctor_schedules').doc(id), {
          doctorId: doctor.id,
          startAt: at(date, start),
          endAt: at(date, end),
          slotMinutes: 30,
          isAvailable: true,
          updatedAt: new Date(),
        }, { merge: true });
        count++;
      }
    }
  }
  if (count) await batch.commit();
  console.log(`Đã ghi ${count} ca làm việc cho ${doctors.length} bác sĩ.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
