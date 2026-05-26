import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseController = TextEditingController();
  final _branchNameController = TextEditingController();
  UserRole _selectedRole = UserRole.owner;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authNotifierProvider.notifier).register(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
            _selectedRole,
            _selectedRole == UserRole.vet ? _licenseController.text : null,
            branchName: _selectedRole == UserRole.admin ? _branchNameController.text : null,
          );

      final currentAuthState = ref.read(authNotifierProvider);

      if (context.mounted && currentAuthState.errorMessage == null) {
        String successMessage = 'Registro exitoso. ¡Bienvenido a Pet-it Care Pro!';
        if (_selectedRole == UserRole.vet) {
          successMessage = 'Registro exitoso. Tu cuenta de veterinario está pendiente de aprobación por el Administrador.';
        } else if (_selectedRole == UserRole.admin) {
          successMessage = '¡Sucursal registrada con éxito! Bienvenido al panel de administración.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE5F4F4),
              AppTheme.background,
              Color(0xFFF5EDE0),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 80.0, 24.0, 24.0),
            child: Column(
              children: [
                const Icon(
                  Icons.pets_outlined,
                  size: 48,
                  color: AppTheme.mintGreen,
                ),
                const SizedBox(height: 16),
                Text(
                  'Crear Cuenta',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Únete a la red digital de cuidado veterinario',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.mintGreen.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tipo de Usuario:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('DUEÑO', style: TextStyle(fontSize: 10))),
                                selected: _selectedRole == UserRole.owner,
                                selectedColor: AppTheme.mintGreen,
                                backgroundColor: AppTheme.surfaceVariant,
                                labelStyle: TextStyle(
                                  color: _selectedRole == UserRole.owner ? Colors.white : AppTheme.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedRole = UserRole.owner;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('VET', style: TextStyle(fontSize: 10))),
                                selected: _selectedRole == UserRole.vet,
                                selectedColor: AppTheme.skyBlue,
                                backgroundColor: AppTheme.surfaceVariant,
                                labelStyle: TextStyle(
                                  color: _selectedRole == UserRole.vet ? Colors.white : AppTheme.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedRole = UserRole.vet;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('SUCURSAL', style: TextStyle(fontSize: 10))),
                                selected: _selectedRole == UserRole.admin,
                                selectedColor: AppTheme.mintGreen,
                                backgroundColor: AppTheme.surfaceVariant,
                                labelStyle: TextStyle(
                                  color: _selectedRole == UserRole.admin ? Colors.white : AppTheme.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedRole = UserRole.admin;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Aviso para staff invitado
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.skyBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.skyBlue.withOpacity(0.3)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.skyBlue, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Si fuiste invitado como parte del staff (lavador, cuidador, recepcionista), regístrate con el correo al que recibiste la invitación y selecciona "Dueño" — tu rol se asignará automáticamente.',
                                  style: TextStyle(color: AppTheme.skyBlue, fontSize: 11, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (authState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.coralRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.coralRed.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.coralRed, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.coralRed,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre Completo',
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.mintGreen),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo Electrónico',
                            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.mintGreen),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu correo';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Correo inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.mintGreen),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu contraseña';
                            }
                            if (value.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        if (_selectedRole == UserRole.vet) ...[
                          TextFormField(
                            controller: _licenseController,
                            decoration: const InputDecoration(
                              labelText: 'Cédula Profesional (ID)',
                              prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.mintGreen),
                              hintText: 'Ej. CED-12345678',
                            ),
                            validator: (value) {
                              if (_selectedRole == UserRole.vet && (value == null || value.isEmpty)) {
                                return 'La cédula profesional es obligatoria';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (_selectedRole == UserRole.admin) ...[
                          TextFormField(
                            controller: _branchNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la Sucursal / Negocio',
                              prefixIcon: Icon(Icons.storefront_outlined, color: AppTheme.mintGreen),
                              hintText: 'Ej. Petit Resort',
                            ),
                            validator: (value) {
                              if (_selectedRole == UserRole.admin && (value == null || value.isEmpty)) {
                                return 'El nombre de la sucursal es obligatorio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        const SizedBox(height: 12),

                        if (authState.isLoading)
                          const Center(
                            child: CircularProgressIndicator(color: AppTheme.mintGreen),
                          )
                        else
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedRole == UserRole.vet
                                  ? AppTheme.skyBlue
                                  : AppTheme.mintGreen,
                            ),
                            child: const Text('REGISTRARSE'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
