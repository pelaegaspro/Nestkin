import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> sendOTP({
    required String phoneNumber,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
    required Function(String verificationId, int? resendToken) onCodeSent,
    void Function(String verificationId)? onTimeout,
    required Function(String error) onError,
  }) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    if (normalizedPhone == null) {
      onError('Enter a valid phone number with country code, for example +917604991136.');
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        forceResendingToken: forceResendingToken,
        timeout: timeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          await _saveUserData();
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_mapPhoneAuthError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onTimeout?.call(verificationId);
        },
      );
    } on FirebaseAuthException catch (e) {
      onError(_mapPhoneAuthError(e));
    } catch (_) {
      onError('Could not start phone verification right now. Please try again.');
    }
  }

  Future<void> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    await _auth.signInWithCredential(credential);
    await _saveUserData();
  }

  Future<void> _saveUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await FCMService().getToken();
    await FirestoreService().saveUser(
      uid: user.uid,
      phone: user.phoneNumber ?? '',
      email: user.email,
      displayName: user.displayName ?? 'User',
      photoUrl: user.photoURL,
      fcmToken: token ?? '',
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      await _saveUserData();
    } on PlatformException catch (e) {
      if ((e.message ?? '').contains('ApiException: 10') ||
          e.code == 'sign_in_failed') {
        throw Exception(
          'Google Sign-In is not fully configured for this Android app yet. '
          'Add the correct SHA-1/SHA-256 in Firebase and download the latest google-services.json.',
        );
      }
      throw Exception(e.message ?? 'Google Sign-In failed.');
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Google Sign-In failed.');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String? _normalizePhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'[\s()-]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+')) return digits;
    if (digits.length == 10) return '+91$digits';
    return null;
  }

  String _mapPhoneAuthError(FirebaseAuthException e) {
    final message = e.message ?? 'Verification failed';
    if (message.contains('CONFIGURATION_NOT_FOUND') ||
        e.code == 'operation-not-allowed') {
      return 'Phone sign-in is not fully configured in Firebase for this Android app yet. '
          'Enable Phone authentication in Firebase Console. If you are using test numbers, verify they are configured there too.';
    }
    if (e.code == 'quota-exceeded' || message.contains('BILLING_NOT_ENABLED')) {
      return 'Phone sign-in is not available for real SMS yet. Enable Firebase billing or use configured test phone numbers.';
    }
    if (e.code == 'invalid-phone-number') {
      return 'Enter a valid phone number in international format, for example +917604991136.';
    }
    if (e.code == 'too-many-requests') {
      return 'Too many verification attempts. Please wait a moment and try again.';
    }
    return message;
  }
}
