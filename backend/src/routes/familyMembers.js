const router = require('express').Router();
const { db } = require('../config/firebase');
const auth = require('../middleware/auth');
const { readHealth, withHealthDefaults, DEFAULTS } = require('../utils/health');
const { isAppointmentActive, isFutureAppointment } = require('../utils/booking');
const { readProfile } = require('../utils/profile');

// Người thân lưu bên trong hồ sơ của từng user, nên người khác không xem được
const col = (uid) => db.collection('users').doc(uid).collection('family_members');

// Người thân đã xóa (xóa mềm) vẫn còn document để giữ hồ sơ khám cũ.
const isArchived = (snap) => snap.data().isArchived === true;

// GET /api/family-members
// Ẩn người thân đã xóa. Lọc trong code vì dữ liệu cũ không có trường isArchived.
router.get('/', auth, async (req, res) => {
  const snap = await col(req.user.uid).get();
  res.json(snap.docs
    .filter((d) => !isArchived(d))
    .map((d) => ({ id: d.id, ...withHealthDefaults(d.data()) })));
});

// Các trường cơ bản của người thân (xem utils/profile.js)
const PROFILE_FIELDS = ['fullName', 'relationship', 'birthday', 'phone'];

// POST /api/family-members
router.post('/', auth, async (req, res) => {
  const { data: profile, error: profileError } = readProfile(
    req.body || {}, PROFILE_FIELDS, { requireName: true });
  if (profileError) return res.status(400).json({ message: profileError });

  // Giới tính và thông tin sức khỏe (xem utils/health.js), thiếu thì lưu mặc định
  const { data: health, error } = readHealth(req.body);
  if (error) return res.status(400).json({ message: error });

  const ref = await col(req.user.uid).add({
    fullName: profile.fullName,
    relationship: profile.relationship || '',
    birthday: profile.birthday || '',
    phone: profile.phone || '',
    ...DEFAULTS,
    ...health,
    createdAt: new Date(),
  });
  res.status(201).json({ id: ref.id });
});

// PATCH /api/family-members/:id
router.patch('/:id', auth, async (req, res) => {
  const ref = col(req.user.uid).doc(req.params.id);
  const snap = await ref.get();
  if (!snap.exists || isArchived(snap)) return res.status(404).json({ message: 'Không tìm thấy' });

  const { data: health, error } = readHealth(req.body);
  if (error) return res.status(400).json({ message: error });

  const { data: profile, error: profileError } = readProfile(req.body, PROFILE_FIELDS);
  if (profileError) return res.status(400).json({ message: profileError });

  const updates = { ...health, ...profile };

  if (Object.keys(updates).length > 0) await ref.update(updates);
  res.json({ message: 'Cập nhật thành công' });
});

// DELETE /api/family-members/:id
// Xóa mềm: đánh dấu isArchived để hồ sơ khám, hóa đơn, lịch hẹn cũ vẫn xem được.
// Còn lịch hẹn sắp tới chưa hủy thì không cho xóa (409).
router.delete('/:id', auth, async (req, res) => {
  const uid = req.user.uid;
  const id = req.params.id;
  const ref = col(uid).doc(id);
  // Transaction: không lọt lịch hẹn vừa được đặt đúng lúc đang xóa
  // (POST /api/appointments đọc người thân trong transaction của nó).
  const result = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists || isArchived(snap)) return 404;
    const appointments = await transaction.get(
      db.collection('appointments').where('patientId', '==', id),
    );
    const hasUpcoming = appointments.docs.some((doc) => {
      const a = doc.data();
      return a.accountId === uid && isAppointmentActive(a) &&
        isFutureAppointment(a.date, a.startTime);
    });
    if (hasUpcoming) return 409;
    transaction.update(ref, { isArchived: true, archivedAt: new Date() });
    return 200;
  });

  if (result === 404) return res.status(404).json({ message: 'Không tìm thấy' });
  if (result === 409) {
    return res.status(409).json({
      message: 'Người thân này còn lịch hẹn sắp tới. Vui lòng hủy lịch hẹn trước khi xóa.',
    });
  }
  res.json({ message: 'Đã xóa' });
});

module.exports = router;
