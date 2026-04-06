import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for Linux.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for Fuchsia.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBFFXLRUwcnfhIVodG6oaRXAponzNRxQZc',
    appId: '1:540538475566:android:6dca2ab7957a5080a2fbbf',
    messagingSenderId: '540538475566',
    projectId: 'nestkin-3aaa5',
    storageBucket: 'nestkin-3aaa5.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAM_p2TgrtJF7eatRTJllp-lRIxPInxDuw',
    appId: '1:540538475566:web:2df0164581139600a2fbbf',
    messagingSenderId: '540538475566',
    projectId: 'nestkin-3aaa5',
    authDomain: 'nestkin-3aaa5.firebaseapp.com',
    storageBucket: 'nestkin-3aaa5.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDj8LLflyJxDspshF71YPXLXofDw5YozVA',
    appId: '1:540538475566:ios:aac674c460dfb7bfa2fbbf',
    messagingSenderId: '540538475566',
    projectId: 'nestkin-3aaa5',
    storageBucket: 'nestkin-3aaa5.firebasestorage.app',
    androidClientId: '540538475566-e0s7ufugo35kc48dhbe5jragf5aiufcp.apps.googleusercontent.com',
    iosBundleId: 'com.example.nestkin',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDj8LLflyJxDspshF71YPXLXofDw5YozVA',
    appId: '1:540538475566:ios:aac674c460dfb7bfa2fbbf',
    messagingSenderId: '540538475566',
    projectId: 'nestkin-3aaa5',
    storageBucket: 'nestkin-3aaa5.firebasestorage.app',
    androidClientId: '540538475566-e0s7ufugo35kc48dhbe5jragf5aiufcp.apps.googleusercontent.com',
    iosBundleId: 'com.example.nestkin',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAM_p2TgrtJF7eatRTJllp-lRIxPInxDuw',
    appId: '1:540538475566:web:23f30ee7bff884faa2fbbf',
    messagingSenderId: '540538475566',
    projectId: 'nestkin-3aaa5',
    authDomain: 'nestkin-3aaa5.firebaseapp.com',
    storageBucket: 'nestkin-3aaa5.firebasestorage.app',
  );

}