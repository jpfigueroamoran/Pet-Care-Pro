import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pets/domain/entities/pet_entity.dart';
import '../../../pets/data/repositories/pet_repository.dart';

class _DurationOption {
  final String label;
  final int? minutes; // null = sin límite
  const _DurationOption(this.label, this.minutes);
}

const _durationOptions = [
  _DurationOption('30 min', 30),
  _DurationOption('1 h', 60),
  _DurationOption('2 h', 120),
  _DurationOption('4 h', 240),
  _DurationOption('8 h', 480),
  _DurationOption('Sin límite', null),
];

class ShareQRScreen extends ConsumerStatefulWidget {
  final String petId;
  const ShareQRScreen({super.key, required this.petId});

  @override
  ConsumerState<ShareQRScreen> createState() => _ShareQRScreenState();
}

class _ShareQRScreenState extends ConsumerState<ShareQRScreen> {
  int _secondsRemaining = 900;
  Timer? _timer;
  String _qrData = '';
  bool _isLoading = true;
  String? _errorMessage;
  int? _durationMinutes = 120; // default 2 h

  @override
  void initState() {
    super.initState();
    _fetchRealQrToken();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRealQrToken() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider);
      final ownerId = currentUser?.uid ?? '';

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generateQrToken');
      final response = await callable.call(<String, dynamic>{
        'petId': widget.petId,
        'ownerId': ownerId,
        'durationMinutes': _durationMinutes,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] == true) {
        final String tokenId = data['tokenId'] as String;
        final int expTimeMs = (data['expiresAt'] as num).toInt();

        final int currentMs = DateTime.now().millisecondsSinceEpoch;
        final int remainingSeconds = ((expTimeMs - currentMs) / 1000).round();

        if (mounted) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);

          setState(() {
            _qrData = tokenId;
            _secondsRemaining = remainingSeconds > 0 ? remainingSeconds : 900;
            _isLoading = false;
          });

          _timer?.cancel();
          _startTimer();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Respuesta inválida del servidor de seguridad.';
            _isLoading = false;
          });
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de seguridad: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          if (_secondsRemaining == 60) HapticFeedback.selectionClick();
          setState(() => _secondsRemaining--);
        }
      } else {
        _timer?.cancel();
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El código QR ha expirado. Generando uno nuevo...'),
              backgroundColor: AppTheme.coralRed,
            ),
          );
          _fetchRealQrToken();
        }
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _onDurationChanged(int? newMinutes) {
    if (_durationMinutes == newMinutes) return;
    _timer?.cancel();
    setState(() => _durationMinutes = newMinutes);
    _fetchRealQrToken();
  }

  String get _accessDescription {
    if (_durationMinutes == null) {
      return 'El veterinario tendrá acceso al expediente hasta que tú lo revoques.';
    }
    if (_durationMinutes! < 60) {
      return 'El veterinario tendrá acceso durante $_durationMinutes minutos después de escanear.';
    }
    final hours = _durationMinutes! ~/ 60;
    return 'El veterinario tendrá acceso durante $hours hora${hours > 1 ? 's' : ''} después de escanear.';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final petsAsync = user != null
        ? ref.watch(ownerPetsStreamProvider(user.uid))
        : const AsyncValue<List<PetEntity>>.data([]);

    final pet = petsAsync.when(
      data: (list) => list.firstWhere(
        (e) => e.id == widget.petId,
        orElse: () => PetEntity(id: 'unknown', name: 'Mascota', species: '', breed: '', age: 0, photoUrl: '', ownerId: '', createdAt: DateTime.now()),
      ),
      loading: () => PetEntity(id: 'loading', name: 'Cargando...', species: '', breed: '', age: 0, photoUrl: '', ownerId: '', createdAt: DateTime.now()),
      error: (_, __) => PetEntity(id: 'error', name: 'Error', species: '', breed: '', age: 0, photoUrl: '', ownerId: '', createdAt: DateTime.now()),
    );

    final isUnlimited = _durationMinutes == null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Compartir Acceso', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pet info card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: pet.photoUrl.isNotEmpty ? NetworkImage(pet.photoUrl) : null,
                      backgroundColor: AppTheme.surfaceVariant,
                      child: pet.photoUrl.isEmpty ? const Icon(Icons.pets, color: AppTheme.textMuted, size: 20) : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pet.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(pet.breed, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Selector de duración ────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Duración del acceso',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationOptions.map((opt) {
                  final isSelected = _durationMinutes == opt.minutes;
                  final color = opt.minutes == null ? AppTheme.coralRed : AppTheme.skyBlue;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _onDurationChanged(opt.minutes);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? color.withValues(alpha: 0.5) : AppTheme.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          color: isSelected ? color : AppTheme.textMuted,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Descripción del acceso
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _accessDescription,
                  style: TextStyle(
                    color: isUnlimited ? AppTheme.coralRed : AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                Container(
                  height: 288,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: AppTheme.mintGreen),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.coralRed.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.coralRed, size: 48),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchRealQrToken,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mintGreen),
                        child: const Text('REINTENTAR'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    // QR container
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: (isUnlimited ? AppTheme.coralRed : AppTheme.skyBlue).withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 240.0,
                        gapless: false,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.slate900),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppTheme.slate900),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cuenta regresiva de validez del QR (ventana de 15 min para escanear)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: AppTheme.goldChampagne, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Escanear en: ${_formatTime(_secondsRemaining)}',
                            style: const TextStyle(color: AppTheme.goldChampagne, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Badge de duración del acceso tras escanear
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: (isUnlimited ? AppTheme.coralRed : AppTheme.skyBlue).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: (isUnlimited ? AppTheme.coralRed : AppTheme.skyBlue).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUnlimited ? Icons.lock_open_outlined : Icons.access_time_outlined,
                            color: isUnlimited ? AppTheme.coralRed : AppTheme.skyBlue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isUnlimited
                                ? 'Sin límite — revoca cuando quieras'
                                : 'Acceso por ${_durationMinutes! < 60 ? '$_durationMinutes min' : '${_durationMinutes! ~/ 60}h'} tras escanear',
                            style: TextStyle(
                              color: isUnlimited ? AppTheme.coralRed : AppTheme.skyBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),
              Text(
                'El veterinario escanea este código QR\npara recibir acceso al expediente de ${pet.name}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
