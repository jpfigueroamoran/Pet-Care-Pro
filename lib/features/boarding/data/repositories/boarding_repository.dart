import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_extension.dart';
import '../../domain/entities/behavioral_assessment_entity.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/boarding_reservation_entity.dart';
import '../../domain/entities/use_case_result.dart';
import '../../domain/entities/vaccination_entry_entity.dart';
import '../../domain/repositories/i_boarding_repository.dart';
import '../models/behavioral_assessment_model.dart';
import '../models/boarding_reservation_model.dart';
import '../models/vaccination_entry_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Implementación: Repositorio de Guardería (Firebase Firestore)
// ─────────────────────────────────────────────────────────────────────────────

class BoardingRepository implements IBoardingRepository {
  final FirebaseFirestore _firestore;

  const BoardingRepository(this._firestore);

  // ── Colecciones ───────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _assessments(String petId) =>
      _firestore
          .demoCollection('pets')
          .doc(petId)
          .collection('behavioral_assessments');

  CollectionReference<Map<String, dynamic>> _vaccinationCard(String petId) =>
      _firestore
          .demoCollection('pets')
          .doc(petId)
          .collection('vaccination_card');

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _firestore.demoCollection('boarding_reservations');

  CollectionReference<Map<String, dynamic>> get _linkCodes =>
      _firestore.demoCollection('pending_links');

  // ── Evaluaciones Conductuales ─────────────────────────────────────────────

