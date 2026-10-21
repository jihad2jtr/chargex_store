import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Generated for project `lyan-chargex`.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBMb_W9_KhfZkk_yIBmBZDmP1RaOlWj-3Q',
    appId: '1:1079509242678:web:f4702c9bbe83e0befad997',
    messagingSenderId: '1079509242678',
    projectId: 'lyan-chargex',
    authDomain: 'lyan-chargex.firebaseapp.com',
    storageBucket: 'lyan-chargex.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBMb_W9_KhfZkk_yIBmBZDmP1RaOlWj-3Q',
    appId: '1:1079509242678:android:f4702c9bbe83e0befad997',
    messagingSenderId: '1079509242678',
    projectId: 'lyan-chargex',
    storageBucket: 'lyan-chargex.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBMb_W9_KhfZkk_yIBmBZDmP1RaOlWj-3Q',
    appId: '1:1079509242678:ios:f4702c9bbe83e0befad997',
    messagingSenderId: '1079509242678',
    projectId: 'lyan-chargex',
    storageBucket: 'lyan-chargex.firebasestorage.app',
    iosBundleId: 'com.layanchargex.app.layanChargex',
  );
}
