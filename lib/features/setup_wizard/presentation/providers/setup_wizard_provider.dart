import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/firestore_extension.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entidades
// ─────────────────────────────────────────────────────────────────────────────

class WizardService {
  final String name;
  final double price;
  final int durationMinutes;

  const WizardService({
    required this.name,
    required this.price,
    required this.durationMinutes,
  });

  WizardService copyWith({String? name, double? price, int? durationMinutes}) =>
      WizardService(
        name: name ?? this.name,
        price: price ?? this.price,
        durationMinutes: durationMinutes ?? this.durationMinutes,
      );

  Map<String, dynamic> toMap() => {
        'id': 'svc_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        'name': name,
        'price': price,
        'durationMinutes': durationMinutes,
      };

  factory WizardService.fromMap(Map<String, dynamic> m) => WizardService(
        name: m['name'] as String? ?? '',
        price: (m['price'] as num? ?? 0).toDouble(),
        durationMinutes: m['durationMinutes'] as int? ?? 30,
      );
}

class WizardFacilityRun {
  final String name;
  final int capacity;
  final String species; // 'dog' | 'cat' | 'both'

  const WizardFacilityRun({
    required this.name,
    required this.capacity,
    required this.species,
  });

  WizardFacilityRun copyWith({String? name, int? capacity, String? species}) =>
      WizardFacilityRun(
        name: name ?? this.name,
        capacity: capacity ?? this.capacity,
        species: species ?? this.species,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'capacity': capacity,
        'species': species,
        'active': true,
      };

  factory WizardFacilityRun.fromMap(Map<String, dynamic> m) =>
      WizardFacilityRun(
        name: m['name'] as String? ?? '',
        capacity: m['capacity'] as int? ?? 1,
        species: m['species'] as String? ?? 'both',
      );
}

class WizardInvite {
  final String email;
  final String role; // 'vet' | 'admin'

  const WizardInvite({required this.email, required this.role});

  Map<String, dynamic> toMap() => {'email': email, 'role': role};

