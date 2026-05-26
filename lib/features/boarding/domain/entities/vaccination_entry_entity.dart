import 'boarding_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entidad: Entrada de Vacunación / Desparasitación
// Extiende el modelo de vaccination_card existente (v1.0.0) con tipado fuerte
// para trazabilidad epidemiológica.
// Ruta Firestore: /pets/{petId}/vaccination_card/{entryId}
// ─────────────────────────────────────────────────────────────────────────────

class VaccinationEntryEntity {
  final String id;

  /// Tipo de vacuna o desparasitante. Null si el entry es de tipo legacy (v1.0.0).
  final VaccineType? vaccineType;

  /// Nombre libre, compatible con registros v1.0.0 que no usan vaccineType.
  final String name;

  /// 'vaccine' | 'dewormer'
  final String type;

  final DateTime appliedAt;

  /// Fecha de siguiente aplicación / vencimiento del esquema.
  final DateTime? nextApplicationAt;

  final String appliedByVetId;
  final String appliedByVetName;
  final bool verifiedByVet;
  final String? lot;
  final String? notes;

  const VaccinationEntryEntity({
    required this.id,
    this.vaccineType,
    required this.name,
    required this.type,
    required this.appliedAt,
    this.nextApplicationAt,
    required this.appliedByVetId,
    required this.appliedByVetName,
    this.verifiedByVet = false,
    this.lot,
    this.notes,
  });

  // ── Lógica de dominio pura ────────────────────────────────────────────────

  /// True si el esquema de vacunación ha vencido (nextApplicationAt en el pasado).
  bool get isExpired {
    if (nextApplicationAt == null) return false;
    return nextApplicationAt!.isBefore(DateTime.now());
  }

  /// Días restantes antes del vencimiento (negativo = ya venció).
  int get daysUntilExpiry {
    if (nextApplicationAt == null) return 9999;
    return nextApplicationAt!.difference(DateTime.now()).inDays;
  }

  /// True si vence en los próximos 30 días (útil para recordatorios).
  bool get expiresSoon => !isExpired && daysUntilExpiry <= 30;

  /// True si es de tipo vacuna (no desparasitación).
  bool get isVaccine => type == 'vaccine';

  /// True si esta vacuna es obligatoria para el ingreso a guardería de la especie dada.
  bool isMandatoryForSpecies(String species) =>
      vaccineType != null &&
      VaccineType.mandatoryForSpecies(species).contains(vaccineType);

  VaccinationEntryEntity copyWith({
    String? id,
    VaccineType? vaccineType,
    String? name,
    String? type,
    DateTime? appliedAt,
    DateTime? nextApplicationAt,
    String? appliedByVetId,
    String? appliedByVetName,
    bool? verifiedByVet,
    String? lot,
    String? notes,
  }) =>
      VaccinationEntryEntity(
        id: id ?? this.id,
        vaccineType: vaccineType ?? this.vaccineType,
        name: name ?? this.name,
        type: type ?? this.type,
        appliedAt: appliedAt ?? this.appliedAt,
        nextApplicationAt: nextApplicationAt ?? this.nextApplicationAt,
        appliedByVetId: appliedByVetId ?? this.appliedByVetId,
        appliedByVetName: appliedByVetName ?? this.appliedByVetName,
        verifiedByVet: verifiedByVet ?? this.verifiedByVet,
        lot: lot ?? this.lot,
        notes: notes ?? this.notes,
      );
}
