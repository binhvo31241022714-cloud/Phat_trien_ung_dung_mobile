const { deleteQuery, requireFirestore } = require('./_firestore');

const positional = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const email = positional[0];
const apply = process.argv.includes('--apply');
const keepProfile = process.argv.includes('--keep-profile');
const collections = [
  'appointments',
  'appointment_slots',
  'visits',
  'prescriptions',
  'invoices',
  'treatments',
  'treatment_sessions',
  'follow_ups',
  'media',
  'treatment_photos',
  'notifications',
  'appointment_requests',
];

async function main() {
  if (!email || !email.includes('@')) {
    throw new Error('Cách dùng: node scripts/cleanup-test-data.js <email> [--apply] [--keep-profile]');
  }
  if (!apply) {
    console.log(`DRY RUN: sẽ dọn dữ liệu nghiệp vụ của tài khoản ${email}.`);
    console.log(`Phạm vi: ${collections.join(', ')}${keepProfile ? '; giữ profile/người thân' : '; gồm profile/người thân nếu có dữ liệu liên quan'}.`);
    console.log('Không có thay đổi nào được ghi. Dùng --apply để thực hiện.');
    return;
  }
  const db = requireFirestore();
  const account = (await db.collection('users').where('email', '==', email).limit(1).get()).docs[0];
  if (!account) throw new Error('Không tìm thấy tài khoản theo email.');
  const uid = account.id;
  const counts = {};
  for (const collection of collections) {
    counts[collection] = await deleteQuery(db, collection, 'accountId', uid, true);
    if (collection === 'notifications') {
      counts[collection] += await deleteQuery(db, collection, 'userId', uid, true);
    }
  }
  if (!keepProfile) {
    const members = await db.collection('users').doc(uid).collection('family_members').get();
    const batch = db.batch();
    members.docs.forEach((doc) => batch.delete(doc.ref));
    if (!members.empty) await batch.commit();
    await db.collection('users').doc(uid).delete();
    counts.family_members = members.size;
    counts.user = 1;
  }
  console.log(JSON.stringify(counts));
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
