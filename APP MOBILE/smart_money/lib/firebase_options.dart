import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
    apiKey: 'AIzaSyCSYT99vIa4hkgVXR8Np5TWGAenoOQrPuE',
    appId: '1:315182273926:android:f5b42eae167dbfc6ed4807',
    messagingSenderId: '315182273926',
    projectId: 'smartmoney-78185-f5bab',
    authDomain: 'smartmoney-78185-f5bab.firebaseapp.com',
    storageBucket: 'smartmoney-78185-f5bab.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCSYT99vIa4hkgVXR8Np5TWGAenoOQrPuE',
    appId: '1:315182273926:android:f5b42eae167dbfc6ed4807',
    messagingSenderId: '315182273926',
    projectId: 'smartmoney-78185-f5bab',
    storageBucket: 'smartmoney-78185-f5bab.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCSYT99vIa4hkgVXR8Np5TWGAenoOQrPuE',
    appId: '1:315182273926:android:f5b42eae167dbfc6ed4807',
    messagingSenderId: '315182273926',
    projectId: 'smartmoney-78185-f5bab',
    storageBucket: 'smartmoney-78185-f5bab.firebasestorage.app',
    iosBundleId: 'com.example.smart_money',
  );
}