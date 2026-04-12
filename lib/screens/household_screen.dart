import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/invite_code_service.dart';
import 'home_screen.dart';
import 'invitations_screen.dart';

class HouseholdScreen extends StatefulWidget {
  final bool skipAutoCheck;
  final String? accessMessage;

  const HouseholdScreen({
    super.key,
    this.skipAutoCheck = false,
    this.accessMessage,
  });

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _fs = FirestoreService();
  final _inviteCodeService = InviteCodeService();
  bool _loading = false;
  String? _error;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    if (!widget.skipAutoCheck) {
      _checkExistingHousehold();
    }
  }

  Future<void> _checkExistingHousehold() async {
    final user = await _fs.getUser(_uid);
    if (!mounted) return;

    if (user?.currentHouseholdId != null &&
        user!.currentHouseholdId!.isNotEmpty) {
      final households = await _fs.getUserHouseholds(_uid);
      final current = households
          .where((h) => h.householdId == user.currentHouseholdId)
          .toList();
      if (current.isNotEmpty) {
        _goHome(current.first.householdId);
        return;
      }
    }

    final households = await _fs.getUserHouseholds(_uid);
    if (households.isNotEmpty && mounted) {
      _goHome(households.first.householdId);
    }
  }

  void _goHome(String householdId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(householdId: householdId),
      ),
    );
  }

  Future<void> _createHousehold() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final householdId =
          await _fs.createHousehold(_nameController.text.trim(), _uid);
      if (!mounted) return;
      _goHome(householdId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _joinHousehold() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final normalizedCode = _codeController.text.trim().toUpperCase();
      final user = await _fs.getUser(_uid);
      final redeemedHouseholdId = user == null
          ? null
          : await _inviteCodeService.redeemInviteCode(
              code: normalizedCode,
              user: user,
            );

      if (redeemedHouseholdId != null) {
        if (!mounted) return;
        _goHome(redeemedHouseholdId);
        return;
      }

      final householdId = await _fs.joinHousehold(
        normalizedCode,
        _uid,
      );

      if (householdId == null) {
        setState(() {
          _loading = false;
          _error = 'Invalid invite code.';
        });
        return;
      }

      if (!mounted) return;
      _goHome(householdId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _error ?? widget.accessMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Create or Join Household')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (message != null)
              Text(
                message,
                style: TextStyle(
                  color: widget.accessMessage != null && _error == null
                      ? Colors.orange.shade800
                      : Colors.red,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Household Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _createHousehold,
                child: const Text('Create Household'),
              ),
            ),
            const Divider(height: 40),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _joinHousehold,
                child: const Text('Join Household'),
              ),
            ),
            const Divider(height: 40),
            TextButton.icon(
              icon: const Icon(Icons.mail_outline),
              label: const Text('Check for Invitations'),
              onPressed: () {
                final user = FirebaseAuth.instance.currentUser!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvitationsScreen(
                      phoneNumber: user.phoneNumber ?? '',
                      userId: user.uid,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
