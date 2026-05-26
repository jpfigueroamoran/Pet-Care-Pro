import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/boarding_reservation_entity.dart';
import '../providers/boarding_providers.dart';
import '../providers/branch_boarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Panel de Recepción — Receptionist Dashboard
// Vista de agenda completa: pendientes, agenda del día y próximas reservas.
// ─────────────────────────────────────────────────────────────────────────────

class ReceptionistDashboardScreen extends ConsumerWidget {
  const ReceptionistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.goldChampagne)),
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
              child: Center(child: CircularProgressIndicator(color: AppTheme.goldChampagne)),
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
      backgroundColor: const Color(0xFF7B4F00),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE8962B), Color(0xFF7B4F00)],
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
                        child: const Icon(Icons.support_agent_outlined,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text('Recepción',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('¡Hola, $name!',
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const Text('Agenda y reservas de la sucursal',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        title: const Text('Recepción',
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

  Widget _buildContent(
      BuildContext context, List<BoardingReservationEntity> all) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekEnd = todayStart.add(const Duration(days: 7));

    final pending = all
        .where((r) => r.status == ReservationStatus.pending)
        .toList();

    final todayAgenda = all
        .where((r) =>
            (r.status == ReservationStatus.confirmed ||
                r.status == ReservationStatus.checkedIn) &&
            r.checkInExpected.isAfter(todayStart) &&
            r.checkInExpected.isBefore(todayEnd))
        .toList();

    final upcomingWeek = all
        .where((r) =>
            r.status == ReservationStatus.confirmed &&
            r.checkInExpected.isAfter(todayEnd) &&
            r.checkInExpected.isBefore(weekEnd))
        .toList();

    final hospedadasNow = all
        .where((r) => r.status == ReservationStatus.checkedIn)
        .toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── KPI Stats ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              _KpiTile('Pendientes', '${pending.length}',
                  AppTheme.coralRed, Icons.pending_actions_outlined),
              const SizedBox(width: 8),
              _KpiTile('Agenda hoy', '${todayAgenda.length}',
                  AppTheme.goldChampagne, Icons.today_outlined),
              const SizedBox(width: 8),
              _KpiTile('Esta semana', '${upcomingWeek.length}',
                  AppTheme.mintGreen, Icons.date_range_outlined),
              const SizedBox(width: 8),
              _KpiTile('Hospedadas', '${hospedadasNow.length}',
                  const Color(0xFF1565C0), Icons.hotel_outlined),
            ],
          ),
        ),

        // ── Acciones Rápidas ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_circle_outline,
                  label: 'Nueva\nReserva',
                  color: AppTheme.mintGreen,
                  onTap: () => context.push('/owner-reservations'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.person_search_outlined,
                  label: 'Buscar\nDueño',
                  color: const Color(0xFF1565C0),
                  onTap: () => context.push('/vet-directory'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.pets_outlined,
                  label: 'Mascotas\nde Sucursal',
                  color: AppTheme.goldChampagne,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),

        // ── Pendientes de Confirmación ────────────────────────────────────
        if (pending.isNotEmpty) ...[
          _SectionHeader('Pendientes de Confirmación',
              Icons.pending_actions_outlined, AppTheme.coralRed,
              badge: pending.length),
          ...pending.map((r) => _AgendaCard(
                reservation: r,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        // ── Agenda del Día ────────────────────────────────────────────────
        if (todayAgenda.isNotEmpty) ...[
          _SectionHeader('Agenda de Hoy', Icons.today_outlined, AppTheme.goldChampagne),
          ...todayAgenda.map((r) => _AgendaCard(
                reservation: r,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        // ── Próxima Semana ────────────────────────────────────────────────
        if (upcomingWeek.isNotEmpty) ...[
          _SectionHeader('Próximas Reservas (7 días)',
              Icons.date_range_outlined, AppTheme.mintGreen),
          ...upcomingWeek.map((r) => _AgendaCard(
                reservation: r,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        // ── Hospedadas Actualmente ────────────────────────────────────────
        if (hospedadasNow.isNotEmpty) ...[
          _SectionHeader('En Guardería Actualmente',
              Icons.hotel_outlined, const Color(0xFF1565C0)),
          ...hospedadasNow.map((r) => _AgendaCard(
                reservation: r,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 56, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text('Sin reservas registradas',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('La agenda de la sucursal aparecerá aquí.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ),

        const SizedBox(height: 40),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos
// ─────────────────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
  final int? badge;

  const _SectionHeader(this.title, this.icon, this.color, {this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          if (badge != null && badge! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ── Tarjeta de agenda ─────────────────────────────────────────────────────────

class _AgendaCard extends ConsumerStatefulWidget {
  final BoardingReservationEntity reservation;
  final void Function(String petId) onTapHistory;

  const _AgendaCard({required this.reservation, required this.onTapHistory});

  @override
  ConsumerState<_AgendaCard> createState() => _AgendaCardState();
}

class _AgendaCardState extends ConsumerState<_AgendaCard> {
  bool _cancelling = false;

  Future<void> _confirmCancel(BuildContext context) async {
    final r = widget.reservation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cancelar reserva?',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Se cancelará la reserva de ${r.petName}. Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NO', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralRed),
            child: const Text('SÍ, CANCELAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    final result = await ref.read(boardingRepositoryProvider).cancelReservation(r.id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva cancelada.'), backgroundColor: AppTheme.coralRed),
      ),
      failure: (msg, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.coralRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    final onTapHistory = widget.onTapHistory;
    final r = reservation;
    const weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    String hhmm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    String ddmm(DateTime dt) =>
        '${weekDays[dt.weekday - 1]} ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

    Color statusColor(ReservationStatus s) {
      switch (s) {
        case ReservationStatus.pending:   return AppTheme.coralRed;
        case ReservationStatus.confirmed: return AppTheme.mintGreen;
        case ReservationStatus.checkedIn: return const Color(0xFF1565C0);
        case ReservationStatus.completed: return AppTheme.textMuted;
        case ReservationStatus.cancelled: return AppTheme.coralRed;
      }
    }

    String statusLabel(ReservationStatus s) {
      switch (s) {
        case ReservationStatus.pending:   return 'Pendiente';
        case ReservationStatus.confirmed: return 'Confirmada';
        case ReservationStatus.checkedIn: return 'En guardería';
        case ReservationStatus.completed: return 'Completada';
        case ReservationStatus.cancelled: return 'Cancelada';
      }
    }

    final sc = statusColor(r.status);
    final sl = statusLabel(r.status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Left: date column
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.goldChampagne.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  hhmm(r.checkInExpected),
                  style: const TextStyle(
                      color: AppTheme.goldChampagne,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                Text(
                  ddmm(r.checkInExpected),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Center: info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.petName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(r.ownerName,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                // Services chips
                if (r.servicesIncluded.isNotEmpty)
                  Text(
                    r.servicesIncluded.map(_serviceLabel).join(' · '),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: status + action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(sl,
                    style: TextStyle(
                        color: sc, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => onTapHistory(r.petId),
                child: const Text('Ver expediente',
                    style: TextStyle(
                        color: AppTheme.mintGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              if (r.status == ReservationStatus.pending ||
                  r.status == ReservationStatus.confirmed) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _cancelling ? null : () => _confirmCancel(context),
                  child: _cancelling
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppTheme.coralRed),
                        )
                      : const Text('Cancelar',
                          style: TextStyle(
                              color: AppTheme.coralRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _serviceLabel(ServiceType s) {
    switch (s) {
      case ServiceType.boarding: return 'Estancia';
      case ServiceType.daycare:  return 'Día';
      case ServiceType.bath:     return 'Baño';
      case ServiceType.haircut:  return 'Corte';
    }
  }
}
