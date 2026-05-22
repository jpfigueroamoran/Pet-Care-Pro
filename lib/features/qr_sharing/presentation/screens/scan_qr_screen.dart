import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ScanQRScreen extends ConsumerStatefulWidget {
  const ScanQRScreen({super.key});

  @override
  ConsumerState<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends ConsumerState<ScanQRScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;
  bool _isValidating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSuccess(String tokenId) async {
    if (_hasScanned || _isValidating) return;

    // Haptic inmediato al detectar el QR
    HapticFeedback.mediumImpact();

    setState(() {
      _hasScanned = true;
      _isValidating = true;
    });

    try {
      _controller.stop();
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Validando arrendamiento clínico con el servidor...'),
        backgroundColor: AppTheme.skyBlue,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final currentUser = ref.read(currentUserProvider);
      final vetId = currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('validateQrLease');
      final response = await callable.call(<String, dynamic>{
        'tokenId': tokenId,
        'vetId': vetId,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] == true) {
        final String petId = data['petId'] as String;

        if (mounted) {
          // Doble pulso fuerte = acceso concedido
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 120));
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Acceso Concedido! Arrendamiento clínico activo por 2 horas.'),
              backgroundColor: AppTheme.mintGreen,
            ),
          );

          setState(() {
            _isValidating = false;
          });

          context.replace('/pet/$petId/history');
        }
      } else {
        _handleValidationError('Respuesta del servidor no válida.');
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        _handlePatientLimitReached(e.message ?? 'Límite de pacientes activos alcanzado.');
      } else {
        _handleValidationError(e.message ?? 'Error de validación en el servidor.');
      }
    } catch (e) {
      _handleValidationError('Error de red al validar pase QR: $e');
    }
  }

  void _handlePatientLimitReached(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _hasScanned = false;
      _isValidating = false;
    });
    try { _controller.start(); } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppTheme.goldChampagne),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Límite Alcanzado',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: AppTheme.textMuted, height: 1.5)),
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
                  Icon(Icons.star, color: AppTheme.goldChampagne, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Actualiza a Básico (25 pacientes) o Profesional/Premium (ilimitados).',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/vet-subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldChampagne,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ver Planes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleValidationError(String message) {
    if (!mounted) return;

    // Triple pulso corto = error / acceso denegado
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 80), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 160), HapticFeedback.heavyImpact);

    setState(() {
      _hasScanned = false;
      _isValidating = false;
    });

    try {
      _controller.start();
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.coralRed),
            SizedBox(width: 8),
            Text('Error de Acceso', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            const Text(
              'Consejo: Genera primero un pase QR real desde el panel del Dueño para Max (pet_001) y escanea su ID aquí.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(color: AppTheme.mintGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Pase QR', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (!_isValidating)
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  _onSuccess(barcodes.first.rawValue!);
                }
              },
            )
          else
            Container(
              color: Colors.black87,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.mintGreen),
              ),
            ),

          if (!_isValidating)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Encuadra el código QR del dueño',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.skyBlue, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.mintGreen,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.mintGreen.withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            final controller = TextEditingController();
                            return AlertDialog(
                              backgroundColor: AppTheme.surface,
                              title: const Text('Simulador de Escáner QR',
                                  style: TextStyle(color: AppTheme.textPrimary)),
                              content: TextField(
                                controller: controller,
                                style: const TextStyle(color: AppTheme.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Pegar Token ID generado por el Dueño',
                                  labelStyle: TextStyle(color: AppTheme.textMuted),
                                  hintText: 'Ej. zX9kLp10sA',
                                  hintStyle: TextStyle(color: AppTheme.textMuted),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CANCELAR',
                                      style: TextStyle(color: AppTheme.textMuted)),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final tokenId = controller.text.trim();
                                    Navigator.pop(context);
                                    if (tokenId.isNotEmpty) {
                                      _onSuccess(tokenId);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.mintGreen),
                                  child: const Text('ESCANEAR'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      label: const Text('SIMULAR ESCANEO DE QR (DEMO)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.skyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
