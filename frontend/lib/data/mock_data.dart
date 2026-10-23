import 'package:flutter/material.dart';

import 'models/appointment.dart';
import 'models/article.dart';
import 'models/dental_service.dart';
import 'models/doctor.dart';
import 'models/patient.dart';
import 'models/patient_records.dart';

class MockData {
  const MockData._();

  static final patients = List<Patient>.unmodifiable([
    Patient(
      id: 'patient-001',
      fullName: 'Nguyễn Minh Anh',
      phone: '0903 456 789',
      dateOfBirth: DateTime(1995, 4, 18),
      relationship: 'Tôi',
      isPrimary: true,
    ),
    Patient(
      id: 'patient-002',
      fullName: 'Nguyễn Hải Nam',
      phone: '0912 345 678',
      dateOfBirth: DateTime(2015, 9, 7),
      relationship: 'Con',
    ),
  ]);

  static const services = [
    DentalService(
      id: 'service-checkup',
      name: 'Khám tổng quát',
      description: 'Khám răng miệng và tư vấn chăm sóc cá nhân.',
      price: 150000,
      durationMinutes: 30,
      icon: Icons.health_and_safety_outlined,
      category: 'Khám và tư vấn',
      isPopular: true,
    ),
    DentalService(
      id: 'service-cleaning',
      name: 'Cạo vôi, đánh bóng',
      description: 'Làm sạch mảng bám, chăm sóc nướu nhẹ nhàng.',
      price: 350000,
      durationMinutes: 45,
      icon: Icons.cleaning_services_outlined,
      category: 'Chăm sóc răng',
      isPopular: true,
    ),
    DentalService(
      id: 'service-combo-family',
      name: 'Combo chăm sóc nụ cười',
      description: 'Khám tổng quát, cạo vôi và đánh bóng răng.',
      price: 450000,
      durationMinutes: 60,
      icon: Icons.auto_awesome_outlined,
      category: 'Chăm sóc răng',
      isCombo: true,
    ),
    DentalService(
      id: 'service-whitening',
      name: 'Tẩy trắng răng',
      description: 'Tư vấn và thực hiện tẩy trắng theo tình trạng răng.',
      price: 2500000,
      durationMinutes: 90,
      icon: Icons.sentiment_satisfied_alt_outlined,
      category: 'Thẩm mỹ nha khoa',
    ),
  ];

  static const doctors = [
    Doctor(
      id: 'doctor-lan',
      fullName: 'BS. Trần Ngọc Lan',
      specialty: 'Nha khoa tổng quát',
      experienceYears: 12,
      rating: 4.9,
      reviewCount: 128,
      introduction:
          'Tận tâm trong thăm khám và tư vấn chăm sóc răng miệng gia đình.',
    ),
    Doctor(
      id: 'doctor-minh',
      fullName: 'BS. Lê Hoàng Minh',
      specialty: 'Nha khoa thẩm mỹ',
      experienceYears: 9,
      rating: 4.8,
      reviewCount: 96,
      introduction:
          'Tập trung vào điều trị bảo tồn và các phương pháp thẩm mỹ an toàn.',
    ),
    Doctor(
      id: 'doctor-thao',
      fullName: 'BS. Phạm Thu Thảo',
      specialty: 'Nha khoa trẻ em',
      experienceYears: 7,
      rating: 4.9,
      reviewCount: 84,
      introduction:
          'Đồng hành cùng trẻ nhỏ với cách thăm khám nhẹ nhàng, thân thiện.',
    ),
  ];

  static final articles = List<Article>.unmodifiable([
    Article(
      id: 'article-brushing',
      title: 'Chải răng đúng cách để bảo vệ nụ cười',
      summary:
          'Những bước đơn giản giúp làm sạch răng hiệu quả và hạn chế tổn thương nướu.',
      category: 'Chăm sóc răng',
      publishedAt: DateTime(2026, 9, 18),
      readingMinutes: 4,
    ),
    Article(
      id: 'article-child',
      title: 'Khi nào nên đưa trẻ đi khám nha khoa?',
      summary:
          'Gợi ý lịch thăm khám phù hợp để trẻ làm quen với việc chăm sóc răng miệng.',
      category: 'Sức khỏe gia đình',
      publishedAt: DateTime(2026, 9, 10),
      readingMinutes: 3,
    ),
    Article(
      id: 'article-floss',
      title: 'Dùng chỉ nha khoa an toàn mỗi ngày',
      summary:
          'Cách vệ sinh kẽ răng nhẹ nhàng để hỗ trợ thói quen chăm sóc răng toàn diện.',
      category: 'Kiến thức nha khoa',
      publishedAt: DateTime(2026, 8, 26),
      readingMinutes: 5,
    ),
  ]);

