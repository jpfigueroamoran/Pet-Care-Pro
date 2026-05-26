import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/admin_dashboard_screen.dart';
import '../../features/auth/presentation/screens/unauthorized_screen.dart';
import '../../features/auth/presentation/screens/edit_profile_screen.dart';
import '../../features/pets/presentation/screens/owner_dashboard_screen.dart';
import '../../features/pets/presentation/screens/add_pet_screen.dart';
import '../../features/qr_sharing/presentation/screens/vet_dashboard_screen.dart';
import '../../features/qr_sharing/presentation/screens/scan_qr_screen.dart';
import '../../features/qr_sharing/presentation/screens/share_qr_screen.dart';
import '../../features/medical_history/presentation/screens/medical_history_screen.dart';
import '../../features/medical_history/presentation/screens/add_medical_record_screen.dart';
import '../../features/qr_sharing/presentation/screens/vet_services_screen.dart';
import '../../features/payments/presentation/screens/create_charge_screen.dart';
import '../../features/payments/presentation/screens/owner_payments_screen.dart';
import '../../features/payments/presentation/screens/spei_payment_screen.dart';
import '../../features/payments/presentation/screens/vet_payment_review_screen.dart';
import '../../features/payments/presentation/screens/vet_payment_settings_screen.dart';
import '../../features/payments/presentation/screens/vet_monthly_report_screen.dart';
import '../../features/subscriptions/presentation/screens/vet_subscription_screen.dart';
import '../../features/vet_directory/presentation/screens/vet_directory_screen.dart';
import '../../features/vet_directory/presentation/screens/vet_location_screen.dart';
import '../../features/boarding/presentation/screens/boarding_registration_flow.dart';
import '../../features/boarding/presentation/screens/caretaker_dashboard_screen.dart';
import '../../features/boarding/presentation/screens/groomer_dashboard_screen.dart';
import '../../features/boarding/presentation/screens/owner_reservations_screen.dart';
import '../../features/boarding/presentation/screens/receptionist_dashboard_screen.dart';
import '../../features/boarding/presentation/screens/service_booking_screen.dart';
import '../../features/setup_wizard/presentation/screens/setup_wizard_screen.dart';

