import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/behavioral_assessment_entity.dart';
import '../../domain/entities/boarding_enums.dart';
import 'boarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado
// ─────────────────────────────────────────────────────────────────────────────

class TriageState {
  final String petId;

  // ── Perfil físico (sincronizado con /pets/{petId}) ─────────────────────
  final double? weightKg;
  final CoatType coatType;
  final CoatCondition coatCondition;
  final SizeCategory? sizeCategory;

  // ── Evaluación conductual ─────────────────────────────────────────────
  final RiskLevel riskLevel;
  final EnergyLevel energyLevel;

  // Sociabilidad
  final DogCompatibility dogCompatibility;
  final bool requiresMuzzle;
  final PlayStyle playStyle;

  // Disparadores de riesgo
  final bool foodGuarding;
  final bool toyGuarding;
  final bool separationAnxiety;
  final bool confinementPanic;
  final bool noiseSensitivity;

  // Tolerancia al manejo
  final BathSensitivity bathSensitivity;
  final DryingSensitivity dryingSensitivity;
  final NailTrimming nailTrimming;

  // Notas operativas
  final String operationalNotes;

  // ── UI ────────────────────────────────────────────────────────────────
  final bool isSaving;
  final String? errorMessage;
  final BehavioralAssessmentEntity? savedAssessment;

  const TriageState({
    required this.petId,
    this.weightKg,
    this.coatType = CoatType.SHORT,
    this.coatCondition = CoatCondition.NORMAL,
    this.sizeCategory,
    this.riskLevel = RiskLevel.green,
    this.energyLevel = EnergyLevel.medium,
    this.dogCompatibility = DogCompatibility.selective,
    this.requiresMuzzle = false,
    this.playStyle = PlayStyle.gentle,
    this.foodGuarding = false,
    this.toyGuarding = false,
    this.separationAnxiety = false,
    this.confinementPanic = false,
    this.noiseSensitivity = false,
    this.bathSensitivity = BathSensitivity.cooperative,
    this.dryingSensitivity = DryingSensitivity.low,
    this.nailTrimming = NailTrimming.cooperative,
    this.operationalNotes = '',
    this.isSaving = false,
    this.errorMessage,
    this.savedAssessment,
  });

  bool get hasActiveTriggers =>
      foodGuarding || toyGuarding || separationAnxiety ||
      confinementPanic || noiseSensitivity;

  bool get isHighRisk =>
      riskLevel == RiskLevel.orange || riskLevel == RiskLevel.red;

  SizeCategory get effectiveSizeCategory {
    if (sizeCategory != null) return sizeCategory!;
    if (weightKg != null) return SizeCategory.fromWeight(weightKg!);
    return SizeCategory.MEDIUM;
  }

