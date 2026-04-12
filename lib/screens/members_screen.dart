import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household_member_model.dart';
import '../models/household_model.dart';
import '../services/firestore_service.dart';
import '../services/invite_code_service.dart';
import 'sos_history_screen.dart';

class MembersScreen extends StatefulWidget {
  final String householdId;

  const MembersScreen({
    super.key,
    required this.householdId,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _fs = FirestoreService();
  final _inviteCodeService = InviteCodeService();
  String? _removingUserId;

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _createInviteCode(HouseholdModel household) async {
    String selectedRole = 'member';
    String? createdCode;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Generate Invite Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'parent', child: Text('Parent')),
                  DropdownMenuItem(value: 'child', child: Text('Child')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedRole = value);
                  }
                },
              ),
              if (createdCode != null) ...[
                const SizedBox(height: 16),
                SelectableText('Invite code: $createdCode'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                final code = await _inviteCodeService.createInviteCode(
                  householdId: household.id,
                  createdBy: _currentUid,
                  role: selectedRole,
                );
                setLocalState(() => createdCode = code);
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
      HouseholdModel household, HouseholdMemberModel member) async {
    if (member.userId == _currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The household creator cannot remove themselves.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Remove ${(member.user['displayName'] ?? 'this member')} from ${household.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _removingUserId = member.userId);
    try {
      await _fs.removeHouseholdMember(
        householdId: widget.householdId,
        actingUserId: _currentUid,
        memberUserId: member.userId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${member.user['displayName'] ?? 'Member'} removed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _removingUserId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HouseholdModel?>(
      stream: _fs.householdStream(widget.householdId),
      builder: (context, householdSnapshot) {
        if (householdSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final household = householdSnapshot.data;
        if (household == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Members')),
            body: const Center(
              child: Text('This household is no longer available.'),
            ),
          );
        }

        return StreamBuilder<List<HouseholdMemberModel>>(
          stream: _fs.householdMembersStream(widget.householdId),
          builder: (context, membersSnapshot) {
            if (membersSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final isAdmin = household.adminId == _currentUid;
            final members = [
              ...(membersSnapshot.data ?? const <HouseholdMemberModel>[])
            ];
            members.sort((a, b) {
              if (a.role != b.role) {
                return a.role == 'admin' ? -1 : 1;
              }

              final aName =
                  (a.user['displayName'] ?? a.user['phoneNumber'] ?? 'User')
                      .toString();
              final bName =
                  (b.user['displayName'] ?? b.user['phoneNumber'] ?? 'User')
                      .toString();
              return aName.toLowerCase().compareTo(bName.toLowerCase());
            });

            return Scaffold(
              appBar: AppBar(
                title: Text('${household.name} Members'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: 'SOS history',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SOSHistoryScreen(householdId: widget.householdId),
                      ),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.password_outlined),
                      tooltip: 'Generate invite code',
                      onPressed: () => _createInviteCode(household),
                    ),
                ],
              ),
              body: members.isEmpty
                  ? const Center(
                      child: Text('No members found for this household.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final name =
                            (member.user['displayName'] ?? 'User').toString();
                        final secondary = (member.user['email'] ??
                                member.user['phoneNumber'] ??
                                'No contact details')
                            .toString();
                        final photoUrl = member.user['photoUrl']?.toString();
                        final initials = name
                            .split(RegExp(r'\s+'))
                            .where((part) => part.isNotEmpty)
                            .take(2)
                            .map((part) => part[0].toUpperCase())
                            .join();

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            leading: CircleAvatar(
                              backgroundImage:
                                  photoUrl != null && photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? Text(initials.isEmpty ? 'U' : initials)
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(name)),
                                if (member.role == 'admin')
                                  const Chip(label: Text('Creator')),
                              ],
                            ),
                            subtitle: Text(secondary),
                            trailing: isAdmin && member.userId != _currentUid
                                ? _removingUserId == member.userId
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                            Icons.person_remove_outlined),
                                        tooltip: 'Remove member',
                                        onPressed: () =>
                                            _confirmRemove(household, member),
                                      )
                                : null,
                          ),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }
}
