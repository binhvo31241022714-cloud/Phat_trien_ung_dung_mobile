import '../../core/widgets/horizontal_card_carousel.dart';
import '../../data/models/home_appointment.dart';
import '../../core/config/app_config.dart';
import '../../providers/content_provider.dart';
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
import '../../core/widgets/network_image_or_icon.dart';
import '../../data/models/appointment.dart';
import '../../data/models/article.dart';
import '../../data/models/dental_service.dart';
import '../../data/models/doctor.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/catalog_provider.dart';
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
    final content = AppConfig.current.dataSource == DataSource.api
        ? context.watch<ContentProvider>()
        : null;
    final articles = content == null
        ? data.articles
        : (content.home?.articles ?? <Article>[]);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extraScale = scale > 1 ? scale - 1 : 0.0;
    final now = DateTime.now();
    final upcomingAppointments = content != null
        ? <Appointment>[
            if (content.home?.appointment != null) content.home!.appointment!
          ]
        : data.appointments
            .where(
              (appointment) =>
                  appointment.patientId == data.appointmentPatientId &&
                  appointment.status.isUpcomingStatus &&
                  !appointment.scheduledAt.isBefore(now),
            )
            .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    // Dịch vụ và bác sĩ lấy từ API. API chưa có cờ "nổi bật" nên lấy 6 dịch
    // vụ đầu tiên.
    context.watch<CatalogProvider>();
    final featuredServices = content == null
        ? data.services.take(6).toList()
        : (content.home?.services ?? <DentalService>[]);
    final doctors =
        content == null ? data.doctors : (content.home?.doctors ?? []);

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
                          icon: Badge(
                              isLabelVisible: (content?.unreadCount ?? 0) > 0,
                              label: Text('${content?.unreadCount ?? 0}'),
                              child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: AppColors.textPrimary)),
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
                  if (content?.errors['unread'] != null)
                    Row(children: [
                      const Expanded(
                          child: Text('Chưa tải được số thông báo chưa đọc.')),
                      TextButton(
                          onPressed: content!.loadUnread,
                          child: const Text('Thử lại'))
                    ]),
                  _contentState(content) ??
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
                  _contentState(content) ??
                      (featuredServices.isEmpty
                          ? const Center(
                              child: Text('Chưa có dịch vụ nổi bật.'))
                          : HorizontalCardCarousel(
                              key: const ValueKey(
                                  'home-featuredServices-carousel'),
                              label: 'Dịch vụ nha khoa',
                              navigationCenterY: 43,
                              itemWidth: 176,
                              itemHeight: 182 + 140 * extraScale,
                              itemCount: featuredServices.length,
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
                            )),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.groups_rounded,
                    title: 'Đội ngũ bác sĩ',
                    actionText: 'Xem tất cả',
                    onAction: () => CatalogNavigation.open(
                        context, 'Đội ngũ bác sĩ', const DoctorListScreen()),
                  ),
                  const SizedBox(height: 12),
                  _contentState(content) ??
                      (doctors.isEmpty
                          ? const Center(
                              child: Text('Chưa có thông tin bác sĩ.'))
                          : HorizontalCardCarousel(
                              key: const ValueKey('home-doctors-carousel'),
                              label: 'Bác sĩ',
                              navigationCenterY: 42,
                              itemWidth: 120,
                              itemHeight: 156 + 90 * extraScale,
                              itemCount: doctors.length,
                              itemBuilder: (context, index) {
                                final doctor = doctors[index];
                                return _DoctorTile(
                                  doctor: doctor,
                                  onTap: () => CatalogNavigation.open(
                                      context,
                                      'Chi tiết bác sĩ',
                                      DoctorDetailScreen(doctor: doctor)),
                                );
                              },
                            )),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.menu_book_rounded,
                    title: 'Kiến thức nha khoa',
                    actionText: 'Xem tất cả',
                    onAction: () => CatalogNavigation.open(context,
                        'Kiến thức nha khoa', const ArticleListScreen()),
                  ),
                  const SizedBox(height: 12),
                  _contentState(content) ??
                      (articles.isEmpty
                          ? const Center(child: Text('Chưa có bài viết.'))
                          : HorizontalCardCarousel(
                              key: const ValueKey('home-articles-carousel'),
                              label: 'Kiến thức nha khoa',
                              navigationCenterY: 58,
                              itemWidth: 180,
                              itemHeight: 206 + 160 * extraScale,
                              itemCount: articles.length,
                              itemBuilder: (context, index) {
                                final article = articles[index];
                                return _ArticleTile(
                                  article: article,
                                  onTap: () => CatalogNavigation.open(
                                      context,
                                      'Chi tiết bài viết',
                                      ArticleDetailScreen(article: article)),
                                );
                              },
                            )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Đang tải hoặc lỗi thì trả về widget tương ứng; có dữ liệu thì null.
  Widget? _contentState(ContentProvider? content) {
    if (content == null) return null;
    if (!content.signedIn) {
      return const Center(child: Text('Vui lòng đăng nhập để xem Trang chủ.'));
    }
    if (content.loading('home') ||
        content.home == null && content.errors['home'] == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (content.errors['home'] != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(content.errors['home']!, textAlign: TextAlign.center),
        TextButton(onPressed: content.loadHome, child: const Text('Thử lại'))
      ]));
    }
    return null;
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
                            _weekDayText(
                                nextAppointment.displayScheduledAt.weekday),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nextAppointment.displayScheduledAt.day.toString(),
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '${_monthText(nextAppointment.displayScheduledAt.month)} ${nextAppointment.displayScheduledAt.year}',
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
                                        _appointmentTime(nextAppointment),
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
                              context: context,
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
                            _doctorName(nextAppointment, context),
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

  String _appointmentTime(Appointment appointment) {
    final start = _formatTime(appointment.displayScheduledAt);
    final end = appointment.displayEndAt;
    if (end != null && end.isAfter(appointment.displayScheduledAt)) {
      return '$start - ${_formatTime(end)}';
    }
    // API Home mapping already applies only an explicitly supplied duration.
    return start;
  }

  String _firstServiceName(Appointment appointment,
      {required BuildContext context}) {
    if (appointment is HomeAppointment && appointment.serviceName != null) {
      return appointment.serviceName!;
    }
    if (appointment.serviceIds.isEmpty) return 'Dịch vụ';
    final services = AppConfig.current.dataSource == DataSource.api
        ? context.read<CatalogProvider>().services
        : context.read<PatientDataProvider>().services;
    for (final service in services) {
      if (service.id == appointment.serviceIds.first &&
          service.name.trim().isNotEmpty) {
        return service.name;
      }
    }
    return 'Chưa có thông tin dịch vụ';
  }

  String _doctorName(Appointment appointment, BuildContext context) {
    if (AppConfig.current.dataSource == DataSource.api &&
        appointment.doctorName?.trim().isNotEmpty == true) {
      return appointment.doctorName!.trim();
    }
    if (appointment.doctorId == null || appointment.doctorId!.trim().isEmpty) {
      return 'Chờ phân công';
    }
    final doctors = AppConfig.current.dataSource == DataSource.api
        ? context.read<CatalogProvider>().doctors
        : context.read<PatientDataProvider>().doctors;
    for (final doctor in doctors) {
      if (doctor.id == appointment.doctorId &&
          doctor.fullName.trim().isNotEmpty) {
        return doctor.fullName;
      }
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
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: NetworkImageOrIcon(
                url: service.imageUrl,
                icon: service.icon,
                iconSize: 28,
                color: AppColors.primary,
                width: double.infinity,
                height: 62,
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
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFDAEBFF),
                borderRadius: BorderRadius.circular(42),
              ),
              child: NetworkImageOrIcon(
                url: doctor.avatarUrl,
                icon: Icons.person_rounded,
                iconSize: 40,
                color: AppColors.primary,
                width: 84,
                height: 84,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: article.imageUrl?.trim().isNotEmpty == true
                    ? Image.network(
                        article.imageUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.menu_book_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.menu_book_rounded,
                        size: 38,
                        color: AppColors.primary,
                      ),
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
                    article.hasPublishedDate
                        ? formatVietnameseDate(article.publishedAt)
                        : '',
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
