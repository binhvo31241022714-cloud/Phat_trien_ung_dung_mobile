const router = require('express').Router();
const {
  asyncHandler,
  buildBookingQuote,
  loadSchedulingData,
  doctorProvidesServices,
  appointmentConflicts,
  slotConflicts,
  scheduleInterval,
  isValidDateKey,
  isFutureAppointment,
  toTimeString,
} = require('../utils/booking');

function parseRequestedServiceIds(value) {
  if (value == null || value === '') return [];
  if (Array.isArray(value)) return value;
  return String(value).split(',').map((id) => id.trim()).filter(Boolean);
}

// GET /api/availability?date=YYYY-MM-DD&durationMinutes=30&doctorId=doc_01&comboId=combo_01
router.get('/', asyncHandler(async (req, res) => {
  const date = String(req.query.date || '');
  if (!isValidDateKey(date)) {
    return res.status(400).json({ message: 'date phải theo định dạng YYYY-MM-DD' });
  }

  const requestedDoctorId = typeof req.query.doctorId === 'string' && req.query.doctorId.trim()
    ? req.query.doctorId.trim()
    : null;
  const comboId = typeof req.query.comboId === 'string' && req.query.comboId.trim()
    ? req.query.comboId.trim()
    : null;
  const serviceIds = parseRequestedServiceIds(req.query.serviceIds);

  let durationMinutes;
  let requiredServiceIds = [...serviceIds];
  if (comboId || serviceIds.length > 0) {
    const quote = await buildBookingQuote({ comboId, serviceIds });
    requiredServiceIds = quote.serviceIds;
    durationMinutes = quote.durationMinutes;
  }
  if (req.query.durationMinutes !== undefined) {
    durationMinutes = Number(req.query.durationMinutes);
  }
  if (!Number.isInteger(durationMinutes) || durationMinutes <= 0 || durationMinutes > 24 * 60) {
    return res.status(400).json({ message: 'durationMinutes phải là số nguyên dương (hoặc truyền comboId để tự tính)' });
  }

  const scheduling = await loadSchedulingData(date);
  let candidateDoctors = scheduling.doctors.filter((doctor) => doctor.isActive !== false);

  if (requestedDoctorId) {
    const selected = candidateDoctors.find((doctor) => doctor.id === requestedDoctorId);
    if (!selected) {
      const exists = scheduling.doctors.some((doctor) => doctor.id === requestedDoctorId);
      return res.status(exists ? 400 : 404).json({
        message: exists ? 'Bác sĩ đã ngừng hoạt động' : 'Không tìm thấy bác sĩ',
      });
    }
    if (!doctorProvidesServices(selected, requiredServiceIds)) {
      return res.status(400).json({ message: 'Bác sĩ không thực hiện được tất cả dịch vụ đã chọn trong combo/dịch vụ này' });
    }
    candidateDoctors = [selected];
  } else if (requiredServiceIds.length > 0) {
    candidateDoctors = candidateDoctors.filter((doctor) =>
      doctorProvidesServices(doctor, requiredServiceIds),
    );
  }

  const slots = [];
  for (const doctor of candidateDoctors) {
    const schedules = scheduling.schedules.filter((schedule) =>
      schedule.doctorId === doctor.id && schedule.isAvailable !== false,
    );
    const seenStarts = new Set();

    for (const schedule of schedules) {
      const interval = scheduleInterval(schedule, date);
      if (!interval) continue;

      for (let startMinute = interval.startMinute;
        startMinute + durationMinutes < 24 * 60 && startMinute + durationMinutes <= interval.endMinute;
        startMinute += interval.slotMinutes) {
        const endMinute = startMinute + durationMinutes;
        const startTime = toTimeString(startMinute);
        const endTime = toTimeString(endMinute);
        const key = `${doctor.id}|${startTime}`;
        if (seenStarts.has(key)) continue;
        seenStarts.add(key);

        if (!isFutureAppointment(date, startTime)) continue;
        if (appointmentConflicts(scheduling.appointments, doctor.id, date, startMinute, endMinute)) continue;
        if (slotConflicts(scheduling.locks, doctor.id, date, startMinute, endMinute)) continue;

        slots.push({
          doctorId: doctor.id,
          doctorName: doctor.name || '',
          date,
          startTime,
          endTime,
          durationMinutes,
        });
      }
    }
  }

  slots.sort((a, b) => a.startTime.localeCompare(b.startTime) || a.doctorName.localeCompare(b.doctorName));
  res.json({ date, durationMinutes, doctorId: requestedDoctorId, slots, count: slots.length });
}));

module.exports = router;
