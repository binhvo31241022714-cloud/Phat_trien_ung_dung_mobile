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
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context)
            .textTheme
            .apply(bodyColor: Colors.black, displayColor: Colors.black),
        cardTheme: CardThemeData(
            color: const Color(0xFFF7F7F7),
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFD8D8D8)))),
      ),
      child: Scaffold(
          backgroundColor: const Color(0xFFF1F5FB),
          appBar: AppBar(
              title: Text(title),
              centerTitle: false,
              toolbarHeight: 48,
              backgroundColor: const Color(0xFFF1F5FB),
              surfaceTintColor: Colors.transparent),
          body: body));
}
