import 'boarding_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entidad: Autorizaciones Legales del Dueño
// ─────────────────────────────────────────────────────────────────────────────

class LegalAuthorizations {
  final bool emergencyMedicationAllowed;
  final DateTime? emergencyMedicationAcceptedAt;
  final bool contactVetAllowed;
  final DateTime? contactVetAcceptedAt;
  final bool waterPlayAllowed;
  final DateTime? waterPlayAcceptedAt;
  final bool mediaUsageAllowed;
  final DateTime? mediaUsageAcceptedAt;

  /// Versión del documento de términos aceptado. Se incrementa cuando cambia
  /// el texto legal — permite auditar qué versión aceptó cada dueño.
  static const String documentVersion = '1.0';

  const LegalAuthorizations({
    this.emergencyMedicationAllowed = false,
    this.emergencyMedicationAcceptedAt,
    this.contactVetAllowed = false,
    this.contactVetAcceptedAt,
    this.waterPlayAllowed = false,
    this.waterPlayAcceptedAt,
    this.mediaUsageAllowed = false,
    this.mediaUsageAcceptedAt,
  });

  /// True si las autorizaciones mínimas de seguridad están firmadas.
  bool get hasMinimumAuthorizations =>
      emergencyMedicationAllowed && contactVetAllowed;

  LegalAuthorizations copyWith({
    bool? emergencyMedicationAllowed,
    DateTime? emergencyMedicationAcceptedAt,
    bool? contactVetAllowed,
    DateTime? contactVetAcceptedAt,
    bool? waterPlayAllowed,
    DateTime? waterPlayAcceptedAt,
    bool? mediaUsageAllowed,
    DateTime? mediaUsageAcceptedAt,
  }) =>
      LegalAuthorizations(
        emergencyMedicationAllowed:
            emergencyMedicationAllowed ?? this.emergencyMedicationAllowed,
        emergencyMedicationAcceptedAt:
            emergencyMedicationAcceptedAt ?? this.emergencyMedicationAcceptedAt,
        contactVetAllowed: contactVetAllowed ?? this.contactVetAllowed,
        contactVetAcceptedAt: contactVetAcceptedAt ?? this.contactVetAcceptedAt,
        waterPlayAllowed: waterPlayAllowed ?? this.waterPlayAllowed,
        waterPlayAcceptedAt: waterPlayAcceptedAt ?? this.waterPlayAcceptedAt,
        mediaUsageAllowed: mediaUsageAllowed ?? this.mediaUsageAllowed,
        mediaUsageAcceptedAt: mediaUsageAcceptedAt ?? this.mediaUsageAcceptedAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidad: Snapshot de Seguridad (auditoría en el momento de la reserva)
// ─────────────────────────────────────────────────────────────────────────────

class SafetySnapshot {
  final RiskLevel riskLevelAtBooking;

  /// Puntuación ICD calculada al momento de la reserva (0–100).
  final double calculatedIcdScore;

  /// Compatibilidad derivada del ICD. Determina si la reserva fue bloqueada
  /// o requirió revisión manual.
  final CompatibilityLevel compatibilityLevel;

  const SafetySnapshot({
    required this.riskLevelAtBooking,
    required this.calculatedIcdScore,
    required this.compatibilityLevel,
  });

  SafetySnapshot copyWith({
    RiskLevel? riskLevelAtBooking,
    double? calculatedIcdScore,
    CompatibilityLevel? compatibilityLevel,
  }) =>
      SafetySnapshot(
        riskLevelAtBooking: riskLevelAtBooking ?? this.riskLevelAtBooking,
        calculatedIcdScore: calculatedIcdScore ?? this.calculatedIcdScore,
        compatibilityLevel: compatibilityLevel ?? this.compatibilityLevel,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidad: Par de Compatibilidad (resultado del ICD por cada par de mascotas)
// ─────────────────────────────────────────────────────────────────────────────

class CompatibilityPair {
  final String withPetId;
  final String withPetName;
  final double score;
  final CompatibilityLevel level;

  const CompatibilityPair({
    required this.withPetId,
    required this.withPetName,
    required this.score,
    required this.level,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidad Principal: Reserva de Guardería / Estancia
// Ruta Firestore: /boarding_reservations/{resId}
// ─────────────────────────────────────────────────────────────────────────────

class BoardingReservationEntity {
  final String id;
  final String petId;
  final String petName;           // Desnormalizado para consultas de agenda
  final String ownerId;
  final String ownerName;         // Desnormalizado
  final String branchId;
  final String facilityRunId;     // Zona física (perrera / área de día)
  final DateTime checkInExpected;
  final DateTime checkOutExpected;
  final ReservationStatus status;
  final List<ServiceType> servicesIncluded;
  final SafetySnapshot safetySnapshot;
  final LegalAuthorizations legalAuthorizations;
  final String? staffNotes;
  final DateTime createdAt;

  const BoardingReservationEntity({
    required this.id,
    required this.petId,
    required this.petName,
    required this.ownerId,
    required this.ownerName,
    required this.branchId,
    required this.facilityRunId,
    required this.checkInExpected,
    required this.checkOutExpected,
    required this.status,
    required this.servicesIncluded,
    required this.safetySnapshot,
    required this.legalAuthorizations,
    this.staffNotes,
    required this.createdAt,
  });

  // ── Lógica de dominio pura ────────────────────────────────────────────────

  Duration get plannedDuration => checkOutExpected.difference(checkInExpected);

  bool get isActive =>
      status == ReservationStatus.confirmed ||
      status == ReservationStatus.checkedIn;

  bool get includesGrooming =>
      servicesIncluded.contains(ServiceType.bath) ||
      servicesIncluded.contains(ServiceType.haircut);

  bool get requiresManualClearance =>
      safetySnapshot.compatibilityLevel.requiresManualReview;

  /// True si el dueño firmó las autorizaciones mínimas requeridas por el contrato.
  bool get isLegallyCleared => legalAuthorizations.hasMinimumAuthorizations;

  BoardingReservationEntity copyWith({
    String? id,
    String? petId,
    String? petName,
    String? ownerId,
    String? ownerName,
    String? branchId,
    String? facilityRunId,
    DateTime? checkInExpected,
    DateTime? checkOutExpected,
    ReservationStatus? status,
    List<ServiceType>? servicesIncluded,
    SafetySnapshot? safetySnapshot,
    LegalAuthorizations? legalAuthorizations,
    String? staffNotes,
    DateTime? createdAt,
  }) =>
      BoardingReservationEntity(
        id: id ?? this.id,
        petId: petId ?? this.petId,
        petName: petName ?? this.petName,
        ownerId: ownerId ?? this.ownerId,
        ownerName: ownerName ?? this.ownerName,
        branchId: branchId ?? this.branchId,
        facilityRunId: facilityRunId ?? this.facilityRunId,
        checkInExpected: checkInExpected ?? this.checkInExpected,
        checkOutExpected: checkOutExpected ?? this.checkOutExpected,
        status: status ?? this.status,
        servicesIncluded: servicesIncluded ?? this.servicesIncluded,
        safetySnapshot: safetySnapshot ?? this.safetySnapshot,
        legalAuthorizations: legalAuthorizations ?? this.legalAuthorizations,
        staffNotes: staffNotes ?? this.staffNotes,
        createdAt: createdAt ?? this.createdAt,
      );
}
