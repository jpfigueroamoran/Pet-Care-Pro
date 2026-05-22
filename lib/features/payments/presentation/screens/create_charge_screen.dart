import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../subscriptions/presentation/providers/subscription_provider.dart';
import '../../../subscriptions/domain/entities/subscription_tier.dart';
import '../../../pets/domain/entities/pet_entity.dart';
import '../../domain/entities/payment_entity.dart';
import '../../data/repositories/payment_repository.dart';

final singlePetFutureProvider = FutureProvider.family<PetEntity?, String>((ref, petId) async {
  final doc = await FirebaseFirestore.instance.demoCollection('pets').doc(petId).get();
  if (doc.exists) {
    return PetEntity.fromMap(doc.data()!, doc.id);
  }
  return null;
});

class CreateChargeScreen extends ConsumerStatefulWidget {
  final String petId;
  const CreateChargeScreen({super.key, required this.petId});

  @override
  ConsumerState<CreateChargeScreen> createState() => _CreateChargeScreenState();
}

class _CreateChargeScreenState extends ConsumerState<CreateChargeScreen> {
  final Set<String> _selectedServiceIds = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final petAsync = ref.watch(singlePetFutureProvider(widget.petId));
    final services = user?.services ?? [];
    final subscriptionTier = ref.watch(subscriptionTierProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Emitir Cobro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: petAsync.when(
        data: (pet) {
          if (pet == null) {
            return Center(
              child: Text(
                'No se encontró información del paciente.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            );
          }

          if (services.isEmpty) {
            return SingleChildScrollView(
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
                    Text(
                      'Catálogo sin Servicios',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Para emitir un cobro, primero debes registrar tus tarifas y catálogo de servicios médicos en tu perfil.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => context.push('/vet-services'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.skyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('DEFINIR MIS SERVICIOS', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          double totalAmount = 0.0;
          final List<VetService> selectedServices = [];
          for (final s in services) {
            if (_selectedServiceIds.contains(s.id)) {
              totalAmount += s.price;
              selectedServices.add(s);
            }
          }

          return Stack(
            children: [
              Column(
                children: [
                  // Info del paciente
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: pet.photoUrl.isNotEmpty ? NetworkImage(pet.photoUrl) : null,
                          backgroundColor: AppTheme.surfaceVariant,
                          child: pet.photoUrl.isEmpty
                              ? const Icon(Icons.pets, color: AppTheme.mintGreen, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pet.name,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pet.species} • ${pet.breed}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.mintGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'PACIENTE',
                            style: TextStyle(color: AppTheme.mintGreen, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Selecciona uno o más servicios aplicados:',
                        style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        final svc = services[index];
                        final isSelected = _selectedServiceIds.contains(svc.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.skyBlue.withValues(alpha: 0.07) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.skyBlue.withValues(alpha: 0.4) : AppTheme.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (val == true) {
                                  _selectedServiceIds.add(svc.id);
                                } else {
                                  _selectedServiceIds.remove(svc.id);
                                }
                              });
                            },
                            activeColor: AppTheme.skyBlue,
                            checkColor: Colors.white,
                            title: Text(
                              svc.name,
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${svc.durationMinutes} min',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ),
                            secondary: Text(
                              '\$${svc.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppTheme.goldChampagne,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Resumen de Cobro
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: const Border(top: BorderSide(color: AppTheme.border)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.mintGreen.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total a cobrar:',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '\$${totalAmount.toStringAsFixed(2)} MXN',
                              style: const TextStyle(
                                color: AppTheme.goldChampagne,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!subscriptionTier.canUseAllPaymentMethods)
                          GestureDetector(
                            onTap: () => context.push('/vet-subscription'),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.goldChampagne.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.goldChampagne.withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline, color: AppTheme.goldChampagne, size: 15),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Plan gratuito: solo efectivo disponible. Actualiza para habilitar SPEI y terminal.',
                                      style: TextStyle(color: AppTheme.goldChampagne, fontSize: 11),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: AppTheme.goldChampagne, size: 15),
                                ],
                              ),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: _selectedServiceIds.isEmpty || _isLoading
                              ? null
                              : () async {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _isLoading = true);
                                  try {
                                    final newPayment = PaymentEntity(
                                      id: '',
                                      petId: pet.id,
                                      petName: pet.name,
                                      ownerId: pet.ownerId,
                                      ownerName: '',
                                      vetId: user!.uid,
                                      vetName: user.displayName,
                                      services: selectedServices,
                                      totalAmount: totalAmount,
                                      status: 'pending',
                                      createdAt: DateTime.now(),
                                      allowedPaymentMethods: subscriptionTier.canUseAllPaymentMethods
                                        ? {
                                            'spei': user.acceptsSpei,
                                            'cash': user.acceptsCash,
                                            'terminal': user.acceptsCardTerminal,
                                          }
                                        : {
                                            'spei': false,
                                            'cash': true,
                                            'terminal': false,
                                          },
                                    );

                                    await ref.read(paymentRepositoryProvider).createPayment(newPayment);

                                    if (mounted) {
                                      context.pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('¡Cargo emitido exitosamente al dueño! 🏷️'),
                                          backgroundColor: AppTheme.mintGreen,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error al emitir cargo: $e'),
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
                            elevation: 2,
                          ),
                          child: const Text(
                            'EMITIR CARGO A DUEÑO',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppTheme.coralRed)),
        ),
      ),
    );
  }
}
