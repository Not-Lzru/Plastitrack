import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../widgets/app_menu_button.dart';
import '../services/pdf_reporte_service.dart';

// ============================ COLORES (locales) ============================
class _C {
  static const canvas = Color(0xFFEAF2FB);
  static const header = Color(0xFF1E3A5F);
  static const primary = Color(0xFF022448);
  static const secondary = Color(0xFF0162A2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainerHighest = Color(0xFFD9E3F6);
  static const onSurfaceVariant = Color(0xFF43474E);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const outline = Color(0xFF74777F);
  static const outlineVariant = Color(0xFFC4C6CF);
  static const borderSubtle = Color(0xFFE2E5EA);
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFE0A526);
  static const error = Color(0xFFD64545);
  static const bar = Color(0xFF3B82C4);
}

// ============================ MODELOS ======================================
class _Defect {
  final String name;
  final int count;
  final double kg;
  const _Defect(this.name, this.count, this.kg);
}

class _Registro {
  final String hora;
  final String iny;
  final String evento;
  final String impacto;
  final IconData icon;
  final Color color;
  final bool bold;
  final DateTime fechaHora;

  const _Registro({
    required this.hora,
    required this.iny,
    required this.evento,
    required this.impacto,
    required this.icon,
    required this.color,
    required this.fechaHora,
    this.bold = false,
  });
}

// ============================ PANTALLA =====================================
class HistorialReportesScreen extends StatefulWidget {
  const HistorialReportesScreen({super.key});

  @override
  State<HistorialReportesScreen> createState() =>
      _HistorialReportesScreenState();
}

class _HistorialReportesScreenState extends State<HistorialReportesScreen> {
  // ---- Filtros ----
  static const _fechas = ['Todos', 'Hoy', 'Ayer', 'Últimos 7 días'];
  static const _inyectoras = ['Todas', 'INY-01', 'INY-02', 'INY-03', 'INY-04', 'INY-05'];
  static const _turnos = ['Todos', 'Turno A (06-14)', 'Turno B (14-22)', 'Turno C (22-06)'];

  String _fecha = 'Todos';
  String _inyectora = 'Todas';
  String _turno = 'Todos';

  // ---- Paginación ----
  static const _pageSize = 5;
  int _page = 1;

  // ---- Estado Backend ----
  bool _isLoading = true;
  String? _errorMessage;

  double _totalKgMerma = 0.0;
  double _totalMinutosParo = 0.0;
  int _totalParosCount = 0;
  int _totalMermaRegs = 0;

  List<_Defect> _defects = [];
  List<_Registro> _todosLosRegistros = [];

  @override
  void initState() {
    super.initState();
    _cargarDashboardReportes();
  }

  void _volverAlDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _generarReportePdf() async {
  if (_registrosFiltrados.isEmpty) {
    _snack('No hay registros filtrados para exportar a PDF.');
    return;
  }

  _snack('Generando documento PDF...');

  await PdfReportService.generarYExportarPdf(
    inyectora: _inyectora,
    turno: _turno,
    fecha: _fecha,
    totalKgMerma: _totalKgMerma,
    totalMinutosParo: _totalMinutosParo,
    registros: _registrosFiltrados,
  );
}

  String _formatearNombreInyectora(String nombreCompleto) {
    if (nombreCompleto.contains('01')) return 'INY-01';
    if (nombreCompleto.contains('02')) return 'INY-02';
    if (nombreCompleto.contains('03')) return 'INY-03';
    if (nombreCompleto.contains('04')) return 'INY-04';
    if (nombreCompleto.contains('05')) return 'INY-05';
    return 'Gral';
  }

  String _formatearHora(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _cargarDashboardReportes() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await AuthService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}/reportes/dashboard');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final metricas = data['metricas_generales'] ?? {};
        final List<dynamic> mermasRaw = data['desglose_mermas'] ?? [];
        final List<dynamic> regMermas = data['registros_mermas'] ?? [];
        final List<dynamic> regParos = data['registros_paros'] ?? [];

        final List<_Defect> defectList = mermasRaw.map((m) {
          final count = int.tryParse(m['cantidad_registros']?.toString() ?? '0') ?? 0;
          final kg = double.tryParse(m['total_kg']?.toString() ?? '0.0') ?? 0.0;
          return _Defect(m['tipo_defecto']?.toString() ?? 'Defecto', count, kg);
        }).toList();

        final List<_Registro> regList = [];

        for (final m in regMermas) {
          final fechaHora = DateTime.tryParse(m['fecha']?.toString() ?? '') ?? DateTime.now();
          regList.add(
            _Registro(
              hora: _formatearHora(fechaHora),
              iny: _formatearNombreInyectora(m['nombre_maquina']?.toString() ?? ''),
              evento: m['evento']?.toString() ?? 'Merma',
              impacto: m['impacto']?.toString() ?? '0.0 kg merma',
              icon: Icons.delete_sweep,
              color: _C.error,
              fechaHora: fechaHora,
            ),
          );
        }

