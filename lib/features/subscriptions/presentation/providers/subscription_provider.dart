import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/subscription_tier.dart';

/// Returns the effective subscription tier for the current vet,
/// factoring in trial expiry client-side as a safety net.
final subscriptionTierProvider = Provider<SubscriptionTier>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isVet) return SubscriptionTier.free;

  final raw = SubscriptionTier.fromString(user.subscriptionTier);

  if (raw == SubscriptionTier.trial) {
    final trialEndsAt = user.trialEndsAt;
    if (trialEndsAt == null || trialEndsAt.isBefore(DateTime.now())) {
      return SubscriptionTier.free;
    }
  }

  return raw;
});

/// Days remaining in the active trial (null when not in trial).
final trialDaysRemainingProvider = Provider<int?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.subscriptionTier != 'trial') return null;
  final trialEndsAt = user.trialEndsAt;
  if (trialEndsAt == null) return null;
  final diff = trialEndsAt.difference(DateTime.now()).inDays;
  return diff > 0 ? diff : null;
});
