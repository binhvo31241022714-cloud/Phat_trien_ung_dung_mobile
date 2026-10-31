const router = require('express').Router();
const auth = require('../middleware/auth');
const requireStaff = require('../middleware/requireStaff');
const {
  APPOINTMENT_STATUSES,
  canTransition,
  ApiError,
  asyncHandler,
  db,
  buildQuoteWithVoucher,
  findVoucherRef,
  loadSchedulingData,
  doctorProvidesServices,
  getCandidateSchedules,
  getSlotLockRefs,
  isValidDateKey,
  parseTime,
  toTimeString,
  scheduleCanCover,
  isFutureAppointment,
  isAppointmentActive,
  parseFirestoreDate,
  shuffle,
} = require('../utils/booking');
const { parseCompletionBody, readCompletion, writeCompletion } = require('../utils/clinical');
const {
  isOpenFollowUp,
  readFollowUpId,
  readLinkedFollowUp,
  reopenFollowUp,
  completeFollowUp,
} = require('../utils/followUps');
const { appointmentReminderId } = require('../jobs/reminders');

function overlaps(startA, endA, startB, endB) {
  return startA < endB && startB < endA;
}

function isRetryableSlotConflict(error) {
  return error.status === 409 || error.code === 10 || error.code === '10' ||
    error.code === 'already-exists';
}

// Dùng chung cho hủy và từ chối: đọc (trong transaction) các slot đang giữ và voucher.
async function readRelease(transaction, appointment) {
  if (!appointment.doctorId || !appointment.endTime) {
    throw new ApiError(500, 'Lịch hẹn thiếu doctorId hoặc endTime nên không thể giải phóng slot an toàn');
  }
  const startMinute = parseTime(appointment.startTime, 'startTime');
  const endMinute = parseTime(appointment.endTime, 'endTime');
  const lockRefs = getSlotLockRefs(appointment.doctorId, appointment.date, startMinute, endMinute);
  const locks = [];
  for (const lock of lockRefs) {
    locks.push({ lock, snapshot: await transaction.get(lock.ref) });
  }

  let voucherRef = null;
  let voucherSnap = null;
  if (appointment.voucherCode) {
    voucherRef = await findVoucherRef(appointment.voucherCode);
    if (voucherRef) {
      voucherSnap = await transaction.get(voucherRef);
    }
  }
  return { locks, voucherRef, voucherSnap };
}

// Ghi phần giải phóng: xóa slot của đúng lịch này, trả 1 lượt voucher.
function writeRelease(transaction, appointmentId, { locks, voucherRef, voucherSnap }) {
  for (const { lock, snapshot } of locks) {
    if (snapshot.exists && snapshot.data().appointmentId === appointmentId) {
      transaction.delete(lock.ref);
    }
  }
  if (voucherSnap && voucherSnap.exists) {
    const currentUsed = Number(voucherSnap.data().usedCount || 0);
    if (currentUsed > 0) {
      transaction.update(voucherRef, { usedCount: currentUsed - 1 });
    }
  }
}

const STATUS_NOTIFICATIONS = {
  confirmed: {
    type: 'appointment_confirmed',
    title: 'Lịch hẹn đã được xác nhận',
    body: (a) => `Lịch hẹn ngày ${a.date} lúc ${a.startTime} đã được phòng khám xác nhận.`,
  },
  rejected: {
    type: 'appointment_rejected',
    title: 'Lịch hẹn bị từ chối',
    body: (a, reason) => `Lịch hẹn ngày ${a.date} lúc ${a.startTime} đã bị từ chối. Lý do: ${reason}`,
  },
  // Hoàn tất chỉ tạo 1 thông báo kết quả khám, refId là visitId.
  completed: {
    type: 'visit_result',
    title: 'Đã có kết quả khám',
    body: (a) => `Kết quả lần khám ngày ${a.date} lúc ${a.startTime} đã sẵn sàng. Bấm để xem chi tiết.`,
  },
};

const IDEMPOTENCY_KEY = /^[A-Za-z0-9_-]{8,100}$/;
const NOTE_MAX_LENGTH = 500;

// Dấu vân tay nội dung yêu cầu: cùng Idempotency-Key mà khác nội dung thì 409.
function requestFingerprint(input) {
  const { createHash } = require('crypto');
  return createHash('sha256').update(JSON.stringify(input)).digest('hex');
}

