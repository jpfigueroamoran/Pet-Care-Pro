import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/firestore_extension.dart';
import '../../data/models/boarding_reservation_model.dart';
import '../../domain/entities/boarding_reservation_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stream: todas las reservas de una sucursal ordenadas por checkInExpected.
// Requiere índice compuesto: branchId ASC + checkInExpected ASC
// (ya creado en firestore.indexes.json para staff agenda).
// ─────────────────────────────────────────────────────────────────────────────

final branchReservationsStreamProvider =
    StreamProvider.family<List<BoardingReservationEntity>, String>((ref, branchId) {
  if (branchId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .demoCollection('boarding_reservations')
      .where('branchId', isEqualTo: branchId)
      .orderBy('checkInExpected')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => BoardingReservationModel.fromMap(doc.data(), doc.id))
          .toList());
});
