import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});
  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _fs = FirestoreService();
  bool _loading = false;
  String? _error;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _checkExistingHousehold();
  }

  Future<void> _checkExistingHousehold() async {
    final households = await _fs.getUserHouseholds(_uid);
    if (households.isNotEmpty && mounted) {
      _goHome(households.first.householdId, households.first.household['name']);
    }
  }

  void _goHome(String householdId, String householdName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HomeScreen(householdId: householdId, householdName: householdName),
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
      if (mounted) _goHome(householdId, _nameController.text.trim());
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
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
      final householdId = await _fs.joinHousehold(
        _codeController.text.trim().toUpperCase(),
        _uid,
      );
      if (householdId == null) {
        setState(() {
          _loading = false;
          _error = 'Invalid invite code';
        });
        return;
      }
      final households = await _fs.getUserHouseholds(_uid);
      final joined = households.firstWhere((h) => h.householdId == householdId);
      if (mounted) _goHome(joined.householdId, joined.household['name']);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create or Join Household')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
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
          ],
        ),
      ),
    );
  }
}
