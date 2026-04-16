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
    apiKey: 'AIzaSyATR6NvI7k91f3FPyuYsWBDCVQMO5Ev8fA',
    appId: '1:1051851661309:android:ab9fdc0e30943d96884394',
    messagingSenderId: '1051851661309',
    projectId: 'smartmoney-78185',
    authDomain: 'smartmoney-78185.firebaseapp.com',
    storageBucket: 'smartmoney-78185.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATR6NvI7k91f3FPyuYsWBDCVQMO5Ev8fA',
    appId: '1:1051851661309:android:ab9fdc0e30943d96884394',
    messagingSenderId: '1051851661309',
    projectId: 'smartmoney-78185',
    storageBucket: 'smartmoney-78185.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyATR6NvI7k91f3FPyuYsWBDCVQMO5Ev8fA',
    appId: '1:1051851661309:android:ab9fdc0e30943d96884394',
    messagingSenderId: '1051851661309',
    projectId: 'smartmoney-78185',
    storageBucket: 'smartmoney-78185.firebasestorage.app',
    iosBundleId: 'com.example.smart_money',
  );
}