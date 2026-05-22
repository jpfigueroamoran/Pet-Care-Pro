import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../domain/entities/active_vet_lease.dart';

class QrRepository {
  final FirebaseFirestore _firestore;

  QrRepository(this._firestore);

  Stream<List<ActiveVetLease>> watchActiveLeasesByOwner(String ownerId) {
    return _firestore
        .demoCollection('qr_tokens')
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            // Composite docs have the form "${vetId}_${petId}" — filter by '_' presence
            // since Firestore auto-IDs and Firebase Auth UIDs never contain underscores.
            .where((doc) => doc.id.contains('_'))
            .map((doc) => ActiveVetLease.fromMap(doc.data(), doc.id))
            .where((lease) => !lease.isExpired)
            .toList());
  }

  Future<String> getVetDisplayName(String vetId) async {
    try {
      final doc = await _firestore.demoCollection('users').doc(vetId).get();
      return doc.data()?['displayName'] as String? ?? 'Veterinario';
    } catch (_) {
      return 'Veterinario';
    }
  }
}

final qrRepositoryProvider = Provider<QrRepository>((ref) {
  return QrRepository(FirebaseFirestore.instance);
});

final activeVetLeasesProvider =
    StreamProvider.family<List<ActiveVetLease>, String>((ref, ownerId) {
  final repo = ref.watch(qrRepositoryProvider);
  return repo.watchActiveLeasesByOwner(ownerId);
});

final vetDisplayNameProvider =
    FutureProvider.family<String, String>((ref, vetId) async {
  final repo = ref.watch(qrRepositoryProvider);
  return repo.getVetDisplayName(vetId);
});