        for (final p in regParos) {
          final fechaHora = DateTime.tryParse(p['fecha']?.toString() ?? '') ?? DateTime.now();
          regList.add(
            _Registro(
              hora: _formatearHora(fechaHora),
              iny: _formatearNombreInyectora(p['nombre_maquina']?.toString() ?? ''),
              evento: p['evento']?.toString() ?? 'Paro de Línea',
              impacto: p['impacto']?.toString() ?? '0 min inactivo',
              icon: Icons.timer_outlined,
              color: _C.warning,
              bold: true,
              fechaHora: fechaHora,
            ),
          );
        }

        regList.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

        setState(() {
          _totalKgMerma = double.tryParse(metricas['total_kg_merma']?.toString() ?? '0.0') ?? 0.0;
          _totalMinutosParo = double.tryParse(metricas['total_minutos_inactivos']?.toString() ?? '0.0') ?? 0.0;
          _totalParosCount = int.tryParse(metricas['total_paros_linea']?.toString() ?? '0') ?? 0;
          _totalMermaRegs = int.tryParse(metricas['total_registros_merma']?.toString() ?? '0') ?? 0;
          _defects = defectList;
          _todosLosRegistros = regList;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesión expirada. Inicia sesión nuevamente.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else if (response.statusCode == 403) {
        setState(() {
          _errorMessage = 'Acceso denegado: Este módulo requiere rol de Supervisor o Administrador.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error de conexión con el backend ($e)';
        _isLoading = false;
      });
    }
  }

  String _obtenerTurnoDesdeHora(DateTime dt) {
    final hour = dt.hour;
    if (hour >= 6 && hour < 14) {
      return 'Turno A (06-14)';
    } else if (hour >= 14 && hour < 22) {
      return 'Turno B (14-22)';
    } else {
      return 'Turno C (22-06)';
    }
  }

  List<_Registro> get _registrosFiltrados {
    return _todosLosRegistros.where((r) {
      if (_inyectora != 'Todas' && r.iny != _inyectora) {
        return false;
      }
      if (_turno != 'Todos') {
        final turnoRegistro = _obtenerTurnoDesdeHora(r.fechaHora);
        if (turnoRegistro != _turno) {
          return false;
        }
      }
      if (_fecha != 'Todos') {
        final ahora = DateTime.now();
        final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);

        if (_fecha == 'Hoy') {
          if (r.fechaHora.isBefore(hoyInicio)) return false;
        } else if (_fecha == 'Ayer') {
          final ayerInicio = hoyInicio.subtract(const Duration(days: 1));
          if (r.fechaHora.isBefore(ayerInicio) || r.fechaHora.isAfter(hoyInicio)) {
            return false;
          }
        } else if (_fecha == 'Últimos 7 días') {
          final hace7Dias = hoyInicio.subtract(const Duration(days: 7));
          if (r.fechaHora.isBefore(hace7Dias)) return false;
        }
      }
      return true;
    }).toList();
  }

