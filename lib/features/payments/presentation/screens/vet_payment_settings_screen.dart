import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class VetPaymentSettingsScreen extends ConsumerStatefulWidget {
  const VetPaymentSettingsScreen({super.key});

  @override
  ConsumerState<VetPaymentSettingsScreen> createState() => _VetPaymentSettingsScreenState();
}

class _VetPaymentSettingsScreenState extends ConsumerState<VetPaymentSettingsScreen> {
  bool _acceptsSpei = true;
  bool _acceptsCash = false;
  bool _acceptsCardTerminal = false;
  bool _isLoading = false;

  late TextEditingController _clabeController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _acceptsSpei = user?.acceptsSpei ?? true;
    _acceptsCash = user?.acceptsCash ?? false;
    _acceptsCardTerminal = user?.acceptsCardTerminal ?? false;
    _clabeController = TextEditingController(text: user?.clabe ?? '');
  }

  @override
  void dispose() {
    _clabeController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    
    // Si activa SPEI, validamos CLABE
    if (_acceptsSpei) {
      final clabe = _clabeController.text.trim();
      if (clabe.length != 18 || int.tryParse(clabe) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresa una CLABE interbancaria válida de 18 dígitos para cobros SPEI.'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      await ref.read(authNotifierProvider.notifier).updateVetClabe(clabe);
    }

    try {
      await ref.read(authNotifierProvider.notifier).updateVetPaymentConfig(
        acceptsSpei: _acceptsSpei,
        acceptsCash: _acceptsCash,
        acceptsCardTerminal: _acceptsCardTerminal,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración de cobros guardada correctamente.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Configuración de Cobros', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Métodos de Pago Aceptados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona los métodos por los cuales los clientes podrán pagarte las consultas y servicios.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // SPEI Toggle
            _buildToggleCard(
              title: 'Transferencia SPEI',
              subtitle: 'Recibe pagos directamente a tu cuenta bancaria',
              icon: Icons.account_balance,
              value: _acceptsSpei,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _acceptsSpei = val);
              },
            ),
            
            if (_acceptsSpei)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                child: TextField(
                  controller: _clabeController,
                  keyboardType: TextInputType.number,
                  maxLength: 18,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Cuenta CLABE (18 dígitos)',
                    hintText: '012345678901234567',
                    prefixIcon: const Icon(Icons.numbers, color: AppTheme.mintGreen),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),

            // Efectivo Toggle
            _buildToggleCard(
              title: 'Efectivo en Consultorio',
              subtitle: 'Los clientes pagarán en caja tras la consulta',
              icon: Icons.payments_outlined,
              value: _acceptsCash,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _acceptsCash = val);
              },
            ),
            const SizedBox(height: 16),

            // Terminal Toggle
            _buildToggleCard(
              title: 'Terminal Física (TPV)',
              subtitle: 'Tienes tu propia terminal para cobro con tarjeta',
              icon: Icons.point_of_sale_outlined,
              value: _acceptsCardTerminal,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _acceptsCardTerminal = val);
              },
            ),
            const SizedBox(height: 16),

            // Tarjeta Online (Proximamente)
            Opacity(
              opacity: 0.6,
              child: _buildToggleCard(
                title: 'Tarjeta en App (Stripe)',
                subtitle: 'Próximamente: Cobros automáticos',
                icon: Icons.credit_card,
                value: false,
                onChanged: null, // Deshabilitado temporalmente
              ),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('GUARDAR CONFIGURACIÓN', style: TextStyle(letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? AppTheme.mintGreen.withOpacity(0.5) : AppTheme.border,
          width: value ? 2 : 1,
        ),
        boxShadow: value ? [
          BoxShadow(
            color: AppTheme.mintGreen.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.mintGreen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Icon(icon, color: value ? AppTheme.mintGreen : AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 36.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
