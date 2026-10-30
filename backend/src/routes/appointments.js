const router = require('express').Router();
const auth = require('../middleware/auth');
const {
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
  shuffle,
} = require('../utils/booking');

function overlaps(startA, endA, startB, endB) {
  return startA < endB && startB < endA;
}

function isRetryableSlotConflict(error) {
  return error.status === 409 || error.code === 10 || error.code === '10' ||
    error.code === 'already-exists';
}

// POST /api/appointments
// Body: { patientId, doctorId?, serviceIds?, comboId?, date, startTime, voucherCode? }
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

  const date = String(body.date || '');
  if (!isValidDateKey(date)) {
    return res.status(400).json({ message: 'date phải theo định dạng YYYY-MM-DD' });
  }
  const startTime = String(body.startTime || '');
  const startMinute = parseTime(startTime, 'startTime');
  if (!isFutureAppointment(date, startTime)) {
    return res.status(400).json({ message: 'Không thể đặt lịch vào thời gian đã qua' });
  }

  const requestedDoctorId = typeof body.doctorId === 'string' && body.doctorId.trim()
    ? body.doctorId.trim()
    : null;
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

  const scheduling = await loadSchedulingData();
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

    const now = new Date();
    transaction.update(appointmentRef, { status: 'cancelled', cancelledAt: now });
    for (const { lock, snapshot } of locks) {
      if (snapshot.exists && snapshot.data().appointmentId === appointmentSnap.id) {
        transaction.delete(lock.ref);
      }
    }
    if (voucherSnap && voucherSnap.exists) {
      const currentUsed = Number(voucherSnap.data().usedCount || 0);
      if (currentUsed > 0) {
        transaction.update(voucherRef, { usedCount: currentUsed - 1 });
      }
    }
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
