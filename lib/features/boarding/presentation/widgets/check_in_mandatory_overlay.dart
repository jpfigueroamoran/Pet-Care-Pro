import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/behavioral_assessment_entity.dart';
import '../../domain/entities/boarding_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CheckInMandatoryOverlay
//
// Diálogo de pantalla completa que se muestra en el momento del check-in físico.
// El header adopta el color de alerta según el nivel de riesgo de la mascota.
// El botón de confirmación permanece bloqueado hasta que el staff marque el
// checkbox de lectura de alertas.
//
// Uso:
//   await CheckInMandatoryOverlay.show(
//     context,
//     assessment: assessment,
//     petName: 'Max',
//     onConfirmed: () { /* proceder con check-in */ },
//   );
// ─────────────────────────────────────────────────────────────────────────────

class CheckInMandatoryOverlay {
  const CheckInMandatoryOverlay._();

  static Future<void> show(
    BuildContext context, {
    required BehavioralAssessmentEntity assessment,
    required String petName,
    required VoidCallback onConfirmed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _OverlayDialog(
        assessment: assessment,
        petName: petName,
        onConfirmed: onConfirmed,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo principal (stateful — gestiona checkbox y scroll)
// ─────────────────────────────────────────────────────────────────────────────

class _OverlayDialog extends StatefulWidget {
  final BehavioralAssessmentEntity assessment;
  final String petName;
  final VoidCallback onConfirmed;

  const _OverlayDialog({
    required this.assessment,
    required this.petName,
    required this.onConfirmed,
  });

  @override
  State<_OverlayDialog> createState() => _OverlayDialogState();
}

class _OverlayDialogState extends State<_OverlayDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _confirmed = false;

  // ── Alert flag model ──────────────────────────────────────────────────────

  static const _critical = _FlagSeverity.critical;
  static const _warning = _FlagSeverity.warning;

  List<_SafetyFlag> get _flags {
    final a = widget.assessment;
    final flags = <_SafetyFlag>[];

    // ── CRÍTICAS ──────────────────────────────────────────────────────────
    if (a.riskLevel == RiskLevel.red) {
      flags.add(const _SafetyFlag(
        severity: _critical,
        title: 'NIVEL DE RIESGO CRÍTICO',
        body: 'Clasificación ROJO. Requiere aislamiento inmediato y supervisión veterinaria constante. No ingresar a áreas comunes bajo ninguna circunstancia.',
      ));
    }
    if (a.riskTriggers.foodGuarding) {
      flags.add(const _SafetyFlag(
        severity: _critical,
        title: 'PROTECCIÓN DE RECURSOS — COMIDA',
        body: 'Reacciona agresivamente ante la presencia de comida de otros animales. Retirar todos los cuencos del área antes del ingreso.',
      ));
    }
    if (a.riskTriggers.toyGuarding) {
      flags.add(const _SafetyFlag(
        severity: _critical,
        title: 'PROTECCIÓN DE RECURSOS — JUGUETES',
        body: 'Manifiesta agresividad ante objetos valorados. Retirar todos los juguetes y objetos estimulantes del área de recepción.',
      ));
    }
    if (a.sociability.dogCompatibility == DogCompatibility.aggressive) {
      flags.add(const _SafetyFlag(
        severity: _critical,
        title: 'AGRESIVIDAD CON OTROS PERROS',
        body: 'No puede compartir espacio con ningún otro animal. Alojamiento individual obligatorio. Asegurar pasillos despejados durante el ingreso.',
      ));
    }
    if (a.handlingTolerance.nailTrimming == NailTrimming.sedationRequired) {
      flags.add(const _SafetyFlag(
        severity: _critical,
        title: 'CORTE DE UÑAS — REQUIERE SEDACIÓN',
        body: 'PROHIBIDO realizar corte de uñas sin coordinación previa con el área clínica. Solo bajo supervisión veterinaria.',
      ));
    }

    // ── ADVERTENCIAS ──────────────────────────────────────────────────────
    if (a.riskLevel == RiskLevel.orange) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'NIVEL DE RIESGO ELEVADO — MANEJO ESPECIALIZADO',
        body: 'Clasificación NARANJA. Activar protocolo de alerta al equipo. No dejar sin supervisión directa durante las primeras 2 horas.',
      ));
    }
    if (a.sociability.requiresMuzzle) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'REQUIERE BOZAL',
        body: 'Uso de bozal obligatorio durante el manejo, cualquier procedimiento de estética o examen clínico. Verificar que el bozal esté disponible antes de recibir al animal.',
      ));
    }
    if (a.sociability.dogCompatibility == DogCompatibility.reactive) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'REACTIVO CON OTROS PERROS',
        body: 'Puede mostrar reactividad si se acerca a otros animales sin introducción controlada. Mantener distancia de seguridad en pasillos y zonas comunes.',
      ));
    }
    if (a.riskTriggers.separationAnxiety) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'ANSIEDAD POR SEPARACIÓN',
        body: 'Puede vocalizar intensamente o mostrar comportamientos destructivos al quedar solo. Supervisión frecuente y ambiente enriquecido recomendados.',
      ));
    }
    if (a.riskTriggers.confinementPanic) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'PÁNICO AL CONFINAMIENTO',
        body: 'Puede intentar escapar o autolesionarse en espacios cerrados. Verificar resistencia del kennel y supervisar el proceso de cierre.',
      ));
    }
    if (a.riskTriggers.noiseSensitivity) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'SENSIBILIDAD AL RUIDO',
        body: 'Reacciona con ansiedad ante ruidos fuertes. Preferir áreas tranquilas e informar al equipo de estética para reducir el uso de secadoras.',
      ));
    }
    if (a.handlingTolerance.bathSensitivity == BathSensitivity.defensive) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'DEFENSIVO EN EL BAÑO',
        body: 'Puede intentar morder durante el proceso de baño. Usar bozal preventivo y técnicas de manejo seguro desde el inicio del servicio.',
      ));
    }
    if (a.handlingTolerance.dryingSensitivity ==
        DryingSensitivity.highPanic) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'REACTIVO AL SECADOR — PÁNICO',
        body: 'Entra en pánico ante el secador de alta potencia. Preferir secado natural o temperatura baja con intervalos de descanso.',
      ));
    }
    if (a.handlingTolerance.nailTrimming == NailTrimming.needsMuzzle) {
      flags.add(const _SafetyFlag(
        severity: _warning,
        title: 'BOZAL OBLIGATORIO — CORTE DE UÑAS',
        body: 'Colocar bozal antes de iniciar el corte de uñas para proteger al personal de estética.',
      ));
    }

    return flags;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Header color based on risk level ─────────────────────────────────────

  Color get _headerColor {
    return switch (widget.assessment.riskLevel) {
      RiskLevel.red => const Color(0xFFB91C1C),
      RiskLevel.orange => const Color(0xFFEA580C),
      RiskLevel.yellow => const Color(0xFFCA8A04),
      RiskLevel.green => AppTheme.mintGreen,
    };
  }

  String get _headerEmoji {
    return switch (widget.assessment.riskLevel) {
      RiskLevel.red => '🔴',
      RiskLevel.orange => '🟠',
      RiskLevel.yellow => '🟡',
      RiskLevel.green => '🟢',
    };
  }

  @override
  Widget build(BuildContext context) {
    final flags = _flags;
    final hasCritical = flags.any((f) => f.isCritical);
    final hasFlags = flags.isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      clipBehavior: Clip.hardEdge,
      shape: const RoundedRectangleBorder(),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            // ── Header impactante ─────────────────────────────────────────
            _Header(
              riskLevel: widget.assessment.riskLevel,
              petName: widget.petName,
              flagCount: flags.length,
              headerColor: _headerColor,
              headerEmoji: _headerEmoji,
            ),

            // ── Contenido scrollable ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  if (!hasFlags)
                    _ClearState()
                  else ...[
                    ...flags.map((flag) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: flag.isCritical
                              ? _CriticalCard(
                                  flag: flag,
                                  pulseAnim: _pulseAnim,
                                )
                              : _WarningCard(flag: flag),
                        )),

                    if (widget.assessment.operationalNotes.trim().isNotEmpty)
                      _OperationalNotes(
                          notes: widget.assessment.operationalNotes),

                    const SizedBox(height: 8),

                    // Checkbox de confirmación
                    _ConfirmCheckbox(
                      confirmed: _confirmed,
                      hasCritical: hasCritical,
                      onChanged: (v) =>
                          setState(() => _confirmed = v ?? false),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Botón de acción (bloqueado hasta confirmar) ───────────────
            _ActionBar(
              enabled: !hasFlags || _confirmed,
              onConfirmed: () {
                Navigator.of(context).pop();
                widget.onConfirmed();
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header de alto impacto
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final RiskLevel riskLevel;
  final String petName;
  final int flagCount;
  final Color headerColor;
  final String headerEmoji;

  const _Header({
    required this.riskLevel,
    required this.petName,
    required this.flagCount,
    required this.headerColor,
    required this.headerEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: headerColor,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'LECTURA OBLIGATORIA — CHECK-IN',
                style: GoogleFonts.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(headerEmoji,
                  style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName,
                      style: GoogleFonts.fredoka(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      riskLevel.displayLabel,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  flagCount == 0
                      ? 'Sin alertas activas — ingreso estándar'
                      : '$flagCount ${flagCount == 1 ? 'alerta de seguridad activa' : 'alertas de seguridad activas'} — Leer todo antes de proceder',
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
// Estado sin alertas
// ─────────────────────────────────────────────────────────────────────────────

class _ClearState extends StatelessWidget {
  const _ClearState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded,
              color: Color(0xFF16A34A), size: 56),
          const SizedBox(height: 12),
          Text('Perfil sin alertas críticas',
              style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF15803D))),
          const SizedBox(height: 6),
          Text(
            'La mascota puede ingresar con protocolo estándar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
                fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta crítica (roja, pulsante)
// ─────────────────────────────────────────────────────────────────────────────

class _CriticalCard extends StatelessWidget {
  final _SafetyFlag flag;
  final Animation<double> pulseAnim;

  const _CriticalCard(
      {required this.flag, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Opacity(opacity: pulseAnim.value, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.coralRed.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.coralRed, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🟥', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.title,
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.coralRed,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    flag.body,
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
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
// Tarjeta de advertencia (amarilla, estática)
// ─────────────────────────────────────────────────────────────────────────────

class _WarningCard extends StatelessWidget {
  final _SafetyFlag flag;

  const _WarningCard({required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.goldChampagne.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldChampagne, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🟨', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flag.title,
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF92400E),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  flag.body,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
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
// Notas operativas
// ─────────────────────────────────────────────────────────────────────────────

class _OperationalNotes extends StatelessWidget {
  final String notes;

  const _OperationalNotes({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 6),
          Text(
            notes,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Checkbox de confirmación de lectura
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmCheckbox extends StatelessWidget {
  final bool confirmed;
  final bool hasCritical;
  final ValueChanged<bool?> onChanged;

  const _ConfirmCheckbox({
    required this.confirmed,
    required this.hasCritical,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: confirmed
            ? const Color(0xFF16A34A).withOpacity(0.08)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: confirmed
                ? const Color(0xFF16A34A)
                : AppTheme.border,
            width: confirmed ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: () => onChanged(!confirmed),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: confirmed,
                onChanged: onChanged,
                activeColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'He leído todas las alertas de seguridad y confirmo que el staff está preparado para el manejo de esta mascota.',
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de acción inferior del diálogo
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onConfirmed;
  final VoidCallback onCancel;

  const _ActionBar({
    required this.enabled,
    required this.onConfirmed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Marca la casilla de confirmación para continuar',
                  style: GoogleFonts.quicksand(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: enabled ? onConfirmed : null,
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                'CONFIRMAR LECTURA — PROCEDER AL CHECK-IN',
                style: GoogleFonts.fredoka(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.border,
                disabledForegroundColor: AppTheme.textMuted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onCancel,
            child: Text('Cancelar check-in',
                style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelos internos
// ─────────────────────────────────────────────────────────────────────────────

enum _FlagSeverity { critical, warning }

class _SafetyFlag {
  final _FlagSeverity severity;
  final String title;
  final String body;

  const _SafetyFlag({
    required this.severity,
    required this.title,
    required this.body,
  });

  bool get isCritical => severity == _FlagSeverity.critical;
}
