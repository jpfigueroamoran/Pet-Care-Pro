import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../pets/data/repositories/pet_repository.dart';
import '../../data/repositories/medical_repository.dart';

class MedicalHistoryScreen extends ConsumerStatefulWidget {
  final String petId;
  const MedicalHistoryScreen({super.key, required this.petId});

  @override
  ConsumerState<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends ConsumerState<MedicalHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final minutes = dt.minute.toString().padLeft(2, '0');
    final hours = dt.hour.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year} - $hours:$minutes';
  }

  Color _getReasonColor(String reason) {
    switch (reason) {
      case 'Urgencia': return AppTheme.coralRed;
      case 'Cirugía': return AppTheme.skyBlue;
      default: return AppTheme.mintGreen;
    }
  }

  IconData _getReasonIcon(String reason) {
    switch (reason) {
      case 'Urgencia': return Icons.warning_amber_rounded;
      case 'Cirugía': return Icons.healing_outlined;
      default: return Icons.description_outlined;
    }
  }

  Widget _buildVaccineStatusChip(DateTime nextDose) {
    final diff = nextDose.difference(DateTime.now()).inDays;
    if (diff < 0) {
      return _chip('VENCIDO / REAPLICAR', AppTheme.coralRed);
    } else if (diff <= 30) {
      return _chip('PRÓXIMO A VENCER', AppTheme.goldChampagne);
    } else {
      return _chip('AL DÍA / VIGENTE', AppTheme.mintGreen);
    }
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showAddVaccineDialog(BuildContext context, UserEntity user, {bool isOwner = false}) {
    String immunizationType = 'Vacuna de Rabia';
    DateTime appliedAt = DateTime.now();
    DateTime nextApplicationAt =
        DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day);
    bool isSaving = false;

    void updateNextDose(String type, Function setDialogState) {
      final now = appliedAt;
      if (type.contains('Desparasitante')) {
        nextApplicationAt = DateTime(now.year, now.month + 6, now.day);
      } else {
        nextApplicationAt = DateTime(now.year + 1, now.month, now.day);
      }
      setDialogState(() {});
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.vaccines_outlined, color: AppTheme.mintGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOwner ? 'Reportar Vacuna Aplicada' : 'Registrar Vacuna / Desparasitante',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: immunizationType,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Tipo de Inmunización',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.medication_outlined, color: AppTheme.mintGreen),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.mintGreen),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Vacuna de Rabia', child: Text('Vacuna de Rabia')),
                      DropdownMenuItem(value: 'Vacuna Múltiple', child: Text('Vacuna Múltiple')),
                      DropdownMenuItem(value: 'Triple Felina', child: Text('Triple Felina')),
                      DropdownMenuItem(value: 'Desparasitante Interno', child: Text('Desparasitante Interno')),
                      DropdownMenuItem(value: 'Desparasitante Externo', child: Text('Desparasitante Externo')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        immunizationType = val;
                        updateNextDose(val, setDialogState);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: appliedAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: AppTheme.mintGreen,
                              onPrimary: Colors.white,
                              surface: AppTheme.surface,
                              onSurface: AppTheme.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        appliedAt = picked;
                        updateNextDose(immunizationType, setDialogState);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha de Aplicación',
                        labelStyle: const TextStyle(color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.event_available_outlined, color: AppTheme.mintGreen),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                      child: Text(
                        '${appliedAt.day}/${appliedAt.month}/${appliedAt.year}',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.mintGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_repeat_outlined, size: 16, color: AppTheme.mintGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Próxima dosis sugerida: ${nextApplicationAt.day}/${nextApplicationAt.month}/${nextApplicationAt.year} '
                            '(${immunizationType.contains('Desparasitante') ? '6 meses' : '1 año'})',
                            style: const TextStyle(color: AppTheme.mintGreen, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          await ref.read(medicalRepositoryProvider).addVaccinationRecord(
                            widget.petId,
                            {
                              'type': immunizationType.contains('Desparasitante') ? 'dewormer' : 'vaccine',
                              'name': immunizationType,
                              'appliedAt': Timestamp.fromDate(appliedAt),
                              'nextApplicationAt': Timestamp.fromDate(nextApplicationAt),
                              if (!isOwner) 'appliedByVetId': user.uid,
                              if (!isOwner) 'appliedByVetName': user.displayName,
                              'verifiedByVet': !isOwner,
                              'notes': '',
                            },
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vacuna registrada en la cartilla digital'),
                                backgroundColor: AppTheme.mintGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al registrar vacuna: $e'),
                                backgroundColor: AppTheme.coralRed,
                              ),
                            );
                          }
                        }
                      },
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18, color: Colors.white),
                label: Text(isSaving ? 'GUARDANDO...' : 'GUARDAR',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _certifyVaccine(String entryId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref.read(medicalRepositoryProvider).certifyVaccinationRecord(
        widget.petId,
        entryId,
        user.uid,
        user.displayName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vacuna certificada correctamente.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al certificar: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    }
  }

  Widget? _buildFab(BuildContext context, UserEntity? user, bool canWrite, bool isOwner) {
    if (_currentTab == 0) {
      if (!canWrite) return null;
      return FloatingActionButton.extended(
        onPressed: () => context.push('/pet/${widget.petId}/history/add'),
        backgroundColor: AppTheme.skyBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVA CONSULTA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }
    if (!canWrite && !isOwner) return null;
    return FloatingActionButton.extended(
      onPressed: () => _showAddVaccineDialog(context, user!, isOwner: !canWrite),
      backgroundColor: AppTheme.mintGreen,
      icon: const Icon(Icons.vaccines_outlined, color: Colors.white),
      label: Text(
        canWrite ? 'REGISTRAR VACUNA' : 'REPORTAR VACUNA',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final historyAsync = ref.watch(medicalHistoryStreamProvider(widget.petId));
    final vaccinesAsync = ref.watch(vaccinationCardStreamProvider(widget.petId));
    final canWrite = user != null && user.role == UserRole.vet && user.isApprovedVet;
    final isOwner = user != null && user.role == UserRole.owner;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Expediente Clínico', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_outlined), text: 'Consultas Clínicas'),
            Tab(icon: Icon(Icons.vaccines_outlined), text: 'Cartilla de Vacunación'),
            Tab(icon: Icon(Icons.show_chart), text: 'Evolución Peso'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Alerta Médica Crítica (Global)
          Consumer(
            builder: (context, ref, child) {
              final petAsync = ref.watch(singlePetStreamProvider(widget.petId));
              final pet = petAsync.valueOrNull;
              if (pet == null) return const SizedBox.shrink();

              if (pet.allergies.isEmpty && pet.chronicConditions.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppTheme.coralRed.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.coralRed),
                        SizedBox(width: 8),
                        Text(
                          'ALERTA MÉDICA CRÍTICA',
                          style: TextStyle(
                            color: AppTheme.coralRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (pet.allergies.isNotEmpty) ...[
                      const Text(
                        'Alergias:',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        pet.allergies.join(', '),
                        style: const TextStyle(color: AppTheme.coralRed, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (pet.chronicConditions.isNotEmpty) ...[
                      const Text(
                        'Enfermedades Crónicas:',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        pet.chronicConditions.join(', '),
                        style: const TextStyle(color: AppTheme.coralRed, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Historial de Consultas ──────────────────────────────────
                historyAsync.when(
            data: (history) {
              if (history.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceVariant,
                          border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2), width: 2),
                        ),
                        child: const Icon(Icons.history_edu_outlined, size: 64, color: AppTheme.skyBlue),
                      ),
                      const SizedBox(height: 32),
                      const Text('Historial Vacío',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text(
                        'Esta mascota no cuenta con registros de consulta aún. Si eres un veterinario autorizado, puedes pulsar el botón flotante inferior para agregar la primera consulta clínica.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      if (canWrite) ...[
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/pet/${widget.petId}/history/add'),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('REGISTRAR PRIMERA CONSULTA',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.skyBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final record = history[index];
                  final reasonColor = _getReasonColor(record.reason);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.mintGreen.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: reasonColor.withValues(alpha: 0.06),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            border: Border(
                              bottom: BorderSide(color: AppTheme.border),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(_getReasonIcon(record.reason), size: 18, color: reasonColor),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: reasonColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      record.reason.toUpperCase(),
                                      style: TextStyle(
                                        color: reasonColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _formatDateTime(record.date),
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DIAGNÓSTICO CLÍNICO',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0)),
                              const SizedBox(height: 6),
                              Text(record.diagnosis,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              const Text('SINTOMATOLOGÍA Y JUSTIFICACIÓN',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0)),
                              const SizedBox(height: 6),
                              Text(record.justification,
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 13, height: 1.5)),
                              const Divider(height: 28, color: AppTheme.border),
                              const Text('TRATAMIENTO DETALLADO',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0)),
                              const SizedBox(height: 6),
                              Text(record.treatment,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
                              const SizedBox(height: 16),
                              const Text('RECETA / PRESCRIPCIÓN MÉDICA',
                                  style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.receipt_long_outlined,
                                                size: 16, color: AppTheme.skyBlue),
                                            SizedBox(width: 6),
                                            Text('Rx Prescripción',
                                                style: TextStyle(
                                                    color: AppTheme.skyBlue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                        Text('${record.weightKg} Kg',
                                            style: const TextStyle(
                                                color: AppTheme.goldChampagne,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const Divider(color: AppTheme.border, height: 16),
                                    Text(record.prescription,
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 13,
                                            height: 1.5,
                                            fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                              if (record.notes.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text('NOTAS ADICIONALES',
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0)),
                                const SizedBox(height: 6),
                                Text(record.notes,
                                    style: const TextStyle(
                                        color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
                              ],
                              const Divider(height: 28, color: AppTheme.border),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.skyBlue.withValues(alpha: 0.12),
                                    child: const Icon(Icons.person_outline, size: 14, color: AppTheme.skyBlue),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Emitido por: ${record.vetName}',
                                        style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error al cargar el historial clínico: $err',
                    style: const TextStyle(color: AppTheme.coralRed), textAlign: TextAlign.center),
              ),
            ),
          ),

          // ── Tab 2: Cartilla de Vacunación ──────────────────────────────────
          vaccinesAsync.when(
            data: (vaccines) {
              if (vaccines.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceVariant,
                          border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.2), width: 2),
                        ),
                        child: const Icon(Icons.vaccines_outlined, size: 64, color: AppTheme.mintGreen),
                      ),
                      const SizedBox(height: 32),
                      const Text('Cartilla Vacía',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text(
                        'Aún no se han registrado vacunas o desparasitantes. Como dueño, puedes reportar vacunas previas con el botón inferior. El veterinario podrá certificarlas en la próxima consulta.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                itemCount: vaccines.length,
                itemBuilder: (context, index) {
                  final entry = vaccines[index];
                  final String name = entry['name'] ?? 'Inmunización';
                  final String type = entry['type'] ?? 'vaccine';
                  final bool verifiedByVet = entry['verifiedByVet'] ?? false;

                  final DateTime appliedAt = entry['appliedAt'] != null
                      ? (entry['appliedAt'] as dynamic).toDate()
                      : DateTime.now();
                  final DateTime nextApplicationAt = entry['nextApplicationAt'] != null
                      ? (entry['nextApplicationAt'] as dynamic).toDate()
                      : DateTime.now();

                  final isVaccine = type == 'vaccine';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: verifiedByVet
                            ? AppTheme.border
                            : AppTheme.goldChampagne.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isVaccine ? AppTheme.mintGreen : AppTheme.skyBlue)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVaccine ? Icons.vaccines : Icons.bug_report,
                            color: isVaccine ? AppTheme.mintGreen : AppTheme.skyBlue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(name,
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                  ),
                                  _buildVaccineStatusChip(nextApplicationAt),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      (verifiedByVet ? AppTheme.mintGreen : AppTheme.goldChampagne)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  verifiedByVet
                                      ? 'CERTIFICADO POR VETERINARIO'
                                      : 'AUTOREPORTADO POR DUEÑO',
                                  style: TextStyle(
                                    color: verifiedByVet
                                        ? AppTheme.mintGreen
                                        : AppTheme.goldChampagne,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aplicada: ${_formatDateTime(appliedAt).split(' - ').first}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Próxima dosis: ${_formatDateTime(nextApplicationAt).split(' - ').first}',
                                style: const TextStyle(
                                    color: AppTheme.goldChampagne,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12),
                              ),
                              if (entry['appliedByVetName'] != null && verifiedByVet) ...[
                                const Divider(color: AppTheme.border, height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.verified_user_outlined,
                                        size: 12, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Firmado por: ${entry['appliedByVetName']}',
                                        style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (canWrite && !verifiedByVet) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _certifyVaccine(entry['id'] as String),
                                    icon: const Icon(Icons.verified_user_outlined, size: 14),
                                    label: const Text('CERTIFICAR REGISTRO'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.mintGreen,
                                      side: const BorderSide(color: AppTheme.mintGreen),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      textStyle: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
            error: (err, stack) => Center(
              child: Text('Error: $err', style: const TextStyle(color: AppTheme.coralRed)),
            ),
          ),
          
          // ── Tab 3: Evolución de Peso ──────────────────────────────────────────
          historyAsync.when(
            data: (history) {
              if (history.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No hay datos suficientes para mostrar la evolución del peso.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              
              // Sort chronologically (oldest first) for the chart
              final sortedHistory = List.of(history)..sort((a, b) => a.date.compareTo(b.date));
              
              final spots = <FlSpot>[];
              for (int i = 0; i < sortedHistory.length; i++) {
                spots.add(FlSpot(i.toDouble(), sortedHistory[i].weightKg));
              }
              
              double minWeight = spots.isEmpty ? 0 : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
              double maxWeight = spots.isEmpty ? 0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
              
              // Expand Y axis a bit for better visualization
              minWeight = (minWeight - 2).clamp(0.0, double.infinity);
              maxWeight = maxWeight + 2;
              
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Curva de Peso',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Monitorea el peso de tu mascota en cada visita clínica para prevenir problemas de salud.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mintGreen.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: AppTheme.border.withValues(alpha: 0.5),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < sortedHistory.length) {
                                      final date = sortedHistory[value.toInt()].date;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          '${date.day}/${date.month}',
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 2,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}kg',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                    );
                                  },
                                  reservedSize: 42,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0,
                            maxX: (sortedHistory.length - 1).toDouble().clamp(0.0, double.infinity),
                            minY: minWeight,
                            maxY: maxWeight,
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: AppTheme.skyBlue,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: AppTheme.skyBlue,
                                      strokeWidth: 2,
                                      strokeColor: AppTheme.surface,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.skyBlue.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((LineBarSpot touchedSpot) {
                                    return LineTooltipItem(
                                      '${touchedSpot.y} Kg',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
            error: (err, stack) => Center(
              child: Text('Error: $err', style: const TextStyle(color: AppTheme.coralRed)),
            ),
          ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: _buildFab(context, user, canWrite, isOwner),
    );
  }
}
