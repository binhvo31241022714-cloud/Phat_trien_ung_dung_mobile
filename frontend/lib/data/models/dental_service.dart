import 'package:flutter/material.dart';

class DentalService {
  final String id;
  final String name;
  final String description;
  final int price;
  final int durationMinutes;
  final IconData icon;
  final String category;
  final bool isCombo;
  final bool isPopular;

  const DentalService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.icon,
    required this.category,
    this.isCombo = false,
    this.isPopular = false,
  });
}
