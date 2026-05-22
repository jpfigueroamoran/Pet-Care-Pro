import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../payments/data/repositories/payment_repository.dart';
import '../../../pets/data/repositories/pet_repository.dart';
import '../../../pets/domain/entities/pet_entity.dart';
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
