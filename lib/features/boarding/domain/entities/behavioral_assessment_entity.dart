import 'boarding_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entidad: Sociabilidad
// ─────────────────────────────────────────────────────────────────────────────

class Sociability {
  final DogCompatibility dogCompatibility;
  final bool requiresMuzzle;
  final PlayStyle playStyle;

  const Sociability({
    required this.dogCompatibility,
    required this.requiresMuzzle,
    required this.playStyle,
  });

  Sociability copyWith({
    DogCompatibility? dogCompatibility,
    bool? requiresMuzzle,
    PlayStyle? playStyle,
  }) =>
      Sociability(
        dogCompatibility: dogCompatibility ?? this.dogCompatibility,
        requiresMuzzle: requiresMuzzle ?? this.requiresMuzzle,
        playStyle: playStyle ?? this.playStyle,
      );

  @override
  String toString() =>
      'Sociability(dogCompatibility: $dogCompatibility, requiresMuzzle: $requiresMuzzle, playStyle: $playStyle)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidad: Disparadores de Riesgo
// ─────────────────────────────────────────────────────────────────────────────

class RiskTriggers {
  final bool foodGuarding;
  final bool toyGuarding;
  final bool separationAnxiety;
  final bool confinementPanic;
  final bool noiseSensitivity;

  const RiskTriggers({
    this.foodGuarding = false,
    this.toyGuarding = false,
    this.separationAnxiety = false,
    this.confinementPanic = false,
    this.noiseSensitivity = false,
  });

  /// Total de disparadores activos — usado como señal en el ICD.
  int get activeTriggerCount {
    int count = 0;
    if (foodGuarding) count++;
    if (toyGuarding) count++;
    if (separationAnxiety) count++;
    if (confinementPanic) count++;
    if (noiseSensitivity) count++;
    return count;
  }

  RiskTriggers copyWith({
    bool? foodGuarding,
    bool? toyGuarding,
    bool? separationAnxiety,
    bool? confinementPanic,
    bool? noiseSensitivity,
  }) =>
      RiskTriggers(
        foodGuarding: foodGuarding ?? this.foodGuarding,
        toyGuarding: toyGuarding ?? this.toyGuarding,
        separationAnxiety: separationAnxiety ?? this.separationAnxiety,
        confinementPanic: confinementPanic ?? this.confinementPanic,
        noiseSensitivity: noiseSensitivity ?? this.noiseSensitivity,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidad: Tolerancia al Manejo
// ─────────────────────────────────────────────────────────────────────────────

class HandlingTolerance {
  final BathSensitivity bathSensitivity;
  final DryingSensitivity dryingSensitivity;
  final NailTrimming nailTrimming;

  const HandlingTolerance({
    required this.bathSensitivity,
    required this.dryingSensitivity,
    required this.nailTrimming,
  });

  /// Suma total de penalizaciones de manejo para el MPT.
  int get totalMptPenaltyMinutes =>
      bathSensitivity.mptPenaltyMinutes +
      dryingSensitivity.mptPenaltyMinutes +
      nailTrimming.mptPenaltyMinutes;

  HandlingTolerance copyWith({
    BathSensitivity? bathSensitivity,
    DryingSensitivity? dryingSensitivity,
    NailTrimming? nailTrimming,
  }) =>
      HandlingTolerance(
        bathSensitivity: bathSensitivity ?? this.bathSensitivity,
        dryingSensitivity: dryingSensitivity ?? this.dryingSensitivity,
        nailTrimming: nailTrimming ?? this.nailTrimming,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidad Principal: Evaluación Conductual
// Confidencial — solo visible para staff con canPerformMedical o isAdmin.
// Ruta Firestore: /pets/{petId}/behavioral_assessments/{assessId}
// ─────────────────────────────────────────────────────────────────────────────

class BehavioralAssessmentEntity {
  final String id;
  final DateTime assessedAt;
  final String assessedBy;       // UID del staff que realizó la evaluación
  final RiskLevel riskLevel;
  final EnergyLevel energyLevel;
  final Sociability sociability;
  final RiskTriggers riskTriggers;
  final HandlingTolerance handlingTolerance;
  final String operationalNotes;

  const BehavioralAssessmentEntity({
    required this.id,
    required this.assessedAt,
    required this.assessedBy,
    required this.riskLevel,
    required this.energyLevel,
    required this.sociability,
    required this.riskTriggers,
    required this.handlingTolerance,
    this.operationalNotes = '',
  });

  // ── Lógica de dominio pura ────────────────────────────────────────────────

  /// Penalización ICD por guardia de recursos (máx 25 pts).
  double get resourceGuardingPenalty {
    int triggers = 0;
    if (riskTriggers.foodGuarding) triggers++;
    if (riskTriggers.toyGuarding) triggers++;
    return (triggers * 12.5).clamp(0, 25);
  }

  /// Penalización ICD por nivel de energía con respecto a otro perro.
  double energyMismatchPenalty(EnergyLevel otherEnergy) {
    final delta = energyLevel.energyDelta(otherEnergy);
    // 0 diferencia = 0 pts; máxima diferencia (3) = 20 pts
    return (delta * 6.67).clamp(0, 20);
  }

  /// Penalización ICD por nivel de riesgo individual (máx 15 pts).
  double get individualRiskPenalty {
    switch (riskLevel) {
      case RiskLevel.green:  return 0;
      case RiskLevel.yellow: return 5;
      case RiskLevel.orange: return 10;
      case RiskLevel.red:    return 15;
    }
  }

  BehavioralAssessmentEntity copyWith({
    String? id,
    DateTime? assessedAt,
    String? assessedBy,
    RiskLevel? riskLevel,
    EnergyLevel? energyLevel,
    Sociability? sociability,
    RiskTriggers? riskTriggers,
    HandlingTolerance? handlingTolerance,
    String? operationalNotes,
  }) =>
      BehavioralAssessmentEntity(
        id: id ?? this.id,
        assessedAt: assessedAt ?? this.assessedAt,
        assessedBy: assessedBy ?? this.assessedBy,
        riskLevel: riskLevel ?? this.riskLevel,
        energyLevel: energyLevel ?? this.energyLevel,
        sociability: sociability ?? this.sociability,
        riskTriggers: riskTriggers ?? this.riskTriggers,
        handlingTolerance: handlingTolerance ?? this.handlingTolerance,
        operationalNotes: operationalNotes ?? this.operationalNotes,
      );
}
