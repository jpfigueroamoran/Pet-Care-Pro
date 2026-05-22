class MedicalRecordEntity {
  final String id;
  final DateTime date;
  final String reason; // Consulta, Urgencia, Cirugía
  final double weightKg;
  final String justification;
  final String diagnosis;
  final String treatment;
  final String prescription;
  final String vetId;
  final String vetName;
  final String notes;
  final List<String> attachments;

  const MedicalRecordEntity({
    required this.id,
    required this.date,
    required this.reason,
    required this.weightKg,
    required this.justification,
    required this.diagnosis,
    required this.treatment,
    required this.prescription,
    required this.vetId,
    required this.vetName,
    required this.notes,
    required this.attachments,
  });

  factory MedicalRecordEntity.fromMap(Map<String, dynamic> map, String docId) {
    return MedicalRecordEntity(
      id: docId,
      date: map['date'] != null
          ? (map['date'] as dynamic).toDate()
          : DateTime.now(),
      reason: map['reason'] ?? 'Consulta',
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      justification: map['justification'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      treatment: map['treatment'] ?? '',
      prescription: map['prescription'] ?? '',
      vetId: map['vetId'] ?? '',
      vetName: map['vetName'] ?? '',
      notes: map['notes'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'reason': reason,
      'weightKg': weightKg,
      'justification': justification,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'prescription': prescription,
      'vetId': vetId,
      'vetName': vetName,
      'notes': notes,
      'attachments': attachments,
    };
  }

  MedicalRecordEntity copyWith({
    String? id,
    DateTime? date,
    String? reason,
    double? weightKg,
    String? justification,
    String? diagnosis,
    String? treatment,
    String? prescription,
    String? vetId,
    String? vetName,
    String? notes,
    List<String>? attachments,
  }) {
    return MedicalRecordEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      weightKg: weightKg ?? this.weightKg,
      justification: justification ?? this.justification,
      diagnosis: diagnosis ?? this.diagnosis,
      treatment: treatment ?? this.treatment,
      prescription: prescription ?? this.prescription,
      vetId: vetId ?? this.vetId,
      vetName: vetName ?? this.vetName,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
    );
  }
}
