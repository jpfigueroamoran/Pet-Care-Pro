import '../../../auth/domain/entities/user_entity.dart';

class PaymentEntity {
  final String id;
  final String petId;
  final String petName;
  final String ownerId;
  final String ownerName;
  final String vetId;
  final String vetName;
  final List<VetService> services;
  final double totalAmount;
  final String status; // pending, pending_review, paid, rejected
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? comprobanteUrl;
  final DateTime? comprobanteUploadedAt;
  final String? rejectionReason;
  
  // Nuevos campos para métodos de pago
  final Map<String, bool>? allowedPaymentMethods; // Lo que el vet permitía al crear el cobro
  final String? selectedPaymentMethod; // 'spei', 'cash', 'terminal'

  const PaymentEntity({
    required this.id,
    required this.petId,
    required this.petName,
    required this.ownerId,
    required this.ownerName,
    required this.vetId,
    required this.vetName,
    required this.services,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.comprobanteUrl,
    this.comprobanteUploadedAt,
    this.rejectionReason,
    this.allowedPaymentMethods,
    this.selectedPaymentMethod,
  });

  factory PaymentEntity.fromMap(Map<String, dynamic> map, String docId) {
    final servicesList = map['services'] as List<dynamic>? ?? [];
    final services = servicesList
        .map((item) => VetService.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return PaymentEntity(
      id: docId,
      petId: map['petId'] ?? '',
      petName: map['petName'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      vetId: map['vetId'] ?? '',
      vetName: map['vetName'] ?? '',
      services: services,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      paidAt: map['paidAt'] != null
          ? (map['paidAt'] as dynamic).toDate()
          : null,
      comprobanteUrl: map['comprobanteUrl'] as String?,
      comprobanteUploadedAt: map['comprobanteUploadedAt'] != null
          ? (map['comprobanteUploadedAt'] as dynamic).toDate()
          : null,
      rejectionReason: map['rejectionReason'] as String?,
      allowedPaymentMethods: map['allowedPaymentMethods'] != null 
          ? Map<String, bool>.from(map['allowedPaymentMethods'] as Map) 
          : null,
      selectedPaymentMethod: map['selectedPaymentMethod'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'petName': petName,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'vetId': vetId,
      'vetName': vetName,
      'services': services.map((s) => s.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt,
      if (paidAt != null) 'paidAt': paidAt,
      if (comprobanteUrl != null) 'comprobanteUrl': comprobanteUrl,
      if (comprobanteUploadedAt != null) 'comprobanteUploadedAt': comprobanteUploadedAt,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (allowedPaymentMethods != null) 'allowedPaymentMethods': allowedPaymentMethods,
      if (selectedPaymentMethod != null) 'selectedPaymentMethod': selectedPaymentMethod,
    };
  }

  PaymentEntity copyWith({
    String? id,
    String? petId,
    String? petName,
    String? ownerId,
    String? ownerName,
    String? vetId,
    String? vetName,
    List<VetService>? services,
    double? totalAmount,
    String? status,
    DateTime? createdAt,
    DateTime? paidAt,
    String? comprobanteUrl,
    DateTime? comprobanteUploadedAt,
    String? rejectionReason,
    Map<String, bool>? allowedPaymentMethods,
    String? selectedPaymentMethod,
  }) {
    return PaymentEntity(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      vetId: vetId ?? this.vetId,
      vetName: vetName ?? this.vetName,
      services: services ?? this.services,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      comprobanteUrl: comprobanteUrl ?? this.comprobanteUrl,
      comprobanteUploadedAt: comprobanteUploadedAt ?? this.comprobanteUploadedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      allowedPaymentMethods: allowedPaymentMethods ?? this.allowedPaymentMethods,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
    );
  }
}
