import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/medical_record_entity.dart';
import '../../data/repositories/medical_repository.dart';

class AddMedicalRecordScreen extends ConsumerStatefulWidget {
  final String petId;
  const AddMedicalRecordScreen({super.key, required this.petId});

  @override
  ConsumerState<AddMedicalRecordScreen> createState() => _AddMedicalRecordScreenState();
}

class _AddMedicalRecordScreenState extends ConsumerState<AddMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _justificationController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedReason = 'Consulta';
  bool _isLoading = false;
  String? _errorMessage;

  bool _registerImmunization = false;
  String _immunizationType = 'Vacuna de Rabia';
  DateTime? _nextDoseDate;

  @override
  void dispose() {
    _weightController.dispose();
    _justificationController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _prescriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateDefaultDoseDate(String type) {
    final now = DateTime.now();
    if (type.contains('Desparasitante')) {
      _nextDoseDate = DateTime(now.year, now.month + 6, now.day);
    } else {
      _nextDoseDate = DateTime(now.year + 1, now.month, now.day);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() {
        _errorMessage = 'No se encontró una sesión activa de veterinario.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newRecord = MedicalRecordEntity(
        id: '',
        date: DateTime.now(),
        reason: _selectedReason,
        weightKg: double.parse(_weightController.text.trim()),
        justification: _justificationController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        treatment: _treatmentController.text.trim(),
        prescription: _prescriptionController.text.trim(),
        vetId: user.uid,
        vetName: user.displayName,
        notes: _notesController.text.trim(),
        attachments: const [],
      );

      await ref.read(medicalRepositoryProvider).addMedicalRecord(widget.petId, newRecord);

      if (_registerImmunization) {
        final immunizationEntry = {
          'type': _immunizationType.contains('Desparasitante') ? 'dewormer' : 'vaccine',
          'name': _immunizationType,
          'appliedAt': DateTime.now(),
          'nextApplicationAt': _nextDoseDate ?? DateTime.now().add(const Duration(days: 365)),
          'appliedByVetId': user.uid,
          'appliedByVetName': user.displayName,
          'notes': 'Aplicado durante la consulta clínica: ${_treatmentController.text.trim()}',
        };
        await ref.read(medicalRepositoryProvider).addVaccinationRecord(widget.petId, immunizationEntry);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Expediente e Inmunización actualizados con éxito! 🩺💉'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al registrar consulta: $e';
      });
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Color? iconColor,
    EdgeInsets? prefixPadding,
  }) {
    final effectiveIcon = Icon(icon, color: iconColor ?? AppTheme.skyBlue);
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textMuted),
      prefixIcon: prefixPadding != null
          ? Padding(padding: prefixPadding, child: effectiveIcon)
          : effectiveIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: iconColor ?? AppTheme.skyBlue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.coralRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.coralRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Registrar Consulta', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        color: AppTheme.skyBlue,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.coralRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.coralRed.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.coralRed, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Padding(
                    padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                    child: Text(
                      'Razón de la Visita',
                      style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'Consulta',
                        label: Text('Consulta'),
                        icon: Icon(Icons.description_outlined),
                      ),
                      ButtonSegment<String>(
                        value: 'Urgencia',
                        label: Text('Urgencia'),
                        icon: Icon(Icons.warning_amber_rounded),
                      ),
                      ButtonSegment<String>(
                        value: 'Cirugía',
                        label: Text('Cirugía'),
                        icon: Icon(Icons.healing_outlined),
                      ),
                    ],
                    selected: {_selectedReason},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedReason = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.skyBlue;
                        }
                        return AppTheme.surfaceVariant;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return AppTheme.textMuted;
                      }),
                      side: WidgetStateProperty.all(const BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(
                      label: 'Peso de la mascota (Kg)',
                      icon: Icons.scale_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el peso';
                      }
                      final weight = double.tryParse(value.trim());
                      if (weight == null || weight <= 0) {
                        return 'Ingresa un peso válido mayor a 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _justificationController,
                    maxLines: 3,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(
                      label: 'Justificación médica / Sintomatología',
                      icon: Icons.search_outlined,
                      prefixPadding: const EdgeInsets.only(bottom: 40),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La justificación o sintomatología es obligatoria';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _diagnosisController,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(
                      label: 'Diagnóstico Clínico',
                      icon: Icons.assignment_outlined,
                      prefixPadding: const EdgeInsets.only(bottom: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El diagnóstico clínico es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _treatmentController,
                    maxLines: 3,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(
                      label: 'Tratamiento',
                      icon: Icons.healing_outlined,
                      prefixPadding: const EdgeInsets.only(bottom: 40),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El tratamiento es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _prescriptionController,
                    maxLines: 3,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(
                      label: 'Receta / Prescripción',
                      icon: Icons.receipt_long_outlined,
                      prefixPadding: const EdgeInsets.only(bottom: 40),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La receta o prescripción médica es obligatoria';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Notas adicionales (Opcional)',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.note_add_outlined, color: AppTheme.skyBlue),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.skyBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.vaccines_outlined, color: AppTheme.mintGreen),
                            SizedBox(width: 8),
                            Text(
                              'Cartilla de Inmunización',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Registra esta visita en la cartilla digital de vacunas o desparasitación de la mascota.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        const Divider(color: AppTheme.border, height: 24),
                        SwitchListTile(
                          title: const Text('¿Aplicar vacuna o desparasitante?',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                          value: _registerImmunization,
                          activeColor: AppTheme.mintGreen,
                          onChanged: (val) {
                            setState(() {
                              _registerImmunization = val;
                              if (val) {
                                _updateDefaultDoseDate(_immunizationType);
                              }
                            });
                          },
                        ),
                        if (_registerImmunization) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _immunizationType,
                            dropdownColor: AppTheme.surface,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Tipo de Inmunización',
                              labelStyle: const TextStyle(color: AppTheme.textMuted),
                              prefixIcon:
                                  const Icon(Icons.medication_outlined, color: AppTheme.mintGreen),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppTheme.mintGreen),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Vacuna de Rabia', child: Text('Vacuna de Rabia')),
                              DropdownMenuItem(
                                  value: 'Vacuna Múltiple', child: Text('Vacuna Múltiple')),
                              DropdownMenuItem(
                                  value: 'Triple Felina', child: Text('Triple Felina')),
                              DropdownMenuItem(
                                  value: 'Desparasitante Interno',
                                  child: Text('Desparasitante Interno')),
                              DropdownMenuItem(
                                  value: 'Desparasitante Externo',
                                  child: Text('Desparasitante Externo')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _immunizationType = val;
                                  _updateDefaultDoseDate(val);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _nextDoseDate ??
                                    DateTime.now().add(const Duration(days: 180)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: AppTheme.mintGreen,
                                        onPrimary: Colors.white,
                                        surface: AppTheme.surface,
                                        onSurface: AppTheme.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _nextDoseDate = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Fecha Sugerida de Reaplicación',
                                labelStyle: const TextStyle(color: AppTheme.textMuted),
                                prefixIcon: const Icon(Icons.calendar_month_outlined,
                                    color: AppTheme.mintGreen),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.border),
                                ),
                              ),
                              child: Text(
                                _nextDoseDate == null
                                    ? 'Seleccionar fecha...'
                                    : '${_nextDoseDate!.day}/${_nextDoseDate!.month}/${_nextDoseDate!.year} '
                                        '(${_immunizationType.contains('Desparasitante') ? 'Sugerido: 6 meses' : 'Sugerido: 1 año'})',
                                style: const TextStyle(color: AppTheme.textPrimary),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.skyBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: AppTheme.skyBlue.withValues(alpha: 0.3),
                    ),
                    child: const Text(
                      'GUARDAR EN EXPEDIENTE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black38,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.skyBlue),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Guardando expediente clínico...',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
