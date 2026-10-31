import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/media/photo_picker.dart';
import '../../data/models/patient_records.dart';
import '../../data/services/media_service.dart';
import '../../core/network/api_client.dart';
import '../shared/media_image.dart';
import '../shared/photo_source_sheet.dart';
import 'records_widgets.dart';

const _maxPhotos = 30;

class TreatmentPhotosScreen extends StatelessWidget {
  const TreatmentPhotosScreen({required this.plan, super.key});
  final TreatmentPlan plan;
  @override
  Widget build(BuildContext context) =>
      AppConfig.current.dataSource == DataSource.api
          ? _ApiTreatmentPhotos(plan: plan)
          : _MockTreatmentPhotos(plan: plan);
}

/// Dữ liệu mẫu: chỉ xem ảnh có sẵn trong ứng dụng.
class _MockTreatmentPhotos extends StatelessWidget {
  const _MockTreatmentPhotos({required this.plan});
  final TreatmentPlan plan;
  @override
  Widget build(BuildContext context) => RecordsPage(
        title: 'Hình ảnh điều trị',
        children: [
          const RecordHeading('Hình ảnh trước – sau điều trị'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child:
                      _Photo(label: 'Trước điều trị', path: plan.beforeImage)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Photo(label: 'Sau điều trị', path: plan.afterImage)),
            ],
          ),
          if (plan.beforeImage == null && plan.afterImage == null)
            const Text('Ảnh minh họa chưa được tải lên.',
                style: TextStyle(color: Color(0xFF666666))),
        ],
      );
}

enum _Phase { before, after, other }

class _TreatmentPhoto {
  _TreatmentPhoto.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        phase = switch ((json['phase'] ?? json['type'])
            ?.toString()
            .trim()
            .toLowerCase()) {
          'before' || 'trước' => _Phase.before,
          'after' || 'sau' => _Phase.after,
          _ => _Phase.other,
        },
        mediaId = _text(json['mediaId']),
        imageUrl = _text(json['imageUrl']),
        note = _text(json['note']),
        canDelete = json['canDelete'] == true;
  final String id;
  final _Phase phase;
  final String? mediaId;
  final String? imageUrl;
  final String? note;
  final bool canDelete;

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}

class _ApiTreatmentPhotos extends StatefulWidget {
  const _ApiTreatmentPhotos({required this.plan});
  final TreatmentPlan plan;
  @override
  State<_ApiTreatmentPhotos> createState() => _ApiTreatmentPhotosState();
}

class _ApiTreatmentPhotosState extends State<_ApiTreatmentPhotos> {
  List<_TreatmentPhoto> _photos = const [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await MediaService.shared.treatmentPhotos(widget.plan.id);
      if (!mounted || request != _request) return;
      setState(() {
        _photos = rows.map(_TreatmentPhoto.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Không tải được hình ảnh điều trị.';
        _loading = false;
      });
    }
  }

