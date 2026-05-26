enum AppMode {
  staff,
  owner,
}

class UIStrings {
  /// Retorna la traducción del nivel de riesgo conductual (riskLevel) según el modo de la aplicación.
  static String riskLevel(String level, AppMode mode) {
    final normalized = level.trim().toLowerCase();
    switch (mode) {
      case AppMode.staff:
        switch (normalized) {
          case 'red':
          case 'high':
            return '⚠️ WARNING: HIGH RISK BEHAVIOR (ICD SCORE < 40)';
          case 'orange':
          case 'medium':
            return '⚡ ATTENTION: MODERATE REACTIVITY (ICD SCORE 40-70)';
          case 'green':
          case 'low':
          default:
            return '✅ COOPERATIVE: LOW RISK STATUS';
        }
      case AppMode.owner:
        switch (normalized) {
          case 'red':
          case 'high':
            return 'Atención personalizada: Estamos brindando cuidados especiales y un espacio tranquilo para mayor comodidad y bienestar de tu mascota.';
          case 'orange':
          case 'medium':
            return 'Cuidado social guiado: Acompañamos a tu mascota en actividades grupales adaptadas a su ritmo para que se sienta feliz y segura.';
          case 'green':
          case 'low':
          default:
            return 'Convivencia plena: Tu mascota está disfrutando al máximo de juegos interactivos y socialización con nuevos amigos en el parque.';
        }
    }
  }

  /// Retorna la etiqueta para el proceso de salida de la guardería ("checkout" vs "regreso a casa")
  static String checkoutLabel(AppMode mode) {
    switch (mode) {
      case AppMode.staff:
        return 'R-STATUS: COMPLETED CHECKOUT (MPT UNITS FREED)';
      case AppMode.owner:
        return '¡Hora de volver a casa! Tu mascota está lista para reunirse contigo.';
    }
  }

  /// Retorna la traducción del estado de una reserva (ReservationStatus)
  static String reservationStatus(String status, AppMode mode) {
    final normalized = status.trim().toLowerCase();
    switch (mode) {
      case AppMode.staff:
        switch (normalized) {
          case 'confirmed':
            return 'R-STATUS: CONFIRMED (FACILITY RUN ALLOCATED)';
          case 'checkedin':
          case 'checked_in':
            return 'R-STATUS: ACTIVE CHECKED-IN (MPT ENGAGED)';
          case 'completed':
            return 'R-STATUS: COMPLETED (RESOURCES ARCHIVED)';
          case 'cancelled':
            return 'R-STATUS: CANCELLED (RUN VOID)';
          default:
            return 'R-STATUS: PENDING SYSTEM CLEARANCE';
        }
      case AppMode.owner:
        switch (normalized) {
          case 'confirmed':
            return 'Estancia programada y lista para recibir a tu consentido.';
          case 'checkedin':
          case 'checked_in':
            return '¡Tu mascota ya está con nosotros recibiendo los mejores cuidados!';
          case 'completed':
            return 'Estancia exitosa: ¡Tu mascota regresó a casa feliz y relajada!';
          case 'cancelled':
            return 'Estancia cancelada. Esperamos verlos de nuevo muy pronto.';
          default:
            return 'Preparando los últimos detalles para recibir a tu mascota.';
        }
    }
  }

  /// Retorna la etiqueta o justificación para autorizaciones médicas urgentes
  static String emergencyMedication(AppMode mode) {
    switch (mode) {
      case AppMode.staff:
        return 'LEGAL AUTH: EMERGENCY MEDICATION DISPENSATION (MANDATORY FOR CLINICAL INTERVENTION)';
      case AppMode.owner:
        return 'Protección médica garantizada: Autorizo la atención veterinaria de urgencia y la administración de medicamentos esenciales para resguardar la salud de mi mascota.';
    }
  }

  /// Retorna la descripción del Motor de Productividad de Tiempos (MPT / Agenda)
  static String mptSummary({
    required int minutes,
    required int staffRequired,
    required AppMode mode,
  }) {
    switch (mode) {
      case AppMode.staff:
        return 'MPT SERVICE METRICS: $minutes min. EST. DUR. | RESOURCES: $staffRequired STAFF UNITS';
      case AppMode.owner:
        return 'Sesión de bienestar personalizada de aproximadamente $minutes minutos de atención exclusiva y cariñosa por parte de nuestros profesionales de cuidado.';
    }
  }
}
