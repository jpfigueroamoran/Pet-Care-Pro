import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Coordenadas por defecto: Ciudad de México
const _kDefaultPosition = LatLng(19.4326, -99.1332);

class VetLocationScreen extends ConsumerStatefulWidget {
  const VetLocationScreen({super.key});

  @override
  ConsumerState<VetLocationScreen> createState() => _VetLocationScreenState();
}

class _VetLocationScreenState extends ConsumerState<VetLocationScreen> {
  GoogleMapController? _mapController;
  late LatLng _markerPosition;
  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user?.clinicLatitude != null && user?.clinicLongitude != null) {
      _markerPosition = LatLng(user!.clinicLatitude!, user.clinicLongitude!);
    } else {
      _markerPosition = _kDefaultPosition;
      _goToCurrentLocation();
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _markerPosition = latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _saveLocation() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateVetLocation(
            latitude: _markerPosition.latitude,
            longitude: _markerPosition.longitude,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación del consultorio guardada.'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación del Consultorio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.mintGreen),
                  ),
                )
              : TextButton(
                  onPressed: _saveLocation,
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                        color: AppTheme.mintGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _markerPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: {
              Marker(
                markerId: const MarkerId('clinic'),
                position: _markerPosition,
                draggable: true,
                infoWindow: const InfoWindow(title: 'Mi Consultorio'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                onDragEnd: (newPos) =>
                    setState(() => _markerPosition = newPos),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Instrucción
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, size: 16, color: AppTheme.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arrastra el pin verde hasta la ubicación exacta de tu consultorio',
                      style:
                          TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón "Mi ubicación"
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              backgroundColor: AppTheme.surface,
              onPressed: _isLocating ? null : _goToCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.mintGreen),
                    )
                  : const Icon(Icons.my_location,
                      color: AppTheme.mintGreen, size: 20),
            ),
          ),

          // Coordenadas actuales
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lat: ${_markerPosition.latitude.toStringAsFixed(6)}  '
                'Lng: ${_markerPosition.longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
