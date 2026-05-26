import 'package:cloud_functions/cloud_functions.dart';

import '../entities/use_case_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Caso de Uso: Vincular Mascota a Dueño mediante Código PET-XXXX
//
// Valida el formato del código localmente, luego delega la lógica al
// Cloud Function `linkPetToOwner`, que centraliza: validación de expiración,
// verificación de sucursal, anti-reuso y rate limiting (5/hora por UID).
// ─────────────────────────────────────────────────────────────────────────────

class LinkPetToOwnerUseCase {
  const LinkPetToOwnerUseCase();

  static final _codeRegex = RegExp(r'^PET-[A-Z0-9]{4}$');

  Future<UseCaseResult<LinkPetData>> call({
    required String code,
    required String newOwnerId,
  }) async {
    final normalizedCode = code.trim().toUpperCase();

    if (!_codeRegex.hasMatch(normalizedCode)) {
      return const Failure(
        message: 'Formato de código inválido. Debe ser PET-XXXX (4 caracteres alfanuméricos).',
        code: FailureCode.validationError,
      );
    }
    if (newOwnerId.trim().isEmpty) {
      return const Failure(
        message: 'El ID del nuevo dueño no puede estar vacío.',
        code: FailureCode.validationError,
      );
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('linkPetToOwner');
      final result = await callable.call<Map<dynamic, dynamic>>({'code': normalizedCode});
      final data = Map<String, dynamic>.from(result.data);
      return Success(LinkPetData(
        petId: data['petId'] as String? ?? '',
        petName: data['petName'] as String? ?? '',
        newOwnerId: data['newOwnerId'] as String? ?? newOwnerId,
      ));
    } on FirebaseFunctionsException catch (e) {
      final code = _mapFunctionsCode(e.code);
      return Failure(message: e.message ?? 'Error al canjear el código.', code: code);
    } catch (e) {
      return Failure(message: 'Error inesperado: $e', code: FailureCode.networkError);
    }
  }

  static FailureCode _mapFunctionsCode(String code) {
    switch (code) {
      case 'not-found':          return FailureCode.notFound;
      case 'permission-denied':  return FailureCode.permissionDenied;
      case 'deadline-exceeded':  return FailureCode.expired;
      case 'failed-precondition':return FailureCode.expired;
      case 'resource-exhausted': return FailureCode.permissionDenied;
      default:                   return FailureCode.networkError;
    }
  }
}
