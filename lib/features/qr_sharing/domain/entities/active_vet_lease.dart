import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveVetLease {
  final String id;
  final String petId;
  final String vetId;
  final String ownerId;
  final String leaseType;
  final DateTime? leaseExpiresAt;

  // Optional display fields stored by demo setup
  final String? petName;
  final String? vetName;

  ActiveVetLease({
    required this.id,
    required this.petId,
    required this.vetId,
    required this.ownerId,
    required this.leaseType,
    this.leaseExpiresAt,
    this.petName,
    this.vetName,
  });

  bool get isHospitalization => leaseType == 'hospitalization';

  bool get isExpired =>
      leaseExpiresAt != null && leaseExpiresAt!.isBefore(DateTime.now());

  factory ActiveVetLease.fromMap(Map<String, dynamic> map, String id) {
    DateTime? leaseExpiresAt;
    final raw = map['leaseExpiresAt'];
    if (raw is Timestamp) {
      leaseExpiresAt = raw.toDate();
    }

    return ActiveVetLease(
      id: id,
      petId: map['petId'] as String? ?? '',
      vetId: map['vetId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      leaseType: map['leaseType'] as String? ?? 'consultation',
      leaseExpiresAt: leaseExpiresAt,
      petName: map['petName'] as String?,
      vetName: map['vetName'] as String?,
    );
  }
}
