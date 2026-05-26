import '../entities/behavioral_assessment_entity.dart';
import '../entities/boarding_enums.dart';
import '../entities/boarding_reservation_entity.dart';
import '../entities/use_case_result.dart';
import '../entities/vaccination_entry_entity.dart';
import '../repositories/i_boarding_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Caso de Uso: Verificar Habilitación Sanitaria y Conductual
//
// Ejecuta el pipeline de validación antes de confirmar una reserva:
//   1. Vacunas obligatorias vigentes (Bordetella + Rabia)
//   2. Nivel de riesgo individual no bloqueante
//   3. Autorizaciones legales mínimas firmadas
//   4. ICD pairwise con mascotas en la misma franja horaria
// ─────────────────────────────────────────────────────────────────────────────

class VerifySanitaryClearanceParams {
  final String petId;
  final DateTime checkIn;
  final DateTime checkOut;
  final bool emergencyMedicationAllowed;
  final bool contactVetAllowed;

  /// Especie de la mascota ('Perro', 'Gato', etc.) — determina las vacunas obligatorias.
  final String species;

  /// Filtra las mascotas activas para el ICD a la misma sucursal.
  final String? branchId;

  const VerifySanitaryClearanceParams({
    required this.petId,
    required this.checkIn,
    required this.checkOut,
    required this.emergencyMedicationAllowed,
    required this.contactVetAllowed,
    this.species = 'Perro',
    this.branchId,
  });
}

class VerifySanitaryClearanceUseCase {
  final IBoardingRepository _repository;

  const VerifySanitaryClearanceUseCase(this._repository);

