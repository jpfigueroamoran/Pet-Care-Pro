import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/boarding_repository.dart';
import '../../domain/entities/behavioral_assessment_entity.dart';
import '../../domain/entities/boarding_reservation_entity.dart';
import '../../domain/entities/vaccination_entry_entity.dart';
import '../../domain/repositories/i_boarding_repository.dart';
import '../../domain/usecases/calculate_service_duration_usecase.dart';
import '../../domain/usecases/generate_pet_link_code_usecase.dart';
import '../../domain/usecases/link_pet_to_owner_usecase.dart';
import '../../domain/usecases/verify_sanitary_clearance_usecase.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repositorio
// ─────────────────────────────────────────────────────────────────────────────

final boardingRepositoryProvider = Provider<IBoardingRepository>((ref) {
  return BoardingRepository(FirebaseFirestore.instance);
});

// ─────────────────────────────────────────────────────────────────────────────
// Casos de Uso
// ─────────────────────────────────────────────────────────────────────────────

final generatePetLinkCodeUseCaseProvider = Provider<GeneratePetLinkCodeUseCase>((ref) {
  return GeneratePetLinkCodeUseCase(ref.watch(boardingRepositoryProvider));
});

final linkPetToOwnerUseCaseProvider = Provider<LinkPetToOwnerUseCase>((ref) {
  return const LinkPetToOwnerUseCase();
});

final verifySanitaryClearanceUseCaseProvider = Provider<VerifySanitaryClearanceUseCase>((ref) {
  return VerifySanitaryClearanceUseCase(ref.watch(boardingRepositoryProvider));
});

// Cómputo puro — no necesita repositorio
final calculateServiceDurationUseCaseProvider =
    Provider<CalculateServiceDurationUseCase>((_) => const CalculateServiceDurationUseCase());

// ─────────────────────────────────────────────────────────────────────────────
// Streams en tiempo real
// ─────────────────────────────────────────────────────────────────────────────

final vaccinationCardStreamProvider =
    StreamProvider.family<List<VaccinationEntryEntity>, String>((ref, petId) {
  return ref.watch(boardingRepositoryProvider).watchVaccinationCard(petId);
});

final behavioralAssessmentsStreamProvider =
    StreamProvider.family<List<BehavioralAssessmentEntity>, String>((ref, petId) {
  return ref.watch(boardingRepositoryProvider).watchAssessments(petId);
});

final petReservationsStreamProvider =
    StreamProvider.family<List<BoardingReservationEntity>, String>((ref, petId) {
  return ref.watch(boardingRepositoryProvider).watchReservationsForPet(petId);
});

/// Stream de todas las reservas de una lista de mascotas del dueño.
/// La clave es una string de petIds ordenados y separados por coma para
/// garantizar igualdad estable entre rebuilds (las listas en Dart usan
/// igualdad por referencia, lo que causaría rebuilds infinitos).
/// Cada sub-stream tiene su propia suscripción: cualquier cambio en
/// cualquier mascota dispara una re-emisión del combinado.
final ownerReservationsStreamProvider =
    StreamProvider.family<List<BoardingReservationEntity>, String>(
        (ref, petIdsKey) {
  if (petIdsKey.isEmpty) return Stream.value([]);

  final petIds = petIdsKey.split(',');
  final repo = ref.watch(boardingRepositoryProvider);
  final sc = StreamController<List<BoardingReservationEntity>>();
  final latest = List<List<BoardingReservationEntity>?>.filled(petIds.length, null);

  void emit() {
    if (latest.any((l) => l == null)) return;
    final combined = latest.expand((l) => l!).toList()
      ..sort((a, b) => b.checkInExpected.compareTo(a.checkInExpected));
    sc.add(combined);
  }

  final subs = petIds.asMap().entries.map((entry) {
    return repo.watchReservationsForPet(entry.value).listen(
      (list) { latest[entry.key] = list; emit(); },
      onError: sc.addError,
    );
  }).toList();

  ref.onDispose(() {
    for (final sub in subs) { sub.cancel(); }
    sc.close();
  });

  return sc.stream;
});