  factory WizardInvite.fromMap(Map<String, dynamic> m) => WizardInvite(
        email: m['email'] as String? ?? '',
        role: m['role'] as String? ?? 'vet',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class WizardState {
  final bool loaded;
  final bool isCompleted;
  final bool saving;
  final String? saveError;

  // 0=welcome  1=profile  2=services  3=facility  4=team  5=done
  final int step;
  final int savedStep;

  // Step 1
  final String businessName;
  final String branchName;
  final String address;
  final String phone;

  // Step 2
  final List<WizardService> services;

  // Step 3
  final List<WizardFacilityRun> runs;

  // Step 4
  final List<WizardInvite> invites;

  const WizardState({
    this.loaded = false,
    this.isCompleted = false,
    this.saving = false,
    this.saveError,
    this.step = 0,
    this.savedStep = 0,
    this.businessName = '',
    this.branchName = '',
    this.address = '',
    this.phone = '',
    this.services = const [],
    this.runs = const [],
    this.invites = const [],
  });

  bool get isWelcome => step == 0;
  bool get isDone => step == 5;
  // steps 1–4 have progress indicator
  int get progressStep => step.clamp(1, 4);

  WizardState copyWith({
    bool? loaded,
    bool? isCompleted,
    bool? saving,
    Object? saveError = _sentinel,
    int? step,
    int? savedStep,
    String? businessName,
    String? branchName,
    String? address,
    String? phone,
    List<WizardService>? services,
    List<WizardFacilityRun>? runs,
    List<WizardInvite>? invites,
  }) =>
      WizardState(
        loaded: loaded ?? this.loaded,
        isCompleted: isCompleted ?? this.isCompleted,
        saving: saving ?? this.saving,
        saveError: saveError == _sentinel ? this.saveError : saveError as String?,
        step: step ?? this.step,
        savedStep: savedStep ?? this.savedStep,
        businessName: businessName ?? this.businessName,
        branchName: branchName ?? this.branchName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        services: services ?? this.services,
        runs: runs ?? this.runs,
        invites: invites ?? this.invites,
      );
}

const _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class SetupWizardNotifier extends StateNotifier<WizardState> {
  SetupWizardNotifier(this._ref) : super(const WizardState()) {
    _load();
  }

  final Ref _ref;

  String? get _uid => _ref.read(currentUserProvider)?.uid;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(
        loaded: true,
        services: _defaultServices,
        runs: _defaultRuns,
      );
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .demoCollection('users')
          .doc(uid)
          .get();
      final w = doc.data()?['setupWizard'] as Map<String, dynamic>?;
      if (w == null) {
        state = state.copyWith(
          loaded: true,
          services: _defaultServices,
          runs: _defaultRuns,
        );
        return;
      }

      final savedStep = w['currentStep'] as int? ?? 0;
      final completed = w['completedAt'] != null;

      List<T> _parseList<T>(String key, T Function(Map<String, dynamic>) fn) {
        final raw = w[key] as List<dynamic>? ?? [];
        return raw
            .map((e) => fn(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      final services = _parseList('services', WizardService.fromMap);
      final runs = _parseList('runs', WizardFacilityRun.fromMap);
      final invites = _parseList('invites', WizardInvite.fromMap);

      state = WizardState(
        loaded: true,
        isCompleted: completed,
        step: savedStep,
        savedStep: savedStep,
        businessName: w['businessName'] as String? ?? '',
        branchName: w['branchName'] as String? ?? '',
        address: w['address'] as String? ?? '',
        phone: w['phone'] as String? ?? '',
        services: services.isEmpty ? _defaultServices : services,
        runs: runs.isEmpty ? _defaultRuns : runs,
        invites: invites,
      );
    } catch (_) {
      state = state.copyWith(
        loaded: true,
        services: _defaultServices,
        runs: _defaultRuns,
      );
    }
  }

  // ── Form setters (in-memory only, no Firestore write) ─────────────────────

  void setBusinessName(String v) =>
      state = state.copyWith(businessName: v, saveError: null);
  void setBranchName(String v) =>
      state = state.copyWith(branchName: v, saveError: null);
  void setAddress(String v) => state = state.copyWith(address: v);
  void setPhone(String v) => state = state.copyWith(phone: v);

  void addService(WizardService s) =>
      state = state.copyWith(services: [...state.services, s]);
  void removeService(int i) {
    final list = [...state.services]..removeAt(i);
    state = state.copyWith(services: list);
  }
  void updateService(int i, WizardService s) {
    final list = [...state.services];
    list[i] = s;
    state = state.copyWith(services: list);
  }

  void addRun(WizardFacilityRun r) =>
      state = state.copyWith(runs: [...state.runs, r]);
  void removeRun(int i) {
    final list = [...state.runs]..removeAt(i);
    state = state.copyWith(runs: list);
  }
  void updateRun(int i, WizardFacilityRun r) {
    final list = [...state.runs];
    list[i] = r;
    state = state.copyWith(runs: list);
  }

  void addInvite(WizardInvite inv) =>
      state = state.copyWith(invites: [...state.invites, inv]);
  void removeInvite(int i) {
    final list = [...state.invites]..removeAt(i);
    state = state.copyWith(invites: list);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void goBack() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, saveError: null);
    }
  }

  Future<void> goNext() async {
    final err = _validate(state.step);
    if (err != null) {
      state = state.copyWith(saveError: err);
      return;
    }
    await _persist(state.step + 1);
  }

  Future<void> complete() async {
    await _persist(5, finalize: true);
  }

  // ── Private ───────────────────────────────────────────────────────────────

  String? _validate(int step) {
    switch (step) {
      case 1:
        if (state.businessName.trim().isEmpty) {
          return 'El nombre del negocio es obligatorio.';
        }
        if (state.branchName.trim().isEmpty) {
          return 'El nombre de la sucursal es obligatorio.';
        }
        return null;
      case 2:
        if (state.services.isEmpty) return 'Agrega al menos un servicio.';
        return null;
      default:
        return null;
    }
  }

  Future<void> _persist(int nextStep, {bool finalize = false}) async {
    final uid = _uid;
    if (uid == null) return;

    state = state.copyWith(saving: true, saveError: null);

    try {
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.demoCollection('users').doc(uid);

      final wizardMap = <String, dynamic>{
        'currentStep': nextStep,
        'businessName': state.businessName.trim(),
        'branchName': state.branchName.trim(),
        'address': state.address.trim(),
        'phone': state.phone.trim(),
        'services': state.services.map((s) => s.toMap()).toList(),
        'runs': state.runs.map((r) => r.toMap()).toList(),
        'invites': state.invites.map((i) => i.toMap()).toList(),
        if (finalize) 'completedAt': FieldValue.serverTimestamp(),
      };

      final batch = firestore.batch();
      batch.update(userRef, {'setupWizard': wizardMap});

      // Persist vetServices when services step is passed
      if (nextStep >= 3) {
        batch.update(userRef,
            {'vetServices': state.services.map((s) => s.toMap()).toList()});
      }

      // On finalization: set branchId on user doc → triggers CF claim sync
      if (finalize) {
        batch.update(userRef, {'branchId': uid});
      }

      await batch.commit();

      // Persist facility runs to their own collection when passed
      if (nextStep >= 4 && state.runs.isNotEmpty) {
        final runBatch = firestore.batch();
        for (final run in state.runs) {
          runBatch.set(
            firestore.demoCollection('facility_runs').doc(),
            {...run.toMap(), 'branchId': uid, 'createdAt': FieldValue.serverTimestamp()},
          );
        }
        await runBatch.commit();
      }

      // Persist invitations
      if (finalize && state.invites.isNotEmpty) {
        final invBatch = firestore.batch();
        for (final inv in state.invites) {
          invBatch.set(
            firestore.demoCollection('staff_invitations').doc(),
            {
              ...inv.toMap(),
              'branchId': uid,
              'branchName': state.branchName.trim(),
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
        await invBatch.commit();
      }

      // Force token refresh so branchId claim takes effect immediately
      if (finalize) {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      }

      state = state.copyWith(
        saving: false,
        step: nextStep,
        savedStep: nextStep,
        isCompleted: finalize ? true : state.isCompleted,
      );
    } catch (e) {
      state = state.copyWith(saving: false, saveError: 'Error al guardar: $e');
    }
  }

  // ── Defaults ──────────────────────────────────────────────────────────────

  static const _defaultServices = [
    WizardService(name: 'Consulta General', price: 450, durationMinutes: 30),
    WizardService(name: 'Vacunación', price: 250, durationMinutes: 15),
    WizardService(name: 'Baño y Secado', price: 350, durationMinutes: 60),
    WizardService(name: 'Corte de Pelo', price: 450, durationMinutes: 90),
  ];

  static const _defaultRuns = [
    WizardFacilityRun(
        name: 'Corral A — Perros Grandes', capacity: 5, species: 'dog'),
    WizardFacilityRun(
        name: 'Corral B — Perros Pequeños', capacity: 8, species: 'dog'),
    WizardFacilityRun(name: 'Suite Felina', capacity: 6, species: 'cat'),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final setupWizardProvider =
    StateNotifierProvider.autoDispose<SetupWizardNotifier, WizardState>(
  (ref) => SetupWizardNotifier(ref),
);

/// Usado por el banner del dashboard: emite true cuando el wizard está completo.
final wizardCompletionProvider =
    StreamProvider.family<bool, String>((ref, uid) {
  return FirebaseFirestore.instance
      .demoCollection('users')
      .doc(uid)
      .snapshots()
      .map((snap) {
    final w = snap.data()?['setupWizard'] as Map<String, dynamic>?;
    return w?['completedAt'] != null;
  });
});
