import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/vaccination_entry_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de Datos: Entrada de Vacunación / Desparasitación
// Ruta Firestore: /pets/{petId}/vaccination_card/{entryId}
// Compatible con registros v1.0.0 (sin vaccineType).
// ─────────────────────────────────────────────────────────────────────────────

class VaccinationEntryModel extends VaccinationEntryEntity {
  const VaccinationEntryModel({
    required super.id,
    super.vaccineType,
    required super.name,
    required super.type,
    required super.appliedAt,
    super.nextApplicationAt,
    required super.appliedByVetId,
    required super.appliedByVetName,
    super.verifiedByVet,
    super.lot,
    super.notes,
  });

  factory VaccinationEntryModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    DateTime? nextApplication;
    if (map['nextApplicationAt'] != null) {
      nextApplication = (map['nextApplicationAt'] as Timestamp).toDate();
    } else if (map['nextApplicationDate'] != null) {
      // Compatibilidad con campo legacy v1.0.0
      nextApplication =
          (map['nextApplicationDate'] as Timestamp).toDate();
    }

    return VaccinationEntryModel(
      id: docId,
      vaccineType: map['vaccineType'] != null
          ? VaccineType.fromString(map['vaccineType'] as String?)
          : null,
      name: map['name'] as String? ??
          map['vaccineName'] as String? ?? // campo legacy
          '',
      type: map['type'] as String? ?? 'vaccine',
      appliedAt: map['appliedAt'] != null
          ? (map['appliedAt'] as Timestamp).toDate()
          : map['date'] != null
              ? (map['date'] as Timestamp).toDate() // campo legacy
              : DateTime.now(),
      nextApplicationAt: nextApplication,
      appliedByVetId: map['appliedByVetId'] as String? ?? '',
      appliedByVetName: map['appliedByVetName'] as String? ??
          map['vetName'] as String? ?? // campo legacy
          '',
      verifiedByVet: map['verifiedByVet'] as bool? ?? false,
      lot: map['lot'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (vaccineType != null) 'vaccineType': vaccineType!.value,
        'name': name,
        'type': type,
        'appliedAt': Timestamp.fromDate(appliedAt),
        if (nextApplicationAt != null)
          'nextApplicationAt': Timestamp.fromDate(nextApplicationAt!),
        'appliedByVetId': appliedByVetId,
        'appliedByVetName': appliedByVetName,
        'verifiedByVet': verifiedByVet,
        if (lot != null) 'lot': lot,
        if (notes != null) 'notes': notes,
      };
}
