import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/setup_wizard_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SetupWizardScreen — Wizard de configuración inicial para admins
// 6 pasos: Bienvenida → Perfil → Servicios → Corrales → Equipo → Listo
// ─────────────────────────────────────────────────────────────────────────────

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _pageController = PageController();
  bool _pageInitialized = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(setupWizardProvider);

    // Animate page whenever step changes (navigation within the wizard)
    ref.listen(setupWizardProvider.select((s) => s.step), (_, next) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        );
      }
    });

    if (!wizard.loaded) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.mintGreen),
        ),
      );
    }

    // On first load, jump the PageView to the persisted step so the displayed
    // page matches the provider state (avoids validation errors on wrong page).
    if (!_pageInitialized) {
      _pageInitialized = true;
      if (wizard.step > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(wizard.step);
          }
        });
      }
    }

    return PopScope(
      canPop: wizard.isWelcome || wizard.isDone,
      onPopInvoked: (didPop) {
        if (!didPop) ref.read(setupWizardProvider.notifier).goBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              if (!wizard.isWelcome && !wizard.isDone)
                _WizardHeader(step: wizard.progressStep),

              // ── Content ─────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _WelcomeStep(),
                    _ProfileStep(),
                    _ServicesStep(),
                    _FacilityStep(),
                    _TeamStep(),
                    _CompleteStep(),
                  ],
                ),
              ),

              // ── Error banner ─────────────────────────────────────────────
              if (wizard.saveError != null)
                _ErrorBanner(message: wizard.saveError!),

              // ── Navigation ───────────────────────────────────────────────
              if (!wizard.isWelcome && !wizard.isDone)
                _WizardNavigation(wizard: wizard),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header con indicador de progreso
