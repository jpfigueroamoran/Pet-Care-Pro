import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../providers/auth_provider.dart';
import '../../../payments/data/repositories/payment_repository.dart';
import '../../../pets/data/repositories/pet_repository.dart';
import '../../../pets/domain/entities/pet_entity.dart';
import '../../../setup_wizard/presentation/providers/setup_wizard_provider.dart';
import '../../domain/entities/user_entity.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  String _formatDateTime(DateTime dt) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final minutes = dt.minute.toString().padLeft(2, '0');
    final hours = dt.hour.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year} - $hours:$minutes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final String? branchId = currentUser?.branchId;
    final bool isLocalAdmin = branchId != null && branchId.isNotEmpty;

    if (isLocalAdmin) {
      return _buildLocalBranchAdminDashboard(context, ref, currentUser!, branchId);
    }

    final paidPaymentsAsync = ref.watch(adminPaidPaymentsStreamProvider);
    final allPetsAsync = ref.watch(adminAllPetsStreamProvider);
    final pendingVetsAsync = ref.watch(pendingVetsStreamProvider);
    final approvedVetsCount = ref.watch(approvedVetsCountProvider).valueOrNull ?? 0;
    final totalPetsCount = allPetsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: paidPaymentsAsync.when(
        data: (paidPayments) {
          double totalVolume = 0.0;
          for (final p in paidPayments) {
            totalVolume += p.totalAmount;
          }
          final double platformEarnings = totalVolume * 0.05;

          final pendingVetCount = pendingVetsAsync.maybeWhen(
            data: (list) => list.length,
            orElse: () => 0,
          );

          return CustomScrollView(
            slivers: [
              // ── AppBar ─────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                actions: [
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
                    'Consola de Administración',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.mintGreen, Color(0xFF095A60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Text(
                                'Bienvenido, Admin',
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Portal de control y auditoría',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Métricas financieras ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.3,
                    children: [
                      _buildMetricCard(
                        context,
                        'Volumen Procesado',
                        '\$${totalVolume.toStringAsFixed(0)}',
                        Icons.account_balance_outlined,
                        AppTheme.mintGreen,
                      ),
                      _buildMetricCard(
                        context,
                        'Ganancia Plataforma (5%)',
                        '\$${platformEarnings.toStringAsFixed(2)}',
                        Icons.monetization_on_outlined,
                        AppTheme.goldChampagne,
                      ),
                      _buildMetricCard(
                        context,
                        'Transacciones Pagadas',
                        '${paidPayments.length}',
                        Icons.receipt_long_outlined,
                        AppTheme.skyBlue,
                      ),
                      _buildMetricCard(
                        context,
                        'Vets en Espera',
                        '$pendingVetCount',
                        Icons.pending_actions_outlined,
                        pendingVetCount > 0 ? AppTheme.goldChampagne : AppTheme.mintGreen,
                      ),
                      _buildMetricCard(
                        context,
                        'Mascotas Registradas',
                        '$totalPetsCount',
                        Icons.pets_outlined,
                        AppTheme.skyBlue,
                      ),
                      _buildMetricCard(
                        context,
                        'Veterinarios Aprobados',
                        '$approvedVetsCount',
                        Icons.verified_user_outlined,
                        AppTheme.mintGreen,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Auditoría de Transacciones ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.bar_chart_outlined, color: AppTheme.skyBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Auditoría de Transacciones Globales',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),

              if (paidPayments.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                    child: Center(
                      child: Text(
                        'Aún no se registran transacciones pagadas en la plataforma.',
                        style: TextStyle(color: AppTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = paidPayments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.mintGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.payments_outlined, color: AppTheme.mintGreen),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mascota: ${tx.petName}',
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dr. ${tx.vetName}',
                                      style: const TextStyle(
                                          color: AppTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${tx.totalAmount.toStringAsFixed(0)} MXN',
                                    style: const TextStyle(
                                      color: AppTheme.goldChampagne,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(tx.createdAt),
                                    style: const TextStyle(
                                        color: AppTheme.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: paidPayments.length,
                    ),
                  ),
                ),

              // ── Gestión de Mascotas ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.pets_outlined, color: AppTheme.mintGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Gestión de Mascotas del Ecosistema',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),

              allPetsAsync.when(
                data: (petsList) {
                  if (petsList.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                        child: Center(
                          child: Text(
                            'Aún no hay mascotas registradas en la base de datos.',
                            style: TextStyle(color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pet = petsList[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => context.push('/pet/${pet.id}/history'),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppTheme.skyBlue.withValues(alpha: 0.15),
                                      backgroundImage: pet.photoUrl.isNotEmpty
                                          ? NetworkImage(pet.photoUrl)
                                          : null,
                                      child: pet.photoUrl.isEmpty
                                          ? const Icon(Icons.pets, color: AppTheme.skyBlue, size: 24)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pet.name,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${pet.species} • ${pet.breed}',
                                            style: const TextStyle(
                                                color: AppTheme.textMuted, fontSize: 12),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Edad: ${pet.age} meses',
                                            style: const TextStyle(
                                              color: AppTheme.goldChampagne,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.history_edu_outlined, color: AppTheme.mintGreen),
                                      tooltip: 'Expediente Clínico',
                                      onPressed: () => context.push('/pet/${pet.id}/history'),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton.icon(
                                      onPressed: () => _showEditPetDialog(context, ref, pet),
                                      icon: const Icon(Icons.edit_note, size: 18, color: Colors.white),
                                      label: const Text('MODIFICAR', style: TextStyle(fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.skyBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: petsList.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: AppTheme.mintGreen),
                    ),
                  ),
                ),
                error: (err, stack) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error al cargar mascotas: $err',
                        style: const TextStyle(color: AppTheme.coralRed)),
                  ),
                ),
              ),

              // ── Validación de Cédulas Veterinarias ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: AppTheme.goldChampagne),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Validación de Cédulas Veterinarias',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                        ),
                      ),
                      if (pendingVetCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.goldChampagne.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.goldChampagne.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '$pendingVetCount pendiente${pendingVetCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: AppTheme.goldChampagne,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              pendingVetsAsync.when(
                data: (pendingVets) {
                  if (pendingVets.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 8, 24, 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppTheme.mintGreen, size: 40),
                              SizedBox(height: 12),
                              Text(
                                'No hay solicitudes pendientes de validación.',
                                style: TextStyle(color: AppTheme.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final vet = pendingVets[index];
                          return _VetValidationCard(vet: vet);
                        },
                        childCount: pendingVets.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: AppTheme.goldChampagne),
                    ),
                  ),
                ),
                error: (err, stack) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error al cargar veterinarios: $err',
                        style: const TextStyle(color: AppTheme.coralRed)),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error al cargar panel admin: $err',
                style: const TextStyle(color: AppTheme.coralRed)),
          ),
        ),
      ),
    );
  }

  void _showEditPetDialog(BuildContext context, WidgetRef ref, PetEntity pet) {
    final nameController = TextEditingController(text: pet.name);
    final speciesController = TextEditingController(text: pet.species);
    final breedController = TextEditingController(text: pet.breed);
    final ageController = TextEditingController(text: (pet.age).toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.edit_outlined, color: AppTheme.mintGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modificar: ${pet.name}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameController, 'Nombre'),
                const SizedBox(height: 16),
                _dialogField(speciesController, 'Especie'),
                const SizedBox(height: 16),
                _dialogField(breedController, 'Raza'),
                const SizedBox(height: 16),
                _dialogField(ageController, 'Edad (Meses)', isNumber: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedPet = pet.copyWith(
                  name: nameController.text.trim(),
                  species: speciesController.text.trim(),
                  breed: breedController.text.trim(),
                  age: int.tryParse(ageController.text.trim()) ?? pet.age,
                );
                try {
                  await ref.read(petRepositoryProvider).updatePet(updatedPet);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡${updatedPet.name} modificada con éxito!'),
                        backgroundColor: AppTheme.mintGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al modificar mascota: $e'),
                        backgroundColor: AppTheme.coralRed,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('GUARDAR CAMBIOS'),
            ),
          ],
        );
      },
    );
  }

  TextField _dialogField(TextEditingController ctrl, String label, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.mintGreen)),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Consola de Administración Local (Sucursal) ──────────────────────────────
  Widget _buildLocalBranchAdminDashboard(
    BuildContext context,
    WidgetRef ref,
    UserEntity admin,
    String branchId,
  ) {
    final branchPetsAsync = ref.watch(branchPetsStreamProvider(branchId));
    final branchStaffAsync = ref.watch(branchStaffStreamProvider(branchId));
    final branchName = branchId.toUpperCase().replaceAll('_', ' ');

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffDialog(context, ref, branchId),
        backgroundColor: AppTheme.mintGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('DAR DE ALTA STAFF', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar (Sucursal física) ──────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            actions: [
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
                branchName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.mintGreen, Color(0xFF095A60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Administración Local',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bienvenido, ${admin.displayName}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Banner: Wizard de configuración pendiente ─────────────────────
          _WizardPendingBanner(adminUid: admin.uid, branchId: branchId),

          // ── Métricas de la Sucursal ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                children: [
                  _buildMetricCard(
                    context,
                    'Mascotas Registradas',
                    branchPetsAsync.maybeWhen(
                      data: (list) => '${list.length}',
                      orElse: () => '...',
                    ),
                    Icons.pets_outlined,
                    AppTheme.skyBlue,
                  ),
                  _buildMetricCard(
                    context,
                    'Colaboradores Totales',
                    branchStaffAsync.maybeWhen(
                      data: (list) => '${list.length}',
                      orElse: () => '...',
                    ),
                    Icons.people_outline,
                    AppTheme.mintGreen,
                  ),
                  _buildMetricCard(
                    context,
                    'Vets Habilitados',
                    branchStaffAsync.maybeWhen(
                      data: (list) => '${list.where((u) => u.role == UserRole.vet && u.isApprovedVet).length}',
                      orElse: () => '0',
                    ),
                    Icons.local_hospital_outlined,
                    AppTheme.goldChampagne,
                  ),
                  _buildMetricCard(
                    context,
                    'Staff de Operaciones',
                    branchStaffAsync.maybeWhen(
                      data: (list) => '${list.where((u) => u.role != UserRole.vet).length}',
                      orElse: () => '0',
                    ),
                    Icons.cut_outlined,
                    AppTheme.skyBlue,
                  ),
                ],
              ),
            ),
          ),

          // ── Título Sección Colaboradores ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined, color: AppTheme.mintGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Gestión de Colaboradores Locales',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

          // ── Listado de Colaboradores ──────────────────────────────────────
          branchStaffAsync.when(
            data: (staffList) {
              if (staffList.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                    child: Center(
                      child: Text(
                        'Aún no hay colaboradores registrados en esta sucursal.\nUsa el botón "DAR DE ALTA STAFF" para comenzar.',
                        style: TextStyle(color: AppTheme.textMuted, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final staff = staffList[index];
                      return _BranchStaffCard(staff: staff);
                    },
                    childCount: staffList.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppTheme.mintGreen),
                ),
              ),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'Error al cargar colaboradores: $err',
                    style: const TextStyle(color: AppTheme.coralRed),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref, String branchId) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    
    String selectedRole = 'vet'; 
    bool canPerformMedical = true;
    bool canPerformServices = false;
    bool isPasswordObscured = true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined, color: AppTheme.mintGreen, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Alta de Colaborador',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: isSaving
                  ? SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(color: AppTheme.mintGreen),
                            SizedBox(height: 16),
                            Text(
                              'Creando cuenta de colaborador...',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Nombre Completo',
                              labelStyle: TextStyle(color: AppTheme.textMuted),
                              prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.mintGreen)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico',
                              labelStyle: TextStyle(color: AppTheme.textMuted),
                              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.mintGreen)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: isPasswordObscured,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Contraseña Temporal',
                              labelStyle: const TextStyle(color: AppTheme.textMuted),
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isPasswordObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppTheme.textMuted,
                                ),
                                onPressed: () {
                                  setState(() => isPasswordObscured = !isPasswordObscured);
                                },
                              ),
                              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.mintGreen)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Rol de Empleado:', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              DropdownButton<String>(
                                value: selectedRole,
                                dropdownColor: AppTheme.surface,
                                underline: Container(),
                                style: const TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.bold),
                                items: const [
                                  DropdownMenuItem(value: 'vet',          child: Text('Veterinario')),
                                  DropdownMenuItem(value: 'groomer',      child: Text('Lavador / Estilista')),
                                  DropdownMenuItem(value: 'caretaker',    child: Text('Cuidador de Guardería')),
                                  DropdownMenuItem(value: 'receptionist', child: Text('Recepcionista')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedRole = value;
                                      canPerformMedical = selectedRole == 'vet';
                                      canPerformServices = selectedRole == 'vet' ||
                                          selectedRole == 'groomer' ||
                                          selectedRole == 'caretaker';
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const Divider(color: AppTheme.border, height: 24),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('¿Procedimientos Médicos?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Habilita la edición de cartillas y recetas', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            value: canPerformMedical,
                            activeColor: AppTheme.mintGreen,
                            onChanged: (val) {
                              setState(() => canPerformMedical = val);
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('¿Servicios y Estética?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Habilita control de citas de estética y cuidados', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            value: canPerformServices,
                            activeColor: AppTheme.mintGreen,
                            onChanged: (val) {
                              setState(() => canPerformServices = val);
                            },
                          ),
                        ],
                      ),
                    ),
              actions: isSaving
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final password = passwordCtrl.text.trim();

                          if (name.isEmpty || email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('El nombre y el correo electrónico son obligatorios.'),
                                backgroundColor: AppTheme.coralRed,
                              ),
                            );
                            return;
                          }

                          if (password.isNotEmpty && password.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('La contraseña debe tener al menos 6 caracteres.'),
                                backgroundColor: AppTheme.coralRed,
                              ),
                            );
                            return;
                          }

                          setState(() => isSaving = true);
                          try {
                            final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('registerBranchStaff');
                            final payload = <String, dynamic>{
                              'email': email,
                              'displayName': name,
                              'role': selectedRole,
                              'canPerformMedical': canPerformMedical,
                              'canPerformServices': canPerformServices,
                            };
                            if (password.isNotEmpty) {
                              payload['password'] = password;
                            }

                            await callable.call(payload);

                            if (context.mounted) {
                              Navigator.pop(context); 
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('¡$name registrado exitosamente como ${_roleLabel(selectedRole)}!'),
                                  backgroundColor: AppTheme.mintGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isSaving = false);
                            String errorMsg = e.toString();
                            if (errorMsg.contains('already-exists') || errorMsg.contains('already registered')) {
                              errorMsg = 'Este correo electrónico ya está registrado.';
                            } else {
                              errorMsg = 'Error al registrar colaborador: $errorMsg';
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: AppTheme.coralRed,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('GUARDAR'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}


String _roleLabel(String role) {
  const labels = {
    'vet':          'Veterinario',
    'groomer':      'Lavador / Estilista',
    'caretaker':    'Cuidador de Guardería',
    'receptionist': 'Recepcionista',
  };
  return labels[role] ?? role;
}

class _VetValidationCard extends ConsumerStatefulWidget {
  final UserEntity vet;
  const _VetValidationCard({required this.vet});

  @override
  ConsumerState<_VetValidationCard> createState() => _VetValidationCardState();
}

class _VetValidationCardState extends ConsumerState<_VetValidationCard> {
  bool _isLoading = false;

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).approveVet(widget.vet.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.vet.displayName} aprobado. Acceso clínico habilitado.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: AppTheme.coralRed),
        );
      }
    }
  }

  void _showRejectDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Motivo de Rechazo',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Describe el motivo del rechazo...',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.coralRed),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await ref.read(authNotifierProvider.notifier).rejectVet(widget.vet.uid, reason);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Solicitud de ${widget.vet.displayName} rechazada.'),
                      backgroundColor: AppTheme.coralRed,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.coralRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CONFIRMAR RECHAZO'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldChampagne.withValues(alpha: 0.25)),
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppTheme.mintGreen),
              ))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.vet.displayName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.goldChampagne.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.goldChampagne.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'PENDIENTE',
                        style: TextStyle(
                          color: AppTheme.goldChampagne,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.vet.email,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 14, color: AppTheme.goldChampagne),
                    const SizedBox(width: 6),
                    Text(
                      'Cédula: ${widget.vet.professionalLicense ?? 'No proporcionada'}',
                      style: const TextStyle(
                        color: AppTheme.goldChampagne,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _showRejectDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.coralRed,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppTheme.coralRed.withValues(alpha: 0.4)),
                          ),
                        ),
                        child: const Text('RECHAZAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape:
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('APROBAR',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner: wizard de configuración pendiente
// ─────────────────────────────────────────────────────────────────────────────

class _WizardPendingBanner extends ConsumerWidget {
  final String adminUid;
  final String branchId;

  const _WizardPendingBanner(
      {required this.adminUid, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionAsync =
        ref.watch(wizardCompletionProvider(adminUid));

    return completionAsync.when(
      data: (isCompleted) {
        if (isCompleted) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: GestureDetector(
              onTap: () => context.push('/setup-wizard'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF3CD), Color(0xFFFFF8E1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppTheme.goldChampagne.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.goldChampagne.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.rocket_launch_outlined,
                          color: AppTheme.goldChampagne, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completa la configuración',
                            style: TextStyle(
                                color: Color(0xFF7B5E00),
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Faltan pasos para que tu negocio esté completamente operativo.',
                            style: TextStyle(
                                color: Color(0xFF9E7A00), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.goldChampagne, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _BranchStaffCard extends ConsumerStatefulWidget {
  final UserEntity staff;
  const _BranchStaffCard({required this.staff});

  @override
  ConsumerState<_BranchStaffCard> createState() => _BranchStaffCardState();
}

class _BranchStaffCardState extends ConsumerState<_BranchStaffCard> {
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final isVet = staff.role == UserRole.vet;
    final isApproved = staff.isApprovedVet;
    final roleBadgeText = _roleLabel(staff.role.name);
    final roleBadgeColor = switch (staff.role) {
      UserRole.vet => AppTheme.goldChampagne,
      UserRole.groomer => AppTheme.mintGreen,
      UserRole.caretaker => AppTheme.skyBlue,
      UserRole.receptionist => const Color(0xFFE8962B),
      _ => AppTheme.skyBlue,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleBadgeColor.withValues(alpha: 0.12),
            child: Text(
              staff.displayName.isNotEmpty ? staff.displayName[0].toUpperCase() : 'C',
              style: TextStyle(
                color: roleBadgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.displayName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  staff.email,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: roleBadgeColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        roleBadgeText,
                        style: TextStyle(
                          color: roleBadgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isApproved ? AppTheme.mintGreen : AppTheme.coralRed).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (isApproved ? AppTheme.mintGreen : AppTheme.coralRed).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        isApproved ? 'ACTIVO' : 'SUSPENDIDO',
                        style: TextStyle(
                          color: isApproved ? AppTheme.mintGreen : AppTheme.coralRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isToggling
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.mintGreen,
                      ),
                    ),
                  ),
                )
              : Switch(
                  value: isApproved,
                  activeColor: AppTheme.mintGreen,
                  inactiveThumbColor: AppTheme.textMuted,
                  inactiveTrackColor: AppTheme.border,
                  onChanged: (newValue) async {
                    setState(() => _isToggling = true);
                    try {
                      await FirebaseFirestore.instance
                          .demoCollection('users')
                          .doc(staff.uid)
                          .update({
                        'isApprovedVet': newValue,
                        'vetStatus': newValue ? 'approved' : 'suspended',
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              newValue
                                  ? '¡Acceso habilitado para ${staff.displayName}!'
                                  : '¡Acceso suspendido para ${staff.displayName}!',
                            ),
                            backgroundColor: newValue ? AppTheme.mintGreen : AppTheme.coralRed,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al cambiar acceso: $e'),
                            backgroundColor: AppTheme.coralRed,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isToggling = false);
                      }
                    }
                  },
                ),
        ],
      ),
    );
  }
}

