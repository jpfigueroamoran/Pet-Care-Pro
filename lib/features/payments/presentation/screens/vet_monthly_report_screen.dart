import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/entities/payment_entity.dart';

class VetMonthlyReportScreen extends ConsumerStatefulWidget {
  const VetMonthlyReportScreen({super.key});

  @override
  ConsumerState<VetMonthlyReportScreen> createState() =>
      _VetMonthlyReportScreenState();
}

class _VetMonthlyReportScreenState
    extends ConsumerState<VetMonthlyReportScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _isExporting = false;

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedYear == now.year && _selectedMonth == now.month) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  List<PaymentEntity> _filterByMonth(List<PaymentEntity> all) {
    return all
        .where((p) =>
            p.createdAt.year == _selectedYear &&
            p.createdAt.month == _selectedMonth)
        .toList();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} ${_monthNames[dt.month - 1].substring(0, 3)} ${dt.year}';
  }

  // ── PDF Export ──────────────────────────────────────────────────────────

  Future<void> _generateAndSharePDF(
      UserEntity? user, List<PaymentEntity> allPayments) async {
    setState(() => _isExporting = true);
    try {
      final monthly = _filterByMonth(allPayments);

      final paid = monthly.where((p) => p.status == 'paid').toList();
      final pending = monthly
          .where((p) => p.status == 'pending' || p.status == 'pending_review' || p.status == 'awaiting_physical_payment')
          .toList();
      final rejected = monthly.where((p) => p.status == 'rejected').toList();

      final totalCollected = paid.fold(0.0, (s, p) => s + p.totalAmount);
      final totalBilled = monthly.fold(0.0, (s, p) => s + p.totalAmount);
      final totalPending = pending.fold(0.0, (s, p) => s + p.totalAmount);
      final uniquePatients = monthly.map((p) => p.petId).toSet().length;

      final Map<String, _ServiceStat> serviceMap = {};
      for (final payment in paid) {
        for (final svc in payment.services) {
          serviceMap.update(
            svc.name,
            (e) => _ServiceStat(name: svc.name, count: e.count + 1, revenue: e.revenue + svc.price),
            ifAbsent: () => _ServiceStat(name: svc.name, count: 1, revenue: svc.price),
          );
        }
      }
      final topServices = serviceMap.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      // Fonts (Open Sans supports Latin extended / Spanish characters)
      final fontRegular = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();
      final fontItalic = await PdfGoogleFonts.openSansItalic();

      final theme = pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
      );

      // Color palette
      const teal = PdfColor(0.047, 0.510, 0.541);          // #0C828A
      const amber = PdfColor(0.910, 0.588, 0.169);          // #E8962B
      const red = PdfColor(0.937, 0.267, 0.267);            // #EF4444
      const green = PdfColor(0.133, 0.773, 0.369);          // #22C55E
      const darkText = PdfColor(0.051, 0.169, 0.180);       // #0D2B2E
      const mutedText = PdfColor(0.243, 0.400, 0.412);      // #3E6669
      const borderColor = PdfColor(0.812, 0.898, 0.890);    // #CFE5E3
      const lightBg = PdfColor(0.941, 0.976, 0.980);        // #F0F9FA

      final periodStr = '${_monthNames[_selectedMonth - 1]} $_selectedYear';
      final nowStr =
          '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            theme: theme,
            margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          ),
          build: (context) => [
            // ── Header ─────────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: teal,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PetCare Pro',
                          style: pw.TextStyle(
                              font: fontBold,
                              color: PdfColors.white,
                              fontSize: 18)),
                      pw.SizedBox(height: 4),
                      pw.Text('Reporte de Transacciones',
                          style: pw.TextStyle(
                              color: PdfColor(0.8, 0.93, 0.94), fontSize: 11)),
                      pw.SizedBox(height: 10),
                      pw.Text(user?.displayName ?? 'Veterinario',
                          style: pw.TextStyle(
                              font: fontBold,
                              color: PdfColors.white,
                              fontSize: 13)),
                      if ((user?.professionalLicense ?? '').isNotEmpty)
                        pw.Text('Cedula Profesional: ${user!.professionalLicense}',
                            style: pw.TextStyle(
                                color: PdfColor(0.8, 0.93, 0.94), fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(periodStr,
                            style: pw.TextStyle(
                                font: fontBold,
                                color: teal,
                                fontSize: 12)),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Generado: $nowStr',
                          style: pw.TextStyle(
                              color: PdfColor(0.8, 0.93, 0.94), fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // ── KPI Row ─────────────────────────────────────────────────────
            pw.Row(
              children: [
                _pdfKpi('Total Cobrado',
                    '\$${totalCollected.toStringAsFixed(2)}', 'MXN', green, fontBold),
                pw.SizedBox(width: 8),
                _pdfKpi('Total Facturado',
                    '\$${totalBilled.toStringAsFixed(0)}', 'MXN', amber, fontBold),
                pw.SizedBox(width: 8),
                _pdfKpi('Por Cobrar',
                    '\$${totalPending.toStringAsFixed(0)}', 'MXN', red, fontBold),
                pw.SizedBox(width: 8),
                _pdfKpi('Pacientes', '$uniquePatients', 'únicos', teal, fontBold),
              ],
            ),

            pw.SizedBox(height: 10),

            // ── Status chips ────────────────────────────────────────────────
            pw.Row(
              children: [
                _pdfStatusChip('Pagados: ${paid.length}', green, fontBold),
                pw.SizedBox(width: 6),
                _pdfStatusChip('Pendientes: ${pending.length}', amber, fontBold),
                pw.SizedBox(width: 6),
                _pdfStatusChip('Rechazados: ${rejected.length}', red, fontBold),
                pw.SizedBox(width: 6),
                _pdfStatusChip('Total cobros: ${monthly.length}', darkText, fontBold),
              ],
            ),

            pw.SizedBox(height: 20),

            // ── Top Services ────────────────────────────────────────────────
            if (topServices.isNotEmpty) ...[
              _pdfSectionTitle('Servicios con Mayor Ingreso', fontBold, darkText),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: teal),
                    children: [
                      _pdfTh('Servicio', fontBold),
                      _pdfTh('Consultas', fontBold),
                      _pdfTh('Ingresos', fontBold),
                    ],
                  ),
                  ...topServices.take(5).map((s) => pw.TableRow(
                        decoration: pw.BoxDecoration(color: lightBg),
                        children: [
                          _pdfTd(s.name, fontRegular, darkText),
                          _pdfTd('${s.count}x', fontRegular, darkText),
                          _pdfTd(
                              '\$${s.revenue.toStringAsFixed(0)} MXN', fontBold, teal),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // ── Transactions Table ──────────────────────────────────────────
            _pdfSectionTitle('Detalle de Cobros — $periodStr', fontBold, darkText),
            pw.SizedBox(height: 8),

            if (monthly.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Center(
                  child: pw.Text('Sin cobros registrados en este periodo.',
                      style: pw.TextStyle(
                          color: mutedText, font: fontItalic, fontSize: 11)),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.4),
                  1: const pw.FlexColumnWidth(1.4),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(2.8),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: teal),
                    children: [
                      _pdfTh('Fecha', fontBold),
                      _pdfTh('Paciente', fontBold),
                      _pdfTh('Dueno', fontBold),
                      _pdfTh('Servicios', fontBold),
                      _pdfTh('Monto', fontBold),
                      _pdfTh('Estado', fontBold),
                    ],
                  ),
                  ...monthly.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    final rowBg = i.isEven ? PdfColors.white : lightBg;
                    final (statusLabel, statusColor) = switch (p.status) {
                      'paid' => ('Pagado', green),
                      'pending_review' => ('Revision', amber),
                      'rejected' => ('Rechazado', red),
                      'awaiting_physical_payment' => ('En Caja', amber),
                      _ => ('Pendiente', mutedText),
                    };
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: [
                        _pdfTd(_formatDate(p.createdAt), fontRegular, darkText,
                            fontSize: 8),
                        _pdfTd(p.petName, fontBold, darkText),
                        _pdfTd(p.ownerName, fontRegular, mutedText),
                        _pdfTd(
                            p.services.map((s) => s.name).join(', '),
                            fontRegular,
                            darkText,
                            fontSize: 8),
                        _pdfTd(
                            '\$${p.totalAmount.toStringAsFixed(0)}',
                            fontBold,
                            statusColor),
                        _pdfTd(statusLabel, fontBold, statusColor, fontSize: 8),
                      ],
                    );
                  }),
                ],
              ),

            pw.SizedBox(height: 20),

            // ── Footer ──────────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PetCare Pro — Reporte Confidencial',
                      style:
                          pw.TextStyle(color: mutedText, fontSize: 8, font: fontItalic)),
                  pw.Text('Generado el $nowStr',
                      style: pw.TextStyle(color: mutedText, fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final filename =
          'petcarepro_${_monthNames[_selectedMonth - 1].toLowerCase()}_$_selectedYear.pdf';

      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppTheme.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── PDF widget helpers ──────────────────────────────────────────────────

  pw.Widget _pdfKpi(String label, String value, String unit, PdfColor color,
      pw.Font fontBold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    font: fontBold, color: PdfColors.white, fontSize: 13)),
            pw.Text('$label ($unit)',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 7.5)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfStatusChip(String text, PdfColor color, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(text,
          style:
              pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 9)),
    );
  }

  pw.Widget _pdfSectionTitle(String text, pw.Font fontBold, PdfColor color) {
    return pw.Text(text,
        style: pw.TextStyle(font: fontBold, color: color, fontSize: 12));
  }

  pw.Widget _pdfTh(String text, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              font: fontBold, color: PdfColors.white, fontSize: 9)),
    );
  }

  pw.Widget _pdfTd(String text, pw.Font font, PdfColor color,
      {double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(text,
          style: pw.TextStyle(font: font, color: color, fontSize: fontSize),
          overflow: pw.TextOverflow.clip),
    );
  }

  // ── Flutter UI ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final allPaymentsAsync =
        ref.watch(vetPaymentsStreamProvider(user?.uid ?? ''));

    // Available synchronously in the same frame — safe to use in AppBar
    final allPayments = allPaymentsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Reporte Mensual',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        backgroundColor: AppTheme.mintGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Exportar PDF',
              onPressed: allPayments == null
                  ? null
                  : () => _generateAndSharePDF(user, allPayments),
            ),
        ],
      ),
      body: allPaymentsAsync.when(
        data: (payments) {
          final monthly = _filterByMonth(payments);
          return _buildReport(context, user, monthly);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.mintGreen),
        ),
        error: (err, _) => Center(
          child: Text('Error al cargar datos: $err',
              style: const TextStyle(color: AppTheme.coralRed)),
        ),
      ),
    );
  }

  Widget _buildReport(
      BuildContext context, UserEntity? user, List<PaymentEntity> monthly) {
    final paid = monthly.where((p) => p.status == 'paid').toList();
    final pending = monthly
        .where((p) =>
            p.status == 'pending' ||
            p.status == 'pending_review' ||
            p.status == 'awaiting_physical_payment')
        .toList();

    final totalBilled = monthly.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalCollected = paid.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalPending = pending.fold(0.0, (sum, p) => sum + p.totalAmount);
    final uniquePatients = monthly.map((p) => p.petId).toSet().length;

    final Map<String, _ServiceStat> serviceMap = {};
    for (final payment in paid) {
      for (final svc in payment.services) {
        serviceMap.update(
          svc.name,
          (existing) => _ServiceStat(
            name: svc.name,
            count: existing.count + 1,
            revenue: existing.revenue + svc.price,
          ),
          ifAbsent: () =>
              _ServiceStat(name: svc.name, count: 1, revenue: svc.price),
        );
      }
    }
    final topServices = serviceMap.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final maxRevenue =
        topServices.isEmpty ? 1.0 : topServices.first.revenue;

    return CustomScrollView(
      slivers: [
        // ── Month navigator ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppTheme.mintGreen,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 28),
                      onPressed: _prevMonth,
                    ),
                    Text(
                      '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: _isCurrentMonth ? Colors.white30 : Colors.white,
                        size: 28,
                      ),
                      onPressed: _isCurrentMonth ? null : _nextMonth,
                    ),
                  ],
                ),
                Text(
                  user?.displayName ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // ── Summary ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.mintGreen, AppTheme.skyBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mintGreen.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Cobrado',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '\$${totalCollected.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (totalPending > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+\$${totalPending.toStringAsFixed(0)} pendiente de cobro',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.0,
                  children: [
                    _kpiCard('Facturado', '\$${totalBilled.toStringAsFixed(0)}',
                        Icons.receipt_outlined, AppTheme.goldChampagne),
                    _kpiCard('Pacientes', '$uniquePatients',
                        Icons.pets_outlined, AppTheme.skyBlue),
                    _kpiCard('Pagados', '${paid.length}',
                        Icons.check_circle_outline, AppTheme.mintGreen),
                    _kpiCard('Pendientes', '${pending.length}',
                        Icons.hourglass_empty_outlined, AppTheme.coralRed),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Top Services ───────────────────────────────────────────────
        if (topServices.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.goldChampagne.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_outlined,
                        color: AppTheme.goldChampagne, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Servicios con Mayor Ingreso',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: topServices
                      .take(5)
                      .map((s) => _serviceBar(s, maxRevenue))
                      .toList(),
                ),
              ),
            ),
          ),
        ],

        // ── Transaction list ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.skyBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.list_alt_outlined,
                          color: AppTheme.skyBlue, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Cobros del Período',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${monthly.length} total',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        if (monthly.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        color: AppTheme.textMuted, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Sin cobros registrados este mes.',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _paymentCard(monthly[index]),
                childCount: monthly.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _kpiCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceBar(_ServiceStat stat, double maxRevenue) {
    final fraction = maxRevenue > 0 ? stat.revenue / maxRevenue : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stat.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stat.count}× · \$${stat.revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: AppTheme.goldChampagne,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.goldChampagne),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(PaymentEntity payment) {
    final (statusLabel, statusColor) = switch (payment.status) {
      'paid' => ('Pagado', AppTheme.mintGreen),
      'pending_review' => ('En revisión', AppTheme.skyBlue),
      'rejected' => ('Rechazado', AppTheme.coralRed),
      'awaiting_physical_payment' => ('En Caja', AppTheme.goldChampagne),
      _ => ('Pendiente', AppTheme.goldChampagne),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pets_outlined, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.petName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  payment.services.map((s) => s.name).join(', '),
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(payment.createdAt),
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${payment.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceStat {
  final String name;
  final int count;
  final double revenue;
  const _ServiceStat(
      {required this.name, required this.count, required this.revenue});
}
