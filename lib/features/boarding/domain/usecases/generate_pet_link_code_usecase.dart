import '../entities/use_case_result.dart';
import '../repositories/i_boarding_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Caso de Uso: Generar Código de Vinculación de Mascota
//
// Crea un código temporal PET-XXXX que el dueño puede escanear o ingresar
// para vincular una mascota a su cuenta. El código expira en 15 minutos.
// ─────────────────────────────────────────────────────────────────────────────

class GeneratePetLinkCodeUseCase {
  final IBoardingRepository _repository;

  const GeneratePetLinkCodeUseCase(this._repository);

  /// [petId] — ID del documento en /pets/{petId}
  /// [expiryMinutes] — tiempo de validez del código (default: 15)
  Future<UseCaseResult<PetLinkCodeData>> call(
    String petId, {
    int expiryMinutes = 15,
  }) async {
    if (petId.trim().isEmpty) {
      return const Failure(
        message: 'El ID de la mascota no puede estar vacío.',
        code: FailureCode.validationError,
      );
    }
    if (expiryMinutes < 1 || expiryMinutes > 60) {
      return const Failure(
        message: 'El tiempo de expiración debe estar entre 1 y 60 minutos.',
        code: FailureCode.validationError,
      );
    }

    return _repository.generateLinkCode(petId, expiryMinutes: expiryMinutes);
  }
}