// Lỗi không được thử bác sĩ khác trong vòng lặp ứng viên.
function fatalConflict(message) {
  const error = new ApiError(409, message);
  error.fatal = true;
  return error;
}

// Đã có appointment_requests/{uid}_{key}: trả lại lịch đã tạo (hoặc 409 nếu khác nội dung).
async function replayRequest(requestSnap, fingerprint, readAppointment) {
  if (!requestSnap.exists) return null;
  if (requestSnap.data().fingerprint !== fingerprint) {
    throw fatalConflict('Mã yêu cầu đã dùng cho một lịch khác');
  }
  const appointmentSnap = await readAppointment(
    db.collection('appointments').doc(requestSnap.data().appointmentId),
  );
  if (!appointmentSnap.exists) throw fatalConflict('Lịch hẹn của mã yêu cầu này không còn tồn tại');
  return { id: appointmentSnap.id, ...appointmentSnap.data() };
}

// POST /api/appointments
// Header tùy chọn: Idempotency-Key (gửi lại cùng key không tạo lịch trùng)
// Body: { patientId, doctorId?, serviceIds?, comboId?, date, startTime, voucherCode?, note?, followUpId? }
// followUpId: đặt từ đề xuất tái khám (A08); follow-up chuyển sang "booked" cùng transaction.
router.post('/', auth, asyncHandler(async (req, res) => {
  const uid = req.user.uid;
  const body = req.body || {};

  // Kiểm tra người khám trước mọi bước về dịch vụ, lịch làm việc, khung giờ, slot.
  // Transaction bên dưới kiểm tra lại lần nữa phòng người thân bị xóa giữa chừng.
  const patientId = typeof body.patientId === 'string' && body.patientId.trim()
    ? body.patientId.trim()
    : uid;
  const patientRef = patientId === uid
    ? db.collection('users').doc(uid)
    : db.collection('users').doc(uid).collection('family_members').doc(patientId);
  if (patientId !== uid) {
    const patientSnap = await patientRef.get();
    if (!patientSnap.exists) {
      return res.status(400).json({ message: 'Người khám không thuộc danh sách người thân của tài khoản này' });
    }
    if (patientSnap.data().isArchived === true) {
      return res.status(400).json({ message: 'Người thân này đã bị xóa khỏi danh sách, không thể đặt lịch mới' });
    }
  }

  const requestKey = req.get('Idempotency-Key');
  if (requestKey !== undefined && !IDEMPOTENCY_KEY.test(requestKey)) {
    return res.status(400).json({ message: 'Idempotency-Key phải gồm 8 đến 100 ký tự chữ, số, "-" hoặc "_"' });
  }
  if (body.note !== undefined && body.note !== null && typeof body.note !== 'string') {
    return res.status(400).json({ message: 'Ghi chú phải là chuỗi' });
  }
  const note = typeof body.note === 'string' ? body.note.trim() : '';
  if (note.length > NOTE_MAX_LENGTH) {
    return res.status(400).json({ message: `Ghi chú tối đa ${NOTE_MAX_LENGTH} ký tự` });
  }

  const date = String(body.date || '');
  if (!isValidDateKey(date)) {
    return res.status(400).json({ message: 'date phải theo định dạng YYYY-MM-DD' });
  }
  const startTime = String(body.startTime || '');
  const startMinute = parseTime(startTime, 'startTime');

  const requestedDoctorId = typeof body.doctorId === 'string' && body.doctorId.trim()
    ? body.doctorId.trim()
    : null;
  const followUpId = readFollowUpId(body.followUpId);

  let requestRef = null;
  let fingerprint = null;
  if (requestKey !== undefined) {
    requestRef = db.collection('appointment_requests').doc(`${uid}_${requestKey}`);
    fingerprint = requestFingerprint({
      patientId,
      date,
      startTime,
      doctorId: requestedDoctorId,
      serviceIds: Array.isArray(body.serviceIds)
        ? [...new Set(body.serviceIds.map(String))].sort()
        : [],
      comboId: body.comboId || null,
      voucherCode: String(body.voucherCode || body.code || '').trim().toUpperCase() || null,
      note,
      followUpId,
    });
    // Gửi lại: trả ngay lịch đã tạo. Phải kiểm tra trước khi xét khung giờ,
    // vì slot đang bị chính lịch đó giữ.
    const replayed = await replayRequest(await requestRef.get(), fingerprint, (ref) => ref.get());
    if (replayed) return res.status(201).json(replayed);
  }

  if (!isFutureAppointment(date, startTime)) {
    return res.status(400).json({ message: 'Không thể đặt lịch vào thời gian đã qua' });
  }
  const quoteInput = {
    serviceIds: body.serviceIds || [],
    comboId: body.comboId || null,
    voucherCode: body.voucherCode || body.code || null,
  };

  // Đọc trước để biết thời lượng và lấy ref voucher; transaction bên dưới sẽ tính lại
  // tất cả dữ liệu giá/voucher và chỉ dùng bản tính bên trong transaction để ghi đơn.
  const preliminaryQuote = await buildQuoteWithVoucher(quoteInput);
  const voucherRef = preliminaryQuote.voucherRef || null;
  const durationMinutes = preliminaryQuote.durationMinutes;
  const endMinute = startMinute + durationMinutes;
  if (endMinute >= 24 * 60) {
    return res.status(400).json({ message: 'Lịch hẹn không được vượt qua ngày kế tiếp' });
  }

  const scheduling = await loadSchedulingData(date);
  const allDoctors = scheduling.doctors;
  let candidateDoctors;
  if (requestedDoctorId) {
    const selected = allDoctors.find((doctor) => doctor.id === requestedDoctorId);
    if (!selected) return res.status(404).json({ message: 'Không tìm thấy bác sĩ' });
    if (selected.isActive === false) return res.status(400).json({ message: 'Bác sĩ đã ngừng hoạt động' });
    if (!doctorProvidesServices(selected, preliminaryQuote.serviceIds)) {
      return res.status(400).json({ message: 'Bác sĩ không thực hiện được tất cả dịch vụ đã chọn trong combo/dịch vụ này' });
    }
    candidateDoctors = [selected];
  } else {
    candidateDoctors = allDoctors.filter((doctor) =>
      doctorProvidesServices(doctor, preliminaryQuote.serviceIds),
    );
    candidateDoctors = shuffle(candidateDoctors);
  }

  const candidates = [];
  for (const doctor of candidateDoctors) {
    const schedules = getCandidateSchedules(
      scheduling.schedules,
      doctor.id,
      date,
      startMinute,
      durationMinutes,
    );
    for (const schedule of schedules) candidates.push({ doctor, schedule });
  }

  if (candidates.length === 0) {
    return res.status(409).json({ message: 'Không có bác sĩ đủ điều kiện làm việc trong khung giờ đã chọn' });
  }

  let lastConflict = null;
  for (const candidate of candidates) {
    const { doctor, schedule } = candidate;
    const doctorRef = db.collection('doctors').doc(doctor.id);
    const scheduleRef = db.collection('doctor_schedules').doc(schedule.id);
    const appointmentRef = db.collection('appointments').doc();
    const notificationRef = db.collection('notifications').doc();

    try {
      const appointment = await db.runTransaction(async (transaction) => {
        // TẤT CẢ reads phải xong trước write để transaction Firestore hợp lệ.
        // Đọc yêu cầu trước tiên: hai lần gửi cùng key chạy song song thì lần
        // thua sẽ được Firestore chạy lại và nhận lịch của lần thắng.
        if (requestRef) {
          const replayed = await replayRequest(
            await transaction.get(requestRef),
            fingerprint,
            (ref) => transaction.get(ref),
          );
          if (replayed) return replayed;
        }
        const patientSnap = await transaction.get(patientRef);
        if (!patientSnap.exists && patientId !== uid) {
          throw new ApiError(400, 'Người khám không thuộc danh sách người thân của tài khoản này');
        }
        if (patientId !== uid && patientSnap.data().isArchived === true) {
          throw new ApiError(400, 'Người thân này đã bị xóa khỏi danh sách, không thể đặt lịch mới');
        }

        const doctorSnap = await transaction.get(doctorRef);
        if (!doctorSnap.exists || doctorSnap.data().isActive === false) {
          throw new ApiError(409, 'Bác sĩ không còn hoạt động, vui lòng chọn lại');
        }
        if (!doctorProvidesServices({ id: doctorSnap.id, ...doctorSnap.data() }, preliminaryQuote.serviceIds)) {
          throw new ApiError(400, 'Bác sĩ không thực hiện được tất cả dịch vụ đã chọn trong combo/dịch vụ này');
        }

        const scheduleSnap = await transaction.get(scheduleRef);
        if (!scheduleSnap.exists || scheduleSnap.data().doctorId !== doctor.id ||
            !scheduleCanCover(scheduleSnap.data(), date, startMinute, preliminaryQuote.durationMinutes)) {
          throw new ApiError(409, 'Lịch làm việc của bác sĩ vừa thay đổi; vui lòng chọn khung giờ khác');
        }

        const quote = await buildQuoteWithVoucher(quoteInput, transaction, voucherRef);
        if (!doctorProvidesServices({ id: doctorSnap.id, ...doctorSnap.data() }, quote.serviceIds)) {
          throw new ApiError(400, 'Bác sĩ không thực hiện được tất cả dịch vụ của combo/dịch vụ đã chọn');
        }
        const actualEndMinute = startMinute + quote.durationMinutes;
        if (actualEndMinute >= 24 * 60 ||
            !scheduleCanCover(scheduleSnap.data(), date, startMinute, quote.durationMinutes)) {
          throw new ApiError(409, 'Thời lượng dịch vụ đã thay đổi và không còn vừa khung giờ này');
        }

        const existingSnapshot = await transaction.get(
          db.collection('appointments')
            .where('doctorId', '==', doctor.id)
            .where('date', '==', date),
        );
        const conflictingAppointment = existingSnapshot.docs.some((doc) => {
          const data = doc.data();
          if (data.date !== date || !isAppointmentActive(data)) return false;
          try {
            return overlaps(
              startMinute,
              actualEndMinute,
              parseTime(data.startTime, 'startTime'),
              parseTime(data.endTime, 'endTime'),
            );
          } catch (_) {
            return false;
          }
        });
        if (conflictingAppointment) {
          throw new ApiError(409, 'Khung giờ vừa được đặt; vui lòng chọn giờ khác');
        }

        const lockRefs = getSlotLockRefs(doctor.id, date, startMinute, actualEndMinute);
        const lockSnapshots = [];
        for (const lock of lockRefs) {
          lockSnapshots.push({ lock, snapshot: await transaction.get(lock.ref) });
        }
        if (lockSnapshots.some(({ snapshot }) => snapshot.exists)) {
          throw new ApiError(409, 'Khung giờ vừa được giữ bởi một lịch hẹn khác');
        }

        // A08: đề xuất tái khám phải đúng bệnh nhân, đúng tài khoản, còn mở.
        let followUpRef = null;
        if (followUpId) {
          followUpRef = db.collection('follow_ups').doc(followUpId);
          const followUpSnap = await transaction.get(followUpRef);
          if (!followUpSnap.exists) throw new ApiError(404, 'Không tìm thấy đề xuất tái khám');
          const followUp = followUpSnap.data();
          if (followUp.accountId && followUp.accountId !== uid) {
            throw new ApiError(403, 'Đề xuất tái khám không thuộc tài khoản này');
          }
          if (followUp.patientId !== patientId) {
            throw new ApiError(400, 'Đề xuất tái khám không thuộc người khám đã chọn');
          }
          if (!isOpenFollowUp(followUp.status)) {
            throw fatalConflict(String(followUp.status).toLowerCase() === 'booked'
              ? 'Đề xuất tái khám này đã được đặt lịch'
              : 'Đề xuất tái khám này không còn hiệu lực');
          }
          if (followUp.serviceId && !quote.serviceIds.includes(followUp.serviceId)) {
            throw new ApiError(400, 'Lịch tái khám phải gồm dịch vụ bác sĩ đã đề xuất');
          }
        }

        const startTimeSaved = toTimeString(startMinute);
        const endTimeSaved = toTimeString(actualEndMinute);
        const doctorName = doctorSnap.data().name || '';
        const appointmentData = {
          accountId: uid,
          patientId,
          doctorId: doctor.id,
          doctorName,
          serviceIds: quote.serviceIds,
          comboId: quote.comboId,
          date,
          startTime: startTimeSaved,
          endTime: endTimeSaved,
          durationMinutes: quote.durationMinutes,
          totalPrice: quote.totalPrice,
          discount: quote.discount,
          voucherCode: quote.voucherCode,
          note,
          followUpId,
          status: 'booked',
          slotKeys: lockRefs.map(({ ref }) => ref.id),
          createdAt: new Date(),
        };

        if (!patientSnap.exists && patientId === uid) {
          transaction.set(patientRef, {
            email: req.user.email || '',
            fullName: req.user.name || '',
            createdAt: new Date(),
          });
        }
        transaction.set(appointmentRef, appointmentData);
        if (followUpRef) {
          transaction.update(followUpRef, {
            status: 'booked', appointmentId: appointmentRef.id, bookedAt: new Date(), updatedAt: new Date(),
          });
        }
        if (requestRef) {
          transaction.set(requestRef, {
            accountId: uid,
            key: requestKey,
            appointmentId: appointmentRef.id,
            fingerprint,
            createdAt: new Date(),
          });
        }
        for (const { lock, snapshot } of lockSnapshots) {
          // snapshot đã được kiểm tra chưa tồn tại trong transaction.
          transaction.set(lock.ref, {
            doctorId: doctor.id,
            date,
            bucketMinute: lock.bucketMinute,
            appointmentId: appointmentRef.id,
            accountId: uid,
            createdAt: new Date(),
          });
        }
        if (quote.voucherRef) {
          transaction.update(quote.voucherRef, {
            usedCount: Number(quote.voucherUsedCount || 0) + 1,
          });
        }
        transaction.set(notificationRef, {
          userId: uid,
          title: 'Đặt lịch thành công',
          body: `Lịch hẹn ngày ${date} lúc ${startTimeSaved} đã được tạo.`,
          type: 'appointment_booked',
          refId: appointmentRef.id,
          isRead: false,
          createdAt: new Date(),
        });

        return { id: appointmentRef.id, ...appointmentData };
      });

      return res.status(201).json(appointment);
    } catch (error) {
      if (error.fatal) throw error;
      if (isRetryableSlotConflict(error) && !requestedDoctorId) {
        lastConflict = error;
        continue;
      }
      if (isRetryableSlotConflict(error)) {
        return res.status(409).json({ message: error.message || 'Khung giờ đã có người đặt' });
      }
      throw error;
    }
  }

  return res.status(409).json({
    message: lastConflict?.message || 'Không còn bác sĩ trống trong khung giờ đã chọn; vui lòng chọn giờ khác',
  });
}));

