import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pets/data/repositories/pet_repository.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/boarding_reservation_entity.dart';
import '../../domain/entities/use_case_result.dart';
import '../../domain/usecases/verify_sanitary_clearance_usecase.dart';
import 'boarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado
// ─────────────────────────────────────────────────────────────────────────────

class ServiceBookingState {
  // ── Selección ─────────────────────────────────────────────────────────
  final String? selectedPetId;
  final String? selectedPetName;
  final List<ServiceType> selectedServices;
  final DateTime? checkIn;
  final DateTime? checkOut;

  // ── Autorizaciones legales del dueño (con timestamps de aceptación) ──
  final bool emergencyMedicationAllowed;
  final DateTime? emergencyMedicationAcceptedAt;
  final bool contactVetAllowed;
  final DateTime? contactVetAcceptedAt;
  final bool waterPlayAllowed;
  final DateTime? waterPlayAcceptedAt;
  final bool mediaUsageAllowed;
  final DateTime? mediaUsageAcceptedAt;

  // ── Resultado MPT (Cloud Function calculateServiceDuration) ───────────
  final int? estimatedMinutes;
  final int? staffUnitsRequired;
  final bool? requiresVetSupervision;
  final bool? canPerformNailTrimming;
  final List<String> penaltyReasons;

  // ── Resultado habilitación sanitaria ─────────────────────────────────
  final SanitaryClearanceData? clearanceData;

  // ── UI ────────────────────────────────────────────────────────────────
  final bool isCalculatingDuration;
  final bool isCheckingClearance;
  final bool isSubmitting;
  final String? errorMessage;
  final BoardingReservationEntity? createdReservation;

  const ServiceBookingState({
    this.selectedPetId,
    this.selectedPetName,
    this.selectedServices = const [],
    this.checkIn,
    this.checkOut,
    this.emergencyMedicationAllowed = false,
    this.emergencyMedicationAcceptedAt,
    this.contactVetAllowed = false,
    this.contactVetAcceptedAt,
    this.waterPlayAllowed = false,
    this.waterPlayAcceptedAt,
    this.mediaUsageAllowed = false,
    this.mediaUsageAcceptedAt,
    this.estimatedMinutes,
    this.staffUnitsRequired,
    this.requiresVetSupervision,
    this.canPerformNailTrimming,
    this.penaltyReasons = const [],
    this.clearanceData,
    this.isCalculatingDuration = false,
    this.isCheckingClearance = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.createdReservation,
  });

  bool get hasDurationResult => estimatedMinutes != null;
  bool get hasClearanceResult => clearanceData != null;
  bool get isCleared => clearanceData?.isCleared ?? false;
  bool get isLoading =>
      isCalculatingDuration || isCheckingClearance || isSubmitting;

  bool get hasMattedWarning =>
      penaltyReasons.any((r) => r.contains('enmarañado'));
  bool get hasReactivityWarning =>
      penaltyReasons.any((r) => r.contains('riesgo'));

  bool get includesGrooming =>
      selectedServices.contains(ServiceType.bath) ||
      selectedServices.contains(ServiceType.haircut);

  /// True si todos los inputs mínimos para un agendamiento están presentes.
  bool get canSubmit =>
      selectedPetId != null &&
      selectedServices.isNotEmpty &&
      checkIn != null &&
      checkOut != null &&
      checkIn!.isBefore(checkOut!);

  LegalAuthorizations get legalAuthorizations => LegalAuthorizations(
        emergencyMedicationAllowed: emergencyMedicationAllowed,
        emergencyMedicationAcceptedAt: emergencyMedicationAcceptedAt,
        contactVetAllowed: contactVetAllowed,
        contactVetAcceptedAt: contactVetAcceptedAt,
        waterPlayAllowed: waterPlayAllowed,
        waterPlayAcceptedAt: waterPlayAcceptedAt,
        mediaUsageAllowed: mediaUsageAllowed,
        mediaUsageAcceptedAt: mediaUsageAcceptedAt,
      );

