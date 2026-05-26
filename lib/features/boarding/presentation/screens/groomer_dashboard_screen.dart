import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/boarding_reservation_entity.dart';
import '../providers/branch_boarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Panel de Estética — Groomer Dashboard
// Muestra reservas con servicios de baño/corte agrupadas por estado.
// ─────────────────────────────────────────────────────────────────────────────

class GroomerDashboardScreen extends ConsumerWidget {
  const GroomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
      );
    }

    final branchId = user.branchId ?? '';
    final asyncRes = ref.watch(branchReservationsStreamProvider(branchId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, ref, user.displayName),
          asyncRes.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error al cargar datos: $e',
                    style: const TextStyle(color: AppTheme.coralRed)),
              ),
            ),
            data: (reservations) => _buildContent(context, reservations),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context, WidgetRef ref, String name) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppTheme.mintGreen,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.mintGreen, Color(0xFF095A60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.content_cut, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Panel de Estética',
                        style: TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('¡Hola, $name!',
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const Text('Servicios de baño y estilismo del día',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        title: const Text('Panel de Estética',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
        collapseMode: CollapseMode.parallax,
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
          color: AppTheme.surface,
          onSelected: (v) async {
            if (v == 'profile') context.push('/edit-profile');
            if (v == 'logout') {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'profile', child: Text('Mi Perfil')),
            PopupMenuItem(value: 'logout', child: Text('Cerrar Sesión')),
          ],
        ),
      ],
    );
  }

  // ── Contenido ──────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, List<BoardingReservationEntity> all) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Solo reservas con servicios de estética
    final grooming = all.where((r) => r.includesGrooming).toList();

    final inService = grooming
        .where((r) => r.status == ReservationStatus.checkedIn)
        .toList();

    final upcoming = grooming
        .where((r) => r.status == ReservationStatus.confirmed ||
            r.status == ReservationStatus.pending)
        .toList();

    final completedToday = grooming
        .where((r) =>
            r.status == ReservationStatus.completed &&
            r.checkOutExpected.isAfter(todayStart) &&
            r.checkOutExpected.isBefore(todayEnd))
        .toList();

    if (grooming.isEmpty) {
      return _emptyState();
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Stats ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              _StatCard(
                  icon: Icons.content_cut_outlined,
                  label: 'En Servicio',
                  value: '${inService.length}',
                  color: AppTheme.mintGreen),
              const SizedBox(width: 10),
              _StatCard(
                  icon: Icons.schedule_outlined,
                  label: 'Programados',
                  value: '${upcoming.length}',
                  color: AppTheme.skyBlue),
              const SizedBox(width: 10),
              _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Completados hoy',
                  value: '${completedToday.length}',
                  color: AppTheme.goldChampagne),
            ],
          ),
        ),

        // ── En Servicio Ahora ───────────────────────────────────────────────
        if (inService.isNotEmpty) ...[
          _SectionHeader(
              'En Servicio Ahora', Icons.pets_outlined, AppTheme.mintGreen),
          ...inService.map((r) => _ReservationCard(
                reservation: r,
                onTapHistory: (petId) => context.push('/pet/$petId/history'),
                onTapCharge: (petId) => context.push('/pet/$petId/charge'),
              )),
        ],

        // ── Próximos ──────────────────────────────────────────────────────
        if (upcoming.isNotEmpty) ...[
          _SectionHeader(
              'Próximas Citas de Estética', Icons.schedule_outlined, AppTheme.skyBlue),
          ...upcoming.map((r) => _ReservationCard(
                reservation: r,
                onTapHistory: (petId) => context.push('/pet/$petId/history'),
                onTapCharge: (petId) => context.push('/pet/$petId/charge'),
              )),
        ],

        // ── Completadas Hoy ───────────────────────────────────────────────
        if (completedToday.isNotEmpty) ...[
          _SectionHeader(
              'Completados Hoy', Icons.check_circle_outline, AppTheme.goldChampagne),
          ...completedToday.map((r) => _ReservationCard(
                reservation: r,
                onTapHistory: (petId) => context.push('/pet/$petId/history'),
                onTapCharge: (petId) => context.push('/pet/$petId/charge'),
              )),
        ],

        const SizedBox(height: 40),
      ]),
    );
  }

  SliverFillRemaining _emptyState() {
    return const SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.content_cut_outlined,
                  size: 64, color: AppTheme.textMuted),
              SizedBox(height: 16),
              Text('Sin servicios de estética',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('No hay reservas con baño o corte programadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets compartidos del groomer dashboard
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final BoardingReservationEntity reservation;
  final void Function(String petId) onTapHistory;
  final void Function(String petId)? onTapCharge;

  const _ReservationCard({required this.reservation, required this.onTapHistory, this.onTapCharge});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    String hhmm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    String ddmm(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    final riskColor = _riskColor(r.safetySnapshot.riskLevelAtBooking);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pet avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.mintGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, color: AppTheme.mintGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.petName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text('Dueño: ${r.ownerName}',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              // Riesgo badge
              if (r.safetySnapshot.riskLevelAtBooking != RiskLevel.green)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    r.safetySnapshot.riskLevelAtBooking.displayLabel,
                    style: TextStyle(
                        color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Servicios
          Wrap(
            spacing: 6,
            children: r.servicesIncluded.map((s) => _serviceChip(s)).toList(),
          ),
          const SizedBox(height: 10),
          // Horario
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                'Entrada: ${ddmm(r.checkInExpected)} ${hhmm(r.checkInExpected)}  '
                '·  Salida: ${hhmm(r.checkOutExpected)}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Acciones
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => onTapHistory(r.petId),
                icon: const Icon(Icons.folder_open_outlined, size: 16),
                label: const Text('Expediente'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.mintGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              if (onTapCharge != null) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => onTapCharge!(r.petId),
                  icon: const Icon(Icons.attach_money_outlined, size: 16),
                  label: const Text('Cobrar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.goldChampagne,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceChip(ServiceType s) {
    final labels = {
      ServiceType.bath: ('Baño', Icons.water_drop_outlined),
      ServiceType.haircut: ('Corte', Icons.content_cut_outlined),
      ServiceType.boarding: ('Estancia', Icons.home_work_outlined),
      ServiceType.daycare: ('Día', Icons.wb_sunny_outlined),
    };
    final (label, icon) = labels[s] ?? (s.value, Icons.miscellaneous_services_outlined);
    return Chip(
      avatar: Icon(icon, size: 14, color: AppTheme.mintGreen),
      label: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      backgroundColor: AppTheme.surfaceVariant,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppTheme.border),
    );
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.green:  return AppTheme.mintGreen;
      case RiskLevel.yellow: return AppTheme.goldChampagne;
      case RiskLevel.orange: return Colors.deepOrange;
      case RiskLevel.red:    return AppTheme.coralRed;
    }
  }
}
