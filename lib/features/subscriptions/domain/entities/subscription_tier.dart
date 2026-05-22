enum SubscriptionTier {
  trial,
  free,
  basico,
  profesional,
  premium;

  static SubscriptionTier fromString(String? s) {
    switch (s) {
      case 'trial':
        return SubscriptionTier.trial;
      case 'basico':
        return SubscriptionTier.basico;
      case 'profesional':
        return SubscriptionTier.profesional;
      case 'premium':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionTier.trial:
        return 'Prueba Gratuita';
      case SubscriptionTier.free:
        return 'Gratuito';
      case SubscriptionTier.basico:
        return 'Básico';
      case SubscriptionTier.profesional:
        return 'Profesional';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  String get mpTierKey {
    switch (this) {
      case SubscriptionTier.basico:
        return 'basico';
      case SubscriptionTier.profesional:
        return 'profesional';
      case SubscriptionTier.premium:
        return 'premium';
      default:
        return 'free';
    }
  }

  int? get monthlyPriceMxn {
    switch (this) {
      case SubscriptionTier.basico:
        return 199;
      case SubscriptionTier.profesional:
        return 299;
      case SubscriptionTier.premium:
        return 499;
      default:
        return null;
    }
  }

  // ── Feature gates ──────────────────────────────────────────────────────────

  /// Pacientes activos simultáneos (QR activos)
  int get maxActivePatients {
    switch (this) {
      case SubscriptionTier.free:
        return 5;
      case SubscriptionTier.basico:
        return 25;
      default:
        return 999999;
    }
  }

  /// Historial clínico disponible en meses (null = ilimitado)
  int? get historyMonths {
    switch (this) {
      case SubscriptionTier.free:
        return 3;
      case SubscriptionTier.basico:
        return 12;
      default:
        return null;
    }
  }

  bool get canUseAllPaymentMethods => this != SubscriptionTier.free;
  bool get canUsePdfReport => this != SubscriptionTier.free;
  bool get isListedInDirectory => this != SubscriptionTier.free;
  bool get isFeaturedInDirectory =>
      this == SubscriptionTier.profesional || this == SubscriptionTier.premium;
  bool get isTopOfDirectory => this == SubscriptionTier.premium;
  bool get hasVerifiedBadge => this == SubscriptionTier.premium;
  bool get hasVaccinationReminders =>
      this == SubscriptionTier.trial ||
      this == SubscriptionTier.profesional ||
      this == SubscriptionTier.premium;

  bool get isPaid => monthlyPriceMxn != null;
  bool get isFreeOrExpired =>
      this == SubscriptionTier.free || this == SubscriptionTier.trial;
}
