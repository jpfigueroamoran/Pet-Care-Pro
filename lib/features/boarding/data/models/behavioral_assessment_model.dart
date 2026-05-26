import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/behavioral_assessment_entity.dart';
import '../../domain/entities/boarding_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de Datos: Evaluación Conductual
// Ruta Firestore: /pets/{petId}/behavioral_assessments/{assessId}
// ─────────────────────────────────────────────────────────────────────────────

class BehavioralAssessmentModel extends BehavioralAssessmentEntity {
  const BehavioralAssessmentModel({
    required super.id,
    required super.assessedAt,
    required super.assessedBy,
    required super.riskLevel,
    required super.energyLevel,
    required super.sociability,
    required super.riskTriggers,
    required super.handlingTolerance,
    super.operationalNotes,
  });

  factory BehavioralAssessmentModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    final sociabilityMap = map['sociability'] as Map<String, dynamic>? ?? {};
    final riskTriggersMap = map['riskTriggers'] as Map<String, dynamic>? ?? {};
    final handlingMap = map['handlingTolerance'] as Map<String, dynamic>? ?? {};

    return BehavioralAssessmentModel(
      id: docId,
      assessedAt: (map['assessedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assessedBy: map['assessedBy'] as String? ?? '',
      riskLevel: RiskLevel.fromString(map['riskLevel'] as String?),
      energyLevel: EnergyLevel.fromString(map['energyLevel'] as String?),
      sociability: Sociability(
        dogCompatibility: DogCompatibility.fromString(
          sociabilityMap['dogCompatibility'] as String?,
        ),
        requiresMuzzle: sociabilityMap['requiresMuzzle'] as bool? ?? false,
        playStyle: PlayStyle.fromString(
          sociabilityMap['playStyle'] as String?,
        ),
      ),
      riskTriggers: RiskTriggers(
        foodGuarding: riskTriggersMap['foodGuarding'] as bool? ?? false,
        toyGuarding: riskTriggersMap['toyGuarding'] as bool? ?? false,
        separationAnxiety: riskTriggersMap['separationAnxiety'] as bool? ?? false,
        confinementPanic: riskTriggersMap['confinementPanic'] as bool? ?? false,
        noiseSensitivity: riskTriggersMap['noiseSensitivity'] as bool? ?? false,
      ),
      handlingTolerance: HandlingTolerance(
        bathSensitivity: BathSensitivity.fromString(
          handlingMap['bathSensitivity'] as String?,
        ),
        dryingSensitivity: DryingSensitivity.fromString(
          handlingMap['dryingSensitivity'] as String?,
        ),
        nailTrimming: NailTrimming.fromString(
          handlingMap['nailTrimming'] as String?,
        ),
      ),
      operationalNotes: map['operationalNotes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'assessedAt': Timestamp.fromDate(assessedAt),
        'assessedBy': assessedBy,
        'riskLevel': riskLevel.value,
        'energyLevel': energyLevel.value,
        'sociability': {
          'dogCompatibility': sociability.dogCompatibility.value,
          'requiresMuzzle': sociability.requiresMuzzle,
          'playStyle': sociability.playStyle.value,
        },
        'riskTriggers': {
          'foodGuarding': riskTriggers.foodGuarding,
          'toyGuarding': riskTriggers.toyGuarding,
          'separationAnxiety': riskTriggers.separationAnxiety,
          'confinementPanic': riskTriggers.confinementPanic,
          'noiseSensitivity': riskTriggers.noiseSensitivity,
        },
        'handlingTolerance': {
          'bathSensitivity': handlingTolerance.bathSensitivity.value,
          'dryingSensitivity': handlingTolerance.dryingSensitivity.value,
          'nailTrimming': handlingTolerance.nailTrimming.value,
        },
        'operationalNotes': operationalNotes,
      };
}
