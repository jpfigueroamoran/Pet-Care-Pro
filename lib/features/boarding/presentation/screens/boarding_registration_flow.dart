import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/vaccination_entry_entity.dart';
import '../providers/boarding_providers.dart';
import '../providers/boarding_registration_notifier.dart';
import '../providers/triage_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flujo de registro en recepción — 4 pasos guiados
// ─────────────────────────────────────────────────────────────────────────────

class BoardingRegistrationFlow extends ConsumerStatefulWidget {
  final String petId;
  final String petName;

  const BoardingRegistrationFlow({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  ConsumerState<BoardingRegistrationFlow> createState() =>
      _BoardingRegistrationFlowState();
}

class _BoardingRegistrationFlowState
    extends ConsumerState<BoardingRegistrationFlow> {
  final _pageController = PageController();
  int _step = 0;

  static const _stepLabels = ['Datos físicos', 'Vacunas', 'Perfil conductual'];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  bool _canAdvance(
      BoardingRegistrationState reg, TriageState triage) {
    if (_step == 0) return (reg.weightKg ?? 0) > 0;
    return true;
  }

  Future<void> _finalize() async {
    final regNotifier =
        ref.read(boardingRegistrationProvider(widget.petId).notifier);
    final triageNotifier =
        ref.read(triageNotifierProvider(widget.petId).notifier);

    // Sync physical data from boarding registration → triage before saving
    final reg = ref.read(boardingRegistrationProvider(widget.petId));
    triageNotifier.setWeight(reg.weightKg);
    triageNotifier.setCoatType(reg.coatType);
    triageNotifier.setCoatCondition(reg.coatCondition);
    if (reg.sizeCategory != null) {
      triageNotifier.setSizeCategory(reg.sizeCategory);
    }

    await triageNotifier.saveAssessment();
    if (!mounted) return;
    final triageAfter = ref.read(triageNotifierProvider(widget.petId));
    if (triageAfter.errorMessage != null) return;

    await regNotifier.saveAndGenerateCode();
    if (!mounted) return;
    final regAfter = ref.read(boardingRegistrationProvider(widget.petId));
    if (regAfter.hasCode) _animateTo(3);
  }

  @override
  Widget build(BuildContext context) {
    final reg = ref.watch(boardingRegistrationProvider(widget.petId));
    final triage = ref.watch(triageNotifierProvider(widget.petId));
    final isLoading = reg.isLoading || triage.isSaving;

    ref.listen(boardingRegistrationProvider(widget.petId), (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.coralRed,
            behavior: SnackBarBehavior.floating,
          ));
      }
    });
    ref.listen(triageNotifierProvider(widget.petId), (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.coralRed,
            behavior: SnackBarBehavior.floating,
          ));
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_step < 3)
            _StepIndicator(current: _step, labels: _stepLabels),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1PhysicalData(petId: widget.petId),
                _Step2VaccinationCard(petId: widget.petId),
                _Step3BehavioralProfile(petId: widget.petId),
                _Step4SuccessCode(
                    petId: widget.petId, petName: widget.petName),
              ],
            ),
          ),
          if (_step < 3)
            _NavBar(
              step: _step,
              isLastForm: _step == 2,
              canAdvance: _canAdvance(reg, triage) && !isLoading,
              isLoading: isLoading,
              onBack: _step > 0 ? () => _animateTo(_step - 1) : null,
              onNext:
                  _step == 2 ? _finalize : () async => _animateTo(_step + 1),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: _step < 3
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary, size: 20),
              onPressed: _step == 0
                  ? () => Navigator.of(context).pop()
                  : () => _animateTo(_step - 1),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingreso en Recepción',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            widget.petName,
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Indicador de pasos
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;

  const _StepIndicator({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < labels.length; i++) ...[
                _StepCircle(index: i, current: current),
                if (i < labels.length - 1)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color:
                          i < current ? AppTheme.mintGreen : AppTheme.border,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .asMap()
                .entries
                .map((e) => Text(
                      e.value,
                      style: GoogleFonts.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: e.key == current
                            ? AppTheme.mintGreen
                            : AppTheme.textMuted,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int index;
  final int current;

  const _StepCircle({required this.index, required this.current});

  @override
  Widget build(BuildContext context) {
    final isDone = index < current;
    final isActive = index == current;
    final color = (isDone || isActive) ? AppTheme.mintGreen : AppTheme.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: isDone
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text(
              '${index + 1}',
              style: GoogleFonts.fredoka(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppTheme.textSecondary,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 1 — Datos físicos
// ─────────────────────────────────────────────────────────────────────────────

class _Step1PhysicalData extends ConsumerStatefulWidget {
  final String petId;

  const _Step1PhysicalData({required this.petId});

  @override
  ConsumerState<_Step1PhysicalData> createState() =>
      _Step1PhysicalDataState();
}

class _Step1PhysicalDataState extends ConsumerState<_Step1PhysicalData> {
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    final w = ref.read(boardingRegistrationProvider(widget.petId)).weightKg;
    _weightCtrl = TextEditingController(text: w?.toString() ?? '');
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boardingRegistrationProvider(widget.petId));
    final notifier =
        ref.read(boardingRegistrationProvider(widget.petId).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(step: 'PASO 1', title: 'Datos Físicos'),
          const SizedBox(height: 20),

          _FieldLabel('Peso actual'),
          const SizedBox(height: 8),
          TextField(
            controller: _weightCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
            decoration: _inputDeco(
              hint: 'Ej: 12.5',
              suffix: 'kg',
            ),
            onChanged: (v) => notifier.setWeight(double.tryParse(v)),
          ),

          if ((state.weightKg ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _AutoBadge(
                '${state.effectiveSizeCategory.value} · ${state.weightKg!.toStringAsFixed(1)} kg'),
          ],

          const SizedBox(height: 24),
          _FieldLabel('Tipo de pelaje'),
          const SizedBox(height: 10),
          _ChipSelector<CoatType>(
            values: CoatType.values,
            selected: state.coatType,
            label: _coatTypeLabel,
            onSelected: notifier.setCoatType,
          ),

          const SizedBox(height: 24),
          _FieldLabel('Condición del pelaje'),
          const SizedBox(height: 10),
          _ChipSelector<CoatCondition>(
            values: CoatCondition.values,
            selected: state.coatCondition,
            label: _coatConditionLabel,
            accent: (v) => v == CoatCondition.MATTED ? AppTheme.coralRed : null,
            onSelected: notifier.setCoatCondition,
          ),

          if (state.coatCondition == CoatCondition.MATTED) ...[
            const SizedBox(height: 12),
            _WarnBanner(
                'Pelaje enmarañado detectado. Se agregarán +30 min al tiempo del servicio de estética.'),
          ],
        ],
      ),
    );
  }

  static String _coatTypeLabel(CoatType v) => switch (v) {
        CoatType.SHORT => 'Corto',
        CoatType.MEDIUM => 'Medio',
        CoatType.LONG => 'Largo',
        CoatType.DOUBLE_COAT => 'Doble capa',
        CoatType.CURLY => 'Rizado',
      };

  static String _coatConditionLabel(CoatCondition v) => switch (v) {
        CoatCondition.EXCELLENT => 'Excelente',
        CoatCondition.NORMAL => 'Normal',
        CoatCondition.MATTED => 'Enmarañado ⚠',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 2 — Triage sanitario / vacunas
// ─────────────────────────────────────────────────────────────────────────────

class _Step2VaccinationCard extends ConsumerWidget {
  final String petId;

  const _Step2VaccinationCard({required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vaccinationCardStreamProvider(petId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(step: 'PASO 2', title: 'Triage Sanitario'),
          const SizedBox(height: 4),
          Text(
            'Verifica que las vacunas obligatorias estén vigentes antes de continuar.',
            style: GoogleFonts.quicksand(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          async.when(
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.mintGreen)),
            error: (e, _) =>
                _ErrBanner('Error al cargar cartilla de vacunación: $e'),
            data: (entries) => _VaccinationBody(entries: entries),
          ),
        ],
      ),
    );
  }
}

class _VaccinationBody extends StatelessWidget {
  final List<VaccinationEntryEntity> entries;

  const _VaccinationBody({required this.entries});

  @override
  Widget build(BuildContext context) {
    const mandatory = [VaccineType.bordetella, VaccineType.rabies];

    // Build a map: vaccineType → most recent entry
    final latestOf = <VaccineType, VaccinationEntryEntity?>{
      for (final t in mandatory) t: null,
    };
    for (final e in entries) {
      if (e.vaccineType != null && mandatory.contains(e.vaccineType)) {
        final prev = latestOf[e.vaccineType!];
        if (prev == null || e.appliedAt.isAfter(prev.appliedAt)) {
          latestOf[e.vaccineType!] = e;
        }
      }
    }

    final others = entries
        .where((e) => e.vaccineType == null || !mandatory.contains(e.vaccineType))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('OBLIGATORIAS PARA GUARDERÍA'),
        const SizedBox(height: 8),
        ...mandatory.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _VaccineCard(
                  name: t.displayName,
                  entry: latestOf[t],
                  mandatory: true),
            )),
        const SizedBox(height: 20),
        _FieldLabel('OTRAS VACUNAS REGISTRADAS'),
        const SizedBox(height: 8),
        if (others.isEmpty)
          _InfoBanner('No hay otras vacunas registradas en esta cartilla.')
        else
          ...others.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VaccineCard(
                    name: e.vaccineType?.displayName ?? e.name,
                    entry: e,
                    mandatory: false),
              )),
      ],
    );
  }
}

