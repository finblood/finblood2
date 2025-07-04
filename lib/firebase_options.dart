// File yang dihasilkan oleh FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [FirebaseOptions] default untuk digunakan dengan aplikasi Firebase Anda.
///
/// Contoh:
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk linux - '
          'Anda dapat mengkonfigurasi ulang dengan menjalankan FlutterFire CLI lagi.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions tidak didukung untuk platform ini.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBHBPCmA_UiVvZoarwiiD4GNl6OvbGlco4',
    appId: '1:419143544864:web:331fa801dfa65b39a38c45',
    messagingSenderId: '419143544864',
    projectId: 'fin-blood-2',
    authDomain: 'fin-blood-2.firebaseapp.com',
    storageBucket: 'fin-blood-2.firebasestorage.app',
    measurementId: 'G-C2NPG61TM6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBDxx9pT3C4JZ6Xq4II9oayGbUa4hCzLZY',
    appId: '1:419143544864:android:a8839c02fa91c6e0a38c45',
    messagingSenderId: '419143544864',
    projectId: 'fin-blood-2',
    storageBucket: 'fin-blood-2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQ1uXu782SJuy-FdeHrDoamec35sZFBOw',
    appId: '1:419143544864:ios:79d184c127a6f7aaa38c45',
    messagingSenderId: '419143544864',
    projectId: 'fin-blood-2',
    storageBucket: 'fin-blood-2.firebasestorage.app',
    iosBundleId: 'com.example.finBlood2',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCQ1uXu782SJuy-FdeHrDoamec35sZFBOw',
    appId: '1:419143544864:ios:79d184c127a6f7aaa38c45',
    messagingSenderId: '419143544864',
    projectId: 'fin-blood-2',
    storageBucket: 'fin-blood-2.firebasestorage.app',
    iosBundleId: 'com.example.finBlood2',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBHBPCmA_UiVvZoarwiiD4GNl6OvbGlco4',
    appId: '1:419143544864:web:a17f957b38af32c6a38c45',
    messagingSenderId: '419143544864',
    projectId: 'fin-blood-2',
    authDomain: 'fin-blood-2.firebaseapp.com',
    storageBucket: 'fin-blood-2.firebasestorage.app',
    measurementId: 'G-81XQWS416K',
  );
}
