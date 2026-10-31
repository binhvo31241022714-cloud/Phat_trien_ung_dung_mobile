import 'appointment_api_status.dart';
import '../../data/api_client.dart' show ApiException;
import '../../providers/appointments_provider.dart';
import '../../data/services/booking_service.dart'
    show AppointmentCancellationInfo;
import '../../core/config/app_config.dart';
import '../../providers/catalog_provider.dart';
import '../../data/models/appointment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({required this.appointmentId, super.key});
  final String appointmentId;
  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen>
    with WidgetsBindingObserver {
  AppointmentCancellationInfo? _cancellation;
  String? _cancelError;
  bool _checking = true;
  bool _busy = false;
  bool _refreshInFlight = false;
  bool get isApi => AppConfig.current.dataSource == DataSource.api;
  @override
  void initState() {
    super.initState();
    if (isApi) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refresh();
        final catalog = context.read<CatalogProvider>();
        if (!catalog.loaded && !catalog.loading && catalog.error == null) {
          catalog.load();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isApi && mounted && state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  /// Luôn đọc lại lịch từ GET /api/appointments/:id khi mở màn hình, cập nhật
  /// cả AppointmentsProvider và PatientDataProvider. Trong lúc tải vẫn hiện dữ
  /// liệu cũ; nút hủy chỉ hiện theo dữ liệu mới.
  Future<void> _refresh() async {
    if (_refreshInFlight || _busy) return;
    _refreshInFlight = true;
    final data = context.read<PatientDataProvider>();
    final provider = context.read<AppointmentsProvider>();
    final generation = data.sessionGeneration;
    final providerGeneration = provider.sessionGeneration;
    setState(() {
      _checking = true;
      _cancellation = null;
      _cancelError = null;
    });
    try {
      final info = await provider.refreshOne(widget.appointmentId);
      if (!mounted ||
          !data.isSessionCurrent(generation) ||
          !provider.isSessionCurrent(providerGeneration)) {
        return;
      }
      final fresh = provider.appointments
          .where((a) => a.id == widget.appointmentId)
          .firstOrNull;
      if (fresh != null) {
        data.upsertApiAppointment(fresh, generation: generation);
      }
      setState(() => _cancellation = info);
    } catch (e) {
      if (!mounted ||
          !data.isSessionCurrent(generation) ||
          !provider.isSessionCurrent(providerGeneration)) {
        return;
      }
      if (e is ApiException && (e.statusCode == 403 || e.statusCode == 404)) {
        // Màn hình sẽ báo "Lịch hẹn không còn khả dụng."
        data.removeApiAppointment(widget.appointmentId, generation: generation);
        return;
      }
      setState(() => _cancelError = e is ApiException
          ? e.message
          : 'Không tải được thông tin mới nhất của lịch hẹn.');
    } finally {
      _refreshInFlight = false;
      if (mounted &&
          data.isSessionCurrent(generation) &&
          provider.isSessionCurrent(providerGeneration)) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _cancelApi() async {
    if (_busy || _cancellation == null) return;
    final data = context.read<PatientDataProvider>();
    final provider = context.read<AppointmentsProvider>();
    final generation = data.sessionGeneration;
    final providerGeneration = provider.sessionGeneration;
    final owners = data.patients.where((p) => p.isPrimary);
    if (owners.isEmpty || !_cancellation!.canCancelFor(owners.first.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _cancelError = null;
    });
    bool current() =>
        mounted &&
        data.isSessionCurrent(generation) &&
        provider.isSessionCurrent(providerGeneration);
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                  title: const Text('Hủy lịch hẹn?'),
                  content: const Text('Bạn có chắc muốn hủy lịch hẹn này?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Giữ lịch')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Xác nhận hủy'))
                  ]));
      if (!current() || confirmed != true) return;
      final error = await provider.cancel(widget.appointmentId,
          snapshot: _cancellation!.appointment);
      if (!current()) return;
      if (error != null) {
        setState(() => _cancelError = error);
        return;
      }
      final result =
          provider.appointments.where((a) => a.id == widget.appointmentId);
      if (result.isNotEmpty) {
        data.upsertApiAppointment(result.first, generation: generation);
      }
      setState(() => _cancellation = null);
      messenger.showSnackBar(const SnackBar(content: Text('Đã hủy lịch hẹn.')));
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  String _services(
      Appointment a, PatientDataProvider data, CatalogProvider? catalog) {
    if (!isApi) return serviceNames(data, a.serviceIds);
    if (a.serviceIds.isEmpty) return 'Chưa có thông tin dịch vụ';
    return a.serviceIds.map((id) {
      final matches = catalog!.services
          .where((s) => s.id == id && s.name.trim().isNotEmpty);
      if (matches.isNotEmpty) return matches.first.name;
      return catalog.loading || !catalog.loaded && catalog.error == null
          ? 'Đang tải dịch vụ…'
          : 'Chưa có thông tin dịch vụ';
    }).join(', ');
  }

  String _doctor(
      Appointment a, PatientDataProvider data, CatalogProvider? catalog) {
    if (!isApi) return doctorName(data, a.doctorId);
    if (a.doctorName?.trim().isNotEmpty == true) return a.doctorName!.trim();
    if (a.doctorId == null || a.doctorId!.trim().isEmpty) {
      return 'Chờ phân công';
    }
    final matches = catalog!.doctors
        .where((d) => d.id == a.doctorId && d.fullName.trim().isNotEmpty);
    if (matches.isNotEmpty) return matches.first.fullName;
    return catalog.loading || !catalog.loaded && catalog.error == null
        ? 'Đang tải bác sĩ…'
        : 'Chưa có thông tin bác sĩ';
  }

  Widget _refreshing() => const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Đang cập nhật trạng thái lịch hẹn…'),
      ]));

  Widget _catalogStatus(CatalogProvider catalog) {
    if (catalog.error != null) {
      return Row(children: [
        Expanded(child: Text(catalog.error!)),
        TextButton(
            onPressed: catalog.loading ? null : catalog.load,
            child: const Text('Thử lại'))
      ]);
    }
    return const Row(children: [
      SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2)),
      SizedBox(width: 8),
      Text('Đang tải danh mục…')
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final catalog = isApi ? context.watch<CatalogProvider>() : null;
    final matches =
        data.appointments.where((a) => a.id == widget.appointmentId);
    if (matches.isEmpty) {
      final source = isApi ? context.watch<AppointmentsProvider?>() : null;
      return RecordsPage(
          title: 'Chi tiết lịch hẹn',
          useRecordsState: false,
          onRefresh: isApi ? _refresh : null,
          children: [
            if (isApi) const AppointmentApiStatus(),
            if (isApi && _checking)
              _refreshing()
            else if (source?.loading != true && source?.error == null)
              const RecordEmpty('Lịch hẹn không còn khả dụng.'),
          ]);
    }
    final a = matches.first;
    final provider = isApi ? context.watch<AppointmentsProvider>() : null;
    final owners = data.patients.where((p) => p.isPrimary);
    final cancellable = isApi &&
        owners.isNotEmpty &&
        _cancellation?.canCancelFor(owners.first.id) == true &&
        a.status != AppointmentStatus.cancelled;
    return RecordsPage(
        title: 'Chi tiết lịch hẹn',
        useRecordsState: false,
        onRefresh: isApi ? _refresh : null,
        children: [
          if (isApi) const AppointmentApiStatus(),
          if (catalog != null &&
              (catalog.loading || !catalog.loaded || catalog.error != null))
            _catalogStatus(catalog),
          RecordCard(children: [
            appointmentBadge(a),
            RecordLine('Mã lịch hẹn', a.id),
            RecordLine('Bệnh nhân',
                data.patients.firstWhere((p) => p.id == a.patientId).fullName),
            RecordLine('Dịch vụ', _services(a, data, catalog)),
            RecordLine('Bác sĩ', _doctor(a, data, catalog)),
            RecordLine('Ngày giờ', appointmentDateText(a)),
            RecordLine('Ghi chú', a.note),
            RecordLine(
                'Tổng tiền', a.totalPrice > 0 ? formatVnd(a.totalPrice) : null),
            if (!isApi)
              const Text(
                  'Lịch hẹn demo. Thao tác hủy chỉ cập nhật dữ liệu trong ứng dụng.',
                  style: TextStyle(color: Color(0xFF666666))),
            if (isApi && _checking) _refreshing(),
            if (isApi && _cancelError != null) ...[
              Text(_cancelError!, style: const TextStyle(color: Colors.red)),
              TextButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Thử lại')),
            ],
            if (cancellable)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                          onPressed: _busy || provider!.isCancelling(a.id)
                              ? null
                              : _cancelApi,
                          child: Text(_busy || provider!.isCancelling(a.id)
                              ? 'Đang hủy…'
                              : 'Hủy lịch')))),
            if (!isApi && data.canCancelAppointment(a))
              RecordButton('Hủy lịch', () async {
                final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                          title: const Text('Hủy lịch hẹn?'),
                          content: const Text(
                              'Lịch hẹn sẽ được giữ lại với trạng thái Đã hủy trong bản demo.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Giữ lịch')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Xác nhận hủy'))
                          ],
                        ));
                if (confirmed == true && context.mounted) {
                  final cancelled = data.cancelAppointment(a.id);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(cancelled
                          ? 'Đã hủy lịch hẹn demo.'
                          : 'Lịch hẹn không còn đủ điều kiện hủy.')));
                }
              }),
          ])
        ]);
  }
}
