import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/vaccination_entry_entity.dart';
import '../../../pets/data/repositories/pet_repository.dart';
import '../providers/boarding_providers.dart';
import '../providers/triage_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de Triage Médico y Conductual
// Accesible únicamente por staff con canPerformMedical o canPerformServices.
// ─────────────────────────────────────────────────────────────────────────────

class MedicalAndBehavioralTriageScreen extends ConsumerStatefulWidget {
  final String petId;
  final String petName;

  const MedicalAndBehavioralTriageScreen({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  ConsumerState<MedicalAndBehavioralTriageScreen> createState() =>
      _MedicalAndBehavioralTriageScreenState();
}

class _MedicalAndBehavioralTriageScreenState
    extends ConsumerState<MedicalAndBehavioralTriageScreen> {
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final triage = ref.watch(triageNotifierProvider(widget.petId));
    final notifier = ref.read(triageNotifierProvider(widget.petId).notifier);
    final vacAsync = ref.watch(vaccinationCardStreamProvider(widget.petId));
    final petSpecies = ref.watch(singlePetStreamProvider(widget.petId))
        .whenOrNull(data: (p) => p?.species) ?? 'Perro';

    // Escuchar errores para feedback visual
    ref.listen(triageNotifierProvider(widget.petId), (prev, next) {
      if (prev?.errorMessage == null && next.errorMessage != null) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.errorMessage!),
          backgroundColor: AppTheme.coralRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
      if (prev?.savedAssessment == null && next.savedAssessment != null) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Evaluación guardada correctamente.'),
          backgroundColor: AppTheme.mintGreen,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Triage — ${widget.petName}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              'Evaluación confidencial — solo staff',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        backgroundColor: AppTheme.mintGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _SectionCard(
            icon: Icons.monitor_weight_outlined,
            title: 'Datos Físicos',
            child: _PhysicalDataSection(
              triage: triage,
              notifier: notifier,
              weightController: _weightController,
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.vaccines_outlined,
            title: 'Cartilla de Vacunación',
            child: vacAsync.when(
              data: (vaccines) => _VaccinationSection(vaccines: vaccines, species: petSpecies),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.mintGreen),
                ),
              ),
              error: (e, _) => _ErrorRow(message: 'Error al cargar vacunas: $e'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.psychology_outlined,
            title: 'Perfil Conductual Confidencial',
            titleColor: AppTheme.goldChampagne,
            child: _BehavioralSection(
              triage: triage,
              notifier: notifier,
              notesController: _notesController,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SaveBar(
        triage: triage,
        onSave: notifier.saveAssessment,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección: Datos Físicos
// ─────────────────────────────────────────────────────────────────────────────

class _PhysicalDataSection extends StatelessWidget {
  final TriageState triage;
  final TriageNotifier notifier;
  final TextEditingController weightController;

  const _PhysicalDataSection({
    required this.triage,
    required this.notifier,
    required this.weightController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Peso
        TextFormField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Peso (kg)',
            hintText: 'Ej. 12.5',
            suffixText: 'kg',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.mintGreen, width: 2),
            ),
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v.replaceAll(',', '.'));
            notifier.setWeight(parsed);
          },
        ),
        const SizedBox(height: 8),
        if (triage.weightKg != null)
          _InfoChip(
            label:
                'Categoría de tamaño: ${triage.effectiveSizeCategory.name}',
            color: AppTheme.mintGreen,
          ),
        const SizedBox(height: 16),

        // Tipo de pelaje
        _FieldLabel(label: 'Tipo de Pelaje'),
        _ChipRow<CoatType>(
          values: CoatType.values,
          selected: triage.coatType,
          labelOf: (v) => v.name,
          onSelect: notifier.setCoatType,
        ),
        const SizedBox(height: 16),

        // Condición del pelaje
        _FieldLabel(label: 'Condición del Pelaje'),
        _ChipRow<CoatCondition>(
          values: CoatCondition.values,
          selected: triage.coatCondition,
          labelOf: (v) {
            switch (v) {
              case CoatCondition.EXCELLENT:
                return 'Excelente';
              case CoatCondition.NORMAL:
                return 'Normal';
              case CoatCondition.MATTED:
                return 'Enmarañado';
            }
          },
          colorOf: (v) =>
              v == CoatCondition.MATTED ? AppTheme.coralRed : null,
          onSelect: notifier.setCoatCondition,
        ),
        if (triage.coatCondition == CoatCondition.MATTED)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _WarningRow(
                message: 'Pelaje enmarañado: +30 min de desanudado en MPT.'),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección: Cartilla de Vacunación
// ─────────────────────────────────────────────────────────────────────────────

class _VaccinationSection extends StatelessWidget {
  final List<VaccinationEntryEntity> vaccines;
  final String species;

  const _VaccinationSection({required this.vaccines, required this.species});

  @override
  Widget build(BuildContext context) {
    if (vaccines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Sin registros de vacunación.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    // Vacunas obligatorias para guardería al frente (según especie)
    final mandatory = vaccines
        .where((v) => v.isMandatoryForSpecies(species) && v.isVaccine)
        .toList();
    final others = vaccines
        .where((v) => !v.isMandatoryForSpecies(species) || !v.isVaccine)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mandatory.isNotEmpty) ...[
          _FieldLabel(label: 'Obligatorias para Ingreso'),
          ...mandatory.map((v) => _VaccineRow(entry: v, highlight: true)),
          const SizedBox(height: 12),
        ],
        if (others.isNotEmpty) ...[
          _FieldLabel(label: 'Resto de Cartilla'),
          ...others.map((v) => _VaccineRow(entry: v, highlight: false)),
        ],
      ],
    );
  }
}

class _VaccineRow extends StatelessWidget {
  final VaccinationEntryEntity entry;
  final bool highlight;

  const _VaccineRow({required this.entry, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = entry.isExpired
        ? AppTheme.coralRed
        : entry.expiresSoon
            ? AppTheme.goldChampagne
            : AppTheme.mintGreen;

    final String statusLabel = entry.isExpired
        ? 'VENCIDA'
        : entry.expiresSoon
            ? 'Vence en ${entry.daysUntilExpiry}d'
            : 'Vigente';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? statusColor.withOpacity(0.06)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? statusColor.withOpacity(0.35) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            entry.isExpired
                ? Icons.cancel_outlined
                : entry.expiresSoon
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
            color: statusColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.vaccineType?.displayName ?? entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  entry.type == 'dewormer' ? 'Desparasitación' : 'Vacuna',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección: Perfil Conductual Confidencial
// ─────────────────────────────────────────────────────────────────────────────

class _BehavioralSection extends StatelessWidget {
  final TriageState triage;
  final TriageNotifier notifier;
  final TextEditingController notesController;

  const _BehavioralSection({
    required this.triage,
    required this.notifier,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner confidencial
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.goldChampagne.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppTheme.goldChampagne.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline,
                  color: AppTheme.goldChampagne, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Esta información es confidencial. Solo visible para staff con permisos.',
                  style: TextStyle(
                      color: AppTheme.goldChampagne,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Nivel de riesgo
        _FieldLabel(label: 'Nivel de Riesgo General'),
        _RiskLevelSelector(
          selected: triage.riskLevel,
          onSelect: notifier.setRiskLevel,
        ),
        const SizedBox(height: 16),

        // Nivel de energía
        _FieldLabel(label: 'Nivel de Energía'),
        _ChipRow<EnergyLevel>(
          values: EnergyLevel.values,
          selected: triage.energyLevel,
          labelOf: (v) {
            switch (v) {
              case EnergyLevel.low:
                return 'Bajo';
              case EnergyLevel.medium:
                return 'Medio';
              case EnergyLevel.high:
                return 'Alto';
              case EnergyLevel.hyperactive:
                return 'Hiperactivo';
            }
          },
          onSelect: notifier.setEnergyLevel,
        ),
        const SizedBox(height: 20),

        const Divider(),
        const SizedBox(height: 12),
        _FieldLabel(label: 'Sociabilidad con Otros Perros'),
        _ChipRow<DogCompatibility>(
          values: DogCompatibility.values,
          selected: triage.dogCompatibility,
          labelOf: (v) {
            switch (v) {
              case DogCompatibility.friendly:
                return 'Amigable';
              case DogCompatibility.selective:
                return 'Selectivo';
              case DogCompatibility.reactive:
                return 'Reactivo';
              case DogCompatibility.aggressive:
                return 'Agresivo';
            }
          },
          colorOf: (v) => v == DogCompatibility.aggressive
              ? AppTheme.coralRed
              : v == DogCompatibility.reactive
                  ? AppTheme.goldChampagne
                  : null,
          onSelect: notifier.setDogCompatibility,
        ),
        const SizedBox(height: 12),

        _SwitchRow(
          label: 'Requiere bozal',
          value: triage.requiresMuzzle,
          onChanged: notifier.setRequiresMuzzle,
        ),
        const SizedBox(height: 12),

        _FieldLabel(label: 'Estilo de Juego'),
        _ChipRow<PlayStyle>(
          values: PlayStyle.values,
          selected: triage.playStyle,
          labelOf: (v) {
            switch (v) {
              case PlayStyle.gentle:
                return 'Suave';
              case PlayStyle.rough:
                return 'Brusco';
              case PlayStyle.none:
                return 'No juega';
            }
          },
          onSelect: notifier.setPlayStyle,
        ),
        const SizedBox(height: 20),

        const Divider(),
        const SizedBox(height: 12),
        _FieldLabel(label: 'Disparadores de Riesgo'),
        _SwitchRow(
          label: 'Protección de comida',
          value: triage.foodGuarding,
          onChanged: notifier.setFoodGuarding,
          alertColor: AppTheme.coralRed,
        ),
        _SwitchRow(
          label: 'Protección de juguetes',
          value: triage.toyGuarding,
          onChanged: notifier.setToyGuarding,
          alertColor: AppTheme.coralRed,
        ),
        _SwitchRow(
          label: 'Ansiedad por separación',
          value: triage.separationAnxiety,
          onChanged: notifier.setSeparationAnxiety,
          alertColor: AppTheme.goldChampagne,
        ),
        _SwitchRow(
          label: 'Pánico en confinamiento',
          value: triage.confinementPanic,
          onChanged: notifier.setConfinementPanic,
          alertColor: AppTheme.goldChampagne,
        ),
        _SwitchRow(
          label: 'Sensibilidad al ruido',
          value: triage.noiseSensitivity,
          onChanged: notifier.setNoiseSensitivity,
          alertColor: AppTheme.goldChampagne,
        ),
        const SizedBox(height: 20),

        const Divider(),
        const SizedBox(height: 12),
        _FieldLabel(label: 'Tolerancia al Manejo'),
        _FieldLabel(label: 'Baño', small: true),
        _ChipRow<BathSensitivity>(
          values: BathSensitivity.values,
          selected: triage.bathSensitivity,
          labelOf: (v) {
            switch (v) {
              case BathSensitivity.cooperative:
                return 'Cooperativo';
              case BathSensitivity.anxious:
                return 'Ansioso (+10 min)';
              case BathSensitivity.defensive:
                return 'Defensivo (+25 min)';
            }
          },
          colorOf: (v) =>
              v == BathSensitivity.defensive ? AppTheme.coralRed : null,
          onSelect: notifier.setBathSensitivity,
        ),
        const SizedBox(height: 12),
        _FieldLabel(label: 'Secado', small: true),
        _ChipRow<DryingSensitivity>(
          values: DryingSensitivity.values,
          selected: triage.dryingSensitivity,
          labelOf: (v) {
            switch (v) {
              case DryingSensitivity.low:
                return 'Bajo';
              case DryingSensitivity.medium:
                return 'Medio (+15 min)';
              case DryingSensitivity.highPanic:
                return 'Pánico (+45 min)';
            }
          },
          colorOf: (v) =>
              v == DryingSensitivity.highPanic ? AppTheme.coralRed : null,
          onSelect: notifier.setDryingSensitivity,
        ),
        const SizedBox(height: 12),
        _FieldLabel(label: 'Corte de Uñas', small: true),
        _ChipRow<NailTrimming>(
          values: NailTrimming.values,
          selected: triage.nailTrimming,
          labelOf: (v) {
            switch (v) {
              case NailTrimming.cooperative:
                return 'Cooperativo';
              case NailTrimming.needsMuzzle:
                return 'Necesita bozal';
              case NailTrimming.sedationRequired:
                return 'Requiere sedación';
            }
          },
          colorOf: (v) => v == NailTrimming.sedationRequired
              ? AppTheme.coralRed
              : null,
          onSelect: notifier.setNailTrimming,
        ),
        const SizedBox(height: 20),

        const Divider(),
        const SizedBox(height: 12),
        _FieldLabel(label: 'Notas Operativas del Staff'),
        TextFormField(
          controller: notesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Observaciones relevantes para el equipo (visible solo internamente)...',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.mintGreen, width: 2),
            ),
          ),
          onChanged: notifier.setOperationalNotes,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de guardado
// ─────────────────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final TriageState triage;
  final VoidCallback onSave;

  const _SaveBar({required this.triage, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (triage.isHighRisk)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WarningRow(
                  message:
                      'Nivel de riesgo ${triage.riskLevel.displayLabel} — el ingreso a área común queda restringido.',
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: triage.isSaving ? null : onSave,
                icon: triage.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                    triage.isSaving ? 'Guardando...' : 'Guardar Evaluación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
// Selector visual de nivel de riesgo
// ─────────────────────────────────────────────────────────────────────────────

class _RiskLevelSelector extends StatelessWidget {
  final RiskLevel selected;
  final ValueChanged<RiskLevel> onSelect;

  const _RiskLevelSelector({required this.selected, required this.onSelect});

  static const _levelColors = {
    RiskLevel.green: Color(0xFF16A34A),
    RiskLevel.yellow: AppTheme.goldChampagne,
    RiskLevel.orange: Color(0xFFF97316),
    RiskLevel.red: AppTheme.coralRed,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RiskLevel.values.map((level) {
        final color = _levelColors[level]!;
        final isSelected = selected == level;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : color.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.circle,
                    color: isSelected ? Colors.white : color,
                    size: 14,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.name.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets reutilizables internos
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? titleColor;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(icon,
                    color: titleColor ?? AppTheme.mintGreen, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;
  final Color? Function(T)? colorOf;

  const _ChipRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
    this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = v == selected;
        final accent =
            colorOf?.call(v) ?? AppTheme.mintGreen;
        return GestureDetector(
          onTap: () => onSelect(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected ? accent.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? accent : AppTheme.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              labelOf(v),
              style: TextStyle(
                color: isSelected ? accent : AppTheme.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? alertColor;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.alertColor,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        value ? (alertColor ?? AppTheme.coralRed) : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: value ? color : AppTheme.textPrimary,
                fontWeight:
                    value ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: alertColor ?? AppTheme.mintGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool small;

  const _FieldLabel({required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: small ? 12 : 13,
          color: small ? AppTheme.textSecondary : AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final String message;

  const _WarningRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.goldChampagne.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppTheme.goldChampagne.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.goldChampagne, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppTheme.goldChampagne,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;

  const _ErrorRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.coralRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.coralRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppTheme.coralRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppTheme.coralRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
