import 'package:flutter/material.dart';

class PatientDetailArguments {
  final String title;
  final String description;

  const PatientDetailArguments({
    required this.title,
    required this.description,
  });
}

class PatientDetailScreen extends StatelessWidget {
  final PatientDetailArguments details;

  const PatientDetailScreen({required this.details, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(details.title),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(details.description),
        ),
      ),
    );
  }
}
