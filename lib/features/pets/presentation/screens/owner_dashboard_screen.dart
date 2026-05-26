import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../qr_sharing/data/repositories/qr_repository.dart';
import '../../../qr_sharing/domain/entities/active_vet_lease.dart';
import '../../domain/entities/pet_entity.dart';
import '../../data/repositories/pet_repository.dart';
import '../../../medical_history/data/repositories/medical_repository.dart';

// Proveedor de notificaciones no leídas del dueño
final ownerUnreadNotificationsProvider =
    StreamProvider.family<int, String>((ref, ownerId) {
  return FirebaseFirestore.instance
      .demoCollection('users')
      .doc(ownerId)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  final Set<String> _revokingLeaseIds = {};

  String _formatAge(int months) {
    if (months <= 0) return 'Recién nacido';
    if (months < 12) {
      return '$months ${months == 1 ? 'mes' : 'meses'}';
    } else {
      final years = months ~/ 12;
      final remainingMonths = months % 12;
      if (remainingMonths == 0) {
        return '$years ${years == 1 ? 'año' : 'años'}';
      } else {
        return '$years ${years == 1 ? 'año' : 'años'} y $remainingMonths ${remainingMonths == 1 ? 'mes' : 'meses'}';
      }
    }
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref, String ownerId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _NotificationsSheet(ownerId: ownerId),
    );
  }

  void _showEditPetDialog(BuildContext context, PetEntity pet) {
    final nameController = TextEditingController(text: pet.name);
    final breedController = TextEditingController(text: pet.breed);
    final ageController = TextEditingController(text: pet.age.toString());
    final allergiesController = TextEditingController(text: pet.allergies.join(', '));
    final conditionsController = TextEditingController(text: pet.chronicConditions.join(', '));

    XFile? dialogImageFile;
    Uint8List? dialogImageBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickDialogImage() async {
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
                setDialogState(() {
                  dialogImageFile = image;
                  dialogImageBytes = bytes;
                });
              }
            } catch (e) {
              debugPrint('Error al seleccionar imagen: $e');
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.edit_outlined, color: AppTheme.mintGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editar: ${pet.name}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: pickDialogImage,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.mintGreen.withValues(alpha: 0.8),
                                  width: 2.5),
                              image: dialogImageBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(dialogImageBytes!),
                                      fit: BoxFit.cover)
                                  : DecorationImage(
                                      image: NetworkImage(pet.photoUrl),
                                      fit: BoxFit.cover),
                              color: AppTheme.surfaceVariant,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: pickDialogImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.mintGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _dialogField(nameController, 'Nombre'),
                  const SizedBox(height: 16),
                  _dialogField(breedController, 'Raza'),
                  const SizedBox(height: 16),
                  _dialogField(ageController, 'Edad (meses)', isNumber: true),
                  const SizedBox(height: 16),
                  _dialogField(allergiesController, 'Alergias (separadas por coma)'),
                  const SizedBox(height: 16),
                  _dialogField(conditionsController, 'Condiciones Crónicas (separadas por coma)'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    String photoUrl = pet.photoUrl;
                    if (dialogImageBytes != null && dialogImageFile != null) {
                      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${dialogImageFile!.name}';
                      final repository = ref.read(petRepositoryProvider);
                      photoUrl = await repository.uploadPetPhoto(pet.ownerId, fileName, dialogImageBytes!);
                    }

                    final updated = pet.copyWith(
                      name: nameController.text.trim(),
                      breed: breedController.text.trim(),
                      age: int.tryParse(ageController.text.trim()) ?? pet.age,
                      photoUrl: photoUrl,
                      allergies: allergiesController.text.trim().isNotEmpty
                          ? allergiesController.text
                              .split(',')
                              .map((e) => e.trim())
                              .toList()
                          : [],
                      chronicConditions: conditionsController.text.trim().isNotEmpty
                          ? conditionsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .toList()
                          : [],
                    );

                    await ref.read(petRepositoryProvider).updatePet(updated);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('¡${updated.name} actualizada con éxito! 🐾'),
                          backgroundColor: AppTheme.mintGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar: $e'),
                          backgroundColor: AppTheme.coralRed,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('GUARDAR',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  TextField _dialogField(TextEditingController ctrl, String label,
      {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.mintGreen)),
      ),
    );
  }

  Future<void> _revokeAccess(
    ActiveVetLease lease,
    String petDisplayName,
    String vetDisplayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Revocar acceso',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Deseas revocar el acceso del Dr. $vetDisplayName al expediente de $petDisplayName?\n\nEl veterinario ya no podrá consultar su historial clínico.',
          style: const TextStyle(color: AppTheme.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralRed),
            child: const Text('REVOCAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _revokingLeaseIds.add(lease.id));

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('revokeVetAccess');
      await callable.call(<String, dynamic>{
        'petId': lease.petId,
        'vetId': lease.vetId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acceso de $vetDisplayName revocado exitosamente.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al revocar: ${e.message}'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _revokingLeaseIds.remove(lease.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    final petsAsync = user != null
        ? ref.watch(ownerPetsStreamProvider(user.uid))
        : const AsyncValue<List<PetEntity>>.data([]);

    final leasesAsync = user != null
        ? ref.watch(activeVetLeasesProvider(user.uid))
        : const AsyncValue<List<ActiveVetLease>>.data([]);

    final unreadCount = user != null
        ? ref.watch(ownerUnreadNotificationsProvider(user.uid)).valueOrNull ?? 0
        : 0;

    final pets = petsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.mintGreen,
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    tooltip: 'Notificaciones',
                    onPressed: () => _showNotificationsSheet(context, ref, user?.uid ?? ''),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppTheme.coralRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
                tooltip: 'Mis Pagos',
                onPressed: () => context.push('/owner-payments'),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  if (value == 'profile') {
                    context.push('/edit-profile');
                  } else if (value == 'logout') {
                    ref.read(authNotifierProvider.notifier).logout();
                    context.go('/login');
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: const [
                        Icon(Icons.person_outline, color: AppTheme.mintGreen, size: 20),
                        SizedBox(width: 12),
                        Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: const [
                        Icon(Icons.logout, color: AppTheme.coralRed, size: 20),
                        SizedBox(width: 12),
                        Text('Cerrar Sesión', style: TextStyle(color: AppTheme.coralRed, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Mis Mascotas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.mintGreen, Color(0xFF095A60)], // Gradiente más profundo
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15), // Glassmorphism ligero
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Text(
                              '¡Hola, ${user?.displayName.split(' ').first ?? 'Dueño'}! 👋',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Controla y comparte el historial clínico',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Buscar Veterinario ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: GestureDetector(
                onTap: () => context.push('/vet-directory'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C828A), Color(0xFF1A9BAF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0C828A).withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buscar Veterinario',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Encuentra vets verificados cerca de ti',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Mis Reservas de Guardería ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: GestureDetector(
                onTap: () => context.push('/owner-reservations'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mintGreen.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.mintGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_work_outlined,
                            color: AppTheme.mintGreen, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mis Reservas de Guardería',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ver estado de estancias y reagendar',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Accesos Veterinarios Activos ────────────────────────────────
          leasesAsync.when(
            data: (leases) {
              if (leases.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.coralRed.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.medical_services_outlined,
                                color: AppTheme.coralRed, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Accesos Veterinarios Activos',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.coralRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${leases.length}',
                              style: const TextStyle(
                                color: AppTheme.coralRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...leases.map((lease) => _ActiveLeaseCard(
                            lease: lease,
                            pets: pets,
                            isRevoking: _revokingLeaseIds.contains(lease.id),
                            onRevoke: _revokeAccess,
                          )),
                      const SizedBox(height: 8),
                      const Divider(color: AppTheme.border),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Recordatorios de Vacunación ────────────────────────────────
          if (pets.isNotEmpty)
            SliverToBoxAdapter(
              child: _VaccinationRemindersSection(pets: pets),
            ),

          // ── Lista de Mascotas ───────────────────────────────────────────
          petsAsync.when(
            data: (pets) {
              if (pets.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
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
                            border: Border.all(
                                color: AppTheme.mintGreen.withValues(alpha: 0.3), width: 2),
                          ),
                          child: const Icon(Icons.pets_outlined,
                              size: 64, color: AppTheme.mintGreen),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Aún no tienes mascotas',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Registra a tu primer compañero de cuatro patas para tener su historial clínico y accesos QR al alcance de tu mano.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-pet'),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'REGISTRAR PRIMERA MASCOTA',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.mintGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pet = pets[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mintGreen.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Image.network(
                                    pet.photoUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, o, s) => Container(
                                      height: 180,
                                      color: AppTheme.surfaceVariant,
                                      child: const Icon(Icons.pets,
                                          size: 64, color: AppTheme.mintGreen),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            pet.species == 'Perro'
                                                ? Icons.pets
                                                : Icons.pets_outlined,
                                            size: 14,
                                            color: AppTheme.mintGreen,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            pet.species,
                                            style: const TextStyle(
                                              color: AppTheme.mintGreen,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: GestureDetector(
                                      onTap: () => _showEditPetDialog(context, pet),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.92),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.edit_outlined,
                                            size: 16, color: AppTheme.skyBlue),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          pet.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                        ),
                                        Text(
                                          _formatAge(pet.age),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.mintGreen,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      pet.breed,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppTheme.textMuted),
                                    ),
                                    if (pet.allergies.isNotEmpty || pet.chronicConditions.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.coralRed.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.coralRed.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, color: AppTheme.coralRed, size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Alerta Médica Activa',
                                                style: const TextStyle(
                                                    color: AppTheme.coralRed,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => context
                                                .push('/pet/${pet.id}/history'),
                                            icon: const Icon(Icons.history_edu,
                                                color: AppTheme.mintGreen),
                                            label: const Text('HISTORIAL'),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                  color: AppTheme.mintGreen),
                                              foregroundColor: AppTheme.mintGreen,
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => context
                                                .push('/pet/${pet.id}/share'),
                                            icon: const Icon(Icons.qr_code,
                                                color: Colors.white),
                                            label: const Text('COMPARTIR'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.skyBlue,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: pets.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.mintGreen),
              ),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error al cargar mascotas: $err',
                    style: const TextStyle(color: AppTheme.coralRed),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-pet'),
        backgroundColor: AppTheme.mintGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Recordatorios de vacunación ────────────────────────────────────────────
class _VaccinationRemindersSection extends ConsumerWidget {
  final List<PetEntity> pets;
  const _VaccinationRemindersSection({required this.pets});

  Color _statusColor(int daysLeft) {
    if (daysLeft < 0) return const Color(0xFFE57373);
    if (daysLeft <= 30) return const Color(0xFFD4A017);
    return AppTheme.mintGreen;
  }

  String _statusLabel(int daysLeft) {
    if (daysLeft < 0) return 'VENCIDO';
    if (daysLeft == 0) return 'HOY';
    return 'EN $daysLeft DÍAS';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderItems = <_ReminderData>[];

    for (final pet in pets) {
      final vaccines = ref.watch(vaccinationCardStreamProvider(pet.id)).valueOrNull ?? [];
      for (final entry in vaccines) {
        final nextRaw = entry['nextApplicationAt'];
        if (nextRaw == null) continue;
        final DateTime nextDate = (nextRaw as dynamic).toDate();
        final int daysLeft = nextDate.difference(DateTime.now()).inDays;
        if (daysLeft <= 30) {
          reminderItems.add(_ReminderData(
            pet: pet,
            vaccineName: entry['name'] as String? ?? 'Inmunización',
            nextDate: nextDate,
            daysLeft: daysLeft,
          ));
        }
      }
    }

    if (reminderItems.isEmpty) return const SizedBox.shrink();

    // Sort: overdue first, then soonest
    reminderItems.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.goldChampagne.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.vaccines_outlined,
                    color: AppTheme.goldChampagne, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recordatorios de Vacunación',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.goldChampagne.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${reminderItems.length}',
                  style: const TextStyle(
                    color: AppTheme.goldChampagne,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...reminderItems.map((item) {
            final color = _statusColor(item.daysLeft);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.vaccines, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.vaccineName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.pet.name,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(item.daysLeft),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/pet/${item.pet.id}/history');
                        },
                        child: const Text(
                          'VER CARTILLA →',
                          style: TextStyle(
                            color: AppTheme.mintGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.border),
        ],
      ),
    );
  }
}

class _ReminderData {
  final PetEntity pet;
  final String vaccineName;
  final DateTime nextDate;
  final int daysLeft;
  const _ReminderData({
    required this.pet,
    required this.vaccineName,
    required this.nextDate,
    required this.daysLeft,
  });
}

// ── Panel de notificaciones ────────────────────────────────────────────────
class _NotificationsSheet extends ConsumerWidget {
  final String ownerId;
  const _NotificationsSheet({required this.ownerId});

  Future<void> _markAllRead(String ownerId) async {
    final snap = await FirebaseFirestore.instance
        .demoCollection('users')
        .doc(ownerId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifStream = FirebaseFirestore.instance
        .demoCollection('users')
        .doc(ownerId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: notifStream,
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        final unread = docs.where((d) => d['read'] == false).length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppTheme.mintGreen, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Notificaciones',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (unread > 0)
                    TextButton(
                      onPressed: () => _markAllRead(ownerId),
                      child: const Text('Marcar leídas',
                          style: TextStyle(
                              color: AppTheme.mintGreen, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(color: AppTheme.border, height: 1),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none_outlined,
                          color: AppTheme.textMuted, size: 40),
                      SizedBox(height: 8),
                      Text('Sin notificaciones',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppTheme.border, height: 1),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isRead = data['read'] == true;
                    final message = data['message'] as String? ?? '';
                    final Timestamp? ts = data['createdAt'] as Timestamp?;
                    final date = ts != null
                        ? _formatTs(ts.toDate())
                        : '';
                    final notifType = data['type'] as String? ?? 'qr_scanned';
                    final IconData notifIcon;
                    final Color notifColor;
                    switch (notifType) {
                      case 'vaccination_reminder':
                        notifIcon = Icons.vaccines;
                        notifColor = AppTheme.coralRed;
                      default:
                        notifIcon = Icons.qr_code_scanner;
                        notifColor = AppTheme.mintGreen;
                    }

                    return InkWell(
                      onTap: isRead
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              docs[i].reference.update({'read': true});
                            },
                      child: Container(
                        color: isRead
                            ? Colors.transparent
                            : notifColor.withValues(alpha: 0.05),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: notifColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(notifIcon,
                                  color: notifColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  if (date.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(date,
                                        style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 10)),
                                  ],
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.mintGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  String _formatTs(DateTime dt) {
    const months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $h:$m';
  }
}

// ── Tarjeta de acceso veterinario activo ───────────────────────────────────
class _ActiveLeaseCard extends ConsumerWidget {
  final ActiveVetLease lease;
  final List<PetEntity> pets;
  final bool isRevoking;
  final Future<void> Function(ActiveVetLease, String, String) onRevoke;

  const _ActiveLeaseCard({
    required this.lease,
    required this.pets,
    required this.isRevoking,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve pet name: from the loaded pets list or the stored field in the doc
    final pet = pets.where((p) => p.id == lease.petId).firstOrNull;
    final petDisplayName = pet?.name ?? lease.petName ?? lease.petId;

    // Resolve vet name: from stored field or async lookup
    final vetNameAsync = lease.vetName != null
        ? AsyncValue.data(lease.vetName!)
        : ref.watch(vetDisplayNameProvider(lease.vetId));
    final vetDisplayName = vetNameAsync.valueOrNull ?? 'Cargando...';

    final isHospitalization = lease.isHospitalization;
    final leaseColor = isHospitalization ? AppTheme.coralRed : AppTheme.skyBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: leaseColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: leaseColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isHospitalization ? Icons.local_hospital_outlined : Icons.schedule_outlined,
              color: leaseColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petDisplayName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dr. $vetDisplayName',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: leaseColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isHospitalization ? 'Hospitalización' : 'Consulta (2h)',
                    style: TextStyle(
                      color: leaseColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isRevoking
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.coralRed,
                  ),
                )
              : TextButton(
                  onPressed: () => onRevoke(lease, petDisplayName, vetDisplayName),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.coralRed,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: AppTheme.coralRed.withValues(alpha: 0.4)),
                    ),
                  ),
                  child: const Text(
                    'REVOCAR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }
}
