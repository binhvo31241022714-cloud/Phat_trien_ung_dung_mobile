import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/patient_navigation.dart';
import '../../features/shared/catalog_navigation.dart';
import '../../features/services/service_list_screen.dart';
import '../../features/services/service_detail_screen.dart';
import '../../features/doctors/doctor_list_screen.dart';
import '../../features/doctors/doctor_detail_screen.dart';
import '../../features/articles/article_list_screen.dart';
import '../../features/articles/article_detail_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/appointment.dart';
import '../../data/models/article.dart';
import '../../data/models/dental_service.dart';
import '../../data/models/doctor.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
        enabled: MainShellScope.maybeOf(context)?.selectedIndex == 0,
        onPopWithResult: (_) {
          if (MainShellScope.maybeOf(context)?.selectedIndex == 0 &&
              (_navigator.currentState?.canPop() ?? false)) {
            _navigator.currentState!.pop();
          }
        },
        child: Navigator(
            key: _navigator,
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings, builder: (_) => const _HomeOverview())),
      );
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview();
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    // Tên lấy từ /api/users/me; chưa tải được thì hiện email đăng nhập.
    final displayName = context
        .watch<ProfileProvider>()
        .displayName(context.watch<UserProvider>().account.email);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extraScale = scale > 1 ? scale - 1 : 0.0;
    final now = DateTime.now();
    final upcomingAppointments = data.appointments
        .where(
          (appointment) =>
              appointment.patientId == data.appointmentPatientId &&
              appointment.status != AppointmentStatus.cancelled &&
              appointment.status != AppointmentStatus.completed &&
              !appointment.scheduledAt.isBefore(now),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final featuredServices =
        data.services.where((service) => service.isPopular).take(6).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Trang chủ',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5EBF3)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          tooltip: 'Thông báo',
                          splashRadius: 18,
                          onPressed: () {
                            data.requestNotifications();
                            PatientNavigation.selectTab(context, 3);
                          },
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDAEBFF),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xin chào,',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildAppointmentCard(context, upcomingAppointments),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.stars_rounded,
                    title: 'Dịch vụ nổi bật',
                    actionText: 'Xem tất cả',
                    onAction: () => CatalogNavigation.open(
                        context, 'Dịch vụ nha khoa', const ServiceListScreen()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 182 + 140 * extraScale,
                    child: featuredServices.isEmpty
                        ? const Center(child: Text('Chưa có dịch vụ nổi bật.'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: featuredServices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final service = featuredServices[index];
                              return _ServiceTile(
                                service: service,
                                onTap: () => CatalogNavigation.open(
                                    context,
                                    'Chi tiết dịch vụ',
                                    ServiceDetailScreen(service: service)),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.groups_rounded,
                    title: 'Đội ngũ bác sĩ',
                    actionText: 'Xem tất cả',
                    onAction: () => CatalogNavigation.open(
                        context, 'Đội ngũ bác sĩ', const DoctorListScreen()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 156 + 90 * extraScale,
                    child: data.doctors.isEmpty
                        ? const Center(child: Text('Chưa có thông tin bác sĩ.'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: data.doctors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final doctor = data.doctors[index];
                              return _DoctorTile(
                                doctor: doctor,
                                onTap: () => CatalogNavigation.open(
                                    context,
                                    'Chi tiết bác sĩ',
                                    DoctorDetailScreen(doctor: doctor)),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.menu_book_rounded,
                    title: 'Kiến thức nha khoa',
                    actionText: 'Xem tất cả',
                    onAction: () => CatalogNavigation.open(context,
                        'Kiến thức nha khoa', const ArticleListScreen()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 206 + 160 * extraScale,
                    child: data.articles.isEmpty
                        ? const Center(child: Text('Chưa có bài viết.'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: data.articles.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final article = data.articles[index];
                              return _ArticleTile(
                                article: article,
                                onTap: () => CatalogNavigation.open(
                                    context,
                                    'Chi tiết bài viết',
                                    ArticleDetailScreen(article: article)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    List<Appointment> upcomingAppointments,
  ) {
    final nextAppointment =
        upcomingAppointments.isNotEmpty ? upcomingAppointments.first : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: nextAppointment == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                      'Lịch hẹn sắp tới',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bạn chưa có lịch hẹn nào trong thời gian tới.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => PatientNavigation.selectTab(context, 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Đặt lịch ngay'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Lịch hẹn sắp tới',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDEEFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Sắp diễn ra',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 112,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEBFA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _weekDayText(nextAppointment.scheduledAt.weekday),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nextAppointment.scheduledAt.day.toString(),
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '${_monthText(nextAppointment.scheduledAt.month)} ${nextAppointment.scheduledAt.year}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${_formatTime(nextAppointment.scheduledAt)} - ${_formatTime(nextAppointment.scheduledAt.add(const Duration(minutes: 30)))}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _firstServiceName(
                              nextAppointment,
                              data: context.read<PatientDataProvider>(),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _doctorName(nextAppointment,
                                context.read<PatientDataProvider>()),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 150,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final data =
                                      context.read<PatientDataProvider>();
                                  data.focusAppointmentsFor(
                                      nextAppointment.patientId,
                                      appointmentId: nextAppointment.id);
                                  PatientNavigation.selectTab(context, 2);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Xem chi tiết'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _weekDayText(int weekday) {
    const names = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return names[weekday - 1];
  }

  String _monthText(int month) {
    const names = [
      '',
      'THÁNG 1',
      'THÁNG 2',
      'THÁNG 3',
      'THÁNG 4',
      'THÁNG 5',
      'THÁNG 6',
      'THÁNG 7',
      'THÁNG 8',
      'THÁNG 9',
      'THÁNG 10',
      'THÁNG 11',
      'THÁNG 12',
    ];
    return names[month];
  }

  String _firstServiceName(Appointment appointment,
      {required PatientDataProvider data}) {
    if (appointment.serviceIds.isEmpty) return 'Dịch vụ';
    for (final service in data.services) {
      if (service.id == appointment.serviceIds.first) return service.name;
    }
    return 'Chưa có thông tin dịch vụ';
  }

  String _doctorName(Appointment appointment, PatientDataProvider data) {
    if (appointment.doctorId == null) return 'Chờ phân công';
    for (final doctor in data.doctors) {
      if (doctor.id == appointment.doctorId) return doctor.fullName;
    }
    return 'Chưa có thông tin bác sĩ';
  }
}

class _ServiceTile extends StatelessWidget {
  final DentalService service;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5EBF3)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 62,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                service.icon,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatVnd(service.price),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorTile extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;

  const _DoctorTile({
    required this.doctor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFDAEBFF),
                borderRadius: BorderRadius.circular(42),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              doctor.fullName.replaceFirst('BS. ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              doctor.specialty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const _ArticleTile({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5EBF3)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              article.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatVietnameseDate(article.publishedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