// GET /api/appointments - lịch hẹn của cả tài khoản, bao gồm lịch người thân
router.get('/', auth, asyncHandler(async (req, res) => {
  const snapshot = await db.collection('appointments')
    .where('accountId', '==', req.user.uid)
    .get();
  const appointments = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  appointments.sort((a, b) => {
    const left = `${a.date || ''}T${a.startTime || ''}`;
    const right = `${b.date || ''}T${b.startTime || ''}`;
    return left.localeCompare(right);
  });
  res.json(appointments);
}));

// GET /api/appointments/staff?status=booked&date=YYYY-MM-DD&sort=schedule|newest
// Nhân viên xem lịch theo trạng thái, kèm patientName. sort=newest: mới đổi trạng thái lên trước.
// Đặt trên /:id để "staff" không bị hiểu là id lịch hẹn.
router.get('/staff', auth, requireStaff, asyncHandler(async (req, res) => {
  const status = String(req.query.status || 'booked').trim().toLowerCase();
  if (!APPOINTMENT_STATUSES.includes(status)) {
    return res.status(400).json({ message: `status phải là một trong: ${APPOINTMENT_STATUSES.join(', ')}` });
  }
  const date = req.query.date === undefined ? null : String(req.query.date);
  if (date !== null && !isValidDateKey(date)) {
    return res.status(400).json({ message: 'date phải theo định dạng YYYY-MM-DD' });
  }

  const sort = String(req.query.sort || 'schedule').trim().toLowerCase();
  if (!['schedule', 'newest'].includes(sort)) {
    return res.status(400).json({ message: 'sort phải là "schedule" hoặc "newest"' });
  }

  let query = db.collection('appointments').where('status', '==', status);
  if (date) query = query.where('date', '==', date);
  const snapshot = await query.get();
  const appointments = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const changedAt = (a) => (parseFirestoreDate(a.statusUpdatedAt) || parseFirestoreDate(a.createdAt))?.getTime() || 0;
  appointments.sort(sort === 'newest'
    // Mới đổi trạng thái (hoặc mới đặt) lên trước: dùng cho demo xác nhận lịch vừa đặt.
    ? (a, b) => changedAt(b) - changedAt(a) || a.id.localeCompare(b.id)
    : (a, b) => `${a.date || ''}T${a.startTime || ''}`.localeCompare(`${b.date || ''}T${b.startTime || ''}`));

  // Tên người khám để nhân viên biết lịch của ai (đọc hồ sơ, dùng lại kết quả đã đọc).
  const names = new Map();
  for (const a of appointments) {
    if (!a.accountId || !a.patientId) continue;
    const key = `${a.accountId}/${a.patientId}`;
    if (!names.has(key)) {
      const ref = a.patientId === a.accountId
        ? db.collection('users').doc(a.accountId)
        : db.collection('users').doc(a.accountId).collection('family_members').doc(a.patientId);
      const snap = await ref.get();
      names.set(key, snap.exists ? snap.data().fullName || snap.data().email || '' : '');
    }
    a.patientName = names.get(key);
  }
  res.json(appointments);
}));

