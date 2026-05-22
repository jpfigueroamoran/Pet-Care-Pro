import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../payments/data/repositories/payment_repository.dart';
import '../../../subscriptions/presentation/providers/subscription_provider.dart';
import '../../../subscriptions/domain/entities/subscription_tier.dart';


class ActivePatient {
  final String id;
  final String name;
  final String breed;
  final String ownerName;
  final int leaseMinutesLeft;
  final int? durationMinutes; // null = sin límite

  const ActivePatient({
    required this.id,
    required this.name,
    required this.breed,
    required this.ownerName,
    required this.leaseMinutesLeft,
    this.durationMinutes,
  });

  bool get isUnlimited => durationMinutes == null;
}

// Escuchar los arrendamientos clínicos activos en Firestore en tiempo real
final activePatientsStreamProvider = StreamProvider<List<ActivePatient>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.vet) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .demoCollection('qr_tokens')
      .where('vetId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .asyncMap((snapshot) async {
    final List<ActivePatient> patients = [];
    final now = DateTime.now();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final leaseExpiresAt = data['leaseExpiresAt'] != null
          ? (data['leaseExpiresAt'] as Timestamp).toDate()
          : now;

      if (leaseExpiresAt.isBefore(now)) continue;

      final petId = data['petId'] as String? ?? '';
      if (petId.isEmpty) continue;

      final leaseMinutesLeft = leaseExpiresAt.difference(now).inMinutes;

      // Recuperar metadatos pre-cargados (ideal para velocidad de renderizado y demo)
      String name = data['petName'] as String? ?? '';
      String breed = data['petBreed'] as String? ?? '';
      String ownerName = data['ownerName'] as String? ?? '';

      // Si falta algún campo (flujo real escaneado), consultar Firestore
      if (name.isEmpty || breed.isEmpty || ownerName.isEmpty) {
        try {
          final petDoc = await FirebaseFirestore.instance.demoCollection('pets').doc(petId).get();
          if (petDoc.exists) {
            final petData = petDoc.data()!;
            if (name.isEmpty) name = petData['name'] as String? ?? 'Paciente';
            if (breed.isEmpty) breed = petData['breed'] as String? ?? 'Mascota';

            if (ownerName.isEmpty) {
              final ownerDoc = await FirebaseFirestore.instance
                  .demoCollection('users')
                  .doc(petData['ownerId'] as String?)
                  .get();
              if (ownerDoc.exists) {
                ownerName = ownerDoc.data()?['displayName'] as String? ?? 'Dueño';
              } else {
                ownerName = 'Dueño';
              }
            }
          }
        } catch (e) {
          if (name.isEmpty) name = 'Paciente';
          if (breed.isEmpty) breed = 'Mascota';
          if (ownerName.isEmpty) ownerName = 'Dueño';
        }
      }

      patients.add(ActivePatient(
        id: petId,
        name: name,
        breed: breed,
        ownerName: ownerName,
        leaseMinutesLeft: leaseMinutesLeft,
        durationMinutes: data['durationMinutes'] as int?,
      ));
    }

    return patients;
  });
});

