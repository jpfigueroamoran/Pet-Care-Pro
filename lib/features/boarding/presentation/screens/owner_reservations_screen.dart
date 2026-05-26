import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pets/data/repositories/pet_repository.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/boarding_reservation_entity.dart';
import '../providers/boarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla: Mis Reservas de Guardería (vista del dueño)
// Muestra el historial y estado actual de todas las reservas de las mascotas
// del dueño, con opción de reagendar reservas confirmadas.
// ─────────────────────────────────────────────────────────────────────────────

class OwnerReservationsScreen extends ConsumerWidget {
  const OwnerReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
      );
    }

    // Obtener mascotas del dueño para derivar los petIds
    final petsAsync = ref.watch(ownerPetsStreamProvider(user.uid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mis Reservas'),
        backgroundColor: AppTheme.mintGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: petsAsync.when(
        data: (pets) {
          final petIds = pets.map((p) => p.id).toList()..sort();
          return _ReservationsList(petIdsKey: petIds.join(','));
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
        error: (e, _) => Center(
          child: Text('Error al cargar mascotas: $e',
              style: const TextStyle(color: AppTheme.coralRed)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ReservationsList extends ConsumerWidget {
  final String petIdsKey;

  const _ReservationsList({required this.petIdsKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(ownerReservationsStreamProvider(petIdsKey));

    return reservationsAsync.when(
      data: (reservations) {
        if (reservations.isEmpty) {
          return _EmptyState();
        }

        final active = reservations.where((r) => r.isActive).toList();
        final past = reservations.where((r) => !r.isActive).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (active.isNotEmpty) ...[
              _SectionHeader(title: 'Activas', count: active.length),
              ...active.map((r) => _ReservationCard(reservation: r, isActive: true)),
              const SizedBox(height: 8),
            ],
            if (past.isNotEmpty) ...[
              _SectionHeader(title: 'Historial', count: past.length),
              ...past.map((r) => _ReservationCard(reservation: r, isActive: false)),
            ],
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: AppTheme.coralRed)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 24),
            const Text(
              'Sin reservas registradas',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando el staff confirme una estancia para tu mascota,\naparecerá aquí con su estado en tiempo real.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ReservationCard extends ConsumerWidget {
  final BoardingReservationEntity reservation;
  final bool isActive;

  const _ReservationCard({required this.reservation, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusInfo = _statusInfo(reservation.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? statusInfo.color.withValues(alpha: 0.35)
              : AppTheme.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: nombre mascota + chip de estado
            Row(
              children: [
                Expanded(
                  child: Text(
                    reservation.petName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                _StatusChip(label: statusInfo.label, color: statusInfo.color),
              ],
            ),
            const SizedBox(height: 10),

            // Fechas
            _DateRow(
              icon: Icons.login,
              label: 'Entrada',
              date: reservation.checkInExpected,
            ),
            const SizedBox(height: 4),
            _DateRow(
              icon: Icons.logout,
              label: 'Salida',
              date: reservation.checkOutExpected,
            ),
            const SizedBox(height: 10),

            // Servicios incluidos
            if (reservation.servicesIncluded.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: reservation.servicesIncluded
                    .map((s) => _ServiceChip(service: s))
                    .toList(),
              ),

            // Seguridad: ICD + nivel de riesgo
            const Divider(height: 20, color: AppTheme.border),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  'ICD: ${reservation.safetySnapshot.calculatedIcdScore.toStringAsFixed(0)}/100',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.warning_amber_outlined,
                    size: 14,
                    color: _riskColor(reservation.safetySnapshot.riskLevelAtBooking)),
                const SizedBox(width: 4),
                Text(
                  reservation.safetySnapshot.riskLevelAtBooking.displayLabel,
                  style: TextStyle(
                      color: _riskColor(reservation.safetySnapshot.riskLevelAtBooking),
                      fontSize: 12),
                ),
              ],
            ),

            // Acciones (solo reservas que no han iniciado)
            if (reservation.status == ReservationStatus.confirmed ||
                reservation.status == ReservationStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (reservation.status == ReservationStatus.confirmed)
                    Expanded(child: _RescheduleButton(reservation: reservation)),
                  if (reservation.status == ReservationStatus.confirmed)
                    const SizedBox(width: 8),
                  Expanded(child: _CancelButton(reservation: reservation)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({String label, Color color}) _statusInfo(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.pending:
        return (label: 'Pendiente', color: AppTheme.goldChampagne);
      case ReservationStatus.confirmed:
        return (label: 'Confirmada', color: AppTheme.skyBlue);
      case ReservationStatus.checkedIn:
        return (label: 'En guardería', color: AppTheme.mintGreen);
      case ReservationStatus.completed:
        return (label: 'Completada', color: AppTheme.textMuted);
      case ReservationStatus.cancelled:
        return (label: 'Cancelada', color: AppTheme.coralRed);
    }
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.green:  return AppTheme.mintGreen;
      case RiskLevel.yellow: return AppTheme.goldChampagne;
      case RiskLevel.orange: return Colors.orange;
      case RiskLevel.red:    return AppTheme.coralRed;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RescheduleButton extends ConsumerStatefulWidget {
  final BoardingReservationEntity reservation;

  const _RescheduleButton({required this.reservation});

  @override
  ConsumerState<_RescheduleButton> createState() => _RescheduleButtonState();
}

class _RescheduleButtonState extends ConsumerState<_RescheduleButton> {
  bool _loading = false;

  Future<void> _pickAndReschedule() async {
    final now = DateTime.now();
    final newCheckIn = await showDateTimePicker(context, initial: widget.reservation.checkInExpected);
    if (newCheckIn == null || !mounted) return;
    final newCheckOut = await showDateTimePicker(context, initial: widget.reservation.checkOutExpected);
    if (newCheckOut == null || !mounted) return;

    if (!newCheckIn.isAfter(now)) {
      _showError('La nueva fecha de entrada debe ser futura.');
      return;
    }
    if (!newCheckIn.isBefore(newCheckOut)) {
      _showError('La fecha de entrada debe ser anterior a la de salida.');
      return;
    }

    setState(() => _loading = true);
    final result = await ref.read(boardingRepositoryProvider).updateReservationDates(
          reservationId: widget.reservation.id,
          petId: widget.reservation.petId,
          newCheckIn: newCheckIn,
          newCheckOut: newCheckOut,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reserva reagendada correctamente.'),
            backgroundColor: AppTheme.mintGreen),
      ),
      failure: (msg, _) => _showError(msg),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.coralRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _pickAndReschedule,
        icon: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.skyBlue),
              )
            : const Icon(Icons.edit_calendar_outlined, size: 16),
        label: const Text('Reagendar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.skyBlue,
          side: const BorderSide(color: AppTheme.skyBlue),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CancelButton extends ConsumerStatefulWidget {
  final BoardingReservationEntity reservation;

  const _CancelButton({required this.reservation});

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _loading = false;

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cancelar reserva?',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Se cancelará la reserva de ${widget.reservation.petName}. Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NO, MANTENER', style: TextStyle(color: AppTheme.textMuted)),
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

    setState(() => _loading = true);
    final result = await ref
        .read(boardingRepositoryProvider)
        .cancelReservation(widget.reservation.id);
    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reserva cancelada correctamente.'),
            backgroundColor: AppTheme.coralRed),
      ),
      failure: (msg, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.coralRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _confirmCancel,
        icon: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.coralRed),
              )
            : const Icon(Icons.cancel_outlined, size: 16),
        label: const Text('Cancelar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.coralRed,
          side: const BorderSide(color: AppTheme.coralRed),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Future<DateTime?> showDateTimePicker(
  BuildContext context, {
  required DateTime initial,
}) async {
  final firstDate = DateTime.now();
  // Clamp: si initial es pasado, abrir el picker en hoy para evitar
  // la assertion initialDate >= firstDate de showDatePicker.
  final safeInitial = initial.isBefore(firstDate) ? firstDate : initial;
  final date = await showDatePicker(
    context: context,
    initialDate: safeInitial,
    firstDate: firstDate,
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final ServiceType service;

  const _ServiceChip({required this.service});

  static const _labels = {
    ServiceType.boarding: 'Pensión',
    ServiceType.daycare:  'Guardería día',
    ServiceType.bath:     'Baño',
    ServiceType.haircut:  'Corte',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _labels[service] ?? service.value,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime date;

  const _DateRow({required this.icon, required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        Text(formatted,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
