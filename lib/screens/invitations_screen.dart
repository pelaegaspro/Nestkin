import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/invitation_model.dart';

class InvitationsScreen extends StatefulWidget {
  final String phoneNumber;
  final String userId;

  const InvitationsScreen({super.key, required this.phoneNumber, required this.userId});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  final _fs = FirestoreService();
  bool _loading = false;

  Future<void> _accept(String id) async {
    setState(() => _loading = true);
    try {
      await _fs.acceptInvitation(id, widget.userId);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined household!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Invitations')),
      body: StreamBuilder<List<InvitationModel>>(
        stream: _fs.getInvitationsByPhone(widget.phoneNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invites = snapshot.data ?? [];
          if (invites.isEmpty) {
            return const Center(
              child: Text('No pending invitations found for this number.', textAlign: TextAlign.center),
            );
          }

          return ListView.builder(
            itemCount: invites.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final invite = invites[index];
              return Card(
                child: ListTile(
                  title: Text('Invitation from ${invite.sender['displayName']}'),
                  subtitle: Text('Household ID: ${invite.householdId}'),
                  trailing: _loading
                      ? const CircularProgressIndicator()
                      : IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _accept(invite.id),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
