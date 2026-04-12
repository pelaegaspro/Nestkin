import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isCurrentUser;
  final bool showSenderMeta;
  final bool showAvatar;
  final VoidCallback? onTapImage;
  final VoidCallback onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.showSenderMeta,
    required this.showAvatar,
    required this.onLongPress,
    this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isCurrentUser ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
    final textColor = isCurrentUser ? Colors.white : Colors.black87;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!isCurrentUser && showSenderMeta)
            Padding(
              padding: const EdgeInsets.only(left: 52, bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _parseColor(message.senderColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(message.senderName),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: showAvatar
                      ? CircleAvatar(
                          radius: 16,
                          backgroundColor: _parseColor(message.senderColor),
                          child: Text(
                            message.senderName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : const SizedBox(width: 32),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: message.type == MessageType.image
                      ? InkWell(
                          onTap: onTapImage,
                          child: CachedNetworkImage(
                            imageUrl: message.imageUrl,
                            width: 220,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              height: 160,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                        )
                      : Text(
                          message.text,
                          style: TextStyle(color: textColor),
                        ),
                ),
              ),
            ],
          ),
          if (message.reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isCurrentUser ? 0 : 52,
                right: isCurrentUser ? 0 : 0,
              ),
              child: Wrap(
                spacing: 6,
                children: message.reactions.entries
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key} ${entry.value.length}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
