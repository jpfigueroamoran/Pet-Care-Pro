import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/firestore_extension.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/use_case_result.dart';
import 'boarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado
// ─────────────────────────────────────────────────────────────────────────────

class BoardingRegistrationState {
  final String petId;

  // Perfil físico capturado en recepción
  final double? weightKg;
  final CoatType coatType;
  final CoatCondition coatCondition;
  final SizeCategory? sizeCategory; // null → se deriva de weightKg

  // Código PET-XXXX generado para entregar al dueño
  final PetLinkCodeData? generatedCode;

  // UI
  final bool isSavingPhysicalData;
  final bool isGeneratingCode;
  final String? errorMessage;

  const BoardingRegistrationState({
    required this.petId,
    this.weightKg,
    this.coatType = CoatType.SHORT,
    this.coatCondition = CoatCondition.NORMAL,
    this.sizeCategory,
    this.generatedCode,
    this.isSavingPhysicalData = false,
    this.isGeneratingCode = false,
    this.errorMessage,
  });

  bool get hasCode => generatedCode != null;
  bool get isCodeValid =>
      generatedCode != null && DateTime.now().isBefore(generatedCode!.expiresAt);
  bool get isLoading => isSavingPhysicalData || isGeneratingCode;

  /// Categoría de tamaño efectiva: explícita si fue fijada manualmente,
  /// calculada desde el peso si no.
  SizeCategory get effectiveSizeCategory {
    if (sizeCategory != null) return sizeCategory!;
    if (weightKg != null) return SizeCategory.fromWeight(weightKg!);
    return SizeCategory.MEDIUM;
  }

  BoardingRegistrationState copyWith({
    double? weightKg,
    CoatType? coatType,
    CoatCondition? coatCondition,
    SizeCategory? sizeCategory,
    PetLinkCodeData? generatedCode,
    bool? isSavingPhysicalData,
    bool? isGeneratingCode,
    String? errorMessage,
    bool clearError = false,
    bool clearCode = false,
    bool clearSizeOverride = false,
  }) =>
      BoardingRegistrationState(
        petId: petId,
        weightKg: weightKg ?? this.weightKg,
        coatType: coatType ?? this.coatType,
        coatCondition: coatCondition ?? this.coatCondition,
        sizeCategory: clearSizeOverride ? null : (sizeCategory ?? this.sizeCategory),
        generatedCode: clearCode ? null : (generatedCode ?? this.generatedCode),
        isSavingPhysicalData: isSavingPhysicalData ?? this.isSavingPhysicalData,
        isGeneratingCode: isGeneratingCode ?? this.isGeneratingCode,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class BoardingRegistrationNotifier
    extends StateNotifier<BoardingRegistrationState> {
  final Ref _ref;

  BoardingRegistrationNotifier(this._ref, String petId)
      : super(BoardingRegistrationState(petId: petId));

  // ── Setters de campo (llamados desde el formulario UI) ─────────────────

  void setWeight(double? kg) => state = state.copyWith(
        weightKg: kg,
        clearSizeOverride: true,
        clearError: true,
      );

  void setCoatType(CoatType type) =>
      state = state.copyWith(coatType: type, clearError: true);

  void setCoatCondition(CoatCondition condition) =>
      state = state.copyWith(coatCondition: condition, clearError: true);

  void setSizeCategory(SizeCategory? size) =>
      state = state.copyWith(sizeCategory: size, clearError: true);

  // ── Acción principal ──────────────────────────────────────────────────────

  /// Persiste el perfil físico en /pets/{petId} y genera el código PET-XXXX.
  /// Ambos pasos son secuenciales: no se muestra el código si el guardado falla.
  Future<void> saveAndGenerateCode() async {
    if (state.isLoading) return;
    if (state.weightKg == null || state.weightKg! <= 0) {
      state = state.copyWith(
        errorMessage: 'Ingresa el peso de la mascota antes de continuar.',
      );
      return;
    }

    state = state.copyWith(
      isSavingPhysicalData: true,
      clearError: true,
      clearCode: true,
    );

    try {
      // 1. Actualizar perfil físico de la mascota en Firestore
      await FirebaseFirestore.instance
          .demoCollection('pets')
          .doc(state.petId)
          .update({
        'weightKg': state.weightKg,
        'coatType': state.coatType.value,
        'coatCondition': state.coatCondition.value,
        if (state.sizeCategory != null)
          'sizeCategory': state.sizeCategory!.value,
      });

      state = state.copyWith(
        isSavingPhysicalData: false,
        isGeneratingCode: true,
      );

      // 2. Generar código PET-XXXX
      final result =
          await _ref.read(generatePetLinkCodeUseCaseProvider)(state.petId);

      result.when(
        success: (codeData) => state = state.copyWith(
          isGeneratingCode: false,
          generatedCode: codeData,
        ),
        failure: (message, _) => state = state.copyWith(
          isGeneratingCode: false,
          errorMessage: message,
        ),
      );
    } on FirebaseException catch (e) {
      state = state.copyWith(
        isSavingPhysicalData: false,
        isGeneratingCode: false,
        errorMessage: e.message ?? 'Error al guardar datos físicos.',
      );
    } catch (e) {
      state = state.copyWith(
        isSavingPhysicalData: false,
        isGeneratingCode: false,
        errorMessage: 'Error inesperado: $e',
      );
    }
  }

  /// Regenera el código cuando el anterior expiró sin necesidad de re-guardar.
  Future<void> regenerateCode() async {
    if (state.isLoading) return;
    state = state.copyWith(
      clearCode: true,
      isGeneratingCode: true,
      clearError: true,
    );
    try {
      final result =
          await _ref.read(generatePetLinkCodeUseCaseProvider)(state.petId);
      result.when(
        success: (codeData) => state =
            state.copyWith(isGeneratingCode: false, generatedCode: codeData),
        failure: (message, _) => state =
            state.copyWith(isGeneratingCode: false, errorMessage: message),
      );
    } catch (e) {
      state = state.copyWith(
        isGeneratingCode: false,
        errorMessage: 'Error al regenerar código: $e',
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final boardingRegistrationProvider = StateNotifierProvider.family<
    BoardingRegistrationNotifier,
    BoardingRegistrationState,
    String>((ref, petId) => BoardingRegistrationNotifier(ref, petId));