  void _message(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add() async {
    final PhotoChoice? choice;
    try {
      choice = await choosePhoto(context, title: 'Thêm ảnh điều trị');
    } on PhotoPickException catch (e) {
      if (mounted) _message(e.message);
      return;
    }
    if (choice is! PhotoPicked || !mounted) return;
    final details = await showDialog<_UploadDetails>(
        context: context,
        builder: (_) => _UploadDialog(sessions: widget.plan.sessions));
    if (details == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await MediaService.shared.uploadTreatmentPhoto(widget.plan.id,
          phase: details.phase == _Phase.after ? 'after' : 'before',
          image: choice.image,
          sessionId: details.sessionId,
          note: details.note);
      if (!mounted) return;
      _message('Đã tải ảnh lên.');
      await _load();
    } catch (e) {
      if (mounted) {
        _message(e is ApiException ? e.message : 'Không tải được ảnh lên.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(_TreatmentPhoto photo) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Xóa ảnh?'),
              content: const Text('Ảnh sẽ bị xóa khỏi liệu trình.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Giữ ảnh')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Xóa')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    try {
      await MediaService.shared.deleteTreatmentPhoto(widget.plan.id, photo.id);
      MediaCache.evict(photo.mediaId);
      if (!mounted) return;
      _message('Đã xóa ảnh.');
      await _load();
    } catch (e) {
      if (mounted) {
        _message(e is ApiException ? e.message : 'Không xóa được ảnh.');
      }
    }
  }

  void _open(_TreatmentPhoto photo) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: _PhotoImage(photo, fit: BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Row(children: [
                IconButton(
                    tooltip: 'Đóng',
                    color: Colors.white,
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close)),
                const Spacer(),
                if (photo.canDelete)
                  IconButton(
                      tooltip: 'Xóa ảnh',
                      color: Colors.white,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _delete(photo);
                      },
                      icon: const Icon(Icons.delete_outline)),
              ]),
            ),
            if (photo.note != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Text(photo.note!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ),
          ]),
        ),
      );

  Widget _section(String title, List<_TreatmentPhoto> photos) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RecordHeading('$title (${photos.length})'),
        if (photos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Chưa có ảnh.',
                style: TextStyle(color: Color(0xFF666666))),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final photo in photos)
                  InkWell(
                    key: ValueKey('treatment-photo-${photo.id}'),
                    onTap: () => _open(photo),
                    borderRadius: BorderRadius.circular(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _PhotoImage(photo),
                    ),
                  ),
              ],
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final byPhase = {
      for (final phase in _Phase.values)
        phase: _photos.where((p) => p.phase == phase).toList(),
    };
    final full = _photos.length >= _maxPhotos;
    return RecordsPage(
      title: 'Hình ảnh điều trị',
      useRecordsState: false,
      onRefresh: _load,
      children: [
        const RecordHeading('Hình ảnh trước – sau điều trị'),
        if (_loading && _photos.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Column(children: [
            Text(_error!, textAlign: TextAlign.center),
            OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ])
        else ...[
          if (_photos.isEmpty) const RecordEmpty('Chưa có ảnh điều trị.'),
          if (_photos.isNotEmpty) ...[
            _section('Trước điều trị', byPhase[_Phase.before]!),
            _section('Sau điều trị', byPhase[_Phase.after]!),
            if (byPhase[_Phase.other]!.isNotEmpty)
              _section('Ảnh khác', byPhase[_Phase.other]!),
          ],
          Text('${_photos.length}/$_maxPhotos ảnh',
              style: const TextStyle(color: Color(0xFF666666))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('add-treatment-photo'),
              onPressed: _uploading || full ? null : _add,
              icon: _uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_uploading
                  ? 'Đang tải ảnh lên…'
                  : full
                      ? 'Đã đủ $_maxPhotos ảnh'
                      : 'Thêm ảnh'),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage(this.photo, {this.fit = BoxFit.cover});
  final _TreatmentPhoto photo;
  final BoxFit fit;

  static const _placeholder = ColoredBox(
      color: Color(0xFFDFE8F6),
      child: Center(
          child: Icon(Icons.image_outlined, color: recordsBlue, size: 28)));

  @override
  Widget build(BuildContext context) {
    final mediaId = photo.mediaId;
    final url = photo.imageUrl;
    if (mediaId != null) {
      return MediaImage(mediaId, fit: fit, error: _placeholder);
    }
    if (url != null && url.startsWith('https://')) {
      return Image.network(url,
          fit: fit,
          errorBuilder: (context, error, stack) => _placeholder);
    }
    return _placeholder;
  }
}

class _UploadDetails {
  const _UploadDetails(this.phase, this.sessionId, this.note);
  final _Phase phase;
  final String? sessionId;
  final String note;
}

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({required this.sessions});
  final List<TreatmentSession> sessions;
  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  _Phase _phase = _Phase.before;
  String? _sessionId;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions.where((s) => s.id.isNotEmpty).toList();
    return AlertDialog(
      title: const Text('Thông tin ảnh'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<_Phase>(
            segments: const [
              ButtonSegment(value: _Phase.before, label: Text('Trước')),
              ButtonSegment(value: _Phase.after, label: Text('Sau')),
            ],
            selected: {_phase},
            onSelectionChanged: (value) =>
                setState(() => _phase = value.first),
          ),
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _sessionId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Buổi điều trị'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Không gắn buổi')),
                for (final s in sessions)
                  DropdownMenuItem(value: s.id, child: Text(s.title)),
              ],
              onChanged: (value) => setState(() => _sessionId = value),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy')),
        FilledButton(
            key: const ValueKey('confirm-upload-photo'),
            onPressed: () => Navigator.pop(
                context, _UploadDetails(_phase, _sessionId, _note.text)),
            child: const Text('Tải lên')),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.label, this.path});
  final String label;
  final String? path;
  Widget placeholder() => const ColoredBox(
      color: Color(0xFFDFE8F6),
      child: Center(
          child: Icon(Icons.image_outlined, color: recordsBlue, size: 28)));
  @override
  Widget build(BuildContext context) => RecordCard(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
                aspectRatio: 1.5,
                child: path == null
                    ? placeholder()
                    : path!.startsWith('https://')
                        ? Image.network(path!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loading) =>
                                loading == null ? child : placeholder(),
                            errorBuilder: (context, error, stack) =>
                                placeholder())
                        : Image.asset(path!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                placeholder()))),
        const SizedBox(height: 8),
        Center(
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]);
}
