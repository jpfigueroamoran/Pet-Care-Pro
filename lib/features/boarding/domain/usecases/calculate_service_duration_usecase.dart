import '../entities/behavioral_assessment_entity.dart';
import '../entities/boarding_enums.dart';
import '../entities/use_case_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Caso de Uso: Motor de Productividad de Tiempos (MPT)
//
// Calcula el tiempo estimado de servicio de estética basándose en:
//   - Tipo y condición del pelaje (coatType × coatCondition)
//   - Tolerancia al manejo (baño, secado, uñas)
//   - Nivel de riesgo (¿requiere supervisión veterinaria?)
//   - Categoría de tamaño (duración base)
// No depende del repositorio — es lógica de dominio pura.
// ─────────────────────────────────────────────────────────────────────────────

class CalculateServiceDurationParams {
  final SizeCategory sizeCategory;
  final CoatType coatType;
  final CoatCondition coatCondition;
  final HandlingTolerance handlingTolerance;
  final RiskLevel riskLevel;
  final List<ServiceType> requestedServices;

  const CalculateServiceDurationParams({
    required this.sizeCategory,
    required this.coatType,
    required this.coatCondition,
    required this.handlingTolerance,
    required this.riskLevel,
    required this.requestedServices,
  });
}

class CalculateServiceDurationUseCase {
  const CalculateServiceDurationUseCase();

  UseCaseResult<ServiceDurationData> call(
    CalculateServiceDurationParams params,
  ) {
    if (!_includesGroomingService(params.requestedServices)) {
      return const Failure(
        message: 'No hay servicios de estética en la solicitud.',
        code: FailureCode.validationError,
      );
    }

    // ── Duración base por tamaño (minutos) ───────────────────────────────
    final baseMinutes = _baseMinutesBySize(params.sizeCategory);

    // ── Multiplicador por tipo de pelaje ─────────────────────────────────
    final coatAdjusted = (baseMinutes * params.coatType.mptMultiplier).round();

    // ── Penalización por condición del pelaje ────────────────────────────
    final afterCondition =
        coatAdjusted + params.coatCondition.mptPenaltyMinutes;

    // ── Penalización por tolerancia al manejo ────────────────────────────
    final totalWithHandling =
        afterCondition + params.handlingTolerance.totalMptPenaltyMinutes;

    // ── Unidades de staff requeridas ─────────────────────────────────────
    final staffUnits = _staffUnits(params.riskLevel, params.sizeCategory);

    // ── Corte de uñas ─────────────────────────────────────────────────────
    final canDoNails =
        !params.handlingTolerance.nailTrimming.requiresClinicCoordination;

    // ── Razones de penalización (para UI informativa) ────────────────────
    final penalties = <String>[];
    if (params.coatType != CoatType.SHORT) {
      penalties.add(
        'Pelaje ${params.coatType.name}: ×${params.coatType.mptMultiplier} sobre tiempo base',
      );
    }
    if (params.coatCondition.mptPenaltyMinutes > 0) {
      penalties.add(
        'Pelaje enmarañado: +${params.coatCondition.mptPenaltyMinutes} min de desanudado',
      );
    }
    if (params.handlingTolerance.bathSensitivity.mptPenaltyMinutes > 0) {
      penalties.add(
        'Sensibilidad al baño (${params.handlingTolerance.bathSensitivity.name}): '
        '+${params.handlingTolerance.bathSensitivity.mptPenaltyMinutes} min',
      );
    }
    if (params.handlingTolerance.dryingSensitivity.mptPenaltyMinutes > 0) {
      penalties.add(
        'Sensibilidad al secado (${params.handlingTolerance.dryingSensitivity.name}): '
        '+${params.handlingTolerance.dryingSensitivity.mptPenaltyMinutes} min',
      );
    }
    if (!canDoNails) {
      penalties.add('Uñas: requiere coordinación clínica — no se realizan en estética');
    }
    if (params.riskLevel.requiresVetSupervision) {
      penalties.add('Nivel de riesgo ROJO: supervisión veterinaria simultánea requerida');
    }

    return Success(ServiceDurationData(
      estimatedMinutes: totalWithHandling,
      staffUnitsRequired: staffUnits,
      requiresVetSupervision: params.riskLevel.requiresVetSupervision,
      canPerformNailTrimming: canDoNails,
      penaltyReasons: penalties,
    ));
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  bool _includesGroomingService(List<ServiceType> services) =>
      services.contains(ServiceType.bath) ||
      services.contains(ServiceType.haircut);

  int _baseMinutesBySize(SizeCategory size) {
    switch (size) {
      case SizeCategory.TOY:    return 45;
      case SizeCategory.SMALL:  return 60;
      case SizeCategory.MEDIUM: return 75;
      case SizeCategory.LARGE:  return 90;
      case SizeCategory.GIANT:  return 120;
    }
  }

  int _staffUnits(RiskLevel risk, SizeCategory size) {
    // GIANT siempre necesita 2 personas; riesgo naranja o rojo agrega 1 extra
    int units = size == SizeCategory.GIANT ? 2 : 1;
    if (risk == RiskLevel.orange || risk == RiskLevel.red) units++;
    return units;
  }
}
