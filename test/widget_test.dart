import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petcare_pro/main.dart';
import 'package:petcare_pro/features/auth/presentation/providers/auth_provider.dart';
import 'package:petcare_pro/features/auth/domain/entities/user_entity.dart';

// FakeAuthNotifier extiende AuthNotifier
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier() : super();

  @override
  Future<void> login(String email, String password, UserRole selectedDemoRole) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 10));
    state = AuthState(
      user: UserEntity(
        uid: 'fake_uid',
        email: email,
        displayName: 'Usuario Fake',
        role: selectedDemoRole,
      ),
      isLoading: false,
    );
  }

  @override
  Future<void> register(String name, String email, String password, UserRole role, String? license, {String? branchName}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 10));
    state = AuthState(
      user: UserEntity(
        uid: 'fake_uid',
        email: email,
        displayName: name,
        role: role,
        branchId: branchName,
        professionalLicense: license,
      ),
      isLoading: false,
    );
  }

  @override
  Future<void> logout() async {
    state = const AuthState();
  }
}

void main() {
  testWidgets('Smoke test - Verificar carga de la pantalla de inicio de sesion', (WidgetTester tester) async {
    // Construir la app dentro de un ProviderScope con overrides para aislar Firebase en los tests
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => FakeAuthNotifier()),
        ],
        child: const PetCareProApp(),
      ),
    );

    // Esperar a que se procese la navegación inicial
    await tester.pumpAndSettle();

    // Verificar que el título de la plataforma y el subtítulo estén presentes en la LoginScreen
    expect(find.text('PetCare Pro'), findsOneWidget);
    expect(find.text('Expediente Clínico Digital Multirrol'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
  });
}
