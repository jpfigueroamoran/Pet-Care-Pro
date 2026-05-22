import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../medical_history/data/repositories/medical_repository.dart';
import '../../domain/entities/pet_entity.dart';
import '../../data/repositories/pet_repository.dart';

class AddPetScreen extends ConsumerStatefulWidget {
  const AddPetScreen({super.key});

  @override
  ConsumerState<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends ConsumerState<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  String _selectedSpecies = 'Perro';
  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _pendingVaccines = [];

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  void _showAddVaccineDialog() {
    String vaccineName = 'Vacuna de Rabia';
    DateTime appliedAt = DateTime.now().subtract(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.vaccines_outlined, color: AppTheme.mintGreen, size: 20),
                SizedBox(width: 8),
                Text('Agregar Vacuna Previa',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: vaccineName,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Vacuna / Desparasitante',
                    labelStyle: const TextStyle(color: AppTheme.textMuted),
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
                    if (val != null) setDialogState(() => vaccineName = val);
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
                    if (picked != null) setDialogState(() => appliedAt = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de Aplicación',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.mintGreen, size: 18),
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () {
                  final isDewormer = vaccineName.contains('Desparasitante');
                  final nextDose = isDewormer
                      ? DateTime(appliedAt.year, appliedAt.month + 6, appliedAt.day)
                      : DateTime(appliedAt.year + 1, appliedAt.month, appliedAt.day);
                  setState(() {
                    _pendingVaccines.add({
                      'type': isDewormer ? 'dewormer' : 'vaccine',
                      'name': vaccineName,
                      'appliedAt': Timestamp.fromDate(appliedAt),
                      'nextApplicationAt': Timestamp.fromDate(nextDose),
                      'appliedByVetName': null,
                      'appliedByVetId': null,
                      'notes': '',
                    });
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('AGREGAR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageFile = image;
          _imageBytes = bytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al seleccionar la imagen: $e';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() {
        _errorMessage = 'No se encontró una sesión de usuario activa.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String photoUrl = '';
      if (_imageBytes != null && _imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.name}';
        final repository = ref.read(petRepositoryProvider);
        photoUrl = await repository.uploadPetPhoto(user.uid, fileName, _imageBytes!);
      } else {
        if (_selectedSpecies == 'Perro') {
          photoUrl = 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&q=80&w=300';
        } else if (_selectedSpecies == 'Gato') {
          photoUrl = 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&q=80&w=300';
        } else {
          photoUrl = 'https://images.unsplash.com/photo-1472491235688-bdc81a63246e?auto=format&fit=crop&q=80&w=300';
        }
      }

      final newPet = PetEntity(
        id: '',
        name: _nameController.text.trim(),
        species: _selectedSpecies,
        breed: _breedController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        photoUrl: photoUrl,
        ownerId: user.uid,
        createdAt: DateTime.now(),
        allergies: _allergiesController.text.trim().isNotEmpty
            ? _allergiesController.text.split(',').map((e) => e.trim()).toList()
            : [],
        chronicConditions: _conditionsController.text.trim().isNotEmpty
            ? _conditionsController.text.split(',').map((e) => e.trim()).toList()
            : [],
      );

      final petId = await ref.read(petRepositoryProvider).addPet(newPet);

      if (_pendingVaccines.isNotEmpty) {
        final medRepo = ref.read(medicalRepositoryProvider);
        for (final vaccine in _pendingVaccines) {
          await medRepo.addVaccinationRecord(petId, {
            ...vaccine,
            'verifiedByVet': false,
            'enteredByOwnerUid': user.uid,
          });
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡${newPet.name} ha sido registrado exitosamente! 🐾'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al registrar mascota: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Registrar Mascota', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : _pickImage,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.8), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.mintGreen.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                              image: _imageBytes != null
                                  ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                                  : null,
                              color: AppTheme.surfaceVariant,
                            ),
                            child: _imageBytes == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.camera_alt, color: AppTheme.mintGreen, size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Añadir Foto',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                        if (_imageBytes != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppTheme.mintGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

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
                    const SizedBox(height: 24),
                  ],

                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la mascota',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.pets, color: AppTheme.mintGreen),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.mintGreen),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.coralRed),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.coralRed),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa el nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                    child: Text('Especie',
                        style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                  ),
                  Row(
                    children: ['Perro', 'Gato', 'Otro'].map((species) {
                      final isSelected = _selectedSpecies == species;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(species),
                            selected: isSelected,
                            selectedColor: AppTheme.mintGreen,
                            backgroundColor: AppTheme.surfaceVariant,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedSpecies = species;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _breedController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Raza',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.category, color: AppTheme.mintGreen),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.mintGreen),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.coralRed),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.coralRed),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa la raza';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Edad (en meses)',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.mintGreen),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.mintGreen),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.coralRed),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.coralRed),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa la edad';
                      }
                      final age = int.tryParse(value.trim());
                      if (age == null || age < 0) {
                        return 'Ingresa un número entero positivo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.coralRed.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.coralRed.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.coralRed, size: 20),
                            SizedBox(width: 8),
                            Text('Alertas Médicas Críticas',
                                style: TextStyle(
                                    color: AppTheme.coralRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _allergiesController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Alergias (separadas por coma)',
                            hintText: 'Ej. Penicilina, Pollo',
                            labelStyle: const TextStyle(color: AppTheme.textMuted),
                            prefixIcon: const Icon(Icons.medication_liquid_outlined, color: AppTheme.coralRed),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.coralRed),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _conditionsController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Condiciones Crónicas',
                            hintText: 'Ej. Diabetes, Epilepsia',
                            labelStyle: const TextStyle(color: AppTheme.textMuted),
                            prefixIcon: const Icon(Icons.favorite_border, color: AppTheme.coralRed),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.coralRed),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vaccines_outlined, color: AppTheme.mintGreen, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cartilla de Vacunación Previa',
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  SizedBox(height: 2),
                                  Text('Registra las vacunas que ya tiene tu mascota (opcional)',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_pendingVaccines.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._pendingVaccines.asMap().entries.map((entry) {
                            final i = entry.key;
                            final v = entry.value;
                            final appliedTs = v['appliedAt'] as Timestamp;
                            final appliedDate = appliedTs.toDate();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppTheme.mintGreen, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${v['name']} — ${appliedDate.day}/${appliedDate.month}/${appliedDate.year}',
                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _pendingVaccines.removeAt(i)),
                                    child: const Icon(Icons.close, color: AppTheme.coralRed, size: 18),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _showAddVaccineDialog,
                          icon: const Icon(Icons.add, size: 18, color: AppTheme.mintGreen),
                          label: const Text('AGREGAR VACUNA PREVIA',
                              style: TextStyle(
                                  color: AppTheme.mintGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: AppTheme.mintGreen.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: AppTheme.mintGreen.withValues(alpha: 0.3),
                    ),
                    child: const Text(
                      'REGISTRAR MASCOTA',
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
                    const CircularProgressIndicator(color: AppTheme.mintGreen),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Subiendo perfil y foto...',
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