class VetDashboardScreen extends ConsumerWidget {
  const VetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final activePatientsAsync = ref.watch(activePatientsStreamProvider);
    final activePatients = activePatientsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <ActivePatient>[],
    );
    final pendingReviewAsync = ref.watch(vetPendingReviewStreamProvider(user?.uid ?? ''));
    final pendingCount = pendingReviewAsync.maybeWhen(data: (list) => list.length, orElse: () => 0);
    final subscriptionTier = ref.watch(subscriptionTierProvider);
    final trialDays = ref.watch(trialDaysRemainingProvider);

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
              IconButton(
                icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                onPressed: () => context.push('/vet-monthly-report'),
                tooltip: 'Reporte Mensual',
              ),
              IconButton(
                icon: const Icon(Icons.loyalty_outlined, color: Colors.white),
                onPressed: () => context.push('/vet-services'),
                tooltip: 'Catálogo de Servicios',
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
                    onPressed: () => context.push('/vet-payment-review'),
                    tooltip: 'Revisión de Facturas',
                  ),
                  if (pendingCount > 0)
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
                          '$pendingCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  if (value == 'profile') {
                    context.push('/edit-profile');
                  } else if (value == 'payment_settings') {
                    context.push('/vet-payment-settings');
                  } else if (value == 'clinic_location') {
                    context.push('/vet-location');
                  } else if (value == 'subscription') {
                    context.push('/vet-subscription');
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
                    value: 'payment_settings',
                    child: Row(
                      children: const [
                        Icon(Icons.payments_outlined, color: AppTheme.mintGreen, size: 20),
                        SizedBox(width: 12),
                        Text('Configurar Cobros', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clinic_location',
                    child: Row(
                      children: const [
                        Icon(Icons.location_on_outlined, color: AppTheme.mintGreen, size: 20),
                        SizedBox(width: 12),
                        Text('Mi Consultorio', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'subscription',
                    child: Row(
                      children: const [
                        Icon(Icons.workspace_premium, color: AppTheme.goldChampagne, size: 20),
                        SizedBox(width: 12),
                        Text('Mi Suscripción', style: TextStyle(fontWeight: FontWeight.bold)),
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
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Panel Veterinario',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.mintGreen, Color(0xFF095A60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        user?.displayName ?? 'Dr. Alejandro Méndez',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cédula: ${user?.professionalLicense ?? 'CED-8472910'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Banner de suscripción / trial
          if (subscriptionTier == SubscriptionTier.trial && trialDays != null)
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => context.push('/vet-subscription'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C828A), Color(0xFF1A9BAF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Prueba gratuita: $trialDays días restantes',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const Text('Ver planes ›', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
          else if (subscriptionTier == SubscriptionTier.free)
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => context.push('/vet-subscription'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.goldChampagne.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: AppTheme.goldChampagne, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Actualiza tu plan para desbloquear funciones Pro',
                          style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      const Text('Ver planes ›', style: TextStyle(color: AppTheme.goldChampagne, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // Sección de Acción Escaneo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.mintGreen, AppTheme.skyBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.mintGreen.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Escanear Pase QR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Solicita acceso temporal al expediente clínico',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.push('/scan-qr');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.mintGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Center(
                        child: Text(
                          'INICIAR ESCÁNER',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Título de Pacientes Activos
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                'Accesos Temporales Activos (${activePatients.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ),
          ),

          // Lista de pacientes
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final patient = activePatients[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.mintGreen.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    patient.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      patient.breed,
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Dueño: ${patient.ownerName}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (patient.isUnlimited)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.coralRed.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.coralRed.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_open_outlined,
                                        size: 11, color: AppTheme.coralRed),
                                    SizedBox(width: 4),
                                    Text(
                                      'Sin límite',
                                      style: TextStyle(
                                        color: AppTheme.coralRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined,
                                      size: 14, color: AppTheme.goldChampagne),
                                  const SizedBox(width: 4),
                                  Text(
                                    patient.leaseMinutesLeft >= 60
                                        ? '${patient.leaseMinutesLeft ~/ 60}h ${patient.leaseMinutesLeft % 60}min'
                                        : '${patient.leaseMinutesLeft} min',
                                    style: const TextStyle(
                                      color: AppTheme.goldChampagne,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    context.push('/pet/${patient.id}/history');
                                  },
                                  child: const Text(
                                    'Expediente',
                                    style: TextStyle(
                                      color: AppTheme.mintGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    context.push('/pet/${patient.id}/charge');
                                  },
                                  child: const Text(
                                    'Cobrar',
                                    style: TextStyle(
                                      color: AppTheme.goldChampagne,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                childCount: activePatients.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
