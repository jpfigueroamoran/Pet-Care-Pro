import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/firestore_extension.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/boarding_reservation_entity.dart';
import '../providers/branch_boarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Panel de Guardería — Caretaker Dashboard
// Muestra reservas activas agrupadas: alertas de riesgo, hospedadas,
// llegadas del día y salidas del día. Permite actualizar status (check-in/out).
// ─────────────────────────────────────────────────────────────────────────────

class CaretakerDashboardScreen extends ConsumerWidget {
  const CaretakerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
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
              child: Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error al cargar datos: $e',
                    style: const TextStyle(color: AppTheme.coralRed)),
              ),
            ),
            data: (reservations) => _buildContent(context, ref, reservations, branchId),
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
      backgroundColor: const Color(0xFF1565C0),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C828A), Color(0xFF1565C0)],
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
                        child: const Icon(Icons.home_work_outlined,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text('Panel de Guardería',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('¡Hola, $name!',
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const Text('Control de estancias y bienestar animal',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        title: const Text('Panel de Guardería',
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
    BuildContext context,
    WidgetRef ref,
    List<BoardingReservationEntity> all,
    String branchId,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final hospitalized = all
        .where((r) => r.status == ReservationStatus.checkedIn)
        .toList();

    final alerts = hospitalized
        .where((r) => r.safetySnapshot.riskLevelAtBooking.requiresStaffAlert)
        .toList();

    final arrivalsToday = all
        .where((r) =>
            r.status == ReservationStatus.confirmed &&
            r.checkInExpected.isAfter(todayStart) &&
            r.checkInExpected.isBefore(todayEnd))
        .toList();

    final departuresToday = hospitalized
        .where((r) =>
            r.checkOutExpected.isAfter(todayStart) &&
            r.checkOutExpected.isBefore(todayEnd))
        .toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── KPI Stats ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              _KpiCard('Hospedadas', '${hospitalized.length}',
                  Icons.hotel_outlined, const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              _KpiCard('Llegadas hoy', '${arrivalsToday.length}',
                  Icons.login_outlined, AppTheme.mintGreen),
              const SizedBox(width: 8),
              _KpiCard('Salidas hoy', '${departuresToday.length}',
                  Icons.logout_outlined, AppTheme.goldChampagne),
              const SizedBox(width: 8),
              _KpiCard('Alertas', '${alerts.length}',
                  Icons.warning_amber_outlined, AppTheme.coralRed),
            ],
          ),
        ),

        // ── Alertas de Riesgo ─────────────────────────────────────────────
        if (alerts.isNotEmpty) ...[
          _SectionHeader(
              '⚠ Requieren Atención Especial', Icons.warning_amber_outlined,
              AppTheme.coralRed),
          ...alerts.map((r) => _ResCard(
                reservation: r,
                ref: ref,
                branchId: branchId,
                showRisk: true,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        // ── Mascotas Hospedadas ───────────────────────────────────────────
        if (hospitalized.isNotEmpty) ...[
          _SectionHeader('Mascotas Hospedadas',
              Icons.home_work_outlined, const Color(0xFF1565C0)),
          ...hospitalized.map((r) => _ResCard(
                reservation: r,
                ref: ref,
                branchId: branchId,
                showCheckout: true,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        // ── Llegadas del Día ──────────────────────────────────────────────
        if (arrivalsToday.isNotEmpty) ...[
          _SectionHeader(
              'Llegadas de Hoy', Icons.login_outlined, AppTheme.mintGreen),
          ...arrivalsToday.map((r) => _ResCard(
                reservation: r,
                ref: ref,
                branchId: branchId,
                showCheckin: true,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        // ── Salidas del Día ───────────────────────────────────────────────
        if (departuresToday.isNotEmpty) ...[
          _SectionHeader(
              'Salidas de Hoy', Icons.logout_outlined, AppTheme.goldChampagne),
          ...departuresToday.map((r) => _ResCard(
                reservation: r,
                ref: ref,
                branchId: branchId,
                showCheckout: true,
                onTapHistory: (id) => context.push('/pet/$id/history'),
              )),
        ],

        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Text('Sin reservas activas en esta sucursal.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
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

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard(this.label, this.value, this.icon, this.color);

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
            Icon(icon, color: color, size: 20),
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
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de reserva con acciones de check-in / check-out ─────────────────

class _ResCard extends ConsumerStatefulWidget {
  final BoardingReservationEntity reservation;
  final WidgetRef ref;
  final String branchId;
  final bool showRisk;
  final bool showCheckin;
  final bool showCheckout;
  final void Function(String petId) onTapHistory;

  const _ResCard({
    required this.reservation,
    required this.ref,
    required this.branchId,
    this.showRisk = false,
    this.showCheckin = false,
    this.showCheckout = false,
    required this.onTapHistory,
  });

  @override
  ConsumerState<_ResCard> createState() => _ResCardState();
}

class _ResCardState extends ConsumerState<_ResCard> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .demoCollection('boarding_reservations')
          .doc(widget.reservation.id)
          .update({'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'checked_in'
              ? '✓ Check-in registrado para ${widget.reservation.petName}'
              : '✓ Check-out registrado para ${widget.reservation.petName}'),
          backgroundColor: AppTheme.mintGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: AppTheme.coralRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    String hhmm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    String ddmm(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

    Color riskColor(RiskLevel lvl) {
      switch (lvl) {
        case RiskLevel.green:  return AppTheme.mintGreen;
        case RiskLevel.yellow: return AppTheme.goldChampagne;
        case RiskLevel.orange: return Colors.deepOrange;
        case RiskLevel.red:    return AppTheme.coralRed;
      }
    }

    final rc = riskColor(r.safetySnapshot.riskLevelAtBooking);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.showRisk && r.safetySnapshot.riskLevelAtBooking != RiskLevel.green
              ? rc.withValues(alpha: 0.4)
              : AppTheme.border,
          width: widget.showRisk ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pets, color: Color(0xFF1565C0), size: 20),
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
                // Risk badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: rc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.safetySnapshot.riskLevelAtBooking.displayLabel,
                    style: TextStyle(
                        color: rc, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Info ──────────────────────────────────────────────────────
            Row(
              children: [
                _InfoPill(
                    Icons.login_outlined,
                    'Entrada: ${ddmm(r.checkInExpected)} ${hhmm(r.checkInExpected)}'),
                const SizedBox(width: 8),
                _InfoPill(
                    Icons.logout_outlined,
                    'Salida: ${ddmm(r.checkOutExpected)} ${hhmm(r.checkOutExpected)}'),
              ],
            ),

            // ── Alertas legales ───────────────────────────────────────────
            if (!r.legalAuthorizations.hasMinimumAuthorizations)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.coralRed, size: 14),
                    const SizedBox(width: 4),
                    const Text('Autorizaciones incompletas',
                        style: TextStyle(
                            color: AppTheme.coralRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            // ── Notas de staff ────────────────────────────────────────────
            if (r.staffNotes != null && r.staffNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Nota: ${r.staffNotes}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic)),
              ),

            const SizedBox(height: 10),

            // ── Acciones ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => widget.onTapHistory(r.petId),
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Expediente'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.mintGreen,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                ),
                if (widget.showCheckin && !_loading)
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('checked_in'),
                    icon: const Icon(Icons.login_outlined, size: 16),
                    label: const Text('Check-in'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintGreen,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (widget.showCheckout && !_loading)
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('completed'),
                    icon: const Icon(Icons.logout_outlined, size: 16),
                    label: const Text('Check-out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldChampagne,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.mintGreen),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }
}
