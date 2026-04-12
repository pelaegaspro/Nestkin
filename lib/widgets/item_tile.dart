import 'package:flutter/material.dart';

import '../models/shopping_item_model.dart';

class ItemTile extends StatelessWidget {
  final ShoppingItemModel item;
  final ValueChanged<bool?> onChecked;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ItemTile({
    super.key,
    required this.item,
    required this.onChecked,
    required this.onDelete,
    required this.onEdit,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = [
      item.name,
      if (item.qty.isNotEmpty) item.qty,
      if (item.unit.isNotEmpty) item.unit
    ].join(' ');
    final addedByName =
        item.addedByName.trim().isEmpty ? 'Member' : item.addedByName;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ListTile(
          leading: Checkbox(
            value: item.isChecked,
            onChanged: onChecked,
          ),
          title: Text(
            titleText,
            style: TextStyle(
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: _parseColor(item.addedByColor),
                child: Text(
                  addedByName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  addedByName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: selectionMode
              ? Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                )
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
