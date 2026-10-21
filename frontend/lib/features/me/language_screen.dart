import 'package:flutter/material.dart';
import 'me_widgets.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const MePage(title: 'Ngôn ngữ', children: [
        MeCard(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: meBlue),
                title: Text('Tiếng Việt'))),
        Text(
            'Ứng dụng hiện chỉ hỗ trợ Tiếng Việt. Các ngôn ngữ khác chưa được hỗ trợ.',
            style: TextStyle(color: Color(0xFF666666))),
      ]);
}
