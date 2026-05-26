import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/boarding_reservation_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de Datos: Reserva de Guardería / Estancia
// Ruta Firestore: /boarding_reservations/{resId}
// ─────────────────────────────────────────────────────────────────────────────

class BoardingReservationModel extends BoardingReservationEntity {
  const BoardingReservationModel({
    required super.id,
    required super.petId,
    required super.petName,
    required super.ownerId,
    required super.ownerName,
    required super.branchId,
    required super.facilityRunId,
    required super.checkInExpected,
    required super.checkOutExpected,
    required super.status,
    required super.servicesIncluded,
    required super.safetySnapshot,
    required super.legalAuthorizations,
    super.staffNotes,
    required super.createdAt,
  });

  factory BoardingReservationModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    final safetyMap = map['safetySnapshot'] as Map<String, dynamic>? ?? {};
    final legalMap = map['legalAuthorizations'] as Map<String, dynamic>? ?? {};

    return BoardingReservationModel(
      id: docId,
      petId: map['petId'] as String? ?? '',
      petName: map['petName'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      facilityRunId: map['facilityRunId'] as String? ?? '',
      checkInExpected:
          (map['checkInExpected'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkOutExpected:
          (map['checkOutExpected'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ReservationStatus.fromString(map['status'] as String?),
      servicesIncluded: (map['servicesIncluded'] as List<dynamic>? ?? [])
          .map((s) => ServiceType.fromString(s as String?))
          .toList(),
      safetySnapshot: SafetySnapshot(
        riskLevelAtBooking: RiskLevel.fromString(
          safetyMap['riskLevelAtBooking'] as String?,
        ),
        calculatedIcdScore:
            (safetyMap['calculatedIcdScore'] as num?)?.toDouble() ?? 100.0,
        compatibilityLevel: _compatibilityFromString(
          safetyMap['compatibilityLevel'] as String?,
        ),
      ),
      legalAuthorizations: LegalAuthorizations(
        emergencyMedicationAllowed: _readBool(legalMap, 'emergencyMedicationAllowed'),
        emergencyMedicationAcceptedAt: _readAcceptedAt(legalMap, 'emergencyMedicationAllowed'),
        contactVetAllowed: _readBool(legalMap, 'contactVetAllowed'),
        contactVetAcceptedAt: _readAcceptedAt(legalMap, 'contactVetAllowed'),
        waterPlayAllowed: _readBool(legalMap, 'waterPlayAllowed'),
        waterPlayAcceptedAt: _readAcceptedAt(legalMap, 'waterPlayAllowed'),
        mediaUsageAllowed: _readBool(legalMap, 'mediaUsageAllowed'),
        mediaUsageAcceptedAt: _readAcceptedAt(legalMap, 'mediaUsageAllowed'),
      ),
      staffNotes: map['staffNotes'] as String?,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'petId': petId,
        'petName': petName,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'branchId': branchId,
        'facilityRunId': facilityRunId,
        'checkInExpected': Timestamp.fromDate(checkInExpected),
        'checkOutExpected': Timestamp.fromDate(checkOutExpected),
        'status': status.value,
        'servicesIncluded':
            servicesIncluded.map((s) => s.value).toList(),
        'safetySnapshot': {
          'riskLevelAtBooking': safetySnapshot.riskLevelAtBooking.value,
          'calculatedIcdScore': safetySnapshot.calculatedIcdScore,
          'compatibilityLevel':
              safetySnapshot.compatibilityLevel.name,
        },
        'legalAuthorizations': {
          'emergencyMedicationAllowed': _authRecord(
              legalAuthorizations.emergencyMedicationAllowed,
              legalAuthorizations.emergencyMedicationAcceptedAt),
          'contactVetAllowed': _authRecord(
              legalAuthorizations.contactVetAllowed,
              legalAuthorizations.contactVetAcceptedAt),
          'waterPlayAllowed': _authRecord(
              legalAuthorizations.waterPlayAllowed,
              legalAuthorizations.waterPlayAcceptedAt),
          'mediaUsageAllowed': _authRecord(
              legalAuthorizations.mediaUsageAllowed,
              legalAuthorizations.mediaUsageAcceptedAt),
          'documentVersion': LegalAuthorizations.documentVersion,
        },
        if (staffNotes != null) 'staffNotes': staffNotes,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static CompatibilityLevel _compatibilityFromString(String? value) {
    switch (value) {
      case 'compatible':         return CompatibilityLevel.compatible;
      case 'supervised':         return CompatibilityLevel.supervised;
      case 'separationAdvised':  return CompatibilityLevel.separationAdvised;
      case 'incompatible':       return CompatibilityLevel.incompatible;
      default:                   return CompatibilityLevel.compatible;
    }
  }

  /// Serializa un campo de autorización al formato enriquecido con timestamp.
  static Map<String, dynamic> _authRecord(bool accepted, DateTime? acceptedAt) =>
      {
        'accepted': accepted,
        if (accepted && acceptedAt != null)
          'acceptedAt': Timestamp.fromDate(acceptedAt),
        'documentVersion': LegalAuthorizations.documentVersion,
      };

  /// Lee el booleano de la representación legada (bool plano) o del nuevo
  /// formato enriquecido ({accepted: bool, ...}). Backward-compatible.
  static bool _readBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    if (value is Map) return value['accepted'] as bool? ?? false;
    return false;
  }

  /// Extrae el timestamp de aceptación del formato enriquecido. Retorna null
  /// para documentos legados con bool plano.
  static DateTime? _readAcceptedAt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is Map) {
      final ts = value['acceptedAt'];
      if (ts is Timestamp) return ts.toDate();
    }
    return null;
  }
}
