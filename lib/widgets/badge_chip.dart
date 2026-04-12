import 'package:flutter/material.dart';

class BadgeChip extends StatelessWidget {
  final String label;

  const BadgeChip({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      visualDensity: VisualDensity.compact,
    );
  }
}
