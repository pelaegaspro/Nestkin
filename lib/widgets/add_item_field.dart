import 'package:flutter/material.dart';

class AddItemField extends StatefulWidget {
  final Future<void> Function(String name, String qty, String unit) onSubmit;

  const AddItemField({
    super.key,
    required this.onSubmit,
  });

  @override
  State<AddItemField> createState() => _AddItemFieldState();
}

class _AddItemFieldState extends State<AddItemField> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _unitController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _qtyController.text.trim(),
        _unitController.text.trim(),
      );
      _nameController.clear();
      _qtyController.clear();
      _unitController.clear();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Add item',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _qtyController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Qty',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _unitController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
