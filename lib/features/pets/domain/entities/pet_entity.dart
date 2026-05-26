import '../../../boarding/domain/entities/boarding_enums.dart';

class PetEntity {
  final String id;
  final String name;
  final String species;
  final String breed;
  final int age; // edad en meses
  final String photoUrl;
  final String ownerId;
  final String branchId;
  final DateTime createdAt;

  // Alertas Médicas Críticas
  final List<String> allergies;
  final List<String> chronicConditions;

  // Perfil Físico — requerido por el MPT (Motor de Productividad de Tiempos)
  final double? weightKg;
  final CoatType? coatType;
  final CoatCondition? coatCondition;
  final SizeCategory? sizeCategory;

  const PetEntity({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.photoUrl,
    required this.ownerId,
    required this.branchId,
    required this.createdAt,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.weightKg,
    this.coatType,
    this.coatCondition,
    this.sizeCategory,
  });

  /// Categoría de tamaño efectiva: explícita si fue fijada por staff,
  /// calculada desde el peso si no.
  SizeCategory get effectiveSizeCategory =>
      sizeCategory ?? (weightKg != null
          ? SizeCategory.fromWeight(weightKg!)
          : SizeCategory.MEDIUM);

  factory PetEntity.fromMap(Map<String, dynamic> map, String docId) {
    int age = (map['age'] as int?) ?? 0;
    if (age == 0 && map['birthDate'] != null) {
      final birthDate = (map['birthDate'] as dynamic).toDate() as DateTime;
      age = DateTime.now().difference(birthDate).inDays ~/ 30;
    }
    return PetEntity(
      id: docId,
      name: map['name'] ?? '',
      species: map['species'] ?? '',
      breed: map['breed'] ?? '',
      age: age,
      photoUrl: map['photoUrl'] ?? '',
      ownerId: map['ownerId'] ?? '',
      branchId: map['branchId'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      allergies: map['allergies'] != null
          ? List<String>.from(map['allergies'])
          : [],
      chronicConditions: map['chronicConditions'] != null
          ? List<String>.from(map['chronicConditions'])
          : [],
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      coatType: map['coatType'] != null
          ? CoatType.fromString(map['coatType'] as String?)
          : null,
      coatCondition: map['coatCondition'] != null
          ? CoatCondition.fromString(map['coatCondition'] as String?)
          : null,
      sizeCategory: map['sizeCategory'] != null
          ? SizeCategory.fromString(map['sizeCategory'] as String?)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'photoUrl': photoUrl,
      'ownerId': ownerId,
      'branchId': branchId,
      'createdAt': createdAt,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      if (weightKg != null) 'weightKg': weightKg,
      if (coatType != null) 'coatType': coatType!.value,
      if (coatCondition != null) 'coatCondition': coatCondition!.value,
      if (sizeCategory != null) 'sizeCategory': sizeCategory!.value,
    };
  }

  PetEntity copyWith({
    String? id,
    String? name,
    String? species,
    String? breed,
    int? age,
    String? photoUrl,
    String? ownerId,
    String? branchId,
    DateTime? createdAt,
    List<String>? allergies,
    List<String>? chronicConditions,
    double? weightKg,
    CoatType? coatType,
    CoatCondition? coatCondition,
    SizeCategory? sizeCategory,
  }) {
    return PetEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      photoUrl: photoUrl ?? this.photoUrl,
      ownerId: ownerId ?? this.ownerId,
      branchId: branchId ?? this.branchId,
      createdAt: createdAt ?? this.createdAt,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      weightKg: weightKg ?? this.weightKg,
      coatType: coatType ?? this.coatType,
      coatCondition: coatCondition ?? this.coatCondition,
      sizeCategory: sizeCategory ?? this.sizeCategory,
    );
  }
}
