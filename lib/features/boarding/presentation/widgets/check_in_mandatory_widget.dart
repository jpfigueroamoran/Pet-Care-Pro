import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/behavioral_assessment_entity.dart';
import '../../domain/entities/boarding_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno: Bandera de seguridad
// ─────────────────────────────────────────────────────────────────────────────

enum _FlagSeverity { critical, warning }

class _SafetyFlag {
  final _FlagSeverity severity;
  final String title;
  final String description;

  const _SafetyFlag({
    required this.severity,
    required this.title,
    required this.description,
  });

  bool get isCritical => severity == _FlagSeverity.critical;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

/// Componente de Lectura Obligatoria para el Check-In.
///
/// Muestra banderas de seguridad derivadas del [BehavioralAssessmentEntity]:
/// - 🟥 CRÍTICAS (pulsantes): guardia de recursos, riesgo crítico, agresividad.
/// - 🟨 ADVERTENCIAS: ansiedad, reactividad, sensibilidades de manejo.
///
/// El staff debe marcar la casilla de confirmación para habilitar [onConfirmed].
class CheckInMandatoryWidget extends StatefulWidget {
  final BehavioralAssessmentEntity assessment;
  final String petName;
  final VoidCallback onConfirmed;

  const CheckInMandatoryWidget({
    super.key,
    required this.assessment,
    required this.petName,
    required this.onConfirmed,
  });

  @override
  State<CheckInMandatoryWidget> createState() =>
      _CheckInMandatoryWidgetState();
}

class _CheckInMandatoryWidgetState extends State<CheckInMandatoryWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Construcción de banderas desde la entidad ─────────────────────────────

