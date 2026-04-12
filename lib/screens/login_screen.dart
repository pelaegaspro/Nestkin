import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService, this.showLogo = true});

  final AuthService? authService;
  final bool showLogo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  late final AuthService _authService;

  String? _verificationId;
  int? _resendToken;
  bool _codeSent = false;
  bool _loading = false;
  bool _otpTimedOut = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await _authService.sendOTP(
      phoneNumber: _phoneController.text.trim(),
      forceResendingToken: _resendToken,
      onCodeSent: (id, resendToken) => setState(() {
        _verificationId = id;
        _resendToken = resendToken;
        _codeSent = true;
        _otpTimedOut = false;
        _loading = false;
      }),
      onTimeout: (id) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _otpTimedOut = true;
          _loading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e), backgroundColor: Colors.redAccent),
        );
      },
    );
  }

  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;
    setState(() => _loading = true);
    try {
      await _authService.verifyOTP(
        verificationId: _verificationId!,
        otp: _otpController.text.trim(),
      );
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
      backgroundColor: const Color(0xFF0B5C68),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B5C68), Color(0xFF073C44)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.showLogo) ...[
                    // Logo Section with a subtle glow
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/images/nestkin_logo.png',
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // Main White Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _codeSent ? 'Verification' : 'Welcome Back',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B5C68),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _codeSent
                              ? 'Enter the 6-digit code sent to your phone'
                              : 'Sign in to manage your household tasks smoothly.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        if (!_codeSent) ...[
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '+91XXXXXXXXXX or 7604991136',
                              prefixIcon: const Icon(Icons.phone_android,
                                  color: Color(0xFF0B5C68)),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '10-digit Indian numbers are automatically converted to +91 format.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _sendOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B5C68),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Send Verification Code',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ] else ...[
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                            decoration: InputDecoration(
                              labelText: '6-Digit OTP',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _verifyOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B5C68),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Verify & Continue',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _codeSent = false;
                              _otpTimedOut = false;
                              _verificationId = null;
                              _resendToken = null;
                            }),
                            child: const Text('Change Number',
                                style: TextStyle(color: Color(0xFF0B5C68))),
                          ),
                          if (_otpTimedOut)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Code timed out. You can request a new one.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          TextButton(
                            onPressed: _loading ? null : _sendOTP,
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(color: Color(0xFF0B5C68)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // External Google Authentication Section
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          'OR CONNECT WITH',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.3))),
                    ],
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _loading = true);
                              try {
                                await _authService.signInWithGoogle();
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(e
                                        .toString()
                                        .replaceFirst('Exception: ', '')),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                      icon: const Icon(
                        Icons.account_circle,
                        size: 24,
                        color: Color(0xFF0B5C68),
                      ),
                      label: const Text('Continue with Google',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        side: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'By continuing, you agree to our Terms and Privacy Policy',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
