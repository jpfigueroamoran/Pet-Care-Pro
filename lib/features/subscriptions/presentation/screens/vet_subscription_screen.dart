import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/subscription_tier.dart';
import '../providers/subscription_provider.dart';

class VetSubscriptionScreen extends ConsumerStatefulWidget {
  const VetSubscriptionScreen({super.key});

  @override
  ConsumerState<VetSubscriptionScreen> createState() =>
      _VetSubscriptionScreenState();
}

class _VetSubscriptionScreenState extends ConsumerState<VetSubscriptionScreen> {
  String? _loadingTier;
  bool _isRefreshing = false;

  Future<void> _subscribe(String tierKey) async {
    setState(() => _loadingTier = tierKey);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createMercadoPagoSubscription');
      final result = await callable.call({'tier': tierKey});
      final checkoutUrl = result.data['checkoutUrl'] as String?;

      if (checkoutUrl != null && mounted) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Completa tu suscripción en MercadoPago y regresa aquí para verificarla.',
                ),
                backgroundColor: AppTheme.mintGreen,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar suscripción: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTier = null);
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(authNotifierProvider.notifier).refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado de suscripción actualizado.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(subscriptionTierProvider);
    final trialDays = ref.watch(trialDaysRemainingProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mi Suscripción'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.mintGreen),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Verificar estado',
              onPressed: _refreshStatus,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Current status banner ──────────────────────────────────────────
          _StatusBanner(tier: tier, trialDays: trialDays, user: user),
          const SizedBox(height: 28),

          const Text(
            'Elige tu plan',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '6 meses gratis incluidos al activar tu cuenta. Sin cobros hasta que decidas continuar.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // ── Tier cards ─────────────────────────────────────────────────────
          _TierCard(
            tier: SubscriptionTier.basico,
            currentTier: tier,
            isLoading: _loadingTier == 'basico',
            onSubscribe: () => _subscribe('basico'),
          ),
          const SizedBox(height: 16),
          _TierCard(
            tier: SubscriptionTier.profesional,
            currentTier: tier,
            isRecommended: true,
            isLoading: _loadingTier == 'profesional',
            onSubscribe: () => _subscribe('profesional'),
          ),
          const SizedBox(height: 16),
          _TierCard(
            tier: SubscriptionTier.premium,
            currentTier: tier,
            isLoading: _loadingTier == 'premium',
            onSubscribe: () => _subscribe('premium'),
          ),
          const SizedBox(height: 28),

          // ── Feature comparison table ───────────────────────────────────────
          _FeatureTable(),
          const SizedBox(height: 24),

          // ── Footer note ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppTheme.textMuted),
                    SizedBox(width: 8),
                    Text(
                      'Pago seguro con MercadoPago',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Puedes cancelar en cualquier momento desde tu cuenta de MercadoPago. '
                  'El acceso permanece activo hasta el final del período pagado.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Status Banner ──────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final SubscriptionTier tier;
  final int? trialDays;
  final dynamic user;

  const _StatusBanner({required this.tier, required this.trialDays, required this.user});

  @override
  Widget build(BuildContext context) {
    if (tier == SubscriptionTier.trial && trialDays != null) {
      return _buildTrialBanner(trialDays!);
    }
    if (tier == SubscriptionTier.free) {
      return _buildFreeBanner();
    }
    return _buildActiveBanner(tier, user);
  }

  Widget _buildTrialBanner(int days) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C828A), Color(0xFF1A9BAF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mintGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prueba Gratuita Activa',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '$days días restantes — acceso completo sin costo',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.coralRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.coralRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, color: AppTheme.coralRed, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Gratuito',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'Funciones limitadas — elige un plan para desbloquear todo',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBanner(SubscriptionTier tier, dynamic user) {
    final mpStatus = user?.mpSubscriptionStatus as String?;
    final isPaused = mpStatus == 'paused';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8962B), Color(0xFFF0A830)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldChampagne.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaused ? Icons.pause_circle_outline : Icons.verified,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaused ? 'Suscripción pausada' : 'Plan ${tier.displayName} activo',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaused
                      ? 'Reanuda tu suscripción en MercadoPago'
                      : '\$${tier.monthlyPriceMxn} MXN / mes · Renovación automática',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tier Card ──────────────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final SubscriptionTier tier;
  final SubscriptionTier currentTier;
  final bool isRecommended;
  final bool isLoading;
  final VoidCallback onSubscribe;

  const _TierCard({
    required this.tier,
    required this.currentTier,
    required this.isLoading,
    required this.onSubscribe,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentTier == tier;
    final borderColor = isRecommended
        ? AppTheme.goldChampagne
        : isActive
            ? AppTheme.mintGreen
            : AppTheme.border;

    final features = _featuresForTier(tier);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isRecommended || isActive ? 2 : 1,
        ),
        boxShadow: isRecommended
            ? [
                BoxShadow(
                  color: AppTheme.goldChampagne.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: isRecommended
                  ? AppTheme.goldChampagne.withValues(alpha: 0.08)
                  : AppTheme.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tier.displayName,
                            style: TextStyle(
                              color: isRecommended
                                  ? AppTheme.goldChampagne
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.goldChampagne,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'RECOMENDADO',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.mintGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ACTIVO',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '\$${tier.monthlyPriceMxn}',
                              style: TextStyle(
                                color: isRecommended
                                    ? AppTheme.goldChampagne
                                    : AppTheme.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text: ' MXN / mes',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  tier == SubscriptionTier.premium
                      ? Icons.workspace_premium
                      : tier == SubscriptionTier.profesional
                          ? Icons.star
                          : Icons.check_circle_outline,
                  color: isRecommended ? AppTheme.goldChampagne : AppTheme.mintGreen,
                  size: 32,
                ),
              ],
            ),
          ),

          // ── Features list ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: features
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              f.$2 ? Icons.check_circle : Icons.cancel_outlined,
                              size: 18,
                              color: f.$2 ? AppTheme.mintGreen : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                f.$1,
                                style: TextStyle(
                                  color: f.$2
                                      ? AppTheme.textPrimary
                                      : AppTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

          // ── CTA ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isActive || isLoading ? null : onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecommended
                      ? AppTheme.goldChampagne
                      : AppTheme.mintGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isActive
                      ? AppTheme.mintGreen.withValues(alpha: 0.4)
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isActive ? 'Plan Actual' : 'Suscribirse',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<(String, bool)> _featuresForTier(SubscriptionTier t) {
    switch (t) {
      case SubscriptionTier.basico:
        return [
          ('Hasta 25 pacientes activos', true),
          ('Todos los métodos de cobro (SPEI, efectivo, terminal)', true),
          ('Reporte PDF de transacciones', true),
          ('Directorio de veterinarios (posición estándar)', true),
          ('Historial clínico — 12 meses', true),
          ('Recordatorios de vacunación automáticos', false),
          ('Posición destacada en directorio', false),
          ('Badge verificado', false),
        ];
      case SubscriptionTier.profesional:
        return [
          ('Pacientes activos ilimitados', true),
          ('Todos los métodos de cobro (SPEI, efectivo, terminal)', true),
          ('Reporte PDF de transacciones', true),
          ('Posición destacada en directorio', true),
          ('Historial clínico completo', true),
          ('Recordatorios de vacunación automáticos', true),
          ('Badge verificado', false),
          ('Posición top del directorio', false),
        ];
      case SubscriptionTier.premium:
        return [
          ('Pacientes activos ilimitados', true),
          ('Todos los métodos de cobro (SPEI, efectivo, terminal)', true),
          ('Reporte PDF de transacciones', true),
          ('Top del directorio (máxima visibilidad)', true),
          ('Historial clínico completo', true),
          ('Recordatorios de vacunación automáticos', true),
          ('Badge verificado en tu perfil', true),
          ('Soporte prioritario', true),
        ];
      default:
        return [];
    }
  }
}

// ── Feature comparison table ───────────────────────────────────────────────────

class _FeatureTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Comparación de planes',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          _tableRow('Pacientes activos', ['5', '25', '∞', '∞'], header: true),
          _tableRow('Métodos de cobro', ['Solo efectivo', 'Todos', 'Todos', 'Todos']),
          _tableRow('Reporte PDF', ['—', '✓', '✓', '✓']),
          _tableRow('Directorio', ['No', 'Estándar', 'Destacado', 'Top']),
          _tableRow('Historial clínico', ['3 meses', '12 meses', 'Completo', 'Completo']),
          _tableRow('Recordatorios vac.', ['—', '—', '✓', '✓']),
          _tableRow('Badge verificado', ['—', '—', '—', '✓'], last: true),
        ],
      ),
    );
  }

  Widget _tableRow(String feature, List<String> values,
      {bool header = false, bool last = false}) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                feature,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),
            ...values.asMap().entries.map((e) {
              final labels = ['Free', 'Básico', 'Pro', 'Premium'];
              return Expanded(
                flex: 2,
                child: Column(
                  children: [
                    if (header)
                      Text(
                        labels[e.key],
                        style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: e.value == '—'
                            ? AppTheme.textMuted
                            : e.value == '✓'
                                ? AppTheme.mintGreen
                                : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