  ServiceBookingState copyWith({
    String? selectedPetId,
    String? selectedPetName,
    List<ServiceType>? selectedServices,
    DateTime? checkIn,
    DateTime? checkOut,
    bool? emergencyMedicationAllowed,
    DateTime? emergencyMedicationAcceptedAt,
    bool? contactVetAllowed,
    DateTime? contactVetAcceptedAt,
    bool? waterPlayAllowed,
    DateTime? waterPlayAcceptedAt,
    bool? mediaUsageAllowed,
    DateTime? mediaUsageAcceptedAt,
    int? estimatedMinutes,
    int? staffUnitsRequired,
    bool? requiresVetSupervision,
    bool? canPerformNailTrimming,
    List<String>? penaltyReasons,
    SanitaryClearanceData? clearanceData,
    bool? isCalculatingDuration,
    bool? isCheckingClearance,
    bool? isSubmitting,
    String? errorMessage,
    BoardingReservationEntity? createdReservation,
    bool clearError = false,
    bool clearDuration = false,
    bool clearClearance = false,
  }) =>
      ServiceBookingState(
        selectedPetId: selectedPetId ?? this.selectedPetId,
        selectedPetName: selectedPetName ?? this.selectedPetName,
        selectedServices: selectedServices ?? this.selectedServices,
        checkIn: checkIn ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
        emergencyMedicationAllowed:
            emergencyMedicationAllowed ?? this.emergencyMedicationAllowed,
        emergencyMedicationAcceptedAt:
            emergencyMedicationAcceptedAt ?? this.emergencyMedicationAcceptedAt,
        contactVetAllowed: contactVetAllowed ?? this.contactVetAllowed,
        contactVetAcceptedAt: contactVetAcceptedAt ?? this.contactVetAcceptedAt,
        waterPlayAllowed: waterPlayAllowed ?? this.waterPlayAllowed,
        waterPlayAcceptedAt: waterPlayAcceptedAt ?? this.waterPlayAcceptedAt,
        mediaUsageAllowed: mediaUsageAllowed ?? this.mediaUsageAllowed,
        mediaUsageAcceptedAt: mediaUsageAcceptedAt ?? this.mediaUsageAcceptedAt,
        estimatedMinutes:
            clearDuration ? null : (estimatedMinutes ?? this.estimatedMinutes),
        staffUnitsRequired: clearDuration
            ? null
            : (staffUnitsRequired ?? this.staffUnitsRequired),
        requiresVetSupervision: clearDuration
            ? null
            : (requiresVetSupervision ?? this.requiresVetSupervision),
        canPerformNailTrimming: clearDuration
            ? null
            : (canPerformNailTrimming ?? this.canPerformNailTrimming),
        penaltyReasons:
            clearDuration ? [] : (penaltyReasons ?? this.penaltyReasons),
        clearanceData:
            clearClearance ? null : (clearanceData ?? this.clearanceData),
        isCalculatingDuration:
            isCalculatingDuration ?? this.isCalculatingDuration,
        isCheckingClearance: isCheckingClearance ?? this.isCheckingClearance,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage:
            clearError ? null : (errorMessage ?? this.errorMessage),
        createdReservation: createdReservation ?? this.createdReservation,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ServiceBookingNotifier extends StateNotifier<ServiceBookingState> {
  final Ref _ref;

  ServiceBookingNotifier(this._ref) : super(const ServiceBookingState());

  // ── Selección de mascota ───────────────────────────────────────────────────

  /// Selecciona la mascota y dispara automáticamente el cálculo MPT si ya
  /// hay servicios de estética seleccionados.
  void selectPet(String petId, String petName) {
    state = state.copyWith(
      selectedPetId: petId,
      selectedPetName: petName,
      clearDuration: true,
      clearClearance: true,
      clearError: true,
    );
    if (state.includesGrooming) _triggerDurationCalculation();
  }

  // ── Selección de servicios ─────────────────────────────────────────────────

  void toggleService(ServiceType service) {
    final updated = List<ServiceType>.from(state.selectedServices);
    if (updated.contains(service)) {
      updated.remove(service);
    } else {
      updated.add(service);
    }
    state = state.copyWith(
      selectedServices: updated,
      clearDuration: true,
      clearError: true,
    );
    // Recalcular reactivamente cuando hay estética + mascota seleccionada
    if (state.selectedPetId != null &&
        updated.any((s) => s == ServiceType.bath || s == ServiceType.haircut)) {
      _triggerDurationCalculation();
    }
  }

  // ── Fechas ────────────────────────────────────────────────────────────────

  void setCheckIn(DateTime dt) =>
      state = state.copyWith(checkIn: dt, clearError: true);

  void setCheckOut(DateTime dt) =>
      state = state.copyWith(checkOut: dt, clearError: true);

  // ── Autorizaciones legales ────────────────────────────────────────────────

  void setEmergencyMedication(bool v) => state = state.copyWith(
        emergencyMedicationAllowed: v,
        emergencyMedicationAcceptedAt: v ? DateTime.now() : null,
      );
  void setContactVet(bool v) => state = state.copyWith(
        contactVetAllowed: v,
        contactVetAcceptedAt: v ? DateTime.now() : null,
      );
  void setWaterPlay(bool v) => state = state.copyWith(
        waterPlayAllowed: v,
        waterPlayAcceptedAt: v ? DateTime.now() : null,
      );
  void setMediaUsage(bool v) => state = state.copyWith(
        mediaUsageAllowed: v,
        mediaUsageAcceptedAt: v ? DateTime.now() : null,
      );

  // ── Cálculo de duración MPT (Cloud Function) ──────────────────────────────

  void _triggerDurationCalculation() {
    final petId = state.selectedPetId;
    final service = state.selectedServices.firstWhere(
      (s) => s == ServiceType.bath || s == ServiceType.haircut,
      orElse: () => ServiceType.daycare,
    );
    if (petId == null || service == ServiceType.daycare) return;
    computeDuration(petId, service);
  }

  Future<void> computeDuration(String petId, ServiceType serviceType) async {
    if (state.isCalculatingDuration) return;
    state = state.copyWith(
      isCalculatingDuration: true,
      clearDuration: true,
      clearError: true,
    );
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('calculateServiceDuration');
      final result = await callable.call<Map<String, dynamic>>({
        'petId': petId,
        'serviceType': serviceType.value,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      state = state.copyWith(
        isCalculatingDuration: false,
        estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt(),
        staffUnitsRequired: (data['staffUnitsRequired'] as num?)?.toInt(),
        requiresVetSupervision: data['requiresVetSupervision'] as bool?,
        canPerformNailTrimming: data['canPerformNailTrimming'] as bool?,
        penaltyReasons: (data['penaltyReasons'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
        isCalculatingDuration: false,
        errorMessage: e.message ?? 'Error al calcular duración del servicio.',
      );
    } catch (e) {
      state = state.copyWith(
        isCalculatingDuration: false,
        errorMessage: 'Error de red al calcular duración: $e',
      );
    }
  }

  // ── Verificación sanitaria ────────────────────────────────────────────────

  Future<void> checkSanitaryClearance() async {
    final petId = state.selectedPetId;
    final checkIn = state.checkIn;
    final checkOut = state.checkOut;
    if (petId == null || checkIn == null || checkOut == null) {
      state = state.copyWith(
        errorMessage: 'Selecciona mascota y fechas antes de verificar.',
      );
      return;
    }
    state = state.copyWith(
      isCheckingClearance: true,
      clearClearance: true,
      clearError: true,
    );
    try {
      final petAsync = _ref.read(singlePetStreamProvider(petId));
      final pet = petAsync.whenOrNull(data: (p) => p);
      final petSpecies = pet?.species ?? 'Perro';
      final petBranchId = pet?.branchId;

      final useCase = _ref.read(verifySanitaryClearanceUseCaseProvider);
      final result = await useCase(VerifySanitaryClearanceParams(
        petId: petId,
        checkIn: checkIn,
        checkOut: checkOut,
        emergencyMedicationAllowed: state.emergencyMedicationAllowed,
        contactVetAllowed: state.contactVetAllowed,
        species: petSpecies,
        branchId: petBranchId,
      ));
      result.when(
        success: (clearanceData) => state = state.copyWith(
          isCheckingClearance: false,
          clearanceData: clearanceData,
        ),
        failure: (message, _) => state = state.copyWith(
          isCheckingClearance: false,
          errorMessage: message,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isCheckingClearance: false,
        errorMessage: 'Error al verificar habilitación sanitaria: $e',
      );
    }
  }

  // ── Crear reserva ─────────────────────────────────────────────────────────

  Future<void> submitReservation({
    required String ownerId,
    required String ownerName,
    required String petName,
    required String facilityRunId,
  }) async {
    if (!state.canSubmit || state.isSubmitting) return;
    if (!(state.clearanceData?.isCleared ?? false)) {
      state = state.copyWith(
        errorMessage:
            'La mascota no tiene habilitación sanitaria. Revisa las alertas.',
      );
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final clearance = state.clearanceData!;
      final petAsync = _ref.read(singlePetStreamProvider(state.selectedPetId!));
      final branchId = petAsync.whenOrNull(data: (p) => p?.branchId) ?? '';

      // Verify no overlapping reservation exists before creating
      final overlapResult = await _ref
          .read(boardingRepositoryProvider)
          .hasOverlappingReservation(
            petId: state.selectedPetId!,
            checkIn: state.checkIn!,
            checkOut: state.checkOut!,
          );
      if (!overlapResult.isFailure && overlapResult.data == true) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
              'Ya existe una reserva activa para esta mascota en las fechas seleccionadas.',
        );
        return;
      }

      final reservation = BoardingReservationEntity(
        id: '',
        petId: state.selectedPetId!,
        petName: petName,
        ownerId: ownerId,
        ownerName: ownerName,
        branchId: branchId,
        facilityRunId: facilityRunId,
        checkInExpected: state.checkIn!,
        checkOutExpected: state.checkOut!,
        status: ReservationStatus.confirmed,
        servicesIncluded: state.selectedServices,
        safetySnapshot: SafetySnapshot(
          riskLevelAtBooking: clearance.riskLevel,
          calculatedIcdScore: clearance.minIcdScore,
          compatibilityLevel:
              CompatibilityLevel.fromScore(clearance.minIcdScore),
        ),
        legalAuthorizations: state.legalAuthorizations,
        createdAt: DateTime.now(),
      );
      final result = await _ref
          .read(boardingRepositoryProvider)
          .createReservation(reservation);
      result.when(
        success: (created) => state = state.copyWith(
          isSubmitting: false,
          createdReservation: created,
        ),
        failure: (message, _) => state = state.copyWith(
          isSubmitting: false,
          errorMessage: message,
        ),
      );
    } catch (e) {
      state =
          state.copyWith(isSubmitting: false, errorMessage: 'Error al reservar: $e');
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void reset() => state = const ServiceBookingState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final serviceBookingProvider =
    StateNotifierProvider<ServiceBookingNotifier, ServiceBookingState>(
  (ref) => ServiceBookingNotifier(ref),
);
