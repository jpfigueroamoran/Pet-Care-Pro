import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/entities/payment_entity.dart';

// Proveedor para obtener el perfil del veterinario (CLABE)
final vetProfileForPaymentProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, vetId) async {
  final doc = await FirebaseFirestore.instance.demoCollection('users').doc(vetId).get();
  return doc.exists ? doc.data() : null;
});

class SpeiPaymentScreen extends ConsumerStatefulWidget {
  final String paymentId;
  const SpeiPaymentScreen({super.key, required this.paymentId});

  @override
  ConsumerState<SpeiPaymentScreen> createState() => _SpeiPaymentScreenState();
}

class _SpeiPaymentScreenState extends ConsumerState<SpeiPaymentScreen> {
  XFile? _selectedImage;
  bool _isUploading = false;
  double _uploadProgress = 0;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _submitComprobante(PaymentEntity payment) async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final uid = ref.read(currentUserProvider)?.uid ?? '';
      final bytes = await _selectedImage!.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('comprobantes/$uid/${widget.paymentId}/$fileName');

      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      await ref.read(paymentRepositoryProvider).submitComprobante(widget.paymentId, downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Comprobante enviado! El veterinario lo revisará pronto.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir comprobante: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentAsync = ref.watch(singlePaymentStreamProvider(widget.paymentId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pago por SPEI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: paymentAsync.when(
        data: (payment) {
          if (payment == null) {
            return Center(
              child: Text('Pago no encontrado.', style: TextStyle(color: AppTheme.textMuted)),
            );
          }

          if (payment.status == 'pending_review') {
            return _buildReviewPendingState(payment);
          }

          if (payment.status == 'paid') {
            return _buildPaidState(payment);
          }

          return _buildPaymentForm(payment);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.mintGreen)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.coralRed))),
      ),
    );
  }

  Widget _buildPaymentForm(PaymentEntity payment) {
    final vetProfileAsync = ref.watch(vetProfileForPaymentProvider(payment.vetId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta de instrucciones (gradient banner)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.mintGreen, AppTheme.skyBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transferencia SPEI',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Sin comisiones · Instantáneo · Seguro',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Datos del cobro
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DETALLES DEL COBRO',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 16),
                _buildDetailRow('Paciente:', payment.petName),
                _buildDetailRow('Veterinario:', payment.vetName),
                _buildDetailRow('Servicios:', payment.services.map((s) => s.name).join(', ')),
                const Divider(color: AppTheme.border, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a transferir:',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                    Text(
                      '\$${payment.totalAmount.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        color: AppTheme.goldChampagne,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // CLABE del veterinario
          vetProfileAsync.when(
            data: (vetData) {
              final clabe = vetData?['clabe'] as String?;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: clabe != null
                        ? AppTheme.mintGreen.withOpacity(0.4)
                        : AppTheme.coralRed.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLABE INTERBANCARIA DESTINO',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    if (clabe != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              clabe,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: clabe));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('CLABE copiada al portapapeles'),
                                  backgroundColor: AppTheme.mintGreen,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, color: AppTheme.mintGreen),
                            tooltip: 'Copiar CLABE',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Beneficiario: ${payment.vetName}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.peachCream.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Concepto: Pago ${widget.paymentId.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(color: AppTheme.goldChampagne, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.coralRed, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'El veterinario aún no ha configurado su CLABE. Contáctalo directamente para coordinar el pago.',
                        style: TextStyle(color: AppTheme.coralRed, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(color: AppTheme.mintGreen),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // Subir comprobante
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('COMPROBANTE DE TRANSFERENCIA',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 16),

                if (_selectedImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImage!.path),
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedImage = null),
                    icon: const Icon(Icons.delete_outline, color: AppTheme.coralRed),
                    label: const Text('Eliminar imagen', style: TextStyle(color: AppTheme.coralRed)),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.skyBlue),
                          label: const Text('CÁMARA', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.skyBlue),
                            foregroundColor: AppTheme.skyBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_outlined, color: AppTheme.skyBlue),
                          label: const Text('GALERÍA', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.skyBlue),
                            foregroundColor: AppTheme.skyBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (_isUploading) ...[
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: AppTheme.border,
              color: AppTheme.mintGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              'Subiendo comprobante... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          ElevatedButton.icon(
            onPressed: _selectedImage == null || _isUploading
                ? null
                : () => _submitComprobante(payment),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            label: const Text(
              'ENVIAR COMPROBANTE',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPendingState(PaymentEntity payment) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.goldChampagne.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.goldChampagne.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.hourglass_top_rounded, size: 64, color: AppTheme.goldChampagne),
            ),
            const SizedBox(height: 24),
            const Text('Comprobante en Revisión',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Tu comprobante fue enviado exitosamente. El veterinario lo revisará y confirmará el pago.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              '\$${payment.totalAmount.toStringAsFixed(2)} MXN',
              style: const TextStyle(color: AppTheme.goldChampagne, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidState(PaymentEntity payment) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.mintGreen.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.mintGreen.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.mintGreen),
            ),
            const SizedBox(height: 24),
            const Text('¡Pago Confirmado!',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              '\$${payment.totalAmount.toStringAsFixed(2)} MXN',
              style: const TextStyle(color: AppTheme.mintGreen, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
