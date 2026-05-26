import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../domain/entities/pet_entity.dart';

class PetRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  PetRepository(this._firestore, this._storage);

  /// Obtener el flujo en tiempo real de las mascotas de un dueño en específico
  Stream<List<PetEntity>> watchPetsByOwner(String ownerId) {
    return _firestore
        .demoCollection('pets')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PetEntity.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Registrar una nueva mascota en Firestore y retornar el ID asignado
  Future<String> addPet(PetEntity pet) async {
    final docRef = await _firestore.demoCollection('pets').add(pet.toMap());
    return docRef.id;
  }

  /// Actualizar los datos de una mascota existente en Firestore
  Future<void> updatePet(PetEntity pet) async {
    await _firestore.demoCollection('pets').doc(pet.id).update(pet.toMap());
  }

  /// Subir imagen de perfil de la mascota a Cloud Storage y obtener su URL pública
  Future<String> uploadPetPhoto(String userId, String fileName, Uint8List fileBytes) async {
    final ref = _storage.ref().child('pets_photos/$userId/$fileName');
    
    // Especificar el tipo de contenido JPEG/PNG para su correcta visualización nativa
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    
    final uploadTask = ref.putData(fileBytes, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Obtener el flujo en tiempo real de todas las mascotas registradas (solo Admin)
  Stream<List<PetEntity>> watchAllPets() {
    return _firestore
        .demoCollection('pets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PetEntity.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}

// Proveedor global del repositorio de mascotas
final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

// Proveedor reactivo del flujo de mascotas filtradas por dueño
final ownerPetsStreamProvider = StreamProvider.family<List<PetEntity>, String>((ref, ownerId) {
  final repository = ref.watch(petRepositoryProvider);
  return repository.watchPetsByOwner(ownerId);
});

// Proveedor reactivo del flujo de todas las mascotas de la plataforma (solo Admin)
final adminAllPetsStreamProvider = StreamProvider<List<PetEntity>>((ref) {
  final repository = ref.watch(petRepositoryProvider);
  return repository.watchAllPets();
});

// Proveedor reactivo de una mascota individual
final singlePetStreamProvider = StreamProvider.family<PetEntity?, String>((ref, petId) {
  return FirebaseFirestore.instance
      .demoCollection('pets')
      .doc(petId)
      .snapshots()
      .map((snap) => snap.exists ? PetEntity.fromMap(snap.data()!, snap.id) : null);
});

// Proveedor reactivo de todas las mascotas asociadas a una sucursal en particular, ordenadas en memoria
final branchPetsStreamProvider = StreamProvider.family<List<PetEntity>, String>((ref, branchId) {
  return FirebaseFirestore.instance
      .demoCollection('pets')
      .where('branchId', isEqualTo: branchId)
      .snapshots()
      .map((snapshot) {
        final pets = snapshot.docs
            .map((doc) => PetEntity.fromMap(doc.data(), doc.id))
            .toList();
        // Ordenamiento seguro en memoria
        pets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return pets;
      });
});

