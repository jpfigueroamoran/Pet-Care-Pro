import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/firestore_extension.dart';
import '../../../subscriptions/domain/entities/subscription_tier.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final _vetDirectoryProvider = FutureProvider<List<_VetEntry>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .demoCollection('users')
      .where('role', isEqualTo: 'vet')
      .where('isApprovedVet', isEqualTo: true)
      .get();

  final vets = <_VetEntry>[];
  for (final doc in snap.docs) {
    final data = doc.data();
    final lat = (data['clinicLatitude'] as num?)?.toDouble();
    final lng = (data['clinicLongitude'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;

    final tier = SubscriptionTier.fromString(data['subscriptionTier'] as String?);
    if (!tier.isListedInDirectory) continue;

    final servicesList = data['services'] as List<dynamic>? ?? [];
    final serviceNames = servicesList
        .take(3)
        .map((s) => (s as Map<dynamic, dynamic>)['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final totalServices = servicesList.length;

    vets.add(_VetEntry(
      id: doc.id,
      name: data['displayName'] as String? ?? 'Veterinario',
      tier: tier,
      latitude: lat,
      longitude: lng,
      serviceNames: serviceNames,
      totalServices: totalServices,
      professionalLicense: data['professionalLicense'] as String?,
    ));
  }
  return vets;
});

// ── Model ─────────────────────────────────────────────────────────────────────

class _VetEntry {
  final String id;
  final String name;
  final SubscriptionTier tier;
  final double latitude;
  final double longitude;
  final List<String> serviceNames;
  final int totalServices;
  final String? professionalLicense;

  const _VetEntry({
    required this.id,
    required this.name,
    required this.tier,
    required this.latitude,
    required this.longitude,
    required this.serviceNames,
    required this.totalServices,
    this.professionalLicense,
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _markerHueForTier(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.premium:
      return BitmapDescriptor.hueYellow; // 60 – dorado
    case SubscriptionTier.profesional:
      return BitmapDescriptor.hueAzure; // 210 – azul
    case SubscriptionTier.basico:
      return BitmapDescriptor.hueCyan; // 180 – cian/menta
    default:
      return BitmapDescriptor.hueGreen; // 120 – verde (trial)
  }
}

Color _colorForTier(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.premium:
      return AppTheme.goldChampagne;
    case SubscriptionTier.profesional:
      return AppTheme.skyBlue;
    case SubscriptionTier.basico:
      return AppTheme.mintGreen;
    default:
      return Colors.green;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VetDirectoryScreen extends ConsumerStatefulWidget {
  const VetDirectoryScreen({super.key});

  @override
  ConsumerState<VetDirectoryScreen> createState() => _VetDirectoryScreenState();
}

class _VetDirectoryScreenState extends ConsumerState<VetDirectoryScreen> {
  GoogleMapController? _mapController;
  Position? _ownerPosition;
  _VetEntry? _selectedVet;

  static const _mexicoCityLatLng = LatLng(19.4326, -99.1332);

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() => _ownerPosition = pos);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
              LatLng(pos.latitude, pos.longitude), 12),
        );
      }
    } catch (_) {}
  }

  Set<Marker> _buildMarkers(List<_VetEntry> vets) {
    return vets.map((vet) {
      return Marker(
        markerId: MarkerId(vet.id),
        position: LatLng(vet.latitude, vet.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(_markerHueForTier(vet.tier)),
        onTap: () => setState(() => _selectedVet = vet),
        zIndex: vet.tier == SubscriptionTier.premium
            ? 3
            : vet.tier == SubscriptionTier.profesional
                ? 2
                : 1,
      );
    }).toSet();
  }

  void _dismissBottomSheet() => setState(() => _selectedVet = null);

  @override
  Widget build(BuildContext context) {
    final vetsAsync = ref.watch(_vetDirectoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Veterinarios Cercanos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: vetsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.mintGreen),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.coralRed)),
        ),
        data: (vets) {
          final markers = _buildMarkers(vets);
          final initialTarget = _ownerPosition != null
              ? LatLng(_ownerPosition!.latitude, _ownerPosition!.longitude)
              : _mexicoCityLatLng;

          return Stack(
            children: [
              // ── Map ───────────────────────────────────────────────────────
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: 12,
                ),
                onMapCreated: (ctrl) {
                  _mapController = ctrl;
                  if (_ownerPosition != null) {
                    ctrl.animateCamera(CameraUpdate.newLatLngZoom(
                        initialTarget, 12));
                  }
                },
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                onTap: (_) => _dismissBottomSheet(),
              ),

              // ── Legend ────────────────────────────────────────────────────
              Positioned(
                top: 12,
                left: 12,
                child: _LegendCard(),
              ),

              // ── Vet count chip ────────────────────────────────────────────
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${vets.length} veterinario${vets.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // ── Bottom sheet info ─────────────────────────────────────────
              if (_selectedVet != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _VetBottomSheet(
                    vet: _selectedVet!,
                    ownerPosition: _ownerPosition,
                    onClose: _dismissBottomSheet,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// ── Legend ─────────────────────────────────────────────────────────────────────

class _LegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendRow(BitmapDescriptor.hueYellow, 'Premium', AppTheme.goldChampagne),
          const SizedBox(height: 4),
          _legendRow(BitmapDescriptor.hueAzure, 'Profesional', AppTheme.skyBlue),
          const SizedBox(height: 4),
          _legendRow(BitmapDescriptor.hueCyan, 'Básico', AppTheme.mintGreen),
        ],
      ),
    );
  }

  Widget _legendRow(double hue, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Bottom Sheet ───────────────────────────────────────────────────────────────

class _VetBottomSheet extends StatelessWidget {
  final _VetEntry vet;
  final Position? ownerPosition;
  final VoidCallback onClose;

  const _VetBottomSheet({
    required this.vet,
    required this.ownerPosition,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = ownerPosition != null
        ? _haversineKm(ownerPosition!.latitude, ownerPosition!.longitude,
            vet.latitude, vet.longitude)
        : null;

    final tierColor = _colorForTier(vet.tier);
    final initials = vet.name.split(' ').take(2).map((w) => w[0]).join();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: tierColor.withValues(alpha: 0.15),
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: tierColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  vet.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: tierColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: tierColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (vet.tier == SubscriptionTier.premium)
                                      Icon(Icons.workspace_premium,
                                          size: 11, color: tierColor),
                                    if (vet.tier == SubscriptionTier.premium)
                                      const SizedBox(width: 3),
                                    Text(
                                      vet.tier.displayName.toUpperCase(),
                                      style: TextStyle(
                                          color: tierColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (distanceKm != null) ...[
                                const Icon(Icons.location_on,
                                    size: 13, color: AppTheme.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  distanceKm < 1
                                      ? '${(distanceKm * 1000).toInt()} m'
                                      : '${distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (vet.professionalLicense != null) ...[
                                const Icon(Icons.verified_user,
                                    size: 13, color: AppTheme.textMuted),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'Cédula: ${vet.professionalLicense}',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppTheme.textMuted, size: 20),
                      onPressed: onClose,
                    ),
                  ],
                ),

                // ── Services ─────────────────────────────────────────────
                if (vet.serviceNames.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 12),
                  const Text(
                    'Servicios',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ...vet.serviceNames.map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ),
                      ),
                      if (vet.totalServices > vet.serviceNames.length)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            '+${vet.totalServices - vet.serviceNames.length} más',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
