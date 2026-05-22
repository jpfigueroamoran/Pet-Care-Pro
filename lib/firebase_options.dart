import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'mock-api-key-petcare-pro-web',
    appId: '1:1234567890:web:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'petcare-pro-app',
    authDomain: 'petcare-pro-app.firebaseapp.com',
    storageBucket: 'petcare-pro-app.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgpHlDxqAXM38Q73bNGlJ1_hUWM93ExGg',
    appId: '1:370446482713:android:46b92e7d2b2c03b4ea9988',
    messagingSenderId: '370446482713',
    projectId: 'petcare-pro-62010',
    storageBucket: 'petcare-pro-62010.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCHZkJBznpdc4BqBU-opu_MbKpmRHh5t_c',
    appId: '1:370446482713:ios:33bfb8b3a638f240ea9988',
    messagingSenderId: '370446482713',
    projectId: 'petcare-pro-62010',
    storageBucket: 'petcare-pro-62010.firebasestorage.app',
    iosBundleId: 'com.petcarepro.petcarePro',
  );

}