// PATCH /api/appointments/:id/status - nhân viên xác nhận, từ chối, hoàn tất lịch
// Body: { status: "confirmed" | "rejected" | "completed", reason? (bắt buộc khi rejected) }
// Khi completed có thể kèm: visit { diagnosis, result, notes },
// prescriptions [{ medicineName, dosage, frequency, durationDays, instructions }],
// invoice { items?: [{ name, quantity, unitPrice }], discount?, paymentMethod?, paid? }.
// Cùng transaction tạo visit_{id}, rx_{id} (nếu có thuốc), inv_{id} và thông báo visit_result.
router.patch('/:id/status', auth, requireStaff, asyncHandler(async (req, res) => {
  const body = req.body || {};
  const status = typeof body.status === 'string' ? body.status.trim().toLowerCase() : '';
  const notice = STATUS_NOTIFICATIONS[status];
  if (!notice) {
    return res.status(400).json({ message: 'status phải là confirmed, rejected hoặc completed' });
  }
  if (body.reason !== undefined && body.reason !== null && typeof body.reason !== 'string') {
    return res.status(400).json({ message: 'Lý do phải là chuỗi' });
  }
  const reason = typeof body.reason === 'string' ? body.reason.trim() : '';
  if (status === 'rejected' && !reason) {
    return res.status(400).json({ message: 'Từ chối lịch hẹn phải ghi lý do' });
  }
  if (reason.length > 500) {
    return res.status(400).json({ message: 'Lý do tối đa 500 ký tự' });
  }
  const hasClinical = ['visit', 'prescriptions', 'invoice'].some((key) => body[key] !== undefined);
  if (hasClinical && status !== 'completed') {
    return res.status(400).json({ message: 'visit, prescriptions, invoice chỉ dùng khi hoàn tất lịch' });
  }
  const clinical = status === 'completed' ? parseCompletionBody(body) : null;

  const appointmentRef = db.collection('appointments').doc(req.params.id);
  // Id cố định: mỗi lịch chỉ có 1 thông báo cho mỗi trạng thái.
  const notificationRef = db.collection('notifications').doc(`${req.params.id}_${status}`);

  const result = await db.runTransaction(async (transaction) => {
    const appointmentSnap = await transaction.get(appointmentRef);
    if (!appointmentSnap.exists) throw new ApiError(404, 'Không tìm thấy lịch hẹn');
    const appointment = appointmentSnap.data();
    const current = String(appointment.status || '').toLowerCase();
    if (!canTransition(current, status)) {
      throw new ApiError(409, `Không thể chuyển lịch hẹn từ "${current || 'không rõ'}" sang "${status}"`);
    }
    const notificationSnap = await transaction.get(notificationRef);
    if (notificationSnap.exists) {
      throw new ApiError(409, 'Lịch hẹn đã được cập nhật trạng thái này trước đó');
    }
    const release = status === 'rejected' ? await readRelease(transaction, appointment) : null;
    const completion = clinical
      ? await readCompletion(transaction, appointmentSnap.id, appointment, clinical)
      : null;
    const followUpRef = status === 'confirmed'
      ? null
      : await readLinkedFollowUp(transaction, appointmentSnap.id, appointment);

    const now = new Date();
    const update = { status, statusUpdatedAt: now, statusUpdatedBy: req.user.uid };
    if (reason) update.statusReason = reason;
    if (completion) update.visitId = completion.ids.visitId;
    transaction.update(appointmentRef, update);
    if (release) {
      writeRelease(transaction, appointmentSnap.id, release);
      reopenFollowUp(transaction, followUpRef, now);
      // Nhắc lịch đã gửi trước đó không còn đúng nữa.
      transaction.delete(db.collection('notifications').doc(
        appointmentReminderId(appointmentSnap.id, appointment.date, appointment.startTime)));
    }
    if (status === 'completed') completeFollowUp(transaction, followUpRef, now);
    const visit = completion
      ? writeCompletion(transaction, {
        appointmentId: appointmentSnap.id,
        appointment,
        input: clinical,
        read: completion,
        staffUid: req.user.uid,
        now,
      })
      : null;
    transaction.set(notificationRef, {
      userId: appointment.accountId,
      title: notice.title,
      body: notice.body(appointment, reason),
      type: notice.type,
      refId: visit ? visit.id : appointmentSnap.id,
      ...(visit ? { appointmentId: appointmentSnap.id, patientId: appointment.patientId } : {}),
      isRead: false,
      createdAt: now,
    });

    return { id: appointmentSnap.id, ...appointment, ...update, ...(visit ? { visit } : {}) };
  });

  res.json(result);
}));

