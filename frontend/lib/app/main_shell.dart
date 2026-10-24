import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/user_profile.dart';
import '../data/providers/patient_data_provider.dart';
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

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  UserProfile? _appliedProfile;

  @override
  void initState() {
    super.initState();
    // Vào trang chính thì tải hồ sơ và danh mục từ API.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileProvider>().ensureLoaded();
      // Dịch vụ, combo, bác sĩ và mục yêu thích.
      context.read<CatalogProvider>().ensureLoaded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Có hồ sơ mới thì đổi tên "Bản thân" trong dữ liệu đặt lịch/hồ sơ khám.
    final profile = context.watch<ProfileProvider>().profile;
    if (profile != null && !identical(profile, _appliedProfile)) {
      _appliedProfile = profile;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PatientDataProvider>().applyAccountProfile(
            name: profile.fullName,
            phone: profile.phone,
            dateOfBirth: profile.birthday);
      });
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
