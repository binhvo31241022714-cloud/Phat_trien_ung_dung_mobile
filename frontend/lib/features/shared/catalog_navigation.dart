import '../../core/widgets/page_background.dart';
import 'package:flutter/material.dart';

/// Push onto the current tab's navigator, retaining MainShell's bottom bar.
class CatalogNavigation {
  const CatalogNavigation._();
  static void open(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CatalogPage(title: title, body: body)));
  }
}

class CatalogPage extends StatelessWidget {
  const CatalogPage({required this.title, required this.body, super.key});
  final String title;
  final Widget body;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageBackground(child: SafeArea(top: false, child: body)));
}
