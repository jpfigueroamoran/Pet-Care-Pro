import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

String _generateUniqueId() {
  final random = Random();
  return '${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(10000)}';
}

class VetServicesScreen extends ConsumerStatefulWidget {
  const VetServicesScreen({super.key});

  @override
  ConsumerState<VetServicesScreen> createState() => _VetServicesScreenState();
}

class _VetServicesScreenState extends ConsumerState<VetServicesScreen> {
  bool _isLoading = false;

  final List<VetService> _suggestedServices = const [
    VetService(id: 'sugg_1', name: 'Consulta General', price: 450.0, durationMinutes: 30),
    VetService(id: 'sugg_2', name: 'Vacunación Completa', price: 350.0, durationMinutes: 15),
    VetService(id: 'sugg_3', name: 'Desparasitación', price: 250.0, durationMinutes: 15),
    VetService(id: 'sugg_4', name: 'Baño y Estética', price: 300.0, durationMinutes: 45),
    VetService(id: 'sugg_5', name: 'Hospedaje Clínico (Día)', price: 600.0, durationMinutes: 1440),
  ];

  Future<void> _addSuggested() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final currentServices = List<VetService>.from(user.services);
        for (final sugg in _suggestedServices) {
          if (!currentServices.any((s) => s.name.toLowerCase() == sugg.name.toLowerCase())) {
            currentServices.add(
              VetService(
                id: _generateUniqueId(),
                name: sugg.name,
                price: sugg.price,
                durationMinutes: sugg.durationMinutes,
              ),
            );
          }
        }
        await ref.read(authNotifierProvider.notifier).updateVetServices(currentServices);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servicios sugeridos agregados exitosamente 🏷️'),
              backgroundColor: AppTheme.mintGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar sugeridos: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showServiceForm({VetService? serviceToEdit}) {
    final nameController = TextEditingController(text: serviceToEdit?.name);
    final priceController = TextEditingController(text: serviceToEdit?.price.toString());
    final durationController = TextEditingController(text: serviceToEdit?.durationMinutes.toString());
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        serviceToEdit == null ? 'Nuevo Servicio' : 'Editar Servicio',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nombre del Servicio',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.skyBlue),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.skyBlue),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre del servicio' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Precio (\$ MXN)',
                            prefixIcon: const Icon(Icons.attach_money, color: AppTheme.skyBlue),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.skyBlue),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa tarifa';
                            final val = double.tryParse(v.trim());
                            if (val == null || val < 0) return 'Precio inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Duración (min)',
                            prefixIcon: const Icon(Icons.timer_outlined, color: AppTheme.skyBlue),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppTheme.skyBlue),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa duración';
                            final val = int.tryParse(v.trim());
                            if (val == null || val <= 0) return 'Duración inválida';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      try {
                        final user = ref.read(currentUserProvider);
                        if (user != null) {
                          final currentServices = List<VetService>.from(user.services);
                          final newService = VetService(
                            id: serviceToEdit?.id ?? _generateUniqueId(),
                            name: nameController.text.trim(),
                            price: double.parse(priceController.text.trim()),
                            durationMinutes: int.parse(durationController.text.trim()),
                          );

                          if (serviceToEdit == null) {
                            currentServices.add(newService);
                          } else {
                            final idx = currentServices.indexWhere((s) => s.id == serviceToEdit.id);
                            if (idx != -1) currentServices[idx] = newService;
                          }

                          await ref.read(authNotifierProvider.notifier).updateVetServices(currentServices);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al guardar servicio: $e'),
                              backgroundColor: AppTheme.coralRed,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.skyBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(serviceToEdit == null ? 'AGREGAR CATÁLOGO' : 'GUARDAR CAMBIOS'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteService(String serviceId) async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final currentServices = List<VetService>.from(user.services);
        currentServices.removeWhere((s) => s.id == serviceId);
        await ref.read(authNotifierProvider.notifier).updateVetServices(currentServices);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servicio eliminado exitosamente 🗑️'),
              backgroundColor: AppTheme.mintGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar servicio: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showClabeDialog(String? currentClabe) {
    final clabeController = TextEditingController(text: currentClabe ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Configurar CLABE Interbancaria',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Los dueños usarán esta CLABE para transferirte el pago por SPEI sin comisiones.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: clabeController,
                  keyboardType: TextInputType.number,
                  maxLength: 18,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, letterSpacing: 2),
                  decoration: InputDecoration(
                    labelText: 'CLABE (18 dígitos)',
                    prefixIcon: const Icon(Icons.account_balance, color: AppTheme.mintGreen),
                    counterStyle: const TextStyle(color: AppTheme.textMuted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.mintGreen, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.coralRed),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.coralRed, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa tu CLABE interbancaria';
                    if (v.trim().length != 18) return 'La CLABE debe tener exactamente 18 dígitos';
                    if (!RegExp(r'^\d{18}$').hasMatch(v.trim())) return 'La CLABE solo debe contener dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      await ref.read(authNotifierProvider.notifier).updateVetClabe(clabeController.text.trim());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('CLABE actualizada correctamente'),
                            backgroundColor: AppTheme.mintGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.coralRed),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('GUARDAR CLABE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
           ),
          ),
        );
      },
    );
  }

  Widget _buildClabeCard(BuildContext context, userEntity) {
    final clabe = userEntity?.clabe as String?;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: clabe != null
              ? AppTheme.mintGreen.withValues(alpha: 0.4)
              : AppTheme.goldChampagne.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (clabe != null ? AppTheme.mintGreen : AppTheme.goldChampagne).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              clabe != null ? Icons.account_balance : Icons.account_balance_outlined,
              color: clabe != null ? AppTheme.mintGreen : AppTheme.goldChampagne,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CLABE para cobros SPEI',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(
                  clabe != null && clabe.length == 18
                      ? '${clabe.substring(0, 6)}••••••••${clabe.substring(14)}'
                      : clabe != null
                          ? clabe
                          : 'Sin configurar — los dueños no pueden pagarte',
                  style: TextStyle(
                    color: clabe != null ? AppTheme.textPrimary : AppTheme.goldChampagne,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showClabeDialog(clabe),
            child: Text(
              clabe != null ? 'EDITAR' : 'AGREGAR',
              style: const TextStyle(color: AppTheme.skyBlue, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final services = user?.services ?? [];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mi Catálogo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildClabeCard(context, user),
              const SizedBox(height: 12),
              Expanded(child: services.isEmpty
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.surfaceVariant,
                            border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2), width: 2),
                          ),
                          child: const Icon(Icons.loyalty_outlined, size: 64, color: AppTheme.skyBlue),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Catálogo Vacío',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aún no has definido tus servicios y tarifas clínicas. Puedes pre-cargar nuestros servicios recomendados con un solo clic o añadir servicios personalizados.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: _addSuggested,
                          icon: const Icon(Icons.auto_awesome, color: Colors.white),
                          label: const Text('PRECARGAR SERVICIOS SUGERIDOS', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.skyBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showServiceForm(),
                          icon: const Icon(Icons.add, color: AppTheme.skyBlue),
                          label: const Text('CREAR SERVICIO PERSONALIZADO', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.skyBlue,
                            side: const BorderSide(color: AppTheme.skyBlue),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final svc = services[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.skyBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.healing_outlined, color: AppTheme.skyBlue),
                        ),
                        title: Text(
                          svc.name,
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  '${svc.durationMinutes} min',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.attach_money, size: 14, color: AppTheme.goldChampagne),
                                Text(
                                  '${svc.price.toStringAsFixed(2)} MXN',
                                  style: const TextStyle(color: AppTheme.goldChampagne, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppTheme.textMuted),
                              onPressed: () => _showServiceForm(serviceToEdit: svc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.coralRed),
                              onPressed: () => _deleteService(svc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.skyBlue),
              ),
            ),
        ],
      ),
      floatingActionButton: services.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showServiceForm(),
              backgroundColor: AppTheme.skyBlue,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('NUEVO SERVICIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