// Proveedor global de GoRouter reactivo al estado de autenticación
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    
    // REDIRECT GUARD: Control centralizado de autenticación y roles (RBAC)
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // 1. Caso: No autenticado
      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // 2. Caso: Autenticado e intentando ir a Login/Register -> Redirigir a su Dashboard
      if (isLoggingIn) {
        final role = authState.user!.role;
        return _getDashboardRoute(role);
      }

      // 3. Caso: Protección de Rutas por Roles (Guards)
      final userRole = authState.user!.role;

      // Restricción de Dashboard de Dueño
      if (state.matchedLocation == '/owner-dashboard' && userRole != UserRole.owner) {
        return '/unauthorized';
      }

      // Restricción de rutas exclusivas del veterinario
      const vetOnlyRoutes = ['/vet-dashboard', '/scan-qr', '/vet-services', '/vet-payment-review', '/vet-monthly-report', '/vet-payment-settings', '/vet-subscription', '/vet-location'];
      if (vetOnlyRoutes.contains(state.matchedLocation) && userRole != UserRole.vet) {
        return '/unauthorized';
      }

      // Restricción de dashboards de staff operativo
      if (state.matchedLocation == '/groomer-dashboard' && userRole != UserRole.groomer) {
        return '/unauthorized';
      }
      if (state.matchedLocation == '/caretaker-dashboard' && userRole != UserRole.caretaker) {
        return '/unauthorized';
      }
      if (state.matchedLocation == '/receptionist-dashboard' && userRole != UserRole.receptionist) {
        return '/unauthorized';
      }

      // Restricción de Dashboard de Administrador
      if (state.matchedLocation == '/admin-dashboard' && userRole != UserRole.admin) {
        return '/unauthorized';
      }

      // Wizard de primer uso: admin sin branchId va al wizard (excepto si ya está ahí)
      if (userRole == UserRole.admin &&
          (authState.user!.branchId == null || authState.user!.branchId!.isEmpty) &&
          state.matchedLocation != '/setup-wizard' &&
          state.matchedLocation != '/login' &&
          state.matchedLocation != '/register') {
        return '/setup-wizard';
      }

      // El resto de rutas dinámicas (como historial) se autovalidan en base a RBAC en pantalla
      return null;
    },

    routes: [
      // Rutas de Autenticación
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Dashboards Especializados
      GoRoute(
        path: '/owner-dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/add-pet',
        builder: (context, state) => const AddPetScreen(),
      ),
      GoRoute(
        path: '/vet-dashboard',
        builder: (context, state) => const VetDashboardScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Módulo QR y Escaneo
      GoRoute(
        path: '/scan-qr',
        builder: (context, state) => const ScanQRScreen(),
      ),
      GoRoute(
        path: '/pet/:petId/share',
        builder: (context, state) {
          final petId = state.pathParameters['petId'] ?? '';
          return ShareQRScreen(petId: petId);
        },
      ),

      // Módulo de Historial Clínico
      GoRoute(
        path: '/pet/:petId/history',
        builder: (context, state) {
          final petId = state.pathParameters['petId'] ?? '';
          return MedicalHistoryScreen(petId: petId);
        },
      ),
      GoRoute(
        path: '/pet/:petId/history/add',
        builder: (context, state) {
          final petId = state.pathParameters['petId'] ?? '';
          return AddMedicalRecordScreen(petId: petId);
        },
      ),
      GoRoute(
        path: '/vet-services',
        builder: (context, state) => const VetServicesScreen(),
      ),
      GoRoute(
        path: '/pet/:petId/charge',
        builder: (context, state) {
          final petId = state.pathParameters['petId'] ?? '';
          return CreateChargeScreen(petId: petId);
        },
      ),
      GoRoute(
        path: '/owner-payments',
        builder: (context, state) => const OwnerPaymentsScreen(),
      ),
      GoRoute(
        path: '/payment/:paymentId/spei',
        builder: (context, state) {
          final paymentId = state.pathParameters['paymentId'] ?? '';
          return SpeiPaymentScreen(paymentId: paymentId);
        },
      ),
      GoRoute(
        path: '/vet-payment-review',
        builder: (context, state) => const VetPaymentReviewScreen(),
      ),
      GoRoute(
        path: '/vet-payment-settings',
        builder: (context, state) => const VetPaymentSettingsScreen(),
      ),
      GoRoute(
        path: '/vet-monthly-report',
        builder: (context, state) => const VetMonthlyReportScreen(),
      ),
      GoRoute(
        path: '/vet-subscription',
        builder: (context, state) => const VetSubscriptionScreen(),
      ),

      // ── Módulo Boarding v1.1.0 ────────────────────────────────────────────
      GoRoute(
        path: '/pet/:petId/boarding-registration',
        builder: (context, state) {
          final petId = state.pathParameters['petId'] ?? '';
          final petName = state.uri.queryParameters['petName'] ?? 'Mascota';
          return BoardingRegistrationFlow(petId: petId, petName: petName);
        },
      ),
      GoRoute(
        path: '/pet/:petId/service-booking',
        builder: (context, state) {
          final petId = state.pathParameters['petId'] ?? '';
          final q = state.uri.queryParameters;
          return ServiceBookingScreen(
            petId: petId,
            petName: q['petName'] ?? 'Mascota',
            ownerId: q['ownerId'] ?? '',
            ownerName: q['ownerName'] ?? '',
            facilityRunId: q['runId'] ?? 'run-default',
          );
        },
      ),
      GoRoute(
        path: '/owner-reservations',
        builder: (context, state) => const OwnerReservationsScreen(),
      ),
      GoRoute(
        path: '/setup-wizard',
        builder: (context, state) => const SetupWizardScreen(),
      ),

      // ── Dashboards de Staff Operativo ────────────────────────────────────
      GoRoute(
        path: '/groomer-dashboard',
        builder: (context, state) => const GroomerDashboardScreen(),
      ),
      GoRoute(
        path: '/caretaker-dashboard',
        builder: (context, state) => const CaretakerDashboardScreen(),
      ),
      GoRoute(
        path: '/receptionist-dashboard',
        builder: (context, state) => const ReceptionistDashboardScreen(),
      ),

      // Acceso Denegado
      GoRoute(
        path: '/vet-directory',
        builder: (context, state) => const VetDirectoryScreen(),
      ),
      GoRoute(
        path: '/vet-location',
        builder: (context, state) => const VetLocationScreen(),
      ),

      // Acceso Denegado
      GoRoute(
        path: '/unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),
    ],
    
    // Manejador de errores de rutas no encontradas
    errorBuilder: (context, state) => const UnauthorizedScreen(),
  );
});

// Función de soporte para resolver dashboards
String _getDashboardRoute(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return '/owner-dashboard';
    case UserRole.vet:
      return '/vet-dashboard';
    case UserRole.groomer:
      return '/groomer-dashboard';
    case UserRole.caretaker:
      return '/caretaker-dashboard';
    case UserRole.receptionist:
      return '/receptionist-dashboard';
    case UserRole.admin:
      return '/admin-dashboard';
  }
}