  List<_SafetyFlag> _buildFlags() {
    final flags = <_SafetyFlag>[];
    final a = widget.assessment;

    // ── CRÍTICAS (rojo — pulsantes) ───────────────────────────────────────

    if (a.riskLevel == RiskLevel.red) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.critical,
        title: 'NIVEL DE RIESGO CRÍTICO',
        description:
            'Clasificación ROJO. Requiere aislamiento inmediato y supervisión veterinaria constante. No ingresar a áreas comunes.',
      ));
    }

    if (a.riskTriggers.foodGuarding) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.critical,
        title: 'PROTECCIÓN DE RECURSOS — COMIDA',
        description:
            'Puede reaccionar agresivamente si hay alimento cerca de otros animales o personal. No acercar cuencos ajenos durante el ingreso.',
      ));
    }

    if (a.riskTriggers.toyGuarding) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.critical,
        title: 'PROTECCIÓN DE RECURSOS — JUGUETES',
        description:
            'Manifiesta agresividad ante objetos valorados. Retirar todos los juguetes del área antes de que ingrese la mascota.',
      ));
    }

    if (a.sociability.dogCompatibility == DogCompatibility.aggressive) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.critical,
        title: 'AGRESIVIDAD CON OTROS PERROS',
        description:
            'No puede compartir espacio con otros animales bajo ninguna circunstancia. Alojamiento individual obligatorio sin excepciones.',
      ));
    }

    if (a.handlingTolerance.nailTrimming == NailTrimming.sedationRequired) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.critical,
        title: 'CORTE DE UÑAS — REQUIERE SEDACIÓN',
        description:
            'NO realizar corte de uñas sin coordinación previa con el área clínica. Procedimiento bajo supervisión veterinaria exclusivamente.',
      ));
    }

    // ── ADVERTENCIAS (amarillo — estáticas) ───────────────────────────────

    if (a.riskLevel == RiskLevel.orange) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'NIVEL DE RIESGO ELEVADO — MANEJO ESPECIALIZADO',
        description:
            'Clasificación NARANJA. Activar protocolo de alerta al equipo antes del ingreso. No dejar sin supervisión directa.',
      ));
    }

    if (a.sociability.dogCompatibility == DogCompatibility.reactive) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'REACTIVO CON OTROS PERROS',
        description:
            'Puede mostrar reactividad si se acerca a otros animales sin introducción controlada. Mantener distancia de seguridad en pasillos.',
      ));
    }

    if (a.sociability.requiresMuzzle) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'REQUIERE BOZAL',
        description:
            'El uso de bozal es obligatorio durante el manejo y cualquier procedimiento de estética o clínico.',
      ));
    }

    if (a.riskTriggers.separationAnxiety) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'ANSIEDAD POR SEPARACIÓN',
        description:
            'Puede vocalizar intensamente o mostrar comportamientos destructivos al quedar solo. Supervisión frecuente y ambiente enriquecido.',
      ));
    }

    if (a.riskTriggers.confinementPanic) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'PÁNICO AL CONFINAMIENTO',
        description:
            'Puede intentar escapar o autolesionarse en espacios cerrados. Verificar resistencia del kennel y supervisar el cierre.',
      ));
    }

    if (a.riskTriggers.noiseSensitivity) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'SENSIBILIDAD AL RUIDO',
        description:
            'Reacciona con ansiedad a ruidos fuertes (ladridos, secadoras, música). Preferir áreas tranquilas e informar al equipo.',
      ));
    }

    if (a.handlingTolerance.bathSensitivity == BathSensitivity.defensive) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'DEFENSIVO EN EL BAÑO',
        description:
            'Puede intentar morder durante el baño. Usar técnicas de manejo seguro y considerar bozal preventivo al inicio del servicio.',
      ));
    }

    if (a.handlingTolerance.dryingSensitivity == DryingSensitivity.highPanic) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'REACTIVO AL SECADOR — PÁNICO',
        description:
            'Entra en pánico ante el secador de alta potencia. Usar secado natural o temperatura baja con intervalos de descanso.',
      ));
    }

    if (a.handlingTolerance.nailTrimming == NailTrimming.needsMuzzle) {
      flags.add(const _SafetyFlag(
        severity: _FlagSeverity.warning,
        title: 'BOZAL OBLIGATORIO — CORTE DE UÑAS',
        description:
            'Requiere bozal durante el corte de uñas para la seguridad del personal de estética.',
      ));
    }

    return flags;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final flags = _buildFlags();
    final hasCritical = flags.any((f) => f.isCritical);
    final hasFlags = flags.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          petName: widget.petName,
          hasCritical: hasCritical,
          flagCount: flags.length,
        ),
        const SizedBox(height: 12),
        if (!hasFlags)
          const _ClearCard()
        else ...[
          ...flags.map((flag) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: flag.isCritical
                    ? _CriticalFlagCard(
                        flag: flag,
                        pulseAnimation: _pulseAnimation,
                      )
                    : _WarningFlagCard(flag: flag),
              )),
          _OperationalNotes(notes: widget.assessment.operationalNotes),
          const SizedBox(height: 12),
          _ConfirmCheckbox(
            confirmed: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
        ],
        const SizedBox(height: 16),
        _ConfirmButton(
          enabled: !hasFlags || _confirmed,
          onPressed: widget.onConfirmed,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String petName;
  final bool hasCritical;
  final int flagCount;

  const _Header({
    required this.petName,
    required this.hasCritical,
    required this.flagCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasCritical ? AppTheme.coralRed : AppTheme.goldChampagne;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            hasCritical ? Icons.warning_rounded : Icons.info_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LECTURA OBLIGATORIA',
                  style: GoogleFonts.fredoka(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  petName,
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  flagCount == 0
                      ? 'Sin alertas de seguridad activas'
                      : '$flagCount ${flagCount == 1 ? 'alerta activa' : 'alertas activas'} — Leer antes de proceder',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ClearCard extends StatelessWidget {
  const _ClearCard();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: green, width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded, color: green, size: 44),
          const SizedBox(height: 8),
          Text(
            'Perfil sin alertas críticas',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'La mascota puede ingresar sin protocolos especiales.',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CriticalFlagCard extends StatelessWidget {
  final _SafetyFlag flag;
  final Animation<double> pulseAnimation;

  const _CriticalFlagCard({
    required this.flag,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) =>
          Opacity(opacity: pulseAnimation.value, child: child),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.coralRed.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.coralRed, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🟥', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.title,
                    style: GoogleFonts.fredoka(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.coralRed,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flag.description,
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WarningFlagCard extends StatelessWidget {
  final _SafetyFlag flag;

  const _WarningFlagCard({required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.goldChampagne.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldChampagne, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🟨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flag.title,
                  style: GoogleFonts.fredoka(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF92400E),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  flag.description,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _OperationalNotes extends StatelessWidget {
  final String notes;

  const _OperationalNotes({required this.notes});

  @override
  Widget build(BuildContext context) {
    if (notes.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTAS OPERATIVAS DEL STAFF',
            style: GoogleFonts.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            notes,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmCheckbox extends StatelessWidget {
  final bool confirmed;
  final ValueChanged<bool?> onChanged;

  const _ConfirmCheckbox({
    required this.confirmed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!confirmed),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: confirmed,
              onChanged: onChanged,
              activeColor: AppTheme.mintGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'He leído todas las alertas de seguridad y estoy listo para proceder con el check-in.',
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _ConfirmButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.check_circle_rounded, size: 20),
        label: Text(
          'CONFIRMAR LECTURA — PROCEDER AL CHECK-IN',
          style: GoogleFonts.fredoka(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.mintGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.border,
          disabledForegroundColor: AppTheme.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: enabled ? 2 : 0,
        ),
      ),
    );
  }
}
