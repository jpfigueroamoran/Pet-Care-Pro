class PetEntity {
  final String id;
  final String name;
  final String species;
  final String breed;
  final int age; // edad en meses
  final String photoUrl;
  final String ownerId;
  final DateTime createdAt;
  
  // Alertas Médicas Críticas
  final List<String> allergies;
  final List<String> chronicConditions;

  const PetEntity({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.photoUrl,
    required this.ownerId,
    required this.createdAt,
    this.allergies = const [],
    this.chronicConditions = const [],
  });

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
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      allergies: map['allergies'] != null ? List<String>.from(map['allergies']) : [],
      chronicConditions: map['chronicConditions'] != null ? List<String>.from(map['chronicConditions']) : [],
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
      'createdAt': createdAt,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
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
    DateTime? createdAt,
    List<String>? allergies,
    List<String>? chronicConditions,
  }) {
    return PetEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      photoUrl: photoUrl ?? this.photoUrl,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
    );
  }
}
