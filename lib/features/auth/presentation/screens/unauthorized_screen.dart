import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../domain/entities/user_entity.dart';

class UnauthorizedScreen extends ConsumerWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFEF0F0),
              AppTheme.background,
              Color(0xFFFEF0F0),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.coralRed.withOpacity(0.10),
                    border: Border.all(color: AppTheme.coralRed.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.gpp_bad_outlined,
                    size: 64,
                    color: AppTheme.coralRed,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Acceso Restringido',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu rol actual (${user?.role.name.toUpperCase() ?? 'N/A'}) no cuenta con los permisos necesarios para visualizar esta sección.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textMuted,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 40),

                ElevatedButton.icon(
                  onPressed: () {
                    if (user != null) {
                      switch (user.role) {
                        case UserRole.owner:
                          context.go('/owner-dashboard');
                          break;
                        case UserRole.vet:
                          context.go('/vet-dashboard');
                          break;
                        case UserRole.admin:
                          context.go('/admin-dashboard');
                          break;
                      }
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('VOLVER AL PANEL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).logout();
                    context.go('/login');
                  },
                  child: const Text(
                    'Cerrar Sesión e Ingresar con otra cuenta',
                    style: TextStyle(color: AppTheme.textMuted, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
