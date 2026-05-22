import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/payment_entity.dart';
import '../../data/repositories/payment_repository.dart';

class OwnerPaymentsScreen extends ConsumerStatefulWidget {
  const OwnerPaymentsScreen({super.key});

  @override
  ConsumerState<OwnerPaymentsScreen> createState() => _OwnerPaymentsScreenState();
}

class _OwnerPaymentsScreenState extends ConsumerState<OwnerPaymentsScreen> {

  String _formatDateTime(DateTime dt) {
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final minutes = dt.minute.toString().padLeft(2, '0');
    final hours = dt.hour.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year} - $hours:$minutes';
  }

  Future<void> _processPayment(PaymentEntity payment) async {
    Map<String, bool> allowed;

    if (payment.vetId.isNotEmpty) {
      try {
        final vetDoc = await FirebaseFirestore.instance
            .demoCollection('users')
            .doc(payment.vetId)
            .get();
        if (vetDoc.exists) {
          final d = vetDoc.data()!;
          allowed = {
            'spei': d['acceptsSpei'] as bool? ?? true,
            'cash': d['acceptsCash'] as bool? ?? false,
            'terminal': d['acceptsCardTerminal'] as bool? ?? false,
          };
        } else {
          allowed = payment.allowedPaymentMethods ?? {'spei': true};
        }
      } catch (_) {
        allowed = payment.allowedPaymentMethods ?? {'spei': true};
      }
    } else {
      allowed = payment.allowedPaymentMethods ?? {'spei': true};
    }

    final bool acceptsSpei = allowed['spei'] == true;
    final bool acceptsCash = allowed['cash'] == true;
    final bool acceptsTerminal = allowed['terminal'] == true;
    final bool hasAnyMethod = acceptsSpei || acceptsCash || acceptsTerminal;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Selecciona un Método de Pago',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Elige una de las opciones habilitadas por el veterinario.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!hasAnyMethod)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.textMuted, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'El veterinario aún no ha configurado métodos de pago. Contáctalo directamente para coordinar el pago.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (acceptsSpei)
                  _buildPaymentOptionBtn(
                    ctx,
                    title: 'Transferencia SPEI',
                    icon: Icons.account_balance,
                    color: AppTheme.mintGreen,
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/payment/${payment.id}/spei');
                    },
                  ),
                if (acceptsCash)
                  _buildPaymentOptionBtn(
                    ctx,
                    title: 'Efectivo en Caja',
                    icon: Icons.payments_outlined,
                    color: AppTheme.skyBlue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _markAsAwaitingPhysical(payment.id, 'cash');
                    },
                  ),
                if (acceptsTerminal)
                  _buildPaymentOptionBtn(
                    ctx,
                    title: 'Terminal Física (TPV)',
                    icon: Icons.point_of_sale_outlined,
                    color: AppTheme.goldChampagne,
                    onTap: () {
                      Navigator.pop(ctx);
                      _markAsAwaitingPhysical(payment.id, 'terminal');
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAsAwaitingPhysical(String paymentId, String method) async {
    try {
      await FirebaseFirestore.instance.demoCollection('payments').doc(paymentId).update({
        'status': 'awaiting_physical_payment',
        'selectedPaymentMethod': method,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago marcado como físico. Por favor entrega el dinero al veterinario.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    }
  }

  Widget _buildPaymentOptionBtn(BuildContext ctx, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final paymentsAsync = ref.watch(ownerPaymentsStreamProvider(user?.uid ?? ''));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mis Pagos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: paymentsAsync.when(
        data: (payments) {
          final pending = payments
              .where((p) => p.status == 'pending' || p.status == 'pending_review' || p.status == 'rejected')
              .toList();
          final history = payments.where((p) => p.status == 'paid').toList();

          if (payments.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceVariant,
                      border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2), width: 2),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.skyBlue),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Sin Transacciones',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tienes cargos pendientes ni pagos realizados registrados en tu cuenta.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: TabBar(
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('PENDIENTES'),
                            if (pending.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.coralRed,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${pending.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(text: 'HISTORIAL'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPaymentList(pending, isPending: true),
                      _buildPaymentList(history, isPending: false),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error al cargar pagos: $err', style: const TextStyle(color: AppTheme.coralRed)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending_review':
        color = AppTheme.goldChampagne;
        label = 'EN REVISIÓN';
        break;
      case 'rejected':
        color = AppTheme.coralRed;
        label = 'RECHAZADO';
        break;
      case 'paid':
        color = AppTheme.mintGreen;
        label = 'PAGADO';
        break;
      case 'awaiting_physical_payment':
        color = AppTheme.skyBlue;
        label = 'ESPERANDO CAJA';
        break;
      default:
        color = AppTheme.coralRed;
        label = 'PENDIENTE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildPaymentList(List<PaymentEntity> list, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline_outlined : Icons.receipt_long_outlined,
              size: 48,
              color: isPending ? AppTheme.mintGreen : AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? '¡Al día! No tienes pagos pendientes' : 'Historial de pagos vacío',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final payment = list[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPending
                  ? AppTheme.coralRed.withValues(alpha: 0.2)
                  : AppTheme.border,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.mintGreen.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          payment.vetName,
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    _buildStatusChip(payment.status),
                  ],
                ),
              ),
              const Divider(color: AppTheme.border, height: 1),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paciente: ${payment.petName}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    ...payment.services.map((svc) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(svc.name, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                            Text(
                              '\$${svc.price.toStringAsFixed(0)}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: AppTheme.border, height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fecha de Cargo', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateTime(payment.createdAt),
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        Text(
                          '\$${payment.totalAmount.toStringAsFixed(2)} MXN',
                          style: const TextStyle(
                            color: AppTheme.goldChampagne,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    if (payment.status == 'pending') ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _processPayment(payment); // intentionally not awaited — shows modal async
                        },
                        icon: const Icon(Icons.payment, size: 18, color: Colors.white),
                        label: const Text('PAGAR', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ] else if (payment.status == 'awaiting_physical_payment') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.storefront_outlined, color: AppTheme.skyBlue, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Por favor paga en caja. Esperando confirmación del veterinario.',
                                style: TextStyle(color: AppTheme.skyBlue, fontSize: 12, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (payment.status == 'pending_review') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.goldChampagne.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.goldChampagne.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, color: AppTheme.goldChampagne, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Comprobante enviado. Esperando revisión del veterinario.',
                                style: TextStyle(color: AppTheme.goldChampagne, fontSize: 12, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (payment.status == 'rejected') ...[
                      const SizedBox(height: 16),
                      if (payment.rejectionReason != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.coralRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.coralRed, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  payment.rejectionReason!,
                                  style: const TextStyle(color: AppTheme.coralRed, fontSize: 12, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: () => _processPayment(payment), // intentionally not awaited
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                        label: const Text('REINTENTAR PAGO', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.coralRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
