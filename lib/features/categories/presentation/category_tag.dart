import 'package:flutter/material.dart';

/// Parsira `#RRGGBB` u [Color] (null ako je vrednost nevažeća).
Color? parseCategoryColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  return Color(int.parse('FF$cleaned', radix: 16));
}

/// Tag ikonica kategorije obojena bojom kategorije (uz neutralni fallback).
class CategoryTag extends StatelessWidget {
  const CategoryTag({super.key, required this.color, this.size = 18});

  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = parseCategoryColor(color) ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return Icon(Icons.local_offer, size: size, color: c);
  }
}
