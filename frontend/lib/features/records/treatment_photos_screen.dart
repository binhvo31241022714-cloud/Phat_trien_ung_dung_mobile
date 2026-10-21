import 'package:flutter/material.dart';
import '../../data/models/patient_records.dart';
import 'records_widgets.dart';

class TreatmentPhotosScreen extends StatelessWidget {
  const TreatmentPhotosScreen({required this.plan, super.key});
  final TreatmentPlan plan;
  @override
  Widget build(BuildContext context) =>
      RecordsPage(title: 'Hình ảnh điều trị', children: [
        const RecordHeading('Hình ảnh trước – sau điều trị'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _Photo(label: 'Trước điều trị', path: plan.beforeImage)),
          const SizedBox(width: 8),
          Expanded(child: _Photo(label: 'Sau điều trị', path: plan.afterImage))
        ]),
        if (plan.beforeImage == null && plan.afterImage == null)
          const Text('Ảnh minh họa chưa được tải lên.',
              style: TextStyle(color: Color(0xFF666666))),
      ]);
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