// GET /api/appointments/:id - chỉ chủ tài khoản được xem
router.get('/:id', auth, asyncHandler(async (req, res) => {
  const snapshot = await db.collection('appointments').doc(req.params.id).get();
  if (!snapshot.exists) return res.status(404).json({ message: 'Không tìm thấy lịch hẹn' });
  const data = snapshot.data();
  if (data.accountId !== req.user.uid) {
    return res.status(403).json({ message: 'Bạn không có quyền xem lịch hẹn này' });
  }
  res.json({ id: snapshot.id, ...data });
}));

// PATCH /api/appointments/:id/cancel - hủy lịch tương lai và giải phóng slot
router.patch('/:id/cancel', auth, asyncHandler(async (req, res) => {
  const uid = req.user.uid;
  const appointmentRef = db.collection('appointments').doc(req.params.id);
  const notificationRef = db.collection('notifications').doc();

  const result = await db.runTransaction(async (transaction) => {
    const appointmentSnap = await transaction.get(appointmentRef);
    if (!appointmentSnap.exists) throw new ApiError(404, 'Không tìm thấy lịch hẹn');
    const appointment = appointmentSnap.data();
    if (appointment.accountId !== uid) throw new ApiError(403, 'Bạn không có quyền hủy lịch hẹn này');
    if (!isAppointmentActive(appointment) || ['completed'].includes(String(appointment.status || '').toLowerCase())) {
      throw new ApiError(400, 'Lịch hẹn này đã được hủy hoặc hoàn tất');
    }
    if (!appointment.date || !appointment.startTime || !isFutureAppointment(appointment.date, appointment.startTime)) {
      throw new ApiError(400, 'Chỉ có thể hủy lịch hẹn chưa diễn ra');
    }
    const release = await readRelease(transaction, appointment);
    const followUpRef = await readLinkedFollowUp(transaction, appointmentSnap.id, appointment);

    const now = new Date();
    transaction.update(appointmentRef, { status: 'cancelled', cancelledAt: now });
    writeRelease(transaction, appointmentSnap.id, release);
    reopenFollowUp(transaction, followUpRef, now);
    transaction.delete(db.collection('notifications').doc(
      appointmentReminderId(appointmentSnap.id, appointment.date, appointment.startTime)));
    transaction.set(notificationRef, {
      userId: uid,
      title: 'Đã hủy lịch hẹn',
      body: `Lịch hẹn ngày ${appointment.date} lúc ${appointment.startTime} đã được hủy.`,
      type: 'appointment_cancelled',
      refId: appointmentSnap.id,
      isRead: false,
      createdAt: now,
    });

    return { id: appointmentSnap.id, status: 'cancelled' };
  });

  res.json(result);
}));

module.exports = router;
