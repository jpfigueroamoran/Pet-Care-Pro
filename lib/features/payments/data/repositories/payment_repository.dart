import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../domain/entities/payment_entity.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepository(this._firestore);

  /// Escuchar los cobros en tiempo real de un dueño en específico ordenados por fecha descendente
  Stream<List<PaymentEntity>> watchPaymentsByOwner(String ownerId) {
    return _firestore
        .demoCollection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentEntity.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Escuchar los cobros emitidos en tiempo real por un veterinario en específico
  Stream<List<PaymentEntity>> watchPaymentsByVet(String vetId) {
    return _firestore
        .demoCollection('payments')
        .where('vetId', isEqualTo: vetId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentEntity.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Escuchar todos los pagos realizados exitosamente a nivel global (Para Admin)
  Stream<List<PaymentEntity>> watchAllPaidPayments() {
    return _firestore
        .demoCollection('payments')
        .where('status', isEqualTo: 'paid')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentEntity.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Crear un nuevo cargo en Firestore con estado "pending"
  Future<void> createPayment(PaymentEntity payment) async {
    await _firestore.demoCollection('payments').add(payment.toMap());
  }

  /// Escuchar cobros pendientes de revisión de comprobante para un veterinario
  Stream<List<PaymentEntity>> watchPendingReviewByVet(String vetId) {
    return _firestore
        .demoCollection('payments')
        .where('vetId', isEqualTo: vetId)
        .where('status', whereIn: ['pending_review', 'awaiting_physical_payment'])
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PaymentEntity.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Dueño sube comprobante de transferencia SPEI
  Future<void> submitComprobante(String paymentId, String comprobanteUrl) async {
    await _firestore.demoCollection('payments').doc(paymentId).update({
      'status': 'pending_review',
      'comprobanteUrl': comprobanteUrl,
      'comprobanteUploadedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Veterinario rechaza un comprobante inválido
  Future<void> rejectPayment(String paymentId, String reason) async {
    await _firestore.demoCollection('payments').doc(paymentId).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
  }

  /// Veterinario aprueba un pago manual o físico
  Future<void> approvePhysicalPayment(String paymentId) async {
    await _firestore.demoCollection('payments').doc(paymentId).update({
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
    });
  }
}

// Proveedor global del repositorio de pagos
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(FirebaseFirestore.instance);
});

// Proveedor de flujo de cargos para dueños
final ownerPaymentsStreamProvider = StreamProvider.family<List<PaymentEntity>, String>((ref, ownerId) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.watchPaymentsByOwner(ownerId);
});

// Proveedor de flujo de cargos para veterinarios
final vetPaymentsStreamProvider = StreamProvider.family<List<PaymentEntity>, String>((ref, vetId) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.watchPaymentsByVet(vetId);
});

// Proveedor de flujo de todos los cobros pagados (Admin)
final adminPaidPaymentsStreamProvider = StreamProvider<List<PaymentEntity>>((ref) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.watchAllPaidPayments();
});

// Proveedor de cobros pendientes de revisión de comprobante (Veterinario)
final vetPendingReviewStreamProvider = StreamProvider.family<List<PaymentEntity>, String>((ref, vetId) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.watchPendingReviewByVet(vetId);
});

// Proveedor de un pago individual por ID (reactivo)
final singlePaymentStreamProvider = StreamProvider.family<PaymentEntity?, String>((ref, paymentId) {
  return FirebaseFirestore.instance
      .demoCollection('payments')
      .doc(paymentId)
      .snapshots()
      .map((snap) => snap.exists ? PaymentEntity.fromMap(snap.data()!, snap.id) : null);
});
