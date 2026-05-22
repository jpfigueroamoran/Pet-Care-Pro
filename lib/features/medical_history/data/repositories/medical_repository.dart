import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../domain/entities/medical_record_entity.dart';

class MedicalRepository {
  final FirebaseFirestore _firestore;

  MedicalRepository(this._firestore);

  /// Escuchar el historial clínico en tiempo real ordenado por fecha descendente
  Stream<List<MedicalRecordEntity>> watchMedicalHistory(String petId) {
    return _firestore
        .demoCollection('pets')
        .doc(petId)
        .collection('medical_history')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MedicalRecordEntity.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Añadir una nueva consulta clínica al expediente en Firestore
  Future<void> addMedicalRecord(String petId, MedicalRecordEntity record) async {
    await _firestore
        .demoCollection('pets')
        .doc(petId)
        .collection('medical_history')
        .add(record.toMap());
  }

  /// Registrar una inmunización (vacuna o desparasitación) en la cartilla de la mascota
  Future<void> addVaccinationRecord(String petId, Map<String, dynamic> entry) async {
    await _firestore
        .demoCollection('pets')
        .doc(petId)
        .collection('vaccination_card')
        .add(entry);
  }

  /// Certificar una entrada de vacunación autoreportada por el dueño
  Future<void> certifyVaccinationRecord(
    String petId,
    String entryId,
    String vetId,
    String vetName,
  ) async {
    await _firestore
        .demoCollection('pets')
        .doc(petId)
        .collection('vaccination_card')
        .doc(entryId)
        .update({
      'verifiedByVet': true,
      'appliedByVetId': vetId,
      'appliedByVetName': vetName,
      'certifiedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Escuchar el historial de la cartilla de vacunación de la mascota en tiempo real
  Stream<List<Map<String, dynamic>>> watchVaccinationCard(String petId) {
    return _firestore
        .demoCollection('pets')
        .doc(petId)
        .collection('vaccination_card')
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}

// Proveedor global del repositorio clínico
final medicalRepositoryProvider = Provider<MedicalRepository>((ref) {
  return MedicalRepository(FirebaseFirestore.instance);
});

// Proveedor de flujo de historial clínico filtrado por petId
final medicalHistoryStreamProvider = StreamProvider.family<List<MedicalRecordEntity>, String>((ref, petId) {
  final repository = ref.watch(medicalRepositoryProvider);
  return repository.watchMedicalHistory(petId);
});

// Proveedor de flujo de la cartilla de vacunación filtrada por petId
final vaccinationCardStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, petId) {
  final repository = ref.watch(medicalRepositoryProvider);
  return repository.watchVaccinationCard(petId);
});