  Future<UseCaseResult<SanitaryClearanceData>> call(
    VerifySanitaryClearanceParams params,
  ) async {
    // ── 1. Cartilla de vacunación ─────────────────────────────────────────
    final vaccResult = await _repository.getVaccinationCard(params.petId);
    if (vaccResult.isFailure) {
      return Failure(
        message: vaccResult.errorMessage,
        code: FailureCode.networkError,
      );
    }
    final vaccines = vaccResult.data;

    // ── 2. Evaluación conductual ──────────────────────────────────────────
    final assessResult =
        await _repository.getLatestAssessment(params.petId);
    if (assessResult.isFailure) {
      return Failure(
        message: assessResult.errorMessage,
        code: FailureCode.networkError,
      );
    }
    final assessment = assessResult.data;

    // ── 3. Mascotas activas en la misma franja (filtradas por sucursal) ─────
    final activePetsResult = await _repository.getAssessmentsForActivePets(
      checkIn: params.checkIn,
      checkOut: params.checkOut,
      excludePetId: params.petId,
      branchId: params.branchId,
    );
    if (activePetsResult.isFailure) {
      return Failure(
        message: activePetsResult.errorMessage,
        code: FailureCode.networkError,
      );
    }
    final activePetAssessments = activePetsResult.data;

    // ── 4. Pipeline de validación ─────────────────────────────────────────
    final blockers = <ClearanceBlocker>[];
    final expiredVaccines = <VaccinationEntryEntity>[];

    // 4a. Vacunas obligatorias
    if (vaccines.isEmpty) {
      blockers.add(const ClearanceBlocker(
        type: ClearanceBlockerType.insufficientVaccinationData,
        description: 'No se encontraron registros de vacunación para esta mascota.',
      ));
    } else {
      for (final required in VaccineType.mandatoryForSpecies(params.species)) {
        final match = _findVaccine(vaccines, required);
        if (match == null) {
          blockers.add(ClearanceBlocker(
            type: ClearanceBlockerType.missingMandatoryVaccine,
            description: 'Vacuna obligatoria faltante: ${required.displayName}.',
            relatedEntityId: required.value,
          ));
        } else if (match.isExpired) {
          expiredVaccines.add(match);
          blockers.add(ClearanceBlocker(
            type: ClearanceBlockerType.expiredMandatoryVaccine,
            description: '${required.displayName} vencida el ${match.nextApplicationAt}.',
            relatedEntityId: match.id,
          ));
        }
      }
    }

    // 4b. Nivel de riesgo individual
    final RiskLevel riskLevel =
        assessment?.riskLevel ?? RiskLevel.green;
    if (riskLevel == RiskLevel.red) {
      blockers.add(ClearanceBlocker(
        type: ClearanceBlockerType.riskLevelTooHigh,
        description:
            'Nivel de riesgo ROJO: requiere aislamiento. El ingreso a área común no está permitido.',
      ));
    }

    // 4c. Autorizaciones legales mínimas
    if (!params.emergencyMedicationAllowed || !params.contactVetAllowed) {
      blockers.add(const ClearanceBlocker(
        type: ClearanceBlockerType.legalAuthorizationsMissing,
        description:
            'Las autorizaciones mínimas (medicación de emergencia y contacto veterinario) no han sido firmadas.',
      ));
    }

    // 4d. ICD pairwise — solo si hay evaluación conductual
    final compatibilityPairs = <CompatibilityPair>[];
    double minIcdScore = 100.0;

    if (assessment != null) {
      for (final other in activePetAssessments) {
        final score = _computeIcd(assessment, other);
        final level = CompatibilityLevel.fromScore(score);
        compatibilityPairs.add(CompatibilityPair(
          withPetId: other.id,
          withPetName: other.assessedBy, // se rellena con petName en la capa data
          score: score,
          level: level,
        ));
        if (score < minIcdScore) minIcdScore = score;
        if (level.blocksAdmission) {
          blockers.add(ClearanceBlocker(
            type: ClearanceBlockerType.incompatibleWithExistingPet,
            description:
                'ICD < 25 con mascota en la misma franja horaria. Se requiere separación.',
            relatedEntityId: other.id,
          ));
        }
      }
    } else if (activePetAssessments.isNotEmpty) {
      // Sin evaluación propia pero hay otras mascotas → revisión manual
      blockers.add(const ClearanceBlocker(
        type: ClearanceBlockerType.insufficientVaccinationData,
        description:
            'No existe evaluación conductual registrada. Se requiere revisión manual del staff.',
      ));
    }

    final requiresManualReview =
        compatibilityPairs.any((p) => p.level.requiresManualReview) ||
        assessment == null ||
        riskLevel.requiresStaffAlert;

    return Success(SanitaryClearanceData(
      isCleared: blockers.isEmpty,
      riskLevel: riskLevel,
      minIcdScore: minIcdScore,
      compatibilityPairs: compatibilityPairs,
      blockers: blockers,
      expiredVaccines: expiredVaccines,
      requiresManualStaffReview: requiresManualReview,
    ));
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  VaccinationEntryEntity? _findVaccine(
    List<VaccinationEntryEntity> vaccines,
    VaccineType type,
  ) {
    try {
      return vaccines.lastWhere(
        (v) => v.vaccineType == type && v.isVaccine,
      );
    } catch (_) {
      return null;
    }
  }

  /// ICD (Índice de Compatibilidad Dinámica) — escala 0–100 (100 = perfecta).
  /// Penalizaciones:
  ///   - Compatibilidad entre perros (DogCompatibility.penaltyWith): 0–40 pts
  ///   - Diferencia de energía (energyMismatchPenalty): 0–20 pts
  ///   - Guardia de recursos del pet A (resourceGuardingPenalty): 0–25 pts
  ///   - Riesgo individual de cada uno (individualRiskPenalty×2): 0–30 pts
  double _computeIcd(
    BehavioralAssessmentEntity a,
    BehavioralAssessmentEntity b,
  ) {
    double penalty = 0;
    penalty += a.sociability.dogCompatibility
        .penaltyWith(b.sociability.dogCompatibility);
    penalty += a.energyMismatchPenalty(b.energyLevel);
    penalty += a.resourceGuardingPenalty;
    penalty += b.resourceGuardingPenalty;
    penalty += a.individualRiskPenalty;
    penalty += b.individualRiskPenalty;
    return (100 - penalty).clamp(0, 100);
  }
}