// ─────────────────────────────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int step; // 1–4

  const _WizardHeader({required this.step});

  static const _labels = ['Perfil', 'Servicios', 'Corrales', 'Equipo'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(4, (i) {
              final idx = i + 1;
              final done = idx < step;
              final active = idx == step;
              return Expanded(
                child: Row(
                  children: [
                    _StepDot(index: idx, done: done, active: active),
                    if (i < 3)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: done
                              ? AppTheme.mintGreen
                              : AppTheme.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              final idx = i + 1;
              final active = idx == step;
              return SizedBox(
                width: 64,
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        active ? FontWeight.bold : FontWeight.normal,
                    color: active
                        ? AppTheme.mintGreen
                        : AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool done;
  final bool active;

  const _StepDot({required this.index, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppTheme.mintGreen
            : active
                ? AppTheme.mintGreen.withValues(alpha: 0.15)
                : AppTheme.surfaceVariant,
        border: Border.all(
          color: done || active ? AppTheme.mintGreen : AppTheme.border,
          width: 2,
        ),
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '$index',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: active ? AppTheme.mintGreen : AppTheme.textMuted,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _WizardNavigation extends ConsumerWidget {
  final WizardState wizard;

  const _WizardNavigation({required this.wizard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(setupWizardProvider.notifier);
    final isLastContent = wizard.step == 4; // last content step before "done"

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (wizard.step > 1)
            OutlinedButton(
              onPressed: wizard.saving ? null : notifier.goBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Atrás'),
            ),
          if (wizard.step > 1) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: wizard.saving
                  ? null
                  : isLastContent
                      ? notifier.complete
                      : notifier.goNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: wizard.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isLastContent ? 'Completar configuración' : 'Siguiente',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppTheme.coralRed.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.coralRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppTheme.coralRed, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared step widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _StepTitle(
      {required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.mintGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.mintGreen, size: 24),
        ),
        const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 14, height: 1.4)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    );
  }
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
      filled: true,
      fillColor: AppTheme.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.mintGreen, width: 1.5)),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Paso 0: Bienvenida
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.mintGreen, Color(0xFF095A60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                Icon(Icons.rocket_launch_outlined,
                    size: 56, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  '¡Configura tu negocio\nen minutos!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3),
                ),
                SizedBox(height: 8),
                Text(
                  'Te guiaremos paso a paso para que tu clínica o guardería esté operativa desde hoy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'En este wizard configurarás:',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...[
            (Icons.business_outlined, 'Perfil de tu negocio',
                'Nombre, sucursal, dirección y contacto'),
            (Icons.medical_services_outlined, 'Catálogo de servicios',
                'Consultas, baños, cortes y más con sus precios'),
            (Icons.home_work_outlined, 'Corrales y habitaciones',
                'Capacidad y especies admitidas en guardería'),
            (Icons.group_add_outlined, 'Tu equipo',
                'Invita a veterinarios y staff con sus roles'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.mintGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.$1, color: AppTheme.mintGreen, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(item.$3,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  ref.read(setupWizardProvider.notifier).goNext(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Comenzar configuración',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 1: Perfil del negocio
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileStep extends ConsumerStatefulWidget {
  const _ProfileStep();

  @override
  ConsumerState<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<_ProfileStep> {
  late final TextEditingController _businessName;
  late final TextEditingController _branchName;
  late final TextEditingController _address;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final s = ref.read(setupWizardProvider);
    _businessName = TextEditingController(text: s.businessName);
    _branchName = TextEditingController(text: s.branchName);
    _address = TextEditingController(text: s.address);
    _phone = TextEditingController(text: s.phone);
  }

  @override
  void dispose() {
    _businessName.dispose();
    _branchName.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(setupWizardProvider.notifier);

    // Sync controllers with persisted data once loading completes
    ref.listen(setupWizardProvider.select((s) => s.loaded), (_, loaded) {
      if (!loaded) return;
      final s = ref.read(setupWizardProvider);
      if (_businessName.text.isEmpty && s.businessName.isNotEmpty) {
        _businessName.text = s.businessName;
      }
      if (_branchName.text.isEmpty && s.branchName.isNotEmpty) {
        _branchName.text = s.branchName;
      }
      if (_address.text.isEmpty && s.address.isNotEmpty) {
        _address.text = s.address;
      }
      if (_phone.text.isEmpty && s.phone.isNotEmpty) {
        _phone.text = s.phone;
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(
            icon: Icons.business_outlined,
            title: 'Perfil del negocio',
            subtitle:
                'Esta información aparecerá en reportes y documentos generados por el sistema.',
          ),
          const SizedBox(height: 28),
          const _FieldLabel('Nombre del negocio *'),
          TextField(
            controller: _businessName,
            onChanged: notifier.setBusinessName,
            decoration: _fieldDecoration('Ej. Clínica Veterinaria Los Robles'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Nombre de la sucursal *'),
          TextField(
            controller: _branchName,
            onChanged: notifier.setBranchName,
            decoration: _fieldDecoration('Ej. Sucursal Norte'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Dirección'),
          TextField(
            controller: _address,
            onChanged: notifier.setAddress,
            decoration:
                _fieldDecoration('Ej. Av. Insurgentes 1234, Col. Centro'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Teléfono de contacto'),
          TextField(
            controller: _phone,
            onChanged: notifier.setPhone,
            decoration: _fieldDecoration('Ej. 55 1234 5678'),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]'))],
          ),
          const SizedBox(height: 8),
          const Text(
            '* Campos obligatorios',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 2: Servicios y precios
// ─────────────────────────────────────────────────────────────────────────────

class _ServicesStep extends ConsumerWidget {
  const _ServicesStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(setupWizardProvider.select((s) => s.services));
    final notifier = ref.read(setupWizardProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            children: [
              const _StepTitle(
                icon: Icons.medical_services_outlined,
                title: 'Servicios y precios',
                subtitle:
                    'Define los servicios que ofreces. Puedes modificarlos en cualquier momento desde el panel de configuración.',
              ),
              const SizedBox(height: 24),
              ...services.asMap().entries.map(
                    (e) => _ServiceItem(
                      index: e.key,
                      service: e.value,
                      onUpdate: (s) => notifier.updateService(e.key, s),
                      onRemove: services.length > 1
                          ? () => notifier.removeService(e.key)
                          : null,
                    ),
                  ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        _AddItemButton(
          label: 'Agregar servicio',
          icon: Icons.add_circle_outline,
          onTap: () => notifier.addService(
            const WizardService(name: '', price: 0, durationMinutes: 30),
          ),
        ),
      ],
    );
  }
}

class _ServiceItem extends StatefulWidget {
  final int index;
  final WizardService service;
  final void Function(WizardService) onUpdate;
  final VoidCallback? onRemove;

  const _ServiceItem({
    required this.index,
    required this.service,
    required this.onUpdate,
    this.onRemove,
  });

  @override
  State<_ServiceItem> createState() => _ServiceItemState();
}

class _ServiceItemState extends State<_ServiceItem> {
  late final TextEditingController _name;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.service.name);
    _price = TextEditingController(
        text: widget.service.price > 0
            ? widget.service.price.toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.mintGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                        color: AppTheme.mintGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _name,
                  onChanged: (v) =>
                      widget.onUpdate(widget.service.copyWith(name: v)),
                  decoration: _fieldDecoration('Nombre del servicio'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.coralRed, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Precio (MXN)'),
                    TextField(
                      controller: _price,
                      onChanged: (v) => widget.onUpdate(
                        widget.service.copyWith(
                            price: double.tryParse(v) ?? 0),
                      ),
                      decoration: _fieldDecoration('450'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Duración'),
                    DropdownButtonFormField<int>(
                      value: widget.service.durationMinutes,
                      decoration: _fieldDecoration(''),
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      dropdownColor: AppTheme.surface,
                      items: [15, 30, 45, 60, 90, 120].map((min) {
                        final label = min < 60
                            ? '$min min'
                            : '${min ~/ 60}h${min % 60 > 0 ? ' ${min % 60}min' : ''}';
                        return DropdownMenuItem(
                            value: min, child: Text(label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          widget.onUpdate(
                              widget.service.copyWith(durationMinutes: v));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 3: Corrales / Habitaciones
// ─────────────────────────────────────────────────────────────────────────────

class _FacilityStep extends ConsumerWidget {
  const _FacilityStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(setupWizardProvider.select((s) => s.runs));
    final notifier = ref.read(setupWizardProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            children: [
              const _StepTitle(
                icon: Icons.home_work_outlined,
                title: 'Corrales y habitaciones',
                subtitle:
                    'Configura los espacios de tu guardería. El sistema usará esta información para gestionar disponibilidad.',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.skyBlue.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.skyBlue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este paso es opcional si solo ofreces consultas o baños sin estancias.',
                        style: TextStyle(
                            color: AppTheme.skyBlue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              ...runs.asMap().entries.map(
                    (e) => _RunItem(
                      index: e.key,
                      run: e.value,
                      onUpdate: (r) => notifier.updateRun(e.key, r),
                      onRemove: () => notifier.removeRun(e.key),
                    ),
                  ),
            ],
          ),
        ),
        _AddItemButton(
          label: 'Agregar corral / habitación',
          icon: Icons.add_home_outlined,
          onTap: () => notifier.addRun(
            const WizardFacilityRun(
                name: '', capacity: 1, species: 'both'),
          ),
        ),
      ],
    );
  }
}

class _RunItem extends StatefulWidget {
  final int index;
  final WizardFacilityRun run;
  final void Function(WizardFacilityRun) onUpdate;
  final VoidCallback onRemove;

  const _RunItem({
    required this.index,
    required this.run,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_RunItem> createState() => _RunItemState();
}

class _RunItemState extends State<_RunItem> {
  late final TextEditingController _name;
  late final TextEditingController _capacity;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.run.name);
    _capacity = TextEditingController(text: '${widget.run.capacity}');
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.home_work_outlined,
                  color: AppTheme.mintGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _name,
                  onChanged: (v) =>
                      widget.onUpdate(widget.run.copyWith(name: v)),
                  decoration: _fieldDecoration('Nombre del espacio'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppTheme.coralRed, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Capacidad'),
                    TextField(
                      controller: _capacity,
                      onChanged: (v) => widget.onUpdate(
                          widget.run.copyWith(capacity: int.tryParse(v) ?? 1)),
                      decoration: _fieldDecoration('Nº mascotas'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Especie'),
                    DropdownButtonFormField<String>(
                      value: widget.run.species,
                      decoration: _fieldDecoration(''),
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      dropdownColor: AppTheme.surface,
                      items: const [
                        DropdownMenuItem(
                            value: 'dog', child: Text('Solo Perros')),
                        DropdownMenuItem(
                            value: 'cat', child: Text('Solo Gatos')),
                        DropdownMenuItem(
                            value: 'both', child: Text('Ambas')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          widget.onUpdate(widget.run.copyWith(species: v));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 4: Equipo e invitaciones
// ─────────────────────────────────────────────────────────────────────────────

class _TeamStep extends ConsumerWidget {
  const _TeamStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(setupWizardProvider.select((s) => s.invites));
    final notifier = ref.read(setupWizardProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            children: [
              const _StepTitle(
                icon: Icons.group_add_outlined,
                title: 'Tu equipo',
                subtitle:
                    'Invita a los miembros de tu equipo. Recibirán un correo para crear su cuenta con el rol asignado.',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.goldChampagne.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.goldChampagne.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.goldChampagne, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este paso es opcional. Puedes invitar a tu equipo en cualquier momento desde el dashboard.',
                        style: TextStyle(
                            color: AppTheme.goldChampagne, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              if (invites.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(Icons.person_add_disabled_outlined,
                            size: 48,
                            color: AppTheme.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          'Sin invitaciones todavía',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...invites.asMap().entries.map(
                      (e) => _InviteItem(
                        index: e.key,
                        invite: e.value,
                        onUpdate: (inv) => notifier.addInvite(inv),
                        onRemove: () => notifier.removeInvite(e.key),
                      ),
                    ),
            ],
          ),
        ),
        _AddItemButton(
          label: 'Agregar miembro',
          icon: Icons.person_add_outlined,
          onTap: () => notifier.addInvite(
              const WizardInvite(email: '', role: 'vet')),
        ),
      ],
    );
  }
}

class _InviteItem extends StatefulWidget {
  final int index;
  final WizardInvite invite;
  final void Function(WizardInvite) onUpdate;
  final VoidCallback onRemove;

  const _InviteItem({
    required this.index,
    required this.invite,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_InviteItem> createState() => _InviteItemState();
}

class _InviteItemState extends State<_InviteItem> {
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.invite.email);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _email,
              onChanged: (v) =>
                  widget.onUpdate(WizardInvite(email: v, role: widget.invite.role)),
              decoration: _fieldDecoration('correo@ejemplo.com'),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: widget.invite.role,
              decoration: _fieldDecoration(''),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13),
              dropdownColor: AppTheme.surface,
              items: const [
                DropdownMenuItem(value: 'vet',          child: Text('Veterinario')),
                DropdownMenuItem(value: 'groomer',      child: Text('Lavador / Estilista')),
                DropdownMenuItem(value: 'caretaker',    child: Text('Cuidador de Guardería')),
                DropdownMenuItem(value: 'receptionist', child: Text('Recepcionista')),
                DropdownMenuItem(value: 'admin',        child: Text('Administrador')),
              ],
              onChanged: (v) {
                if (v != null) {
                  widget.onUpdate(
                      WizardInvite(email: widget.invite.email, role: v));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.remove_circle_outline,
                color: AppTheme.coralRed, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paso 5: ¡Configuración completa!
// ─────────────────────────────────────────────────────────────────────────────

class _CompleteStep extends ConsumerWidget {
  const _CompleteStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(setupWizardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Column(
        children: [
          // Hero de confirmación
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), AppTheme.mintGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  '¡Todo listo!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Tu negocio está configurado y listo para operar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Resumen
          _SummaryCard(
            icon: Icons.business_outlined,
            title: wizard.businessName.isEmpty
                ? 'Negocio'
                : wizard.businessName,
            subtitle: wizard.branchName.isEmpty
                ? '—'
                : wizard.branchName,
          ),
          _SummaryCard(
            icon: Icons.medical_services_outlined,
            title: '${wizard.services.length} servicio${wizard.services.length == 1 ? '' : 's'} configurado${wizard.services.length == 1 ? '' : 's'}',
            subtitle: wizard.services.map((s) => s.name).join(', '),
          ),
          if (wizard.runs.isNotEmpty)
            _SummaryCard(
              icon: Icons.home_work_outlined,
              title:
                  '${wizard.runs.length} corral${wizard.runs.length == 1 ? '' : 'es'} registrado${wizard.runs.length == 1 ? '' : 's'}',
              subtitle: wizard.runs.map((r) => r.name).join(', '),
            ),
          if (wizard.invites.isNotEmpty)
            _SummaryCard(
              icon: Icons.group_outlined,
              title:
                  '${wizard.invites.length} invitación${wizard.invites.length == 1 ? '' : 'es'} enviada${wizard.invites.length == 1 ? '' : 's'}',
              subtitle: wizard.invites.map((i) => i.email).join(', '),
            ),

          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.mintGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.mintGreen.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    color: AppTheme.mintGreen, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Puedes ajustar cualquier configuración en cualquier momento desde el panel de Ajustes del dashboard.',
                    style: TextStyle(
                        color: AppTheme.mintGreen,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/admin-dashboard'),
              icon: const Icon(Icons.dashboard_outlined, size: 20),
              label: const Text(
                'Ir al Dashboard',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.2),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SummaryCard(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mintGreen, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppTheme.mintGreen, size: 18),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: Add item button
// ─────────────────────────────────────────────────────────────────────────────

class _AddItemButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddItemButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.mintGreen,
          side: const BorderSide(color: AppTheme.mintGreen),
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