  @override
  Future<UseCaseResult<BehavioralAssessmentEntity?>> getLatestAssessment(
    String petId,
  ) async {
    try {
      final snap = await _assessments(petId)
          .orderBy('assessedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return const Success(null);
      final doc = snap.docs.first;
      return Success(BehavioralAssessmentModel.fromMap(doc.data(), doc.id));
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al obtener evaluación conductual.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  @override
  Stream<List<BehavioralAssessmentEntity>> watchAssessments(String petId) =>
      _assessments(petId)
          .orderBy('assessedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => BehavioralAssessmentModel.fromMap(d.data(), d.id))
              .toList());

  @override
  Future<UseCaseResult<BehavioralAssessmentEntity>> saveAssessment(
    String petId,
    BehavioralAssessmentEntity assessment,
  ) async {
    try {
      final model = BehavioralAssessmentModel(
        id: assessment.id,
        assessedAt: assessment.assessedAt,
        assessedBy: assessment.assessedBy,
        riskLevel: assessment.riskLevel,
        energyLevel: assessment.energyLevel,
        sociability: assessment.sociability,
        riskTriggers: assessment.riskTriggers,
        handlingTolerance: assessment.handlingTolerance,
        operationalNotes: assessment.operationalNotes,
      );
      final ref = assessment.id.isEmpty
          ? _assessments(petId).doc()
          : _assessments(petId).doc(assessment.id);
      await ref.set(model.toMap());
      final saved = BehavioralAssessmentModel.fromMap(
        {...model.toMap(), 'assessedAt': Timestamp.fromDate(model.assessedAt)},
        ref.id,
      );
      return Success(saved);
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al guardar evaluación conductual.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  // ── Cartilla de Vacunación ────────────────────────────────────────────────

  @override
  Future<UseCaseResult<List<VaccinationEntryEntity>>> getVaccinationCard(
    String petId,
  ) async {
    try {
      final snap = await _vaccinationCard(petId)
          .orderBy('appliedAt', descending: false)
          .get();
      final entries = snap.docs
          .map((d) => VaccinationEntryModel.fromMap(d.data(), d.id))
          .toList();
      return Success(entries);
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al obtener cartilla de vacunación.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  @override
  Stream<List<VaccinationEntryEntity>> watchVaccinationCard(String petId) =>
      _vaccinationCard(petId)
          .orderBy('appliedAt', descending: false)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => VaccinationEntryModel.fromMap(d.data(), d.id))
              .toList());

  // ── Reservas de Guardería ─────────────────────────────────────────────────

  @override
  Future<UseCaseResult<BoardingReservationEntity>> createReservation(
    BoardingReservationEntity reservation,
  ) async {
    try {
      final model = BoardingReservationModel(
        id: reservation.id,
        petId: reservation.petId,
        petName: reservation.petName,
        ownerId: reservation.ownerId,
        ownerName: reservation.ownerName,
        branchId: reservation.branchId,
        facilityRunId: reservation.facilityRunId,
        checkInExpected: reservation.checkInExpected,
        checkOutExpected: reservation.checkOutExpected,
        status: reservation.status,
        servicesIncluded: reservation.servicesIncluded,
        safetySnapshot: reservation.safetySnapshot,
        legalAuthorizations: reservation.legalAuthorizations,
        staffNotes: reservation.staffNotes,
        createdAt: reservation.createdAt,
      );
      final ref = reservation.id.isEmpty
          ? _reservations.doc()
          : _reservations.doc(reservation.id);
      await ref.set(model.toMap());
      return Success(BoardingReservationModel.fromMap(
        {...model.toMap(), 'createdAt': Timestamp.fromDate(model.createdAt)},
        ref.id,
      ));
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al crear reserva.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  @override
  Future<UseCaseResult<BoardingReservationEntity>> updateReservationStatus(
    String reservationId,
    ReservationStatus newStatus, {
    String? staffNotes,
  }) async {
    try {
      final update = <String, dynamic>{'status': newStatus.value};
      if (staffNotes != null) update['staffNotes'] = staffNotes;
      await _reservations.doc(reservationId).update(update);
      final snap = await _reservations.doc(reservationId).get();
      if (!snap.exists) {
        return const Failure(
          message: 'Reserva no encontrada después de actualizar.',
          code: FailureCode.notFound,
        );
      }
      return Success(
        BoardingReservationModel.fromMap(snap.data()!, snap.id),
      );
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al actualizar estado de reserva.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  @override
  Future<UseCaseResult<BoardingReservationEntity>> updateReservationDates({
    required String reservationId,
    required String petId,
    required DateTime newCheckIn,
    required DateTime newCheckOut,
  }) async {
    if (!newCheckIn.isBefore(newCheckOut)) {
      return const Failure(
        message: 'La fecha de entrada debe ser anterior a la de salida.',
        code: FailureCode.validationError,
      );
    }
    try {
      // Verificar solapamiento con otras reservas activas de la misma mascota
      final overlapSnap = await _reservations
          .where('petId', isEqualTo: petId)
          .where('status', whereIn: ['confirmed', 'checked_in'])
          .where('checkInExpected', isLessThan: Timestamp.fromDate(newCheckOut))
          .where('checkOutExpected', isGreaterThan: Timestamp.fromDate(newCheckIn))
          .limit(2)
          .get();

      final conflicting = overlapSnap.docs.where((d) => d.id != reservationId);
      if (conflicting.isNotEmpty) {
        return const Failure(
          message: 'Ya existe una reserva activa para esta mascota en el período seleccionado.',
          code: FailureCode.validationError,
        );
      }

      await _reservations.doc(reservationId).update({
        'checkInExpected': Timestamp.fromDate(newCheckIn),
        'checkOutExpected': Timestamp.fromDate(newCheckOut),
      });
      final snap = await _reservations.doc(reservationId).get();
      if (!snap.exists) {
        return const Failure(
          message: 'Reserva no encontrada después de actualizar.',
          code: FailureCode.notFound,
        );
      }
      return Success(BoardingReservationModel.fromMap(snap.data()!, snap.id));
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al reagendar la reserva.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  @override
  Future<UseCaseResult<void>> cancelReservation(String reservationId) async {
    try {
      final snap = await _reservations.doc(reservationId).get();
      if (!snap.exists) {
        return const Failure(message: 'Reserva no encontrada.', code: FailureCode.notFound);
      }
      final status = snap.data()?['status'] as String? ?? '';
      if (status != 'pending' && status != 'confirmed') {
        return const Failure(
          message: 'Solo se pueden cancelar reservas pendientes o confirmadas.',
          code: FailureCode.validationError,
        );
      }
      await _reservations.doc(reservationId).update({'status': 'cancelled'});
      return const Success(null);
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al cancelar la reserva.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  @override
  Future<UseCaseResult<List<BoardingReservationEntity>>>
      getActiveReservationsForDate(DateTime date, {String? branchId}) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      var query = _reservations
          .where('status', whereIn: ['confirmed', 'checked_in'])
          .where('checkInExpected',
              isLessThan: Timestamp.fromDate(endOfDay))
          .where('checkOutExpected',
              isGreaterThan: Timestamp.fromDate(startOfDay));
      if (branchId != null && branchId.isNotEmpty) {
        query = query.where('branchId', isEqualTo: branchId);
      }
      final snap = await query.get();
      final reservations = snap.docs
          .map((d) => BoardingReservationModel.fromMap(d.data(), d.id))
          .toList();
      return Success(reservations);
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al obtener reservas activas.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  @override
  Stream<List<BoardingReservationEntity>> watchReservationsForPet(
    String petId,
  ) =>
      _reservations
          .where('petId', isEqualTo: petId)
          .orderBy('checkInExpected', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => BoardingReservationModel.fromMap(d.data(), d.id))
              .toList());

  // ── Sistema de Vinculación de Mascotas ────────────────────────────────────

  @override
  Future<UseCaseResult<PetLinkCodeData>> generateLinkCode(
    String petId, {
    int expiryMinutes = 15,
  }) async {
    try {
      final petSnap = await _firestore.demoCollection('pets').doc(petId).get();
      final branchId = petSnap.exists ? (petSnap.data()?['branchId'] as String? ?? '') : '';

      final code = 'PET-${_generateCode()}';
      final expiresAt =
          DateTime.now().add(Duration(minutes: expiryMinutes));
      await _linkCodes.doc(code).set({
        'petId': petId,
        'code': code,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'redeemed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'branchId': branchId,
      });
      return Success(PetLinkCodeData(
        code: code,
        expiresAt: expiresAt,
        petId: petId,
      ));
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al generar código de vinculación.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  // ── ICD Batch ─────────────────────────────────────────────────────────────

  @override
  Future<UseCaseResult<List<BehavioralAssessmentEntity>>>
      getAssessmentsForActivePets({
    required DateTime checkIn,
    required DateTime checkOut,
    String? excludePetId,
    String? branchId,
  }) async {
    try {
      final reservationsResult =
          await getActiveReservationsForDate(checkIn, branchId: branchId);
      if (reservationsResult.isFailure) {
        return Failure(
          message: reservationsResult.errorMessage,
          code: FailureCode.networkError,
        );
      }

      final petIds = reservationsResult.data
          .map((r) => r.petId)
          .where((id) => id != excludePetId)
          .toSet()
          .toList();

      if (petIds.isEmpty) return const Success([]);

      final assessmentFutures = petIds
          .map((id) => getLatestAssessment(id))
          .toList();

      final results = await Future.wait(assessmentFutures);
      final assessments = results
          .where((r) => r.isSuccess && r.data != null)
          .map((r) => r.data!)
          .toList();

      return Success(assessments);
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al obtener evaluaciones batch.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  // ── Validación de solapamiento ────────────────────────────────────────────

  @override
  Future<UseCaseResult<bool>> hasOverlappingReservation({
    required String petId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    try {
      final snap = await _reservations
          .where('petId', isEqualTo: petId)
          .where('status', whereIn: ['confirmed', 'checked_in'])
          .where('checkInExpected',
              isLessThan: Timestamp.fromDate(checkOut))
          .where('checkOutExpected',
              isGreaterThan: Timestamp.fromDate(checkIn))
          .limit(1)
          .get();
      return Success(snap.docs.isNotEmpty);
    } on FirebaseException catch (e) {
      return Failure(
        message: e.message ?? 'Error al verificar reservas existentes.',
        code: _mapFirestoreCode(e.code),
      );
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  static const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final _random = Random.secure();

  String _generateCode() => String.fromCharCodes(
        Iterable.generate(
          4,
          (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
        ),
      );

  FailureCode _mapFirestoreCode(String code) {
    switch (code) {
      case 'not-found':           return FailureCode.notFound;
      case 'permission-denied':   return FailureCode.permissionDenied;
      case 'unavailable':
      case 'deadline-exceeded':   return FailureCode.networkError;
      default:                    return FailureCode.networkError;
    }
  }
}
