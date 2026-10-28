import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../widgets/app_menu_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = -1;
  bool _isLoading = true;
  
  // Unidad seleccionada para visualizar la gráfica y KPI general (kg o pcs)
  String _unidadSeleccionadaGrafica = 'kg'; // 'kg' o 'pcs'

  // Variables de Estado para los datos del Backend
  double _totalMermasKg = 0.0;
  int _totalMermasPiezas = 0;
  int _totalParosMinutos = 0;
  int _parosActivosCount = 0;
  List<dynamic> _registrosRecientes = [];

  // Mermas por inyectora divididas por unidad
  Map<String, double> _mermasKgPorInyectora = {
    'INY-01': 0.0,
    'INY-02': 0.0,
    'INY-03': 0.0,
    'INY-04': 0.0,
    'INY-05': 0.0,
  };
  Map<String, double> _mermasPiezasPorInyectora = {
    'INY-01': 0.0,
    'INY-02': 0.0,
    'INY-03': 0.0,
    'INY-04': 0.0,
    'INY-05': 0.0,
  };

  Map<String, int> _parosPorMotivo = {};

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Carga de Datos desde la API de Express
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 1. Obtener Mermas (GET /api/mermas)
      final resMermas = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/mermas'),
        headers: headers,
      );

      // 2. Obtener Paros Activos (GET /api/paros/activos)
      final resParosActivos = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/paros/activos'),
        headers: headers,
      );

      // 3. Obtener Histórico General de Paros (GET /api/paros)
      final resParosTodos = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/paros'),
        headers: headers,
      );

      double sumMermasKg = 0.0;
      int sumMermasPiezas = 0;

      Map<String, double> tempKgInyectoras = {
        'INY-01': 0.0, 'INY-02': 0.0, 'INY-03': 0.0, 'INY-04': 0.0, 'INY-05': 0.0,
      };
      Map<String, double> tempPiezasInyectoras = {
        'INY-01': 0.0, 'INY-02': 0.0, 'INY-03': 0.0, 'INY-04': 0.0, 'INY-05': 0.0,
      };

      List<dynamic> recientes = [];

      if (resMermas.statusCode == 200) {
        final Map<String, dynamic> bodyMermas = jsonDecode(resMermas.body);
        final List<dynamic> mermasData = bodyMermas['mermas'] ?? [];

        for (var item in mermasData) {
          final peso = double.tryParse(item['peso_kilogramos']?.toString() ?? '0') ?? 0.0;
          final piezas = int.tryParse(item['cantidad_piezas']?.toString() ?? item['piezas']?.toString() ?? '0') ?? 0;
          final unidadFormato = item['unidad']?.toString().toLowerCase() ?? (piezas > 0 && peso == 0 ? 'pcs' : 'kg');

          final tipoDefecto = item['tipo_defecto']?.toString() ?? 'Sin clasificar';
          
          final idOrden = item['id_orden']?.toString() ?? '1';
          final inyectoraTag = 'Inyectora #$idOrden';

          final keyInyectora = 'INY-0${(int.tryParse(idOrden) ?? 1) % 5 == 0 ? 5 : (int.tryParse(idOrden) ?? 1) % 5}';
          
          sumMermasKg += peso;
          sumMermasPiezas += piezas;

          tempKgInyectoras[keyInyectora] = (tempKgInyectoras[keyInyectora] ?? 0.0) + peso;
          tempPiezasInyectoras[keyInyectora] = (tempPiezasInyectoras[keyInyectora] ?? 0.0) + piezas.toDouble();

          String horaFormateada = '00:00';
          if (item['fecha_hora'] != null) {
            try {
              final date = DateTime.parse(item['fecha_hora']);
              horaFormateada = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
            } catch (_) {}
          }

          String valorEtiqueta = '$peso kg';
          if (unidadFormato == 'pcs' || unidadFormato == 'piezas' || (piezas > 0 && peso == 0)) {
            valorEtiqueta = '$piezas pcs';
          } else if (piezas > 0 && peso > 0) {
            valorEtiqueta = '${peso.toStringAsFixed(1)} kg ($piezas pcs)';
          } else {
            valorEtiqueta = '${peso.toStringAsFixed(1)} kg';
          }

          recientes.add({
            'tipo': 'merma',
            'maquina': inyectoraTag,
            'hora': horaFormateada,
            'descripcion': tipoDefecto,
            'valor': valorEtiqueta,
            'tag': item['registrado_por'] ?? 'Usuario',
            'raw_date': item['fecha_hora'] ?? '',
          });
        }
      }

      int sumMinutosParos = 0;
      Map<String, int> tempParosPorMotivo = {};
      int countParosActivos = 0;

      // Procesar Todos los Paros de la Base de Datos para la gráfica general de causas
      List<dynamic> todosLosParos = [];
      if (resParosTodos.statusCode == 200) {
        final Map<String, dynamic> bodyTodos = jsonDecode(resParosTodos.body);
        todosLosParos = bodyTodos['paros'] ?? bodyTodos['data'] ?? [];
      }

      // Procesar Paros Activos
      List<dynamic> parosActivosData = [];
      if (resParosActivos.statusCode == 200) {
        final Map<String, dynamic> bodyActivos = jsonDecode(resParosActivos.body);
        parosActivosData = bodyActivos['parosActivos'] ?? bodyActivos['paros'] ?? [];
      }

      countParosActivos = parosActivosData.length;

      // Combinar histórico + activos si el endpoint de 'todos' no incluye activos
      final Set<dynamic> listaParosCombinada = {...todosLosParos, ...parosActivosData};

      final ahora = DateTime.now();

      for (var item in listaParosCombinada) {
        final motivo = item['motivo']?.toString() ?? 'Paro sin especificar';
        tempParosPorMotivo[motivo] = (tempParosPorMotivo[motivo] ?? 0) + 1;

        int duracionMins = 0;
        final duracionSegs = int.tryParse(item['duracion_segundos']?.toString() ?? '');

        if (duracionSegs != null && duracionSegs > 0) {
          duracionMins = duracionSegs ~/ 60;
        } else if (item['hora_inicio'] != null) {
          try {
            final inicio = DateTime.parse(item['hora_inicio']);
            final fin = item['hora_fin'] != null ? DateTime.parse(item['hora_fin']) : ahora;
            duracionMins = fin.difference(inicio).inMinutes;
            if (duracionMins < 0) duracionMins = 0;
          } catch (_) {}
        }

        sumMinutosParos += duracionMins;
      }

      // Agregar a recientes los paros activos
      for (var item in parosActivosData) {
        int duracionMins = 0;
        String horaInicioStr = '00:00';
        if (item['hora_inicio'] != null) {
          try {
            final inicio = DateTime.parse(item['hora_inicio']);
            duracionMins = ahora.difference(inicio).inMinutes;
            if (duracionMins < 0) duracionMins = 0;
            horaInicioStr = '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        final motivo = item['motivo']?.toString() ?? 'Paro sin especificar';
        final idOrden = item['id_orden']?.toString() ?? '1';
        final maquinaLabel = item['nombre_maquina'] ?? 'Inyectora #$idOrden';

        recientes.add({
          'tipo': 'paro',
          'maquina': maquinaLabel,
          'hora': horaInicioStr,
          'descripcion': motivo,
          'valor': '-$duracionMins min',
          'tag': 'Activo',
          'raw_date': item['hora_inicio'] ?? '',
        });
      }

      recientes.sort((a, b) => (b['raw_date'].toString()).compareTo(a['raw_date'].toString()));

      if (!mounted) return;
      setState(() {
        _totalMermasKg = sumMermasKg;
        _totalMermasPiezas = sumMermasPiezas;
        _totalParosMinutos = sumMinutosParos;
        _parosActivosCount = countParosActivos;
        _mermasKgPorInyectora = tempKgInyectoras;
        _mermasPiezasPorInyectora = tempPiezasInyectoras;
        _parosPorMotivo = tempParosPorMotivo;
        _registrosRecientes = recientes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _resetToMainDashboard() {
    setState(() => _selectedIndex = -1);
    _fetchDashboardData();
  }

  void _irACapturaMerma() {
    Navigator.pushNamed(context, '/captura_merma');
  }

  void _irACapturaParos() {
    Navigator.pushNamed(context, '/captura_paros');
  }

  String _formatTiempoMuerto(int minutosTotales) {
    final horas = minutosTotales ~/ 60;
    final mins = minutosTotales % 60;
    return '${horas.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
      );
    }

    switch (_selectedIndex) {
      case 2:
        return const Center(child: Text('Vista de Monitoreo de Inyectoras'));
      case 3:
        return const Center(child: Text('Vista de Historial y Reportes'));
      case 0:
      case 1:
      case -1:
      default:
        return RefreshIndicator(
          onRefresh: _fetchDashboardData,
          color: const Color(0xFF1E3A5F),
          child: _MainDashboardContent(
            onIrACapturaMerma: _irACapturaMerma,
            onIrACapturaParos: _irACapturaParos,
            totalMermasKg: _totalMermasKg,
            totalMermasPiezas: _totalMermasPiezas,
            tiempoMuertoFormateado: _formatTiempoMuerto(_totalParosMinutos),
            parosActivosCount: _parosActivosCount,
            registrosRecientes: _registrosRecientes,
            mermasKgPorInyectora: _mermasKgPorInyectora,
            mermasPiezasPorInyectora: _mermasPiezasPorInyectora,
            unidadGrafica: _unidadSeleccionadaGrafica,
            onCambiarUnidadGrafica: (nuevaUnidad) {
              setState(() {
                _unidadSeleccionadaGrafica = nuevaUnidad;
              });
            },
            parosPorMotivo: _parosPorMotivo,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 2,
        toolbarHeight: 56,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            InkWell(
              onTap: _resetToMainDashboard,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
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
            Text(
              'Panel Principal',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
            onPressed: _fetchDashboardData,
          ),
          const AppMenuButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: Container(
        height: 64,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(index: 0, icon: Icons.scale_outlined, activeIcon: Icons.scale_rounded, label: 'Merma'),
            _buildNavItem(index: 1, icon: Icons.pause_circle_outline, activeIcon: Icons.pause_circle_rounded, label: 'Paros'),
            _buildNavItem(index: 2, icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Monitoreo'),
            _buildNavItem(index: 3, icon: Icons.show_chart_outlined, activeIcon: Icons.show_chart_rounded, label: 'Historial'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (index == 0) {
            _irACapturaMerma();
          } else if (index == 1) {
            _irACapturaParos();
          } else if (index == 2) {
            Navigator.pushNamed(context, '/monitoreo');
          } else {
            Navigator.pushNamed(context, '/historial');
          }
        },
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
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? const Color(0xFF022448) : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
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
}

class _MainDashboardContent extends StatelessWidget {
  final VoidCallback onIrACapturaMerma;
  final VoidCallback onIrACapturaParos;
  final double totalMermasKg;
  final int totalMermasPiezas;
  final String tiempoMuertoFormateado;
  final int parosActivosCount;
  final List<dynamic> registrosRecientes;
  
  final Map<String, double> mermasKgPorInyectora;
  final Map<String, double> mermasPiezasPorInyectora;
  final String unidadGrafica;
  final ValueChanged<String> onCambiarUnidadGrafica;

  final Map<String, int> parosPorMotivo;

  const _MainDashboardContent({
    required this.onIrACapturaMerma,
    required this.onIrACapturaParos,
    required this.totalMermasKg,
    required this.totalMermasPiezas,
    required this.tiempoMuertoFormateado,
    required this.parosActivosCount,
    required this.registrosRecientes,
    required this.mermasKgPorInyectora,
    required this.mermasPiezasPorInyectora,
    required this.unidadGrafica,
    required this.onCambiarUnidadGrafica,
    required this.parosPorMotivo,
  });

  // Mapeo de Colores Específico por Categoría/Motivo
  Color _obtenerColorMotivo(String motivo, int index) {
    final m = motivo.toLowerCase();
    if (m.contains('mecánic') || m.contains('mecanic') || m.contains('falla')) {
      return const Color(0xFFD64545); // Rojo
    } else if (m.contains('ajuste') || m.contains('parámetr')) {
      return const Color(0xFFE0A526); // Amarillo / Ámbar
    } else if (m.contains('materia') || m.contains('resina') || m.contains('falta')) {
      return const Color(0xFF3B82C4); // Azul
    } else if (m.contains('mantenimient')) {
      return const Color(0xFF8B5CF6); // Púrpura
    } else if (m.contains('cambio') || m.contains('molde')) {
      return const Color(0xFF10B981); // Verde
    } else if (m.contains('eléctric') || m.contains('electric')) {
      return const Color(0xFFF97316); // Naranja
    }

    final List<Color> coloresDefecto = [
      const Color(0xFFD64545),
      const Color(0xFFE0A526),
      const Color(0xFF3B82C4),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF97316),
      const Color(0xFF06B6D4),
    ];
    return coloresDefecto[index % coloresDefecto.length];
  }

  @override
  Widget build(BuildContext context) {
    final isPiezas = unidadGrafica == 'pcs';
    final mermasActuales = isPiezas ? mermasPiezasPorInyectora : mermasKgPorInyectora;

    final totalMermasMostrar = isPiezas 
        ? totalMermasPiezas.toString() 
        : totalMermasKg.toStringAsFixed(1);
    final unidadMermasMostrar = isPiezas ? 'pcs' : 'kg';

    final maxMerma = mermasActuales.values.fold(0.0, (prev, curr) => curr > prev ? curr : prev);

    final int totalParosCount = parosPorMotivo.values.fold(0, (sum, count) => sum + count);

    final List<MapEntry<String, int>> listaMotivos = parosPorMotivo.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onIrACapturaMerma,
                child: _buildKpiCard(
                  title: 'Total Mermas',
                  value: totalMermasMostrar,
                  unit: unidadMermasMostrar,
                  icon: Icons.hourglass_empty_rounded,
                  iconColor: const Color(0xFF0162A2),
                  bgColor: const Color(0xFFE0F2FE),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onIrACapturaParos,
                child: _buildKpiCard(
                  title: 'Tiempo Muerto',
                  value: tiempoMuertoFormateado,
                  unit: 'hrs',
                  icon: parosActivosCount > 0 ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  iconColor: parosActivosCount > 0 ? const Color(0xFFD64545) : const Color(0xFFE0A526),
                  bgColor: parosActivosCount > 0 ? const Color(0xFFFFDAD6) : const Color(0xFFFEF3C7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        _buildSectionCardHeader(
          title: 'Mermas por Inyectora',
          icon: Icons.bar_chart_rounded,
          actionWidget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUnitToggleOption('Kg', 'kg'),
                _buildUnitToggleOption('Piezas', 'pcs'),
              ],
            ),
          ),
          child: SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ['INY-01', 'INY-02', 'INY-03', 'INY-04', 'INY-05'].map((inyectoraKey) {
                final double val = mermasActuales[inyectoraKey] ?? 0.0;
                final double heightFactor = maxMerma > 0 ? (val / maxMerma) : 0.05;
                final bool isCritical = maxMerma > 0 && val == maxMerma;

                final textFormatted = isPiezas 
                    ? '${val.toInt()} pcs' 
                    : '${val.toStringAsFixed(1)} kg';

                return _buildBarItem(
                  textFormatted,
                  heightFactor < 0.1 ? 0.1 : heightFactor,
                  inyectoraKey,
                  isCritical: isCritical,
                  onTap: onIrACapturaMerma,
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 16),
        InkWell(
          onTap: onIrACapturaParos,
          borderRadius: BorderRadius.circular(12),
          child: _buildSectionCard(
            title: 'Causas de Paros',
            icon: Icons.pie_chart_outline_rounded,
            iconColor: parosActivosCount > 0 ? const Color(0xFFD64545) : const Color(0xFF0162A2),
            badge: parosActivosCount > 0 ? '$parosActivosCount Activos' : 'Sin Activos',
            badgeColor: parosActivosCount > 0 ? const Color(0xFFFFDAD6) : const Color(0xFFE2E8F0),
            badgeTextColor: parosActivosCount > 0 ? const Color(0xFFD64545) : const Color(0xFF475569),
            child: parosPorMotivo.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: Text('No hay paros de línea registrados en la base de datos.')),
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CustomPaint(
                                painter: _DonutChartPainter(
                                  entries: listaMotivos,
                                  total: totalParosCount,
                                  colorResolver: _obtenerColorMotivo,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Total', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280))),
                                Text(
                                  tiempoMuertoFormateado, 
                                  style: GoogleFonts.inter(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: parosActivosCount > 0 ? const Color(0xFFD64545) : const Color(0xFF121C2A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: listaMotivos.asMap().entries.map((mapEntry) {
                            final idx = mapEntry.key;
                            final entry = mapEntry.value;
                            final percentage = totalParosCount > 0 ? ((entry.value / totalParosCount) * 100).toStringAsFixed(0) : '0';
                            final color = _obtenerColorMotivo(entry.key, idx);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: _buildLegendItem(
                                entry.key.length > 14 ? '${entry.key.substring(0, 13)}...' : entry.key,
                                '$percentage%',
                                color,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _buildRecentRecordsCard(),
      ],
    );
  }

  Widget _buildUnitToggleOption(String label, String unitKey) {
    final isSelected = unidadGrafica == unitKey;
    return GestureDetector(
      onTap: () => onCambiarUnidadGrafica(unitKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRecordsCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 8),
                  Text(
                    'Registros Recientes',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF121C2A)),
                  ),
                ],
              ),
              InkWell(
                onTap: onIrACapturaMerma,
                child: Row(
                  children: [
                    Text('Capturar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0162A2))),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF0162A2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (registrosRecientes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Sin registros recientes acumulados.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
              ),
            )
          else
            ...registrosRecientes.take(4).map((rec) {
              final isParo = rec['tipo'] == 'paro';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildRecentRecordItem(
                  icon: isParo ? Icons.warning_amber_rounded : Icons.delete_outline_rounded,
                  iconBgColor: isParo ? const Color(0xFFFCE8E6) : const Color(0xFFFEF3C7),
                  iconColor: isParo ? const Color(0xFFD64545) : const Color(0xFFD97706),
                  machine: rec['maquina'],
                  time: rec['hora'],
                  description: rec['descripcion'],
                  tag1Text: rec['valor'],
                  tag1Bg: isParo ? const Color(0xFFFFE2E2) : const Color(0xFFFEF3C7),
                  tag1Color: isParo ? const Color(0xFFD64545) : const Color(0xFFB45309),
                  tag2Text: rec['tag'],
                  tag2Bg: const Color(0xFFE8F0FE),
                  tag2Color: const Color(0xFF4A6572),
                  onTap: isParo ? onIrACapturaParos : onIrACapturaMerma,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentRecordItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String machine,
    required String time,
    required String description,
    String? tag1Text,
    Color? tag1Bg,
    Color? tag1Color,
    String? tag2Text,
    Color? tag2Bg,
    Color? tag2Color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(machine, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF121C2A))),
                      Text(time, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  if (tag1Text != null || tag2Text != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (tag1Text != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: tag1Bg, borderRadius: BorderRadius.circular(4)),
                            child: Text(tag1Text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: tag1Color)),
                          ),
                        if (tag1Text != null && tag2Text != null) const SizedBox(width: 6),
                        if (tag2Text != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: tag2Bg, borderRadius: BorderRadius.circular(4)),
                            child: Text(tag2Text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: tag2Color)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: iconColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF121C2A))),
              const SizedBox(width: 4),
              Text(unit, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCardHeader({
    required String title,
    required IconData icon,
    Color iconColor = const Color(0xFF0162A2),
    required Widget actionWidget,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 8),
                  Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF121C2A))),
                ],
              ),
              actionWidget,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Color iconColor = const Color(0xFF0162A2),
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 8),
                  Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF121C2A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                child: Text(badge, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: badgeTextColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBarItem(String valText, double heightFactor, String label, {required bool isCritical, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCritical) const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFD64545)),
              Text(
                valText,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isCritical ? const Color(0xFFD64545) : const Color(0xFF6B7280),
                  fontWeight: isCritical ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: 32,
            height: 80 * heightFactor,
            decoration: BoxDecoration(
              color: isCritical ? const Color(0xFF022448) : const Color(0xFF3B82C4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isCritical ? const Color(0xFF0162A2) : const Color(0xFF121C2A))),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String percent, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF121C2A))),
            ],
          ),
          Text(percent, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: dotColor)),
        ],
      ),
    );
  }
}

// Pintador de Gráfica Circular (Dona) en base a los datos y colores calculados
class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int total;
  final Color Function(String motivo, int index) colorResolver;

  _DonutChartPainter({
    required this.entries,
    required this.total,
    required this.colorResolver,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    double startAngle = -pi / 2;

    for (int i = 0; i < entries.length; i++) {
      final sweepAngle = (entries[i].value / total) * 2 * pi;
      paint.color = colorResolver(entries[i].key, i);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.entries != entries || oldDelegate.total != total;
}
