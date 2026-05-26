// ─────────────────────────────────────────────────────────────────────────────
// PetCare Pro v1.1.0 — Boarding Enums
// Enumeraciones del dominio de guardería, estética y evaluación conductual.
// ─────────────────────────────────────────────────────────────────────────────

// ── Perfil Conductual ─────────────────────────────────────────────────────────

enum RiskLevel {
  green,
  yellow,
  orange,
  red;

  static RiskLevel fromString(String? s) {
    switch (s) {
      case 'green':  return RiskLevel.green;
      case 'yellow': return RiskLevel.yellow;
      case 'orange': return RiskLevel.orange;
      case 'red':    return RiskLevel.red;
      default:       return RiskLevel.green;
    }
  }

  String get value => name;

  /// Verde y amarillo permiten área común bajo supervisión estándar.
  bool get allowsCommonArea => this == green || this == yellow;

  /// Naranja y rojo requieren protocolo de alerta al staff antes del ingreso.
  bool get requiresStaffAlert => this == orange || this == red;

  /// Solo rojo requiere supervisión veterinaria simultánea.
  bool get requiresVetSupervision => this == red;

  String get displayLabel {
    switch (this) {
      case green:  return 'Sin riesgo';
      case yellow: return 'Supervisión recomendada';
      case orange: return 'Manejo especializado';
      case red:    return 'Alto riesgo — Aislamiento';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum EnergyLevel {
  low,
  medium,
  high,
  hyperactive;

  static EnergyLevel fromString(String? s) {
    switch (s) {
      case 'low':        return EnergyLevel.low;
      case 'medium':     return EnergyLevel.medium;
      case 'high':       return EnergyLevel.high;
      case 'hyperactive': return EnergyLevel.hyperactive;
      default:           return EnergyLevel.medium;
    }
  }

  String get value => name;

  /// Diferencia de energía entre dos perros para el cálculo del ICD.
  int energyDelta(EnergyLevel other) => (index - other.index).abs();
}

// ─────────────────────────────────────────────────────────────────────────────

enum DogCompatibility {
  friendly,
  selective,
  reactive,
  aggressive;

  static DogCompatibility fromString(String? s) {
    switch (s) {
      case 'friendly':   return DogCompatibility.friendly;
      case 'selective':  return DogCompatibility.selective;
      case 'reactive':   return DogCompatibility.reactive;
      case 'aggressive': return DogCompatibility.aggressive;
      default:           return DogCompatibility.selective;
    }
  }

  String get value => name;

  /// Penalización en el ICD para un par de compatibilidades (A, B).
  /// Simétrica: penaltyWith(B) debe coincidir con B.penaltyWith(this).
  int penaltyWith(DogCompatibility other) {
    // Si cualquiera es agresivo → penalización máxima (40 pts)
    if (this == aggressive || other == aggressive) return 40;
    // Si cualquiera es reactivo y el otro no es friendly → alta penalización
    if ((this == reactive && other != friendly) ||
        (other == reactive && this != friendly)) return 25;
    // Reactivo vs friendly → penalización moderada
    if (this == reactive || other == reactive) return 15;
    // Ambos selectivos → penalización baja
    if (this == selective && other == selective) return 5;
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum PlayStyle {
  gentle,
  rough,
  none;

  static PlayStyle fromString(String? s) {
    switch (s) {
      case 'gentle': return PlayStyle.gentle;
      case 'rough':  return PlayStyle.rough;
      case 'none':   return PlayStyle.none;
      default:       return PlayStyle.gentle;
    }
  }

  String get value => name;
}

// ── Tolerancia al Manejo (estética y clínica) ─────────────────────────────────

enum BathSensitivity {
  cooperative,
  anxious,
  defensive;

  static BathSensitivity fromString(String? s) {
    switch (s) {
      case 'cooperative': return BathSensitivity.cooperative;
      case 'anxious':     return BathSensitivity.anxious;
      case 'defensive':   return BathSensitivity.defensive;
      default:            return BathSensitivity.cooperative;
    }
  }

  String get value => name;

  /// Minutos de penalización en el MPT por sensibilidad al baño.
  int get mptPenaltyMinutes {
    switch (this) {
      case cooperative: return 0;
      case anxious:     return 10;
      case defensive:   return 25;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum DryingSensitivity {
  low,
  medium,
  highPanic;

  static DryingSensitivity fromString(String? s) {
    switch (s) {
      case 'low':       return DryingSensitivity.low;
      case 'medium':    return DryingSensitivity.medium;
      case 'high_panic':
      case 'highPanic': return DryingSensitivity.highPanic;
      default:          return DryingSensitivity.low;
    }
  }

  String get value => this == highPanic ? 'high_panic' : name;

  int get mptPenaltyMinutes {
    switch (this) {
      case low:       return 0;
      case medium:    return 15;
      case highPanic: return 45;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum NailTrimming {
  cooperative,
  needsMuzzle,
  sedationRequired;

  static NailTrimming fromString(String? s) {
    switch (s) {
      case 'cooperative':      return NailTrimming.cooperative;
      case 'needs_muzzle':
      case 'needsMuzzle':      return NailTrimming.needsMuzzle;
      case 'sedation_required':
      case 'sedationRequired': return NailTrimming.sedationRequired;
      default:                 return NailTrimming.cooperative;
    }
  }

  String get value {
    switch (this) {
      case cooperative:     return 'cooperative';
      case needsMuzzle:     return 'needs_muzzle';
      case sedationRequired: return 'sedation_required';
    }
  }

  int get mptPenaltyMinutes {
    switch (this) {
      case cooperative:     return 0;
      case needsMuzzle:     return 10;
      case sedationRequired: return 0; // No se realiza — requiere coordinación clínica
    }
  }

  /// Cuando es true, el servicio de estética no puede ejecutar el corte de uñas;
  /// se debe coordinar con el área clínica.
  bool get requiresClinicCoordination => this == sedationRequired;
}

// ── Perfil Físico de la Mascota ───────────────────────────────────────────────

enum CoatType {
  SHORT,
  MEDIUM,
  LONG,
  DOUBLE_COAT,
  CURLY;

  static CoatType fromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'SHORT':       return CoatType.SHORT;
      case 'MEDIUM':      return CoatType.MEDIUM;
      case 'LONG':        return CoatType.LONG;
      case 'DOUBLE_COAT': return CoatType.DOUBLE_COAT;
      case 'CURLY':       return CoatType.CURLY;
      default:            return CoatType.SHORT;
    }
  }

  String get value => name;

  /// Multiplicador de tiempo aplicado sobre la duración base del MPT.
  double get mptMultiplier {
    switch (this) {
      case SHORT:       return 1.0;
      case MEDIUM:      return 1.2;
      case LONG:        return 1.5;
      case DOUBLE_COAT: return 1.7;
      case CURLY:       return 1.6;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum CoatCondition {
  EXCELLENT,
  NORMAL,
  MATTED;

  static CoatCondition fromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'EXCELLENT': return CoatCondition.EXCELLENT;
      case 'NORMAL':    return CoatCondition.NORMAL;
      case 'MATTED':    return CoatCondition.MATTED;
      default:          return CoatCondition.NORMAL;
    }
  }

  String get value => name;

  /// MATTED agrega 30 minutos fijos de desanudado previo al baño.
  int get mptPenaltyMinutes => this == MATTED ? 30 : 0;
}

// ─────────────────────────────────────────────────────────────────────────────

enum SizeCategory {
  TOY,    // < 4 kg
  SMALL,  // 4 – 9.9 kg
  MEDIUM, // 10 – 24.9 kg
  LARGE,  // 25 – 44.9 kg
  GIANT;  // ≥ 45 kg

  static SizeCategory fromString(String? s) {
    switch (s?.toUpperCase()) {
      case 'TOY':    return SizeCategory.TOY;
      case 'SMALL':  return SizeCategory.SMALL;
      case 'MEDIUM': return SizeCategory.MEDIUM;
      case 'LARGE':  return SizeCategory.LARGE;
      case 'GIANT':  return SizeCategory.GIANT;
      default:       return SizeCategory.MEDIUM;
    }
  }

  String get value => name;

  static SizeCategory fromWeight(double weightKg) {
    if (weightKg < 4)   return SizeCategory.TOY;
    if (weightKg < 10)  return SizeCategory.SMALL;
    if (weightKg < 25)  return SizeCategory.MEDIUM;
    if (weightKg < 45)  return SizeCategory.LARGE;
    return SizeCategory.GIANT;
  }
}

// ── Reserva de Guardería ──────────────────────────────────────────────────────

enum ReservationStatus {
  pending,
  confirmed,
  checkedIn,
  completed,
  cancelled;

  static ReservationStatus fromString(String? s) {
    switch (s) {
      case 'pending':    return ReservationStatus.pending;
      case 'confirmed':  return ReservationStatus.confirmed;
      case 'checked_in':
      case 'checkedIn':  return ReservationStatus.checkedIn;
      case 'completed':  return ReservationStatus.completed;
      case 'cancelled':  return ReservationStatus.cancelled;
      default:           return ReservationStatus.pending;
    }
  }

  String get value => this == checkedIn ? 'checked_in' : name;
}

// ─────────────────────────────────────────────────────────────────────────────

enum ServiceType {
  boarding,
  daycare,
  bath,
  haircut;

  static ServiceType fromString(String? s) {
    switch (s) {
      case 'boarding': return ServiceType.boarding;
      case 'daycare':  return ServiceType.daycare;
      case 'bath':     return ServiceType.bath;
      case 'haircut':  return ServiceType.haircut;
      default:         return ServiceType.daycare;
    }
  }

  String get value => name;
}

// ── Vacunas ───────────────────────────────────────────────────────────────────

enum VaccineType {
  parvovirus,
  parainfluenza,
  distemper,          // Moquillo
  adenovirus,
  coronavirus_v,      // Coronavirus canino
  leptospirosis,
  bordetella,         // Tos de las perreras — OBLIGATORIA para perros en guardería
  rabies,             // Rabia — OBLIGATORIA por ley (todas las especies)
  tripleFelineFHCP,   // Triple Felina HCP — OBLIGATORIA para gatos en guardería
  felineLeukemia,     // Leucemia Felina (FeLV)
  felineChlamydia;    // Clamidiosis Felina

  static VaccineType fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'parvovirus':          return VaccineType.parvovirus;
      case 'parainfluenza':       return VaccineType.parainfluenza;
      case 'distemper':
      case 'moquillo':            return VaccineType.distemper;
      case 'adenovirus':          return VaccineType.adenovirus;
      case 'coronavirus_v':
      case 'coronavirus':         return VaccineType.coronavirus_v;
      case 'leptospirosis':       return VaccineType.leptospirosis;
      case 'bordetella':          return VaccineType.bordetella;
      case 'rabies':
      case 'rabia':               return VaccineType.rabies;
      case 'triple_feline_fhcp':
      case 'triplefelinefhcp':    return VaccineType.tripleFelineFHCP;
      case 'feline_leukemia':
      case 'felineleukemia':      return VaccineType.felineLeukemia;
      case 'feline_chlamydia':
      case 'felinechlamydia':     return VaccineType.felineChlamydia;
      default:                    return VaccineType.parvovirus;
    }
  }

  String get value => name;

  String get displayName {
    switch (this) {
      case parvovirus:        return 'Parvovirus';
      case parainfluenza:     return 'Parainfluenza';
      case distemper:         return 'Moquillo (Distemper)';
      case adenovirus:        return 'Adenovirus';
      case coronavirus_v:     return 'Coronavirus Canino';
      case leptospirosis:     return 'Leptospirosis';
      case bordetella:        return 'Bordetella (Tos Perreras)';
      case rabies:            return 'Rabia';
      case tripleFelineFHCP:  return 'Triple Felina (HCP)';
      case felineLeukemia:    return 'Leucemia Felina (FeLV)';
      case felineChlamydia:   return 'Clamidiosis Felina';
    }
  }

  /// Vacunas obligatorias para el ingreso a guardería según especie.
  /// Cualquier vacuna de la lista vencida o ausente bloquea la admisión.
  static List<VaccineType> mandatoryForSpecies(String species) {
    final lower = species.toLowerCase();
    if (lower == 'gato' || lower == 'cat' || lower == 'feline') {
      return [tripleFelineFHCP, rabies];
    }
    return [bordetella, rabies]; // Perros y demás especies
  }
}

// ── Compatibilidad (ICD) ──────────────────────────────────────────────────────

enum CompatibilityLevel {
  compatible,       // ICD >= 75
  supervised,       // ICD 50–74
  separationAdvised, // ICD 25–49
  incompatible;     // ICD < 25

  static CompatibilityLevel fromScore(double score) {
    if (score >= 75) return compatible;
    if (score >= 50) return supervised;
    if (score >= 25) return separationAdvised;
    return incompatible;
  }

  bool get blocksAdmission => this == incompatible;
  bool get requiresManualReview => this == separationAdvised || this == supervised;
}
