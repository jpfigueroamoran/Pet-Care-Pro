import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../domain/entities/user_entity.dart';

class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserEntity? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  /// Escucha los cambios del estado de autenticación y carga el perfil de Firestore automáticamente
  void _init() {
    // Si Firebase no está inicializado (como en las pruebas unitarias/widget), retornamos de forma segura
    if (Firebase.apps.isEmpty) {
      return;
    }
    
    FirebaseAuth.instance.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        state = const AuthState();
      } else {
        await _loadUserProfile(firebaseUser);
      }
    });
  }

  /// Carga el perfil del usuario desde Cloud Firestore
  Future<void> _loadUserProfile(User firebaseUser) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .demoCollection('users')
          .doc(firebaseUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final roleStr = data['role'] as String? ?? 'owner';
        final role = UserRole.values.firstWhere(
          (e) => e.name == roleStr,
          orElse: () => UserRole.owner,
        );

        final servicesList = data['services'] as List<dynamic>? ?? [];
        final services = servicesList
            .map((item) => VetService.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();

        final trialEndsAtRaw = data['trialEndsAt'];
        final userEntity = UserEntity(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: data['displayName'] as String? ?? firebaseUser.displayName ?? 'Usuario',
          role: role,
          isApprovedVet: data['isApprovedVet'] as bool? ?? false,
          professionalLicense: data['professionalLicense'] as String?,
          services: services,
          clabe: data['clabe'] as String?,
          vetStatus: data['vetStatus'] as String?,
          acceptsSpei: data['acceptsSpei'] as bool? ?? true,
          acceptsCash: data['acceptsCash'] as bool? ?? false,
          acceptsCardTerminal: data['acceptsCardTerminal'] as bool? ?? false,
          preferredPaymentMethod: data['preferredPaymentMethod'] as String?,
          pushNotificationsEnabled: data['pushNotificationsEnabled'] as bool? ?? true,
          clinicLatitude: (data['clinicLatitude'] as num?)?.toDouble(),
          clinicLongitude: (data['clinicLongitude'] as num?)?.toDouble(),
          clinicAddress: data['clinicAddress'] as String?,
          subscriptionTier: data['subscriptionTier'] as String? ?? 'free',
          trialEndsAt: trialEndsAtRaw != null ? (trialEndsAtRaw as dynamic).toDate() as DateTime : null,
          mpSubscriptionId: data['mpSubscriptionId'] as String?,
          mpSubscriptionStatus: data['mpSubscriptionStatus'] as String?,
        );

        state = AuthState(user: userEntity, isLoading: false);

        // Persist FCM token for push notifications
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await FirebaseFirestore.instance
                .demoCollection('users')
                .doc(firebaseUser.uid)
                .update({'fcmToken': token});
          }
        } catch (_) {}
      } else {
        // Si no existe el perfil de Firestore aún, creamos un fallback temporal
        final userEntity = UserEntity(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'Usuario Nuevo',
          role: UserRole.owner,
          isApprovedVet: false,
        );
        state = AuthState(user: userEntity, isLoading: false);
      }
    } catch (e) {
      // Fallback si hay un error de red o de permisos iniciales
      final userEntity = UserEntity(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'Usuario',
        role: UserRole.owner,
        isApprovedVet: false,
      );
      state = AuthState(user: userEntity, isLoading: false);
    }
  }

  /// Inicio de sesión real con Firebase Auth
  Future<void> login(String email, String password, UserRole selectedDemoRole) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      final User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // En emuladores locales, para facilitar pruebas cruzadas, creamos el documento
        // si no existe, garantizando que el usuario tenga el rol que seleccionó
        final userDocRef = FirebaseFirestore.instance.demoCollection('users').doc(firebaseUser.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          await userDocRef.set({
            'uid': firebaseUser.uid,
            'email': email,
            'displayName': selectedDemoRole == UserRole.admin 
                ? 'Administrador Principal' 
                : (selectedDemoRole == UserRole.vet ? 'Dr. Alejandro Méndez' : 'Sofia Guerrero'),
            'role': selectedDemoRole.name,
            'isApprovedVet': selectedDemoRole == UserRole.vet ? true : false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        await _loadUserProfile(firebaseUser);
      }
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        errorMessage: _getAuthErrorMessage(e.code),
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        errorMessage: 'Ocurrió un error inesperado al iniciar sesión.',
        isLoading: false,
      );
    }
  }

  /// Registro de nuevos usuarios en Firebase Auth y Firestore
  Future<void> register(String name, String email, String password, UserRole role, String? license) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(name);

        // Guardamos el perfil en Firestore con el rol dinámico asignado
        final profileData = <String, dynamic>{
          'uid': firebaseUser.uid,
          'email': email,
          'displayName': name,
          'role': role.name,
          'isApprovedVet': false, // Los veterinarios inician inactivos hasta aprobación del admin
          'professionalLicense': license,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (role == UserRole.vet) {
          profileData['vetStatus'] = 'pending';
        }
        await FirebaseFirestore.instance.demoCollection('users').doc(firebaseUser.uid).set(profileData);

        await _loadUserProfile(firebaseUser);
      }
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        errorMessage: _getAuthErrorMessage(e.code),
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        errorMessage: 'Ocurrió un error inesperado al registrar el usuario.',
        isLoading: false,
      );
    }
  }

  /// Guarda la ubicación del consultorio del veterinario
  Future<void> updateVetLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    final updates = <String, dynamic>{
      'clinicLatitude': latitude,
      'clinicLongitude': longitude,
      if (address != null) 'clinicAddress': address,
    };

    await FirebaseFirestore.instance
        .demoCollection('users')
        .doc(currentUser.uid)
        .update(updates);

    state = state.copyWith(
      user: currentUser.copyWith(
        clinicLatitude: latitude,
        clinicLongitude: longitude,
        clinicAddress: address ?? currentUser.clinicAddress,
      ),
    );
  }

  /// Recarga el perfil del usuario actual desde Firestore (útil tras un cambio de suscripción)
  Future<void> refreshProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await firebaseUser.reload();
      await _loadUserProfile(firebaseUser);
    }
  }

  /// Cerrar Sesión en Firebase Auth
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await FirebaseAuth.instance.signOut();
    state = const AuthState();
  }

  /// Método especial de demostración para Inversionistas:
  /// Realiza inicio de sesión automático. Si la cuenta no existe en Firebase Auth, la crea al vuelo.
  /// Además, asocia automáticamente los datos semilla de la base de datos a los UIDs de la demo
  /// para garantizar una experiencia interactiva sin fallos de permisos.
  Future<void> signInDemo(UserRole role) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final String email = 'demo.${role.name}@petcarepro.com';
    const String password = 'investor2026';
    
    try {
      UserCredential userCredential;
      try {
        // 1. Intentar iniciar sesión
        userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
      } catch (e) {
        // 2. Si no existe, crear la cuenta automáticamente
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
      }
      
      final User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        final String displayName = role == UserRole.admin
            ? 'Administrador SaaS'
            : (role == UserRole.vet ? 'Dr. Alejandro Méndez (Demo)' : 'Carlos Mendoza (Demo)');
            
        await firebaseUser.updateDisplayName(displayName);
        
        // 3. LLAMAR A LA CLOUD FUNCTION PARA CONFIGURAR LA DEMO (Bypasseando reglas del cliente de forma ultra segura)
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('setupDemoUser');
        await callable.call(<String, dynamic>{
          'role': role.name,
          'displayName': displayName,
        });

        // Forzar la recarga de los Custom Claims para que GoRouter y el cliente lean el nuevo JWT de inmediato
        await firebaseUser.getIdTokenResult(true);

        await _loadUserProfile(firebaseUser);
      }
    } catch (e) {
      state = AuthState(
        errorMessage: 'Error en acceso rápido de demostración: $e',
        isLoading: false,
      );
    }
  }

  /// Actualizar el catálogo de servicios del veterinario en Firestore y localmente
  Future<void> updateVetServices(List<VetService> newServices) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    final servicesData = newServices.map((s) => s.toMap()).toList();
    await FirebaseFirestore.instance
        .demoCollection('users')
        .doc(currentUser.uid)
        .update({'services': servicesData});

    final updatedUser = currentUser.copyWith(services: newServices);
    state = state.copyWith(user: updatedUser);
  }

  /// Actualizar la CLABE interbancaria del veterinario en Firestore y localmente
  Future<void> updateVetClabe(String clabe) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .demoCollection('users')
        .doc(currentUser.uid)
        .update({'clabe': clabe});

    final updatedUser = currentUser.copyWith(clabe: clabe);
    state = state.copyWith(user: updatedUser);
  }

  /// Actualizar configuración de métodos de cobro del Vet
  Future<void> updateVetPaymentConfig({
    required bool acceptsSpei,
    required bool acceptsCash,
    required bool acceptsCardTerminal,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.demoCollection('users').doc(currentUser.uid).update({
      'acceptsSpei': acceptsSpei,
      'acceptsCash': acceptsCash,
      'acceptsCardTerminal': acceptsCardTerminal,
    });

    final updatedUser = currentUser.copyWith(
      acceptsSpei: acceptsSpei,
      acceptsCash: acceptsCash,
      acceptsCardTerminal: acceptsCardTerminal,
    );
    state = state.copyWith(user: updatedUser);
  }

  /// Actualizar método de pago preferido del Dueño
  Future<void> updateOwnerPreferredPayment(String method) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.demoCollection('users').doc(currentUser.uid).update({
      'preferredPaymentMethod': method,
    });

    final updatedUser = currentUser.copyWith(preferredPaymentMethod: method);
    state = state.copyWith(user: updatedUser);
  }

  /// Activar/Desactivar notificaciones push
  Future<void> updatePushNotificationsConfig(bool enabled) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.demoCollection('users').doc(currentUser.uid).update({
      'pushNotificationsEnabled': enabled,
    });

    final updatedUser = currentUser.copyWith(pushNotificationsEnabled: enabled);
    state = state.copyWith(user: updatedUser);
  }

  /// Aprueba un veterinario: marca isApprovedVet = true y vetStatus = 'approved'.
  /// El trigger onUserProfileUpdatedV2 sincroniza los Custom Claims automáticamente.
  Future<void> approveVet(String uid) async {
    await FirebaseFirestore.instance.demoCollection('users').doc(uid).update({
      'isApprovedVet': true,
      'vetStatus': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rechaza un veterinario: conserva isApprovedVet = false y guarda el motivo.
  Future<void> rejectVet(String uid, String reason) async {
    await FirebaseFirestore.instance.demoCollection('users').doc(uid).update({
      'isApprovedVet': false,
      'vetStatus': 'rejected',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Helper de traducción de códigos de error de Firebase
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Este usuario ha sido deshabilitado.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Credenciales incorrectas.';
      case 'email-already-in-use':
        return 'Este correo electrónico ya está registrado.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'operation-not-allowed':
        return 'El registro por correo/contraseña no está habilitado.';
      default:
        return 'Error de autenticación: $code';
    }
  }
}

// Proveedor de estado global de Autenticación
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// Proveedor conveniente del usuario actual
final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authNotifierProvider).user;
});

