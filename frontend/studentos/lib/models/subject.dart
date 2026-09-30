import 'package:flutter/material.dart';

class Subject {
  final int id;
  final String name;
  final String code;
  final String color;
  final String icon;
  final String difficulty;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    required this.icon,
    required this.difficulty,
  });

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: j['id'],
        name: j['name'],
        code: j['code'] ?? '',
        color: j['color'] ?? '#6C63FF',
        icon: j['icon'] ?? 'book',
        difficulty: j['difficulty'] ?? 'Medium',
      );

  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6C63FF);
    }
  }
}
