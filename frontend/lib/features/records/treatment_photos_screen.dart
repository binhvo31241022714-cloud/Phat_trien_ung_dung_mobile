import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../data/models/patient_records.dart';
import '../../data/services/records_service.dart';
import '../../core/network/api_client.dart';
import 'records_widgets.dart';

class TreatmentPhotosScreen extends StatelessWidget {
  const TreatmentPhotosScreen({required this.plan, super.key});
  final TreatmentPlan plan;
  @override
  Widget build(BuildContext context) => RecordsPage(
        title: 'Hình ảnh điều trị',
        children: [
          const RecordHeading('Hình ảnh trước – sau điều trị'),
          if (AppConfig.current.dataSource != DataSource.api)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _Photo(
                        label: 'Trước điều trị', path: plan.beforeImage)),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        _Photo(label: 'Sau điều trị', path: plan.afterImage)),
              ],
            )
          else
            FutureBuilder<List<dynamic>>(
              future: RecordsService().photos(plan.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final message = snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Không tải được hình ảnh điều trị.';
                  return Column(
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      OutlinedButton(
                        onPressed: () => (context as Element).markNeedsBuild(),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  );
                }
                String? before;
                String? after;
                for (final item in snapshot.data ?? const []) {
                  if (item is! Map<String, dynamic>) continue;
                  final url = item['imageUrl']?.toString();
                  final type = item['type']?.toString().toLowerCase();
                  if (url == null || url.isEmpty) continue;
                  if (type == 'before' || type == 'trước') {
                    before = url;
                  } else if (type == 'after' || type == 'sau') {
                    after = url;
                  }
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _Photo(label: 'Trước điều trị', path: before)),
                    const SizedBox(width: 8),
                    Expanded(child: _Photo(label: 'Sau điều trị', path: after)),
                  ],
                );
              },
            ),
          if (AppConfig.current.dataSource != DataSource.api &&
              plan.beforeImage == null &&
              plan.afterImage == null)
            const Text('Ảnh minh họa chưa được tải lên.',
                style: TextStyle(color: Color(0xFF666666))),
        ],
      );
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
