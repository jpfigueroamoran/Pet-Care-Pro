/// Representa fallos de negocio e infraestructura en las capas Data y Domain.
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Fallo que ocurre al fallar la autenticación con Firebase Auth.
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Fallo derivado de restricciones de Firestore Security Rules o accesos QR expirados.
class SecurityFailure extends Failure {
  const SecurityFailure(super.message);
}

/// Fallo al interactuar con Firestore o Cloud Storage (red, datos corruptos, etc.).
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Fallo general para errores no esperados en tiempo de ejecución.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
