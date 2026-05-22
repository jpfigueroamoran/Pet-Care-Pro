import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

extension FirestoreCollectionExtension on FirebaseFirestore {
  /// Retorna la colección correspondiente, aplicando el prefijo 'demo_'
  /// si el usuario actual está autenticado con una cuenta demo.
  CollectionReference<Map<String, dynamic>> demoCollection(String path) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDemo = currentUser != null &&
        currentUser.email != null &&
        currentUser.email!.startsWith('demo.');

    if (isDemo) {
      final segments = path.split('/');
      if (segments.isNotEmpty) {
        final root = segments[0];
        if (root == 'users' || root == 'pets' || root == 'payments' || root == 'qr_tokens') {
          segments[0] = 'demo_$root';
        }
      }
      return collection(segments.join('/'));
    }
    return collection(path);
  }
}
