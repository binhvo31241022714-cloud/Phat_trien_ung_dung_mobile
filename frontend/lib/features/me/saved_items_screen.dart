import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/patient_data_provider.dart';
import 'me_widgets.dart';

class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final articles = data.savedArticles;
    final services =
        data.services.where((s) => data.savedServiceIds.contains(s.id));
    final doctors =
        data.doctors.where((d) => data.savedDoctorIds.contains(d.id));
    final empty = articles.isEmpty && services.isEmpty && doctors.isEmpty;
    return MePage(title: 'Đã lưu', children: [
      if (empty)
        const MeCard(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: Column(children: [
                  Icon(Icons.bookmark_border, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('Chưa có nội dung đã lưu.',
                      style: TextStyle(color: Color(0xFF666666)))
                ])))),
      for (final a in articles)
        _SavedTile(
            a.title,
            'Bài viết',
            () => MeRoutes.open(context, MeRoutes.article, arguments: a),
            () => data.toggleSavedArticle(a.id)),
      for (final s in services)
        _SavedTile(
            s.name,
            'Dịch vụ',
            () => MeRoutes.open(context, MeRoutes.service, arguments: s),
            () => data.toggleSavedService(s.id)),
      for (final d in doctors)
        _SavedTile(
            d.fullName,
            'Bác sĩ',
            () => MeRoutes.open(context, MeRoutes.doctor, arguments: d),
            () => data.toggleSavedDoctor(d.id)),
      if (!empty)
        const Text('Nội dung đã lưu chỉ tồn tại trong bộ nhớ của bản demo.',
            style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
    ]);
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile(this.title, this.category, this.onTap, this.onRemove);
  final String title, category;
  final VoidCallback onTap, onRemove;
  @override
  Widget build(BuildContext context) => MeCard(
      onTap: onTap,
      child: Row(children: [
        const Icon(Icons.bookmark, color: meBlue),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(category, style: const TextStyle(color: Color(0xFF666666)))
        ])),
        IconButton(
            tooltip: 'Bỏ lưu $title',
            onPressed: onRemove,
            icon: const Icon(Icons.bookmark_remove_outlined))
      ]));
}
