import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'me_widgets.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>();
    // Chỉ liệt kê ngôn ngữ giao diện thật sự hỗ trợ (hiện chỉ Tiếng Việt).
    return MePage(title: 'Ngôn ngữ', children: [
      MeCard(
          child: Column(children: [
        for (final entry in UserProvider.supportedLanguages.entries)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  users.languageCode == entry.key
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: meBlue),
              title: Text(entry.value),
              onTap: () => users.setLanguage(entry.key)),
      ])),
      const Text('Sắp có thêm ngôn ngữ.',
          style: TextStyle(color: Color(0xFF666666))),
    ]);
  }
}