  static final appointments = List<Appointment>.unmodifiable([
    Appointment(
      id: 'appointment-20261024',
      patientId: 'patient-001',
      doctorId: 'doctor-lan',
      serviceIds: ['service-cleaning'],
      scheduledAt: DateTime(2026, 10, 24, 9, 30),
      status: AppointmentStatus.confirmed,
      note: 'Vui lòng đến trước giờ hẹn 10 phút.',
    ),
    Appointment(
      id: 'appointment-20261012',
      patientId: 'patient-001',
      doctorId: 'doctor-minh',
      serviceIds: ['service-checkup'],
      scheduledAt: DateTime(2026, 10, 12, 14),
      status: AppointmentStatus.completed,
    ),
    Appointment(
      id: 'appointment-20261026-child',
      patientId: 'patient-002',
      doctorId: 'doctor-thao',
      serviceIds: ['service-checkup'],
      scheduledAt: DateTime(2026, 10, 26, 10),
      status: AppointmentStatus.pending,
    ),
  ]);

  static final visits = List<Visit>.unmodifiable([
    Visit(
      id: 'visit-20261012',
      appointmentId: 'appointment-20261012',
      doctorId: 'doctor-minh',
      serviceIds: ['service-checkup'],
      patientId: 'patient-001',
      visitedAt: DateTime(2026, 10, 12, 14),
      clinic: 'Cơ sở Quận 3',
      diagnosis: 'Răng và nướu ổn định',
      note: 'Tiếp tục chải răng đúng cách, tái khám định kỳ sau 6 tháng.',
    ),
  ]);

  static final prescriptions = List<Prescription>.unmodifiable([
    Prescription(
      id: 'prescription-20261012',
      visitId: 'visit-20261012',
      issuedAt: DateTime(2026, 10, 12, 14, 30),
      items: [],
      instructions: 'Không có thuốc được kê trong lần khám này.',
    ),
  ]);

  static final receipts = List<Receipt>.unmodifiable([
    Receipt(
      id: 'receipt-20261012',
      appointmentId: 'appointment-20261012',
      issuedAt: DateTime(2026, 10, 12, 14, 45),
      amount: 150000,
      paymentMethod: 'Thanh toán tại quầy',
      subtotal: 150000,
      items: const [ReceiptItem(name: 'Khám tổng quát', price: 150000)],
    ),
  ]);

  static const treatmentPlans = [
    TreatmentPlan(
      id: 'treatment-plan-001',
      patientId: 'patient-001',
      title: 'Chăm sóc răng định kỳ',
      description: 'Khám tổng quát và vệ sinh răng miệng định kỳ.',
      completedVisits: 1,
      totalVisits: 2,
      sessions: [
        TreatmentSession(title: 'Buổi 1', completed: true),
        TreatmentSession(title: 'Buổi 2', completed: false),
      ],
    ),
  ];

  static final followups = List<Followup>.unmodifiable([
    Followup(
      id: 'followup-20270412',
      patientId: 'patient-001',
      doctorId: 'doctor-lan',
      scheduledAt: DateTime(2027, 4, 12, 9),
      note: 'Tái khám và kiểm tra sức khỏe răng miệng định kỳ.',
    ),
  ]);

  static final notifications = List<PatientNotification>.unmodifiable([
    PatientNotification(
      id: 'notification-appointment',
      category: NotificationCategory.appointment,
      appointmentId: 'appointment-20261024',
      title: 'Nhắc lịch hẹn',
      message: 'Bạn có lịch cạo vôi răng vào 09:30 ngày 24/10/2026.',
      createdAt: DateTime(2026, 10, 20, 8),
    ),
    PatientNotification(
      id: 'notification-record',
      title: 'Hồ sơ khám đã cập nhật',
      message: 'Biên nhận lần khám ngày 12/10/2026 đã có trong hồ sơ.',
      createdAt: DateTime(2026, 10, 12, 15),
      isRead: true,
    ),
  ]);
}