  TriageState copyWith({
    double? weightKg,
    CoatType? coatType,
    CoatCondition? coatCondition,
    SizeCategory? sizeCategory,
    RiskLevel? riskLevel,
    EnergyLevel? energyLevel,
    DogCompatibility? dogCompatibility,
    bool? requiresMuzzle,
    PlayStyle? playStyle,
    bool? foodGuarding,
    bool? toyGuarding,
    bool? separationAnxiety,
    bool? confinementPanic,
    bool? noiseSensitivity,
    BathSensitivity? bathSensitivity,
    DryingSensitivity? dryingSensitivity,
    NailTrimming? nailTrimming,
    String? operationalNotes,
    bool? isSaving,
    String? errorMessage,
    BehavioralAssessmentEntity? savedAssessment,
    bool clearError = false,
  }) =>
      TriageState(
        petId: petId,
        weightKg: weightKg ?? this.weightKg,
        coatType: coatType ?? this.coatType,
        coatCondition: coatCondition ?? this.coatCondition,
        sizeCategory: sizeCategory ?? this.sizeCategory,
        riskLevel: riskLevel ?? this.riskLevel,
        energyLevel: energyLevel ?? this.energyLevel,
        dogCompatibility: dogCompatibility ?? this.dogCompatibility,
        requiresMuzzle: requiresMuzzle ?? this.requiresMuzzle,
        playStyle: playStyle ?? this.playStyle,
        foodGuarding: foodGuarding ?? this.foodGuarding,
        toyGuarding: toyGuarding ?? this.toyGuarding,
        separationAnxiety: separationAnxiety ?? this.separationAnxiety,
        confinementPanic: confinementPanic ?? this.confinementPanic,
        noiseSensitivity: noiseSensitivity ?? this.noiseSensitivity,
        bathSensitivity: bathSensitivity ?? this.bathSensitivity,
        dryingSensitivity: dryingSensitivity ?? this.dryingSensitivity,
        nailTrimming: nailTrimming ?? this.nailTrimming,
        operationalNotes: operationalNotes ?? this.operationalNotes,
        isSaving: isSaving ?? this.isSaving,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        savedAssessment: savedAssessment ?? this.savedAssessment,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class TriageNotifier extends StateNotifier<TriageState> {
  final Ref _ref;

  TriageNotifier(this._ref, String petId) : super(TriageState(petId: petId));

  // ── Setters individuales ──────────────────────────────────────────────────

  void setWeight(double? kg) =>
      state = state.copyWith(weightKg: kg, clearError: true);
  void setCoatType(CoatType v) =>
      state = state.copyWith(coatType: v, clearError: true);
  void setCoatCondition(CoatCondition v) =>
      state = state.copyWith(coatCondition: v, clearError: true);
  void setSizeCategory(SizeCategory? v) =>
      state = state.copyWith(sizeCategory: v, clearError: true);
  void setRiskLevel(RiskLevel v) =>
      state = state.copyWith(riskLevel: v, clearError: true);
  void setEnergyLevel(EnergyLevel v) =>
      state = state.copyWith(energyLevel: v, clearError: true);
  void setDogCompatibility(DogCompatibility v) =>
      state = state.copyWith(dogCompatibility: v, clearError: true);
  void setRequiresMuzzle(bool v) =>
      state = state.copyWith(requiresMuzzle: v);
  void setPlayStyle(PlayStyle v) =>
      state = state.copyWith(playStyle: v);
  void setFoodGuarding(bool v) =>
      state = state.copyWith(foodGuarding: v);
  void setToyGuarding(bool v) =>
      state = state.copyWith(toyGuarding: v);
  void setSeparationAnxiety(bool v) =>
      state = state.copyWith(separationAnxiety: v);
  void setConfinementPanic(bool v) =>
      state = state.copyWith(confinementPanic: v);
  void setNoiseSensitivity(bool v) =>
      state = state.copyWith(noiseSensitivity: v);
  void setBathSensitivity(BathSensitivity v) =>
      state = state.copyWith(bathSensitivity: v);
  void setDryingSensitivity(DryingSensitivity v) =>
      state = state.copyWith(dryingSensitivity: v);
  void setNailTrimming(NailTrimming v) =>
      state = state.copyWith(nailTrimming: v);
  void setOperationalNotes(String v) =>
      state = state.copyWith(operationalNotes: v);

  // ── Acción principal ──────────────────────────────────────────────────────

  /// Guarda la evaluación conductual en Firestore y actualiza los campos
  /// físicos del documento de la mascota en una operación paralela.
  Future<void> saveAssessment() async {
    if (state.isSaving) return;
    state = state.copyWith(isSaving: true, clearError: true);

    final staffUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (staffUid.isEmpty) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No se pudo identificar al staff autenticado.',
      );
      return;
    }

    try {
      // Construir la entidad de evaluación
      final assessment = BehavioralAssessmentEntity(
        id: '',
        assessedAt: DateTime.now(),
        assessedBy: staffUid,
        riskLevel: state.riskLevel,
        energyLevel: state.energyLevel,
        sociability: Sociability(
          dogCompatibility: state.dogCompatibility,
          requiresMuzzle: state.requiresMuzzle,
          playStyle: state.playStyle,
        ),
        riskTriggers: RiskTriggers(
          foodGuarding: state.foodGuarding,
          toyGuarding: state.toyGuarding,
          separationAnxiety: state.separationAnxiety,
          confinementPanic: state.confinementPanic,
          noiseSensitivity: state.noiseSensitivity,
        ),
        handlingTolerance: HandlingTolerance(
          bathSensitivity: state.bathSensitivity,
          dryingSensitivity: state.dryingSensitivity,
          nailTrimming: state.nailTrimming,
        ),
        operationalNotes: state.operationalNotes,
      );

      // Guardar evaluación conductual + actualizar perfil físico en paralelo
      final repo = _ref.read(boardingRepositoryProvider);
      await Future.wait([
        repo.saveAssessment(state.petId, assessment).then((result) {
          result.when(
            success: (saved) =>
                state = state.copyWith(isSaving: false, savedAssessment: saved),
            failure: (message, _) =>
                state = state.copyWith(isSaving: false, errorMessage: message),
          );
        }),
        if (state.weightKg != null)
          FirebaseFirestore.instance
              .collection('pets')
              .doc(state.petId)
              .update({
            'weightKg': state.weightKg,
            'coatType': state.coatType.value,
            'coatCondition': state.coatCondition.value,
            if (state.sizeCategory != null)
              'sizeCategory': state.sizeCategory!.value,
          }),
      ]);
    } on FirebaseException catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.message ?? 'Error de Firestore al guardar evaluación.',
      );
    } catch (e) {
      state =
          state.copyWith(isSaving: false, errorMessage: 'Error inesperado: $e');
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final triageNotifierProvider = StateNotifierProvider.family<
    TriageNotifier,
    TriageState,
    String>((ref, petId) => TriageNotifier(ref, petId));
