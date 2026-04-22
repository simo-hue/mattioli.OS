import 'package:flutter/material.dart';

class Goal {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final String icon;
  final Color color;
  final String startDate; // 'yyyy-MM-dd'
  final String? endDate;

  const Goal({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    required this.icon,
    required this.color,
    required this.startDate,
    this.endDate,
  });
}
