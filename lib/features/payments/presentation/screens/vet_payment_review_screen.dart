import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/entities/payment_entity.dart';

class VetPaymentReviewScreen extends ConsumerWidget {
  const VetPaymentReviewScreen({super.key});

  String _formatDateTime(DateTime dt) {
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year} · ${dt.hour}:$min h';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final paymentsAsync = ref.watch(vetPendingReviewStreamProvider(user?.uid ?? ''));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Revisión de Comprobantes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: paymentsAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.mintGreen.withOpacity(0.2), width: 2),
                      ),
                      child: const Icon(Icons.task_alt_outlined, size: 64, color: AppTheme.mintGreen),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Sin comprobantes pendientes',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Todos los comprobantes han sido revisados. Aparecerán aquí cuando un dueño envíe su transferencia SPEI.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _PaymentReviewCard(
                payment: payment,
                formatDateTime: _formatDateTime,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $err', style: const TextStyle(color: AppTheme.coralRed)),
          ),
        ),
      ),
    );
  }
}

class _PaymentReviewCard extends ConsumerStatefulWidget {
  final PaymentEntity payment;
  final String Function(DateTime) formatDateTime;

  const _PaymentReviewCard({required this.payment, required this.formatDateTime});

  @override
  ConsumerState<_PaymentReviewCard> createState() => _PaymentReviewCardState();
}

class _PaymentReviewCardState extends ConsumerState<_PaymentReviewCard> {
  bool _isProcessing = false;

  Future<void> _approve() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);
    try {
      if (widget.payment.status == 'awaiting_physical_payment') {
        await ref.read(paymentRepositoryProvider).approvePhysicalPayment(widget.payment.id);
      } else {
        final callable = FirebaseFunctions.instance.httpsCallable('approveComprobante');
        await callable.call({'paymentId': widget.payment.id});
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pago aprobado exitosamente!'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showRejectDialog() async {
    HapticFeedback.lightImpact();
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppTheme.coralRed),
            SizedBox(width: 8),
            Text('Rechazar Comprobante', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El dueño recibirá esta razón de rechazo y podrá subir un nuevo comprobante.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ej: El comprobante no muestra el monto correcto...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.coralRed, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralRed),
            child: const Text('RECHAZAR'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(paymentRepositoryProvider).rejectPayment(
          widget.payment.id,
          reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comprobante rechazado. El dueño será notificado.'),
              backgroundColor: AppTheme.coralRed,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.coralRed),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _viewFullImage() {
    if (widget.payment.comprobanteUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: widget.payment.comprobanteUrl!,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: AppTheme.mintGreen),
            ),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.textMuted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.goldChampagne.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mintGreen.withOpacity(0.05),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paciente: ${payment.petName}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.formatDateTime(payment.comprobanteUploadedAt ?? payment.createdAt),
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.goldChampagne.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.goldChampagne.withOpacity(0.4)),
                  ),
                  child: Text(
                    payment.status == 'awaiting_physical_payment' ? 'EN CAJA' : 'EN REVISIÓN',
                    style: TextStyle(
                      color: payment.status == 'awaiting_physical_payment' ? AppTheme.skyBlue : AppTheme.goldChampagne,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.border, height: 1),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (payment.comprobanteUrl != null) ...[
                  GestureDetector(
                    onTap: _viewFullImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CachedNetworkImage(
                            imageUrl: payment.comprobanteUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 180,
                              color: AppTheme.surfaceVariant,
                              child: const Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 180,
                              color: AppTheme.surfaceVariant,
                              child: const Icon(Icons.broken_image, color: AppTheme.textMuted, size: 48),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Toca para ampliar',
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (payment.status == 'awaiting_physical_payment') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.skyBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          payment.selectedPaymentMethod == 'terminal' ? Icons.point_of_sale_outlined : Icons.payments_outlined,
                          color: AppTheme.skyBlue,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment.selectedPaymentMethod == 'terminal' ? 'Pago con Terminal (TPV)' : 'Pago en Efectivo',
                                style: const TextStyle(color: AppTheme.skyBlue, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'El dueño indicó que pagará físicamente en el consultorio. Confirma al recibir el dinero.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monto declarado:', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                    Text(
                      '\$${payment.totalAmount.toStringAsFixed(2)} MXN',
                      style: const TextStyle(color: AppTheme.goldChampagne, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (_isProcessing)
                  const Center(child: CircularProgressIndicator(color: AppTheme.mintGreen))
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showRejectDialog,
                          icon: const Icon(Icons.cancel_outlined, color: AppTheme.coralRed, size: 18),
                          label: const Text('RECHAZAR', style: TextStyle(color: AppTheme.coralRed, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.coralRed),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _approve,
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                          label: Text(
                            payment.status == 'awaiting_physical_payment' ? 'CONFIRMAR PAGO' : 'APROBAR',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.mintGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
