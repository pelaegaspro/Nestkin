import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../services/chat_repository.dart';
import '../services/firestore_service.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker.dart';
import 'image_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final String householdId;

  const ChatScreen({
    super.key,
    required this.householdId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repository = ChatRepository();
  final _firestoreService = FirestoreService();
  final _scrollController = ScrollController();
  bool _uploadingImage = false;

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _sendText(String text) async {
    try {
      final user = await _firestoreService.getUser(_currentUid);
      final householdMember = await _firestoreService.getHouseholdMember(
        householdId: widget.householdId,
        userId: _currentUid,
      );
      if (user == null) {
        throw Exception('Could not find your profile.');
      }
      await _repository.sendMessage(
        householdId: widget.householdId,
        message: MessageModel(
          id: '',
          text: text,
          imageUrl: '',
          type: MessageType.text,
          senderId: user.id,
          senderName: user.displayName,
          senderColor: householdMember?.color ?? '#0B5C68',
          timestamp: Timestamp.now(),
          readBy: [user.id],
          reactions: const {},
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _sendImage(Uint8List bytes) async {
    setState(() => _uploadingImage = true);
    try {
      final user = await _firestoreService.getUser(_currentUid);
      final householdMember = await _firestoreService.getHouseholdMember(
        householdId: widget.householdId,
        userId: _currentUid,
      );
      if (user == null) {
        throw Exception('Could not find your profile.');
      }
      final imageUrl = await _repository.uploadChatImage(
        householdId: widget.householdId,
        bytes: bytes,
      );
      await _repository.sendMessage(
        householdId: widget.householdId,
        message: MessageModel(
          id: '',
          text: '',
          imageUrl: imageUrl,
          type: MessageType.image,
          senderId: user.id,
          senderName: user.displayName,
          senderColor: householdMember?.color ?? '#0B5C68',
          timestamp: Timestamp.now(),
          readBy: [user.id],
          reactions: const {},
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  void _openReactionPicker(MessageModel message) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => Center(
        child: ReactionPicker(
          onSelected: (emoji) async {
            Navigator.pop(context);
            await _repository.toggleReaction(
              householdId: widget.householdId,
              message: message,
              emoji: emoji,
              currentUid: _currentUid,
            );
          },
        ),
      ),
    );
  }

  bool _showTimestampHeader(MessageModel? previous, MessageModel current) {
    if (previous == null) {
      return true;
    }
    return current.sentAt.difference(previous.sentAt).inMinutes > 30;
  }

  String _formatTimestamp(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household Chat')),
      bottomNavigationBar: ChatInputBar(
        onSendText: _sendText,
        onSendImage: _sendImage,
        isUploading: _uploadingImage,
      ),
      body: StreamBuilder<List<MessageModel>>(
        stream: _repository.streamMessages(widget.householdId),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? const <MessageModel>[];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _repository.markMessagesAsRead(
              householdId: widget.householdId,
              currentUid: _currentUid,
              messages: messages,
            );
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          });

          if (messages.isEmpty) {
            return const Center(child: Text('No messages yet. Say hello.'));
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final previous = index > 0 ? messages[index - 1] : null;
              final next = index < messages.length - 1 ? messages[index + 1] : null;
              final showSenderMeta = previous == null || previous.senderId != message.senderId;
              final showAvatar = next == null || next.senderId != message.senderId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showTimestampHeader(previous, message))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            _formatTimestamp(message.sentAt),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ),
                    MessageBubble(
                      message: message,
                      isCurrentUser: message.senderId == _currentUid,
                      showSenderMeta: showSenderMeta,
                      showAvatar: showAvatar,
                      onLongPress: () => _openReactionPicker(message),
                      onTapImage: message.type == MessageType.image
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImageViewerScreen(imageUrl: message.imageUrl),
                                ),
                              )
                          : null,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
