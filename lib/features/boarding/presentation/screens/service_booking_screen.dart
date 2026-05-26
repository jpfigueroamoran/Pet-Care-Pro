import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/boarding_enums.dart';
import '../../domain/entities/use_case_result.dart';
import '../providers/service_booking_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de agendamiento de servicios — MPT reactivo
// ─────────────────────────────────────────────────────────────────────────────

class ServiceBookingScreen extends ConsumerStatefulWidget {
  final String petId;
  final String petName;
  final String ownerId;
  final String ownerName;
  final String facilityRunId;

  const ServiceBookingScreen({
    super.key,
    required this.petId,
    required this.petName,
    required this.ownerId,
    required this.ownerName,
    this.facilityRunId = 'run-default',
  });

  @override
  ConsumerState<ServiceBookingScreen> createState() =>
      _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends ConsumerState<ServiceBookingScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-select pet when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(serviceBookingProvider.notifier)
          .selectPet(widget.petId, widget.petName);
    });
  }

  @override
  void dispose() {
    ref.read(serviceBookingProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isCheckIn}) async {
    final now = DateTime.now();
    final initial = isCheckIn
        ? (ref.read(serviceBookingProvider).checkIn ?? now)
        : (ref.read(serviceBookingProvider).checkOut ??
            now.add(const Duration(days: 1)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => _datePickerTheme(context, child),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => _datePickerTheme(context, child),
    );
    if (time == null || !mounted) return;

    final combined =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final notifier = ref.read(serviceBookingProvider.notifier);
    if (isCheckIn) {
      notifier.setCheckIn(combined);
    } else {
      notifier.setCheckOut(combined);
    }
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) =>
      Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.mintGreen,
            onPrimary: Colors.white,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceBookingProvider);

    ref.listen(serviceBookingProvider, (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.coralRed,
            behavior: SnackBarBehavior.floating,
          ));
        ref.read(serviceBookingProvider.notifier).clearError();
      }
      if (next.createdReservation != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reserva creada con éxito'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agendar Servicio',
                style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            Text(widget.petName,
                style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Selección de servicios ────────────────────────────────
                _SectionCard(
                  title: 'Servicios',
                  child: _ServiceSelector(
                    selected: state.selectedServices,
                    onToggle: (s) => ref
                        .read(serviceBookingProvider.notifier)
                        .toggleService(s),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Resultado MPT (reactivo) ──────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: state.isCalculatingDuration
                      ? const _MptShimmer()
                      : state.hasDurationResult
                          ? _MptResultCard(state: state)
                              .animate()
                              .fadeIn(duration: 350.ms)
                              .slideY(begin: 0.06, end: 0, duration: 350.ms)
                          : const SizedBox.shrink(),
                ),
                if (state.hasDurationResult) const SizedBox(height: 12),

                // ── Fechas ────────────────────────────────────────────────
                _SectionCard(
                  title: 'Fechas de Estancia',
                  child: Column(
                    children: [
                      _DateTile(
                        label: 'Check-In',
                        icon: Icons.login_rounded,
                        dt: state.checkIn,
                        onTap: () => _pickDateTime(isCheckIn: true),
                      ),
                      const Divider(color: AppTheme.border, height: 1),
                      _DateTile(
                        label: 'Check-Out',
                        icon: Icons.logout_rounded,
                        dt: state.checkOut,
                        onTap: () => _pickDateTime(isCheckIn: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Habilitación sanitaria ────────────────────────────────
                _SectionCard(
                  title: 'Habilitación Sanitaria',
                  child: _ClearanceSection(state: state),
                ),
                const SizedBox(height: 12),

                // ── Autorizaciones legales ────────────────────────────────
                _SectionCard(
                  title: 'Autorizaciones del Dueño',
                  child: _LegalAuthSection(state: state),
                ),
              ]),
            ),
          ),
        ],
      ),

      // ── Barra de acción flotante ──────────────────────────────────────────
      bottomSheet: _SubmitBar(
        state: state,
        onSubmit: () => ref.read(serviceBookingProvider.notifier).submitReservation(
          ownerId: widget.ownerId,
          ownerName: widget.ownerName,
          petName: widget.petName,
          facilityRunId: widget.facilityRunId,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector de servicios
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceSelector extends StatelessWidget {
  final List<ServiceType> selected;
  final void Function(ServiceType) onToggle;

  const _ServiceSelector(
      {required this.selected, required this.onToggle});

  static const _items = [
    (ServiceType.boarding, Icons.night_shelter_rounded, 'Hospedaje'),
    (ServiceType.daycare, Icons.wb_sunny_rounded, 'Guardería día'),
    (ServiceType.bath, Icons.water_drop_rounded, 'Baño'),
    (ServiceType.haircut, Icons.content_cut_rounded, 'Estética'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: _items.map((item) {
        final (type, icon, label) = item;
        final isSelected = selected.contains(type);
        return GestureDetector(
          onTap: () => onToggle(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.mintGreen.withOpacity(0.12)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? AppTheme.mintGreen : AppTheme.border,
                  width: isSelected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: isSelected
                        ? AppTheme.mintGreen
                        : AppTheme.textSecondary,
                    size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: GoogleFonts.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppTheme.mintGreen
                            : AppTheme.textPrimary)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de resumen MPT
// ─────────────────────────────────────────────────────────────────────────────

class _MptResultCard extends StatelessWidget {
  final ServiceBookingState state;

  const _MptResultCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final mins = state.estimatedMinutes ?? 0;
    final staff = state.staffUnitsRequired ?? 1;
    final needsVet = state.requiresVetSupervision ?? false;
    final noNail = !(state.canPerformNailTrimming ?? true);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.mintGreen.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mintGreen.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.mintGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Resumen Operativo MPT',
                    style: GoogleFonts.fredoka(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),

          // ── Main metrics ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Duration
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$mins',
                        style: GoogleFonts.fredoka(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mintGreen,
                          height: 1,
                        ),
                      ),
                      Text('minutos est.',
                          style: GoogleFonts.quicksand(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                Container(width: 1, height: 72, color: AppTheme.border),

                // Staff + flags
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetricRow(
                          icon: Icons.people_alt_rounded,
                          value: '$staff ${staff == 1 ? 'cuidador' : 'cuidadores'}',
                          color: AppTheme.textPrimary,
                        ),
                        const SizedBox(height: 6),
                        if (needsVet)
                          _MetricRow(
                            icon: Icons.local_hospital_rounded,
                            value: 'Sup. veterinaria',
                            color: AppTheme.coralRed,
                          ),
                        if (noNail)
                          _MetricRow(
                            icon: Icons.content_cut_rounded,
                            value: 'Sin corte de uñas',
                            color: AppTheme.goldChampagne,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Penalties ──────────────────────────────────────────────────
          if (state.penaltyReasons.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.goldChampagne.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.goldChampagne),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.goldChampagne, size: 16),
                      const SizedBox(width: 6),
                      Text('Tiempo adicional incluido',
                          style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF92400E))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...state.penaltyReasons.map((r) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ',
                                style: TextStyle(
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(r,
                                  style: GoogleFonts.quicksand(
                                      fontSize: 12,
                                      color: const Color(0xFF78350F))),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MetricRow(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(value,
                style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer de carga para MPT
// ─────────────────────────────────────────────────────────────────────────────

class _MptShimmer extends StatelessWidget {
  const _MptShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
          height: 110,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                  color: AppTheme.mintGreen, strokeWidth: 2.5),
              const SizedBox(height: 12),
              Text('Calculando duración del servicio...',
                  style: GoogleFonts.quicksand(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: AppTheme.surfaceVariant);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector de fechas
// ─────────────────────────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? dt;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.icon,
    required this.dt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(icon, color: AppTheme.mintGreen, size: 22),
      title: Text(label,
          style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary)),
      subtitle: Text(
        dt != null ? _fmt(dt!) : 'Seleccionar fecha y hora',
        style: GoogleFonts.fredoka(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: dt != null ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.textMuted),
      onTap: onTap,
    );
  }

  static String _fmt(DateTime dt) {
    const months = [
      'Ene','Feb','Mar','Abr','May','Jun',
      'Jul','Ago','Sep','Oct','Nov','Dic'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} — $h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección de habilitación sanitaria
// ─────────────────────────────────────────────────────────────────────────────

class _ClearanceSection extends ConsumerWidget {
  final ServiceBookingState state;

  const _ClearanceSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCheck = state.selectedPetId != null &&
        state.checkIn != null &&
        state.checkOut != null;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: canCheck && !state.isCheckingClearance
                ? () => ref
                    .read(serviceBookingProvider.notifier)
                    .checkSanitaryClearance()
                : null,
            icon: state.isCheckingClearance
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: AppTheme.mintGreen, strokeWidth: 2))
                : const Icon(Icons.verified_user_rounded, size: 18),
            label: Text(
              state.isCheckingClearance
                  ? 'Verificando...'
                  : 'Verificar Habilitación Sanitaria',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.mintGreen,
              side: const BorderSide(color: AppTheme.mintGreen),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        if (!canCheck && !state.hasClearanceResult) ...[
          const SizedBox(height: 8),
          Text(
            'Selecciona mascota, fechas y servicios antes de verificar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
                fontSize: 12, color: AppTheme.textMuted),
          ),
        ],

        if (state.hasClearanceResult) ...[
          const SizedBox(height: 12),
          _ClearanceResult(data: state.clearanceData!),
        ],
      ],
    );
  }
}

class _ClearanceResult extends StatelessWidget {
  final SanitaryClearanceData data;

  const _ClearanceResult({required this.data});

  @override
  Widget build(BuildContext context) {
    final cleared = data.isCleared;
    final color = cleared ? const Color(0xFF16A34A) : AppTheme.coralRed;
    final icon =
        cleared ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleared
                          ? 'Habilitada para ingreso'
                          : 'Ingreso bloqueado',
                      style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    Text(
                      'ICD mínimo: ${data.minIcdScore.toStringAsFixed(0)}/100 · Riesgo: ${data.riskLevel.displayLabel}',
                      style: GoogleFonts.quicksand(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Blockers
        if (data.blockers.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...data.blockers.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.coralRed.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.coralRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block_rounded,
                          color: AppTheme.coralRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(b.description,
                            style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: AppTheme.coralRed,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              )),
        ],

        if (data.requiresManualStaffReview) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.goldChampagne.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.goldChampagne),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.manage_search_rounded,
                    color: AppTheme.goldChampagne, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Se requiere revisión manual del staff antes de confirmar el ingreso.',
                    style: GoogleFonts.quicksand(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Autorizaciones legales del dueño
// ─────────────────────────────────────────────────────────────────────────────

class _LegalAuthSection extends ConsumerWidget {
  final ServiceBookingState state;

  const _LegalAuthSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(serviceBookingProvider.notifier);
    return Column(
      children: [
        _AuthSwitch(
          label: 'Medicación de emergencia',
          subtitle: 'Autoriza al staff a administrar medicamentos de urgencia',
          value: state.emergencyMedicationAllowed,
          onChanged: notifier.setEmergencyMedication,
        ),
        _AuthSwitch(
          label: 'Contacto veterinario',
          subtitle: 'Autoriza al staff a contactar a un veterinario',
          value: state.contactVetAllowed,
          onChanged: notifier.setContactVet,
        ),
        _AuthSwitch(
          label: 'Juegos con agua',
          subtitle: 'Autoriza la participación en actividades acuáticas',
          value: state.waterPlayAllowed,
          onChanged: notifier.setWaterPlay,
        ),
        _AuthSwitch(
          label: 'Uso de imágenes y video',
          subtitle: 'Autoriza publicar fotos o videos en redes sociales',
          value: state.mediaUsageAllowed,
          onChanged: notifier.setMediaUsage,
        ),
      ],
    );
  }
}

class _AuthSwitch extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _AuthSwitch({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        title: Text(label,
            style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        subtitle: Text(subtitle,
            style: GoogleFonts.quicksand(
                fontSize: 12, color: AppTheme.textSecondary)),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.mintGreen,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de acción inferior
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final ServiceBookingState state;
  final VoidCallback onSubmit;

  const _SubmitBar({required this.state, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        state.canSubmit && state.isCleared && !state.isSubmitting;

    String hint = '';
    if (!state.canSubmit) {
      hint = 'Selecciona servicios, mascota y fechas.';
    } else if (!state.hasClearanceResult) {
      hint = 'Verifica la habilitación sanitaria primero.';
    } else if (!state.isCleared) {
      hint = 'La mascota no puede ingresar. Revisa las alertas.';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint.isNotEmpty) ...[
            Text(hint,
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                    fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canSubmit ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.border,
                disabledForegroundColor: AppTheme.textMuted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Confirmar Reserva',
                      style: GoogleFonts.fredoka(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de sección genérica
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(title,
                style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