  List<_Registro> get _visiblesPaginados {
    final filtrados = _registrosFiltrados;
    final startIndex = (_page - 1) * _pageSize;
    if (startIndex >= filtrados.length) return [];
    final endIndex = (startIndex + _pageSize > filtrados.length)
        ? filtrados.length
        : startIndex + _pageSize;
    return filtrados.sublist(startIndex, endIndex);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.canvas,
      appBar: _buildHeader(),
      body: RefreshIndicator(
        onRefresh: _cargarDashboardReportes,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LiveHeaderBar(
                  onBack: _volverAlDashboard,
                  onGenerarPdf: _generarReportePdf,
                ),
              ),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: _C.error, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: _C.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _cargarDashboardReportes,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildKpis(),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPareto(),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildRegistros(),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E3A5F),
          boxShadow: [
            BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: _volverAlDashboard,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 2),
                        ],
                      ),
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuAxfsHF5Ob5Z3JX61JIAaGmh0QHcFmQE2-owzMJHUjaHiMUUWk2NJbOwrdm4TZuAI6F7F4Am2Qtmtffcf8cx7B6G2Cc34i2MexuNvlE7mcs5D8yXgdySG7tmVrWpfhtpoeDHBfjEJ6oZ9iWYPQf4RSm9p6ZGTRkWmgveFRoi4LhwHJ1fdHv6cyLMmsJ1ui9KN70S76IpwdER3frR8TMG80Y1ZuSEnsHMd8gPwkCkbPvVgKGwnO-U9gJ8QR3hsV6WH92F3gngFRnwQGOIg',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.precision_manufacturing_rounded,
                          size: 20,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Historial y Reportes',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFFFFFFF),
                      ),
                    ),
                  ),
                  const AppMenuButton(),
                  const SizedBox(width: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterPill(
            icon: Icons.calendar_today,
            label: 'Fecha:',
            value: _fecha,
            options: _fechas,
            onSelected: (v) => setState(() => _fecha = v),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            icon: Icons.precision_manufacturing,
            label: 'Inyectora:',
            value: _inyectora,
            options: _inyectoras,
            onSelected: (v) => setState(() {
              _inyectora = v;
              _page = 1;
            }),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            icon: Icons.schedule,
            label: 'Turno:',
            value: _turno,
            options: _turnos,
            onSelected: (v) => setState(() => _turno = v),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _KpiCard(
              title: 'Merma Total',
              icon: Icons.scale,
              iconColor: _C.warning,
              value: _totalKgMerma.toStringAsFixed(1),
              unit: 'kg',
              trendIcon: Icons.analytics_outlined,
              trendText: '$_totalMermaRegs registros',
              trendColor: _C.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _KpiCard(
              title: 'Tiempo Paro',
              icon: Icons.timer_off,
              iconColor: _C.error,
              value: _totalMinutosParo.toStringAsFixed(0),
              unit: 'min',
              trendIcon: Icons.warning_amber_rounded,
              trendText: '$_totalParosCount eventos reg.',
              trendColor: _C.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPareto() {
    if (_defects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Text(
          'Sin datos suficientes para el análisis de Pareto.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: _C.textSecondary),
        ),
      );
    }

    final total = _defects.fold<int>(0, (s, d) => s + d.count);
    var acc = 0;
    final cum = <double>[];
    for (final d in _defects) {
      acc += d.count;
      cum.add(total > 0 ? (acc / total * 100) : 0.0);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Análisis de Causa Raíz',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _C.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Distribución de defectos acumulados en producción',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _C.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _C.bar,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Frecuencia', style: _caption()),
                    const SizedBox(width: 16),
                    Container(
                      width: 12,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _C.header,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('% Acumulado', style: _caption()),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ParetoPainter(data: _defects, cumulative: cum),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < _defects.length; i++)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _defects[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _C.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cum[i].round()}% cum.',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _C.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistros() {
    final filtrados = _registrosFiltrados;
    final visibles = _visiblesPaginados;
    final total = filtrados.length;
    final totalPages = (total / _pageSize).ceil();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Registros Recientes',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary,
                  ),
                ),
                Text(
                  'Filtro: $_inyectora',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _C.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: _C.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                _headCell('HORA', _kHoraW, left: 12),
                _headCell('INYECTORA', _kInyW, left: 8),
                Expanded(child: _headText('EVENTO / IMPACTO', left: 12)),
                const SizedBox(width: _kActionW),
              ],
            ),
          ),
          if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Sin registros para este filtro.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: _C.textSecondary),
              ),
            )
          else
            for (var i = 0; i < visibles.length; i++)
              _RegistroRow(
                registro: visibles[i],
                zebra: i.isOdd,
                onTap: () {
                  _snack('Detalle: ${visibles[i].evento} (${visibles[i].iny})');
                },
              ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Página $_page de ${totalPages == 0 ? 1 : totalPages}',
                    style: _caption(),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _page > 1 ? () => setState(() => _page--) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _page < totalPages ? () => setState(() => _page++) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(30, 58, 95, 0.08),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.scale_rounded,
                label: 'Merma',
                onTap: () => Navigator.pushReplacementNamed(context, '/captura_merma'),
              ),
              _buildNavItem(
                icon: Icons.pause_circle_outline,
                label: 'Paros',
                onTap: () => Navigator.pushReplacementNamed(context, '/captura_paros'),
              ),
              _buildNavItem(
                icon: Icons.grid_view_outlined,
                label: 'Monitoreo',
                onTap: () => Navigator.pushReplacementNamed(context, '/monitoreo'),
              ),
              _buildNavItem(
                icon: Icons.show_chart_outlined,
                label: 'Historial',
                isSelected: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 3,
              width: 24,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0162A2) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFF022448) : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF022448) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _kHoraW = 100;
  static const double _kInyW = 84;
  static const double _kActionW = 40;

  Widget _headCell(String text, double width, {required double left}) {
    return SizedBox(width: width, child: _headText(text, left: left));
  }

  Widget _headText(String text, {required double left}) {
    return Padding(
      padding: EdgeInsets.only(left: left),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _C.onSurfaceVariant,
        ),
      ),
    );
  }

  TextStyle _caption() => GoogleFonts.inter(
        fontSize: 12,
        color: _C.textSecondary,
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      );
}

