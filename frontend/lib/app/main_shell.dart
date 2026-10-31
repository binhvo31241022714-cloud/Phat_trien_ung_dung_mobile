import '../providers/content_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../data/models/family_member.dart';
import '../data/models/user_profile.dart';
import '../data/providers/patient_data_provider.dart';
import '../providers/appointments_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/profile_provider.dart';

import 'patient_navigation.dart';
import '../screens/home/home_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/records/records_home_screen.dart';
import '../features/me/me_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  UserProfile? _appliedProfile;
  List<FamilyMember>? _appliedFamily;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Vào trang chính thì tải hồ sơ và danh mục từ API.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profiles = context.read<ProfileProvider>();
      if (AppConfig.current.dataSource != DataSource.api) {
        profiles.ensureLoaded();
        return;
      }
      _loadAccount();
      // Dịch vụ, combo, bác sĩ và mục yêu thích.
      context.read<CatalogProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Quay lại app (có thể đã có nhắc lịch mới): cập nhật số chưa đọc trên chuông.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        AppConfig.current.dataSource != DataSource.api) {
      return;
    }
    final content = context.read<ContentProvider>();
    if (content.signedIn) content.loadUnread();
  }

  Future<void> _loadAccount() async {
    final profiles = context.read<ProfileProvider>();
    final records = context.read<PatientDataProvider>();
    final appointments = context.read<AppointmentsProvider>();
    final generation = records.sessionGeneration;
    bool current() => mounted && records.isSessionCurrent(generation);
    await profiles.ensureLoaded();
    if (!current() || profiles.profile == null) return;
    if (!profiles.familyLoaded) await profiles.loadFamily();
    if (!current()) return;
    records.syncPatients(profiles.profile!, profiles.family,
        generation: generation);
    await records.loadRecords();
    if (!current()) return;
    await appointments.ensureLoaded();
    if (!current()) return;
    records.replaceAppointments(appointments.appointments,
        generation: generation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profiles = context.watch<ProfileProvider>();
    // Thêm/sửa/xóa người thân xong thì ProfileProvider tải lại danh sách:
    // đồng bộ luôn người khám để tab Hồ sơ và Đặt lịch thấy ngay.
    final family = profiles.family;
    if (AppConfig.current.dataSource == DataSource.api &&
        profiles.familyLoaded &&
        profiles.profile != null &&
        !identical(family, _appliedFamily)) {
      _appliedFamily = family;
      final records = context.read<PatientDataProvider>();
      final generation = records.sessionGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final latest = profiles.profile;
        if (!mounted || !records.isSessionCurrent(generation) || latest == null) {
          return;
        }
        records.syncPatients(latest, profiles.family, generation: generation);
      });
    }

    // Có hồ sơ mới thì đổi tên "Bản thân" trong dữ liệu đặt lịch/hồ sơ khám.
    final profile = profiles.profile;
    if (profile != null && !identical(profile, _appliedProfile)) {
      _appliedProfile = profile;
      final records = context.read<PatientDataProvider>();
      final generation = records.sessionGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !records.isSessionCurrent(generation) ||
            records.patients.isEmpty) {
          return;
        }
        records.applyAccountProfile(
            name: profile.fullName,
            phone: profile.phone,
            dateOfBirth: profile.birthday,
            avatarMediaId: profile.avatarMediaId);
      });
    }
  }

  void _onTabSelected(int index) {
    if (index == 0 && AppConfig.current.dataSource == DataSource.api) {
      final content = context.read<ContentProvider>();
      content.loadHome();
      content.loadUnread();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.current.dataSource == DataSource.api &&
        context.watch<PatientDataProvider>().patients.isEmpty) {
      final profiles = context.watch<ProfileProvider>();
      return Scaffold(
          body: Center(
              child: profiles.profileError == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(profiles.profileError!),
                      TextButton(
                          onPressed: _loadAccount, child: const Text('Thử lại'))
                    ])));
    }
    return MainShellScope(
      onSelectTab: _onTabSelected,
      selectedIndex: _selectedIndex,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            HomeScreen(),
            BookingScreen(),
            RecordsHomeScreen(),
            MeScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            border: Border(
              top: BorderSide(color: Color(0xFFE5EBF3)),
            ),
          ),
          child: NavigationBarTheme(
              data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                      TextStyle(
                          fontSize: 11,
                          color: states.contains(WidgetState.selected)
                              ? const Color(0xFF247BF3)
                              : const Color(0xFF666666),
                          fontWeight: states.contains(WidgetState.selected)
                              ? FontWeight.w600
                              : FontWeight.normal))),
              child: NavigationBar(
                height: 72,
                backgroundColor: const Color(0xFFF5F7FA),
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                indicatorColor: const Color(0xFFEAF4FF),
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onTabSelected,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon:
                        Icon(Icons.home_rounded, color: Color(0xFF247BF3)),
                    label: 'Trang chủ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded,
                        color: Color(0xFF247BF3)),
                    label: 'Đặt lịch',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon:
                        Icon(Icons.folder_rounded, color: Color(0xFF247BF3)),
                    label: 'Hồ sơ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon:
                        Icon(Icons.person_rounded, color: Color(0xFF247BF3)),
                    label: 'Tôi',
                  ),
                ],
              )),
        ),
      ),
    );
  }
}
