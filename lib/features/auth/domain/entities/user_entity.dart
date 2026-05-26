enum UserRole {
  owner,
  vet,
  groomer,      // Lavador / Estilista de mascotas
  caretaker,    // Cuidador de guardería
  receptionist, // Recepcionista
  admin;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'vet':
        return UserRole.vet;
      case 'groomer':
        return UserRole.groomer;
      case 'caretaker':
        return UserRole.caretaker;
      case 'receptionist':
        return UserRole.receptionist;
      case 'admin':
        return UserRole.admin;
      case 'owner':
      default:
        return UserRole.owner;
    }
  }

  String get name => toString().split('.').last;
}

class VetService {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;

  const VetService({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
  });

  factory VetService.fromMap(Map<String, dynamic> map) {
    return VetService(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: map['durationMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'durationMinutes': durationMinutes,
    };
  }
}

class UserEntity {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? branchId; // <--- Multi-tenant branch ID
  final bool isApprovedVet;
  final String? professionalLicense;
  final List<VetService> services;
  final String? clabe;
  // 'pending' | 'approved' | 'rejected' — solo relevante para vets
  final String? vetStatus;
  
  // Preferencias de Pago (Vet)
  final bool acceptsSpei;
  final bool acceptsCash;
  final bool acceptsCardTerminal;
  
  // Preferencia de Pago (Dueño)
  final String? preferredPaymentMethod; // 'cash', 'spei', 'terminal'
  
  // Preferencias Generales
  final bool pushNotificationsEnabled;

  // Ubicación del consultorio (Vets)
  final double? clinicLatitude;
  final double? clinicLongitude;
  final String? clinicAddress;

  // Suscripción (Vets)
  final String subscriptionTier; // 'trial' | 'free' | 'basico' | 'profesional' | 'premium'
  final DateTime? trialEndsAt;
  final String? mpSubscriptionId;
  final String? mpSubscriptionStatus; // 'authorized' | 'paused' | 'cancelled'

  const UserEntity({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.branchId,
    this.isApprovedVet = false,
    this.professionalLicense,
    this.services = const [],
    this.clabe,
    this.vetStatus,
    this.acceptsSpei = true,
    this.acceptsCash = false,
    this.acceptsCardTerminal = false,
    this.preferredPaymentMethod,
    this.pushNotificationsEnabled = true,
    this.clinicLatitude,
    this.clinicLongitude,
    this.clinicAddress,
    this.subscriptionTier = 'free',
    this.trialEndsAt,
    this.mpSubscriptionId,
    this.mpSubscriptionStatus,
  });

  bool get isOwner => role == UserRole.owner;
  bool get isVet => role == UserRole.vet;
  bool get isGroomer => role == UserRole.groomer;
  bool get isCaretaker => role == UserRole.caretaker;
  bool get isReceptionist => role == UserRole.receptionist;
  bool get isAdmin => role == UserRole.admin;
  bool get isStaff => role == UserRole.groomer || role == UserRole.caretaker || role == UserRole.receptionist;

  UserEntity copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? branchId,
    bool? isApprovedVet,
    String? professionalLicense,
    List<VetService>? services,
    String? clabe,
    String? vetStatus,
    bool? acceptsSpei,
    bool? acceptsCash,
    bool? acceptsCardTerminal,
    String? preferredPaymentMethod,
    bool? pushNotificationsEnabled,
    double? clinicLatitude,
    double? clinicLongitude,
    String? clinicAddress,
    String? subscriptionTier,
    DateTime? trialEndsAt,
    String? mpSubscriptionId,
    String? mpSubscriptionStatus,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      isApprovedVet: isApprovedVet ?? this.isApprovedVet,
      professionalLicense: professionalLicense ?? this.professionalLicense,
      services: services ?? this.services,
      clabe: clabe ?? this.clabe,
      vetStatus: vetStatus ?? this.vetStatus,
      acceptsSpei: acceptsSpei ?? this.acceptsSpei,
      acceptsCash: acceptsCash ?? this.acceptsCash,
      acceptsCardTerminal: acceptsCardTerminal ?? this.acceptsCardTerminal,
      preferredPaymentMethod: preferredPaymentMethod ?? this.preferredPaymentMethod,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      clinicLatitude: clinicLatitude ?? this.clinicLatitude,
      clinicLongitude: clinicLongitude ?? this.clinicLongitude,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      mpSubscriptionId: mpSubscriptionId ?? this.mpSubscriptionId,
      mpSubscriptionStatus: mpSubscriptionStatus ?? this.mpSubscriptionStatus,
    );
  }
}
