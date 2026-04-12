import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/household_model.dart';
import '../services/firestore_service.dart';
import '../services/invite_code_service.dart';

class InviteMemberScreen extends StatefulWidget {
  final String householdId;

  const InviteMemberScreen({super.key, required this.householdId});

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _phoneController = TextEditingController();
  final _fs = FirestoreService();
  final _inviteCodeService = InviteCodeService();
  final _contactPicker = FlutterNativeContactPicker();

  bool _sendingInvite = false;
  bool _loadingHousehold = true;
  bool _loadingJoinCode = true;
  HouseholdModel? _household;
  String? _joinCode;

  @override
  void initState() {
    super.initState();
    _loadHousehold();
  }

  Future<void> _loadHousehold() async {
    try {
      final household = await _fs.getHousehold(widget.householdId);
      final currentUser = FirebaseAuth.instance.currentUser;
      final joinCode = household == null || currentUser == null
          ? null
          : await _inviteCodeService.ensureInviteCode(
              householdId: widget.householdId,
              createdBy: currentUser.uid,
              role: 'member',
              preferredCode: household.inviteCode,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _household = household;
        _joinCode = joinCode;
        _loadingHousehold = false;
        _loadingJoinCode = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingHousehold = false;
        _loadingJoinCode = false;
      });
      _showMessage(
        error.toString().replaceFirst(
            'Exception: ', 'Could not prepare the join code right now. '),
      );
    }
  }

  Future<void> _sendInvite() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('Enter a phone number first.');
      return;
    }

    setState(() => _sendingInvite = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be signed in to send an invitation.');
      }

      await _fs.sendInvitation(
        householdId: widget.householdId,
        senderId: user.uid,
        recipientPhone: phone,
      );

      if (!mounted) {
        return;
      }
      _showMessage('Invitation sent!', backgroundColor: Colors.green);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() => _sendingInvite = false);
      }
    }
  }

  Future<void> _pickContact() async {
    try {
      final contact = await _contactPicker.selectPhoneNumber();
      final phoneNumbers = contact?.phoneNumbers ?? const <String>[];
      final fallbackNumber = phoneNumbers.isNotEmpty ? phoneNumbers.first : '';
      final selectedPhone =
          (contact?.selectedPhoneNumber ?? fallbackNumber).trim();
      if (selectedPhone.isEmpty) {
        if (!mounted) {
          return;
        }
        _showMessage('No phone number was selected.');
        return;
      }

      setState(() {
        _phoneController.text = selectedPhone;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not open contacts right now.');
    }
  }

  Future<void> _openWhatsAppInvite() async {
    final inviteCode = _joinCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      _showMessage(
          'Invite code is still loading. Please try again in a moment.');
      return;
    }

    final normalizedPhone = _normalizePhoneNumber(_phoneController.text.trim());
    if (normalizedPhone == null) {
      _showMessage(
          'Enter a valid phone number with country code, for example +917604991136.');
      return;
    }

    final whatsappDigits = normalizedPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = _buildInviteMessage(inviteCode);
    final uri = Uri.parse(
      'https://wa.me/$whatsappDigits?text=${Uri.encodeComponent(message)}',
    );

    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      _showMessage('Could not open WhatsApp right now.');
    }
  }

  Future<void> _copyInviteMessage() async {
    final inviteCode = _joinCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      _showMessage(
          'Invite code is still loading. Please try again in a moment.');
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: _buildInviteMessage(inviteCode)),
    );
    if (!mounted) {
      return;
    }
    _showMessage('Join message copied.');
  }

  String _buildInviteMessage(String inviteCode) {
    final householdName = _household?.name ?? 'my household';
    return 'Join my Nestkin household "$householdName". '
        'Open Nestkin, tap "Join Household", and enter invite code: $inviteCode';
  }

  String? _normalizePhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'[\s()-]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('+')) {
      return digits;
    }
    if (digits.length == 10) {
      return '+91$digits';
    }
    return null;
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Member')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Invite someone by phone number, pick them from contacts, or open WhatsApp with a ready-to-send join message.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_loadingHousehold)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              )
            else if (_household != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _household!.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _loadingJoinCode
                          ? 'Preparing join code...'
                          : 'Join code: ${_joinCode ?? 'Unavailable'}',
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+91 XXXXX XXXXX',
                prefixIcon: const Icon(Icons.phone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickContact,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Pick From Contacts'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sendingInvite ? null : _sendInvite,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _sendingInvite
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Send In-App Invitation',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openWhatsAppInvite,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Open WhatsApp Invite'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _copyInviteMessage,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy Join Message'),
            ),
          ],
        ),
      ),
    );
  }
}
