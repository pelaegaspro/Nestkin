import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkin/screens/login_screen.dart';
import 'package:nestkin/services/auth_service.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('shows the OTP form after a verification code is sent',
        (tester) async {
      final authService = _TestAuthService();

      await tester.pumpWidget(
        _buildTestApp(LoginScreen(authService: authService, showLogo: false)),
      );

      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(authService.lastPhoneNumber, '9876543210');
      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);
      expect(find.text('Resend Code'), findsOneWidget);
    });

    testWidgets('shows a snackbar when sending OTP fails', (tester) async {
      final authService = _TestAuthService()
        ..sendOtpError = 'Could not send code';

      await tester.pumpWidget(
        _buildTestApp(LoginScreen(authService: authService, showLogo: false)),
      );

      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.text('Could not send code'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('submits the entered OTP with the current verification id',
        (tester) async {
      final authService = _TestAuthService();

      await tester.pumpWidget(
        _buildTestApp(LoginScreen(authService: authService, showLogo: false)),
      );

      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pump();

      expect(authService.lastVerificationId, 'verification-id');
      expect(authService.lastOtp, '123456');
    });
  });
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: child);
}

class _TestAuthService implements AuthService {
  String? lastPhoneNumber;
  String? lastVerificationId;
  String? lastOtp;
  String? sendOtpError;

  @override
  Future<void> sendOTP({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
    required Function(String verificationId, int? resendToken) onCodeSent,
    void Function(String verificationId)? onTimeout,
    required Function(String error) onError,
  }) async {
    lastPhoneNumber = phoneNumber;

    if (sendOtpError != null) {
      onError(sendOtpError!);
      return;
    }

    onCodeSent('verification-id', 101);
  }

  @override
  Future<void> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    lastVerificationId = verificationId;
    lastOtp = otp;
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
