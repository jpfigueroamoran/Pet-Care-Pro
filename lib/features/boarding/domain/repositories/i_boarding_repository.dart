import '../entities/behavioral_assessment_entity.dart';
import '../entities/boarding_enums.dart';
import '../entities/boarding_reservation_entity.dart';
import '../entities/use_case_result.dart';
import '../entities/vaccination_entry_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Contrato: Repositorio de Guardería v1.1.0
// Define todas las operaciones de datos del dominio de boarding.
// La implementación concreta vive en data/repositories/.
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class IBoardingRepository {
  // ── Evaluaciones Conductuales ─────────────────────────────────────────────

  /// Obtiene la evaluación conductual más reciente de una mascota.
  /// Retorna null si no existe evaluación registrada.
  Future<UseCaseResult<BehavioralAssessmentEntity?>> getLatestAssessment(
    String petId,
  );

  /// Stream de todas las evaluaciones conductuales de una mascota,
  /// ordenadas de más reciente a más antigua.
  Stream<List<BehavioralAssessmentEntity>> watchAssessments(String petId);

  /// Persiste una nueva evaluación conductual.
  Future<UseCaseResult<BehavioralAssessmentEntity>> saveAssessment(
    String petId,
    BehavioralAssessmentEntity assessment,
  );

  // ── Cartilla de Vacunación ────────────────────────────────────────────────

  /// Retorna todas las entradas de vacunación/desparasitación de una mascota.
  Future<UseCaseResult<List<VaccinationEntryEntity>>> getVaccinationCard(
    String petId,
  );

  /// Stream en tiempo real de la cartilla de vacunación.
  Stream<List<VaccinationEntryEntity>> watchVaccinationCard(String petId);

  // ── Reservas de Guardería ─────────────────────────────────────────────────

  /// Crea una nueva reserva de guardería.
  Future<UseCaseResult<BoardingReservationEntity>> createReservation(
    BoardingReservationEntity reservation,
  );

  /// Actualiza el estado de una reserva existente.
  Future<UseCaseResult<BoardingReservationEntity>> updateReservationStatus(
    String reservationId,
    ReservationStatus newStatus, {
    String? staffNotes,
  });

  /// Modifica las fechas de una reserva existente, verificando que no haya
  /// solapamiento con otras reservas activas de la misma mascota.
  Future<UseCaseResult<BoardingReservationEntity>> updateReservationDates({
    required String reservationId,
    required String petId,
    required DateTime newCheckIn,
    required DateTime newCheckOut,
  });

  /// Cancela una reserva en estado pending o confirmed.
  Future<UseCaseResult<void>> cancelReservation(String reservationId);

  /// Obtiene las reservas activas en una fecha dada (para cálculo de ICD).
  /// [branchId] filtra por sucursal para evitar contaminación multi-tenant.
  Future<UseCaseResult<List<BoardingReservationEntity>>>
      getActiveReservationsForDate(DateTime date, {String? branchId});

  /// Stream de reservas de una mascota específica.
  Stream<List<BoardingReservationEntity>> watchReservationsForPet(String petId);

  // ── Sistema de Vinculación de Mascotas ────────────────────────────────────

  /// Genera y persiste un código temporal PET-XXXX para vincular una mascota
  /// a un dueño. El código expira en [expiryMinutes] minutos.
  Future<UseCaseResult<PetLinkCodeData>> generateLinkCode(
    String petId, {
    int expiryMinutes = 15,
  });

  // ── Pares de Compatibilidad (ICD) ─────────────────────────────────────────

  /// Retorna las evaluaciones conductuales de todas las mascotas con reserva
  /// activa en el rango de fechas dado, para calcular el ICD en batch.
  Future<UseCaseResult<List<BehavioralAssessmentEntity>>>
      getAssessmentsForActivePets({
    required DateTime checkIn,
    required DateTime checkOut,
    String? excludePetId,
    String? branchId,
  });

  /// Verifica si ya existe una reserva activa (confirmed o checked_in) para
  /// [petId] que se solape con el rango [checkIn]–[checkOut].
  Future<UseCaseResult<bool>> hasOverlappingReservation({
    required String petId,
    required DateTime checkIn,
    required DateTime checkOut,
  });
}
