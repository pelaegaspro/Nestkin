import 'package:flutter/material.dart';

class ReactionPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const ReactionPicker({
    super.key,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢'];
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: emojis
              .map(
                (emoji) => IconButton(
                  onPressed: () => onSelected(emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