class _VaccineCard extends StatelessWidget {
  final String name;
  final VaccinationEntryEntity? entry;
  final bool mandatory;

  const _VaccineCard(
      {required this.name, required this.entry, required this.mandatory});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String badge;

    if (entry == null) {
      color = AppTheme.coralRed;
      icon = Icons.cancel_rounded;
      badge = 'AUSENTE';
    } else if (entry!.isExpired) {
      color = AppTheme.coralRed;
      icon = Icons.warning_rounded;
      badge = 'VENCIDA';
    } else if (entry!.expiresSoon) {
      color = AppTheme.goldChampagne;
      icon = Icons.schedule_rounded;
      badge = 'POR VENCER';
    } else {
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
      badge = 'AL DÍA';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          style: GoogleFonts.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                    ),
                    if (mandatory) ...[
                      const SizedBox(width: 6),
                      _Pill('OBLIGATORIA', AppTheme.mintGreen),
                    ],
                  ],
                ),
                if (entry != null && entry!.nextApplicationAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Vence: ${_fmt(entry!.nextApplicationAt!)}',
                    style: GoogleFonts.quicksand(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          _Pill(badge, color),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    const m = [
      'Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 3 — Perfil conductual (confidencial)
// ─────────────────────────────────────────────────────────────────────────────

class _Step3BehavioralProfile extends ConsumerStatefulWidget {
  final String petId;

  const _Step3BehavioralProfile({required this.petId});

  @override
  ConsumerState<_Step3BehavioralProfile> createState() =>
      _Step3BehavioralProfileState();
}

class _Step3BehavioralProfileState
    extends ConsumerState<_Step3BehavioralProfile> {
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final notes =
        ref.read(triageNotifierProvider(widget.petId)).operationalNotes;
    _notesCtrl = TextEditingController(text: notes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(triageNotifierProvider(widget.petId));
    final notifier = ref.read(triageNotifierProvider(widget.petId).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(step: 'PASO 3', title: 'Perfil Conductual'),
          const SizedBox(height: 4),
          _ConfidentialTag(),
          const SizedBox(height: 20),

          // Risk level selector
          _FieldLabel('Nivel de riesgo'),
          const SizedBox(height: 10),
          _RiskSelector(
              selected: state.riskLevel, onSelected: notifier.setRiskLevel),

          const SizedBox(height: 24),
          _FieldLabel('Compatibilidad con otros perros'),
          const SizedBox(height: 10),
          _ChipSelector<DogCompatibility>(
            values: DogCompatibility.values,
            selected: state.dogCompatibility,
            label: (v) => switch (v) {
              DogCompatibility.friendly => 'Amigable',
              DogCompatibility.selective => 'Selectivo',
              DogCompatibility.reactive => 'Reactivo',
              DogCompatibility.aggressive => 'Agresivo ⚠',
            },
            accent: (v) {
              if (v == DogCompatibility.aggressive) return AppTheme.coralRed;
              if (v == DogCompatibility.reactive) return AppTheme.goldChampagne;
              return null;
            },
            onSelected: notifier.setDogCompatibility,
          ),

          const SizedBox(height: 24),
          _FieldLabel('Disparadores de riesgo'),
          const SizedBox(height: 8),
          _BigToggle(
            icon: Icons.front_hand_rounded,
            label: 'Requiere bozal',
            value: state.requiresMuzzle,
            onChanged: notifier.setRequiresMuzzle,
            warn: true,
          ),
          _BigToggle(
            icon: Icons.restaurant_rounded,
            label: 'Protección de comida',
            value: state.foodGuarding,
            onChanged: notifier.setFoodGuarding,
            warn: true,
          ),
          _BigToggle(
            icon: Icons.sports_soccer_rounded,
            label: 'Protección de juguetes',
            value: state.toyGuarding,
            onChanged: notifier.setToyGuarding,
            warn: true,
          ),
          _BigToggle(
            icon: Icons.lock_outline_rounded,
            label: 'Pánico al confinamiento',
            value: state.confinementPanic,
            onChanged: notifier.setConfinementPanic,
            warn: true,
          ),
          _BigToggle(
            icon: Icons.mood_bad_rounded,
            label: 'Ansiedad por separación',
            value: state.separationAnxiety,
            onChanged: notifier.setSeparationAnxiety,
            warn: false,
          ),
          _BigToggle(
            icon: Icons.hearing_disabled_rounded,
            label: 'Sensibilidad al ruido',
            value: state.noiseSensitivity,
            onChanged: notifier.setNoiseSensitivity,
            warn: false,
          ),

          const SizedBox(height: 24),
          _FieldLabel('Tolerancia al baño'),
          const SizedBox(height: 10),
          _ChipSelector<BathSensitivity>(
            values: BathSensitivity.values,
            selected: state.bathSensitivity,
            label: (v) => switch (v) {
              BathSensitivity.cooperative => 'Cooperativo',
              BathSensitivity.anxious => 'Ansioso',
              BathSensitivity.defensive => 'Defensivo ⚠',
            },
            accent: (v) =>
                v == BathSensitivity.defensive ? AppTheme.coralRed : null,
            onSelected: notifier.setBathSensitivity,
          ),

          const SizedBox(height: 20),
          _FieldLabel('Tolerancia al secador'),
          const SizedBox(height: 10),
          _ChipSelector<DryingSensitivity>(
            values: DryingSensitivity.values,
            selected: state.dryingSensitivity,
            label: (v) => switch (v) {
              DryingSensitivity.low => 'Baja',
              DryingSensitivity.medium => 'Media',
              DryingSensitivity.highPanic => 'Pánico ⚠',
            },
            accent: (v) =>
                v == DryingSensitivity.highPanic ? AppTheme.coralRed : null,
            onSelected: notifier.setDryingSensitivity,
          ),

          const SizedBox(height: 24),
          _FieldLabel('Notas operativas'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: GoogleFonts.quicksand(
                fontSize: 14, color: AppTheme.textPrimary),
            decoration: _inputDeco(hint: 'Instrucciones especiales para el equipo...'),
            onChanged: notifier.setOperationalNotes,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 4 — Éxito: Código PET-XXXX
// ─────────────────────────────────────────────────────────────────────────────

class _Step4SuccessCode extends ConsumerWidget {
  final String petId;
  final String petName;

  const _Step4SuccessCode(
      {required this.petId, required this.petName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boardingRegistrationProvider(petId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Success icon
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF16A34A).withOpacity(0.12),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 50),
          ),
          const SizedBox(height: 16),
          Text('Registro completado',
              style: GoogleFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(petName,
              style: GoogleFonts.quicksand(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),

          const SizedBox(height: 40),

          if (state.isLoading) ...[
            const CircularProgressIndicator(color: AppTheme.mintGreen),
            const SizedBox(height: 16),
            Text('Generando código...',
                style: GoogleFonts.quicksand(color: AppTheme.textSecondary)),
          ] else if (state.generatedCode != null) ...[
            Text('CÓDIGO DE VINCULACIÓN',
                style: GoogleFonts.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.0)),
            const SizedBox(height: 12),

            // Code card
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
              decoration: BoxDecoration(
                color: AppTheme.mintGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.mintGreen, width: 2),
              ),
              child: Text(
                state.generatedCode!.code,
                style: GoogleFonts.fredoka(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mintGreen,
                  letterSpacing: 5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Comparte este código con el dueño para vincular la mascota.',
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),

            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: state.generatedCode!.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Código copiado'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text('Copiar',
                        style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.mintGreen,
                      side: const BorderSide(color: AppTheme.mintGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final msg = Uri.encodeComponent(
                          '¡Hola! El código para vincular a *$petName* en PetCare Pro es: *${state.generatedCode!.code}*\n\nÚsalo en la app para conectar tu cuenta con tu mascota.');
                      launchUrl(
                          Uri.parse('https://wa.me/?text=$msg'),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('WhatsApp',
                        style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoBanner(
                'Este código vence en 15 minutos. Si el dueño no lo usa a tiempo, puedes regenerarlo desde el perfil de la mascota.'),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Finalizar registro',
                  style: GoogleFonts.fredoka(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de navegación inferior
// ─────────────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final int step;
  final bool isLastForm;
  final bool canAdvance;
  final bool isLoading;
  final VoidCallback? onBack;
  final Future<void> Function() onNext;

  const _NavBar({
    required this.step,
    required this.isLastForm,
    required this.canAdvance,
    required this.isLoading,
    this.onBack,
    required this.onNext,
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
      child: Row(
        children: [
          if (onBack != null) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: isLoading ? null : onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Anterior',
                    style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canAdvance ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.border,
                disabledForegroundColor: AppTheme.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      isLastForm ? 'Guardar y Generar Código' : 'Siguiente',
                      style: GoogleFonts.fredoka(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Componentes reutilizables internos
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String step;
  final String title;

  const _SectionHeader({required this.step, required this.title});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step,
              style: GoogleFonts.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mintGreen,
                  letterSpacing: 1.2)),
          Text(title,
              style: GoogleFonts.fredoka(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
        ],
      );
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            letterSpacing: 0.6),
      );
}

class _ChipSelector<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final void Function(T) onSelected;
  final Color? Function(T)? accent;

  const _ChipSelector({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.accent,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.map((v) {
          final isSelected = v == selected;
          final color = accent?.call(v) ?? AppTheme.mintGreen;
          return ChoiceChip(
            label: Text(label(v),
                style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppTheme.textPrimary)),
            selected: isSelected,
            selectedColor: color,
            backgroundColor: AppTheme.surface,
            side: BorderSide(color: isSelected ? color : AppTheme.border),
            onSelected: (_) => onSelected(v),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          );
        }).toList(),
      );
}

class _RiskSelector extends StatelessWidget {
  final RiskLevel selected;
  final void Function(RiskLevel) onSelected;

  const _RiskSelector(
      {required this.selected, required this.onSelected});

  static const _items = [
    (RiskLevel.green, Color(0xFF16A34A), '🟢', 'Sin riesgo'),
    (RiskLevel.yellow, Color(0xFFCA8A04), '🟡', 'Supervisión'),
    (RiskLevel.orange, Color(0xFFEA580C), '🟠', 'Especializado'),
    (RiskLevel.red, AppTheme.coralRed, '🔴', 'Alto riesgo'),
  ];

  @override
  Widget build(BuildContext context) => Row(
        children: _items.map((item) {
          final (level, color, emoji, lbl) = item;
          final isSelected = level == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.14)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isSelected ? color : AppTheme.border,
                      width: isSelected ? 2 : 1),
                ),
                child: Column(
                  children: [
                    Text(emoji,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(lbl,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? color
                                : AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
}

class _BigToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  final bool warn;

  const _BigToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.warn,
  });

  @override
  Widget build(BuildContext context) {
    final active = value && warn;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: active ? AppTheme.coralRed.withOpacity(0.06) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active
                ? AppTheme.coralRed.withOpacity(0.4)
                : AppTheme.border),
      ),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        secondary: Icon(icon,
            color: active ? AppTheme.coralRed : AppTheme.textSecondary,
            size: 22),
        title: Text(label,
            style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: active ? AppTheme.coralRed : AppTheme.textPrimary)),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.coralRed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _AutoBadge extends StatelessWidget {
  final String text;

  const _AutoBadge(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.mintGreen.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.mintGreen.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded,
                color: AppTheme.mintGreen, size: 13),
            const SizedBox(width: 5),
            Text(text,
                style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mintGreen)),
          ],
        ),
      );
}

class _ConfidentialTag extends StatelessWidget {
  const _ConfidentialTag();

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.skyBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.skyBlue),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded,
                color: AppTheme.mintGreen, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confidencial — solo visible para staff con acceso médico.',
                style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: GoogleFonts.quicksand(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3)),
      );
}

class _WarnBanner extends StatelessWidget {
  final String text;

  const _WarnBanner(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.goldChampagne.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.goldChampagne),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.goldChampagne, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.mintGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _ErrBanner extends StatelessWidget {
  final String text;

  const _ErrBanner(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.coralRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.coralRed.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.coralRed, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: AppTheme.coralRed,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared decoration helper
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDeco({required String hint, String? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.quicksand(color: AppTheme.textMuted),
      suffixText: suffix,
      suffixStyle: GoogleFonts.quicksand(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.mintGreen, width: 1.5)),
    );
