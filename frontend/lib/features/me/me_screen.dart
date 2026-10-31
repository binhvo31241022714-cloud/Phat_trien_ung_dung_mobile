import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/patient_navigation.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/models/article.dart';
import '../../data/models/dental_service.dart';
import '../../data/models/doctor.dart';
import '../../data/models/family_member.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';
import '../../data/providers/patient_data_provider.dart';
import '../articles/article_detail_screen.dart';
import '../services/service_detail_screen.dart';
import '../doctors/doctor_detail_screen.dart';
import 'email_verification_card.dart';
import 'health_info_section.dart';
import 'me_widgets.dart';
import 'edit_profile_screen.dart';
import 'family_list_screen.dart';
import 'family_form_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'language_screen.dart';
import 'change_password_screen.dart';
import 'privacy_screen.dart';
import 'help_screen.dart';
import 'saved_items_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final _navigator = GlobalKey<NavigatorState>();
  int _notificationsVersion = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version =
        context.watch<PatientDataProvider>().notificationsOpenVersion;
    if (_notificationsVersion != version) {
      _notificationsVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigator.currentState?.popUntil((r) => r.isFirst);
        _navigator.currentState?.pushNamed(MeRoutes.notifications);
      });
    }
  }

  Route<void> _route(RouteSettings settings) {
    final arg = settings.arguments;
    final page = switch (settings.name) {
      MeRoutes.profile => const EditProfileScreen(),
      MeRoutes.family => const FamilyListScreen(),
      MeRoutes.familyForm => FamilyFormScreen(member: arg as FamilyMember?),
      MeRoutes.notifications => const NotificationsScreen(),
      MeRoutes.settings => const SettingsScreen(),
      MeRoutes.language => const LanguageScreen(),
      MeRoutes.password => const ChangePasswordScreen(),
      MeRoutes.privacy => const PrivacyScreen(),
      MeRoutes.help => const HelpScreen(),
      MeRoutes.saved => const SavedItemsScreen(),
      MeRoutes.article => _Detail(
          title: 'Chi tiết bài viết',
          child: ArticleDetailScreen(article: arg as Article)),
      MeRoutes.service => _Detail(
          title: 'Chi tiết dịch vụ',
          child: ServiceDetailScreen(service: arg as DentalService)),
      MeRoutes.doctor => _Detail(
          title: 'Chi tiết bác sĩ',
          child: DoctorDetailScreen(doctor: arg as Doctor)),
      _ => const _AccountOverview(),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    final active = MainShellScope.maybeOf(context)?.selectedIndex == 3;
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC)));
    return Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context)
              .textTheme
              .apply(bodyColor: Colors.black, displayColor: Colors.black),
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: meBlue),
          cardTheme: CardThemeData(
              color: const Color(0xFFF7F7F7),
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFD8D8D8)))),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: const StadiumBorder())),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 40),
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: const StadiumBorder())),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black)),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: border,
              enabledBorder: border,
              focusedBorder:
                  border.copyWith(borderSide: const BorderSide(color: meBlue))),
        ),
        child: NavigatorPopHandler<Object?>(
            enabled: active,
            onPopWithResult: (_) {
              if (active && (_navigator.currentState?.canPop() ?? false)) {
                _navigator.currentState!.pop();
              }
            },
            child: Navigator(key: _navigator, onGenerateRoute: _route)));
  }
}

class _AccountOverview extends StatelessWidget {
  const _AccountOverview();
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().account;
    final profile = context.watch<ProfileProvider>();
    return MePage(title: 'Tôi', children: [
      Center(
          child: MeAvatar(
              radius: 42, mediaId: profile.profile?.avatarMediaId)),
      const SizedBox(height: 12),
      Text(profile.displayName(user.email),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Tài khoản bệnh nhân',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF666666))),
      if (profile.profile?.health.hasWarning ?? false) ...[
        const SizedBox(height: 8),
        const Center(child: HealthWarningBadge()),
      ],
      // Chỉ nhắc, không chặn dùng app khi chưa xác minh.
      if (context.watch<UserProvider>().emailVerified == false) ...[
        const SizedBox(height: 16),
        const EmailVerificationCard(),
      ],
      const SizedBox(height: 20),
      // Lỗi tải hồ sơ: báo lỗi nhưng vẫn để menu và nút Đăng xuất dùng được.
      if (profile.profileError != null && !profile.profileLoading)
        MeCard(
            child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text('Chưa tải được hồ sơ: ${profile.profileError}')),
          TextButton(
              onPressed: profile.loadProfile, child: const Text('Thử lại')),
        ])),
      for (final item in const [
        ('Thông tin cá nhân', Icons.person_outline, MeRoutes.profile),
        ('Quản lý người thân', Icons.people_outline, MeRoutes.family),
        ('Thông báo', Icons.notifications_none, MeRoutes.notifications),
        ('Cài đặt', Icons.settings_outlined, MeRoutes.settings),
        ('Trợ giúp', Icons.help_outline, MeRoutes.help),
        ('Đã lưu', Icons.bookmark_border, MeRoutes.saved),
      ])
        MeCard(
            onTap: () => MeRoutes.open(context, item.$3),
            child: Row(children: [
              Icon(item.$2, color: meBlue, size: 22),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(item.$1,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
            ])),
      Theme(
          data: Theme.of(context).copyWith(
              outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: const StadiumBorder()))),
          child: SecondaryButton(
              label: 'Đăng xuất',
              icon: Icons.logout,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                            title: const Text('Đăng xuất khỏi tài khoản?'),
                            content: const Text(
                                'Bạn sẽ trở về màn hình chào mừng. Lần sau cần đăng nhập lại.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Hủy')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Đăng xuất'))
                            ]));
                if (confirmed == true && context.mounted) {
                  PatientNavigation.logout(context);
                }
              })),
    ]);
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      appBar: meAppBar(title),
      body: child);
}