// ============================ BARRA DE ENCABEZADO DE NAVEGACIÓN ============
class _LiveHeaderBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onGenerarPdf;

  const _LiveHeaderBar({
    required this.onBack,
    required this.onGenerarPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Color.fromARGB(255, 30, 58, 95),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de Planta',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromARGB(255, 30, 58, 95),
                      ),
                    ),
                    Text(
                      'Reporte - Nave Industrial A',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Generar Reporte PDF',
          child: Material(
            color: _C.surface,
            elevation: 1,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onGenerarPdf,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 20, color: _C.error),
                    const SizedBox(width: 6),
                    Text(
                      'PDF',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================ PILL DE FILTRO ===============================
class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _FilterPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      position: PopupMenuPosition.under,
      color: _C.surface,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<String>(
            value: o,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    o,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: o == value ? FontWeight.w600 : FontWeight.w400,
                      color: _C.textPrimary,
                    ),
                  ),
                ),
                if (o == value) const Icon(Icons.check, size: 16, color: _C.secondary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _C.secondary),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: _C.textSecondary)),
            const SizedBox(width: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _C.textPrimary)),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, size: 18, color: _C.outline),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final IconData trendIcon;
  final String trendText;
  final Color trendColor;

  const _KpiCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.trendIcon,
    required this.trendText,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _C.textSecondary,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(fontSize: 12, color: _C.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  trendText,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: trendColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegistroRow extends StatelessWidget {
  final _Registro registro;
  final bool zebra;
  final VoidCallback onTap;

  const _RegistroRow({
    required this.registro,
    required this.zebra,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = registro;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: zebra ? _C.canvas : _C.surface,
        child: Row(
          children: [
            SizedBox(
              width: _HistorialReportesScreenState._kHoraW,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: _C.outline),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        r.hora,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: _C.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _HistorialReportesScreenState._kInyW,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _C.surfaceContainer,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      r.iny,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.evento,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _C.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(r.icon, size: 13, color: r.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            r.impacto,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: r.color,
                              fontWeight: r.bold ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _HistorialReportesScreenState._kActionW,
              child: const Icon(Icons.chevron_right, size: 18, color: _C.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ GRÁFICA DE PARETO ============================
class _ParetoPainter extends CustomPainter {
  final List<_Defect> data;
  final List<double> cumulative;

  _ParetoPainter({required this.data, required this.cumulative});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final sx = size.width / 320;
    final sy = size.height / 140;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final maxVal = data.map((e) => e.count).fold<int>(1, (a, b) => a > b ? a : b).toDouble();

    final gridPaint = Paint()
      ..color = _C.borderSubtle
      ..strokeWidth = 1;
    for (final y in [20.0, 55.0, 90.0]) {
      _dashed(canvas, p(20, y), p(300, y), gridPaint, 2 * sx, 2 * sx);
    }

    canvas.drawLine(
      p(20, 125),
      p(300, 125),
      Paint()
        ..color = _C.outlineVariant
        ..strokeWidth = 1,
    );

    final guidePaint = Paint()
      ..color = _C.error.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    _dashed(canvas, p(20, 40), p(300, 40), guidePaint, 3 * sx, 3 * sx);
    _text(canvas, '80%', p(302, 42), 9, FontWeight.w600, _C.error);

    final barPaint = Paint()..color = _C.bar;
    final double stepX = data.length > 1 ? (260.0 / data.length) : 130.0;

    for (var i = 0; i < data.length; i++) {
      final x = 30.0 + i * stepX;
      final h = (data[i].count / maxVal) * 80;
      final y = 125 - h;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * sx, y * sy, 26 * sx, h * sy),
          const Radius.circular(3),
        ),
        barPaint,
      );

      _text(
        canvas,
        '${data[i].count}',
        p(x + 13, y - 4),
        10,
        FontWeight.w700,
        _C.textPrimary,
        center: true,
      );
    }

    final pts = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final cx = 43.0 + i * stepX;
      final cy = 125 - (cumulative[i] * 0.85);
      pts.add(p(cx, cy));
    }

    if (pts.isNotEmpty) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = _C.header
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      for (var i = 0; i < pts.length; i++) {
        canvas.drawCircle(pts[i], 3.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          pts[i],
          3.5,
          Paint()
            ..color = _C.header
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset basePos,
    double fontSize,
    FontWeight weight,
    Color color, {
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dx = center ? basePos.dx - tp.width / 2 : basePos.dx;
    tp.paint(canvas, Offset(dx, basePos.dy - baseline));
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, double dash, double gap) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = (d + dash) > total ? total : d + dash;
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ParetoPainter old) =>
      old.data != data || old.cumulative != cumulative;
}