// Stream de count de veterinarios aprobados (Admin only)
final approvedVetsCountProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .demoCollection('users')
      .where('role', isEqualTo: 'vet')
      .where('isApprovedVet', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.length);
});

// Stream de veterinarios pendientes de validación (Admin only)
// Filtra client-side: role == 'vet', isApprovedVet == false, vetStatus != 'rejected'
final pendingVetsStreamProvider = StreamProvider<List<UserEntity>>((ref) {
  return FirebaseFirestore.instance
      .demoCollection('users')
      .where('role', isEqualTo: 'vet')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) {
              final data = doc.data();
              final servicesList = data['services'] as List<dynamic>? ?? [];
              final services = servicesList
                  .map((item) => VetService.fromMap(Map<String, dynamic>.from(item as Map)))
                  .toList();
              return UserEntity(
                uid: doc.id,
                email: data['email'] as String? ?? '',
                displayName: data['displayName'] as String? ?? 'Veterinario',
                role: UserRole.vet,
                isApprovedVet: data['isApprovedVet'] as bool? ?? false,
                professionalLicense: data['professionalLicense'] as String?,
                services: services,
                clabe: data['clabe'] as String?,
                vetStatus: data['vetStatus'] as String?,
              );
            })
            .where((u) => !u.isApprovedVet && u.vetStatus != 'rejected')
            .toList();
      });
});
