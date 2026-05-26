import 'boarding_enums.dart';
import 'boarding_reservation_entity.dart';
import 'vaccination_entry_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Patrón Result — Dominio de Guardería v1.1.0
// Encapsula éxito/fallo sin exponer detalles de infraestructura (Firebase, etc.)
// ─────────────────────────────────────────────────────────────────────────────

enum FailureCode {
  notFound,
  permissionDenied,
  expired,
  validationError,
  networkError,
  businessRuleViolation,
  insufficientData,
}

// ─────────────────────────────────────────────────────────────────────────────

sealed class UseCaseResult<T> {
  const UseCaseResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get data => (this as Success<T>).data;
  String get errorMessage => (this as Failure<T>).message;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, FailureCode code) failure,
  }) {
    if (this is Success<T>) return success((this as Success<T>).data);
    final f = this as Failure<T>;
    return failure(f.message, f.code);
  }
}

final class Success<T> extends UseCaseResult<T> {
  @override
  final T data;
  const Success(this.data);
}

final class Failure<T> extends UseCaseResult<T> {
  final String message;
  final FailureCode code;
  const Failure({required this.message, required this.code});
}

// ─────────────────────────────────────────────────────────────────────────────
// Tipos de resultado específicos por caso de uso
// ─────────────────────────────────────────────────────────────────────────────

// ── Resultado: Habilitación Sanitaria y Conductual ───────────────────────────

enum ClearanceBlockerType {
  expiredMandatoryVaccine,
  missingMandatoryVaccine,
  riskLevelTooHigh,
  incompatibleWithExistingPet,
  legalAuthorizationsMissing,
  insufficientVaccinationData,
}

class ClearanceBlocker {
  final ClearanceBlockerType type;
  final String description;
  final String? relatedEntityId;

  const ClearanceBlocker({
    required this.type,
    required this.description,
    this.relatedEntityId,
  });
}

class SanitaryClearanceData {
  final bool isCleared;
  final RiskLevel riskLevel;
  final double minIcdScore;
  final List<CompatibilityPair> compatibilityPairs;
  final List<ClearanceBlocker> blockers;
  final List<VaccinationEntryEntity> expiredVaccines;
  final bool requiresManualStaffReview;

  const SanitaryClearanceData({
    required this.isCleared,
    required this.riskLevel,
    required this.minIcdScore,
    required this.compatibilityPairs,
    required this.blockers,
    required this.expiredVaccines,
    required this.requiresManualStaffReview,
  });
}

// ── Resultado: Motor de Productividad de Tiempos ─────────────────────────────

class ServiceDurationData {
  final int estimatedMinutes;
  final int staffUnitsRequired;
  final bool requiresVetSupervision;
  final bool canPerformNailTrimming;
  final List<String> penaltyReasons;

  const ServiceDurationData({
    required this.estimatedMinutes,
    required this.staffUnitsRequired,
    required this.requiresVetSupervision,
    required this.canPerformNailTrimming,
    required this.penaltyReasons,
  });
}

// ── Resultado: Generación de Código de Vinculación ───────────────────────────

class PetLinkCodeData {
  final String code;
  final DateTime expiresAt;
  final String petId;

  const PetLinkCodeData({
    required this.code,
    required this.expiresAt,
    required this.petId,
  });
}

// ── Resultado: Vinculación de Mascota a Dueño ────────────────────────────────

class LinkPetData {
  final String petId;
  final String petName;
  final String newOwnerId;

  const LinkPetData({
    required this.petId,
    required this.petName,
    required this.newOwnerId,
  });
}
