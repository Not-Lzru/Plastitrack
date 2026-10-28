import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../widgets/app_menu_button.dart';

class StitchColors {
  static const canvasBackground = Color(0xFFEAF2FB);
  static const primaryContainer = Color(0xFF1E3A5F);
  static const primary = Color(0xFF022448);
  static const onPrimary = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainerHigh = Color(0xFFDEE9FC);
  static const surfaceContainerHighest = Color(0xFFD9E3F6);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const secondary = Color(0xFF0162A2);
  static const statusSuccess = Color(0xFF2E9E5B);
  static const statusError = Color(0xFFD64545);
  static const statusWarning = Color(0xFFE0A526);
  static const badgeSupervisor = Color(0xFF3B82C4);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
}

enum MachineStatus { running, alert, stopped }

extension MachineStatusX on MachineStatus {
  Color get color => switch (this) {
        MachineStatus.running => StitchColors.statusSuccess,
        MachineStatus.alert => StitchColors.statusWarning,
        MachineStatus.stopped => StitchColors.statusError,
      };

  Color get iconBoxColor => switch (this) {
        MachineStatus.running => StitchColors.surfaceContainer,
        MachineStatus.alert => const Color(0xFFFFDDB2).withValues(alpha: 0.35),
        MachineStatus.stopped => StitchColors.errorContainer.withValues(alpha: 0.40),
      };

  IconData get statusIcon => switch (this) {
        MachineStatus.running => Icons.speed,
        MachineStatus.alert => Icons.warning_amber_rounded,
        MachineStatus.stopped => Icons.timer_outlined,
      };
}

class Machine {
  final int idOrden;
  final String name;
  final String mold;
  final MachineStatus status;
  final String statusLabel;
  final String? stopwatch;
  String operatorName;
  final String operatorShift;
  final String operatorState;
  final String order;
  final String orderDesc;
  final String goal;
  final int stops;
  final int stopMinutes;
  final double scrapKg;
  bool expanded;

  Machine({
    required this.idOrden,
    required this.name,
    required this.mold,
    required this.status,
    required this.statusLabel,
    required this.operatorName,
    required this.operatorShift,
    required this.operatorState,
    required this.order,
    required this.orderDesc,
    required this.goal,
    required this.stops,
    required this.stopMinutes,
    required this.scrapKg,
    this.stopwatch,
    this.expanded = false,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    final estadoStr = (json['estado_actual'] ?? json['estado'] ?? 'activa').toString().toLowerCase();
    
    MachineStatus status = MachineStatus.running;
    String statusLabel = 'Operando Normal';

    if (estadoStr == 'paro' || estadoStr == 'detenida') {
      status = MachineStatus.stopped;
      statusLabel = 'En Paro';
    } else if (estadoStr == 'alerta') {
      status = MachineStatus.alert;
      statusLabel = 'Alerta de Proceso';
    }

    final totalSegundos = int.tryParse(json['segundos_paro_activo']?.toString() ?? '0') ?? 0;
    final minutosParoActivo = (totalSegundos / 60).floor();

    final totalMermaRaw = json['total_merma_kg']?.toString() ?? '0.0';
    final double mermaKg = double.tryParse(totalMermaRaw) ?? 0.0;

    final totalParosRaw = json['total_paros']?.toString() ?? '0';
    final int totalParos = int.tryParse(totalParosRaw) ?? 0;

    return Machine(
      idOrden: int.tryParse(json['id_orden']?.toString() ?? '0') ?? 0,
      name: json['nombre_maquina']?.toString() ?? 'Inyectora',
      mold: 'Orden Activa',
      status: status,
      statusLabel: statusLabel,
      stopwatch: (status == MachineStatus.stopped && minutosParoActivo > 0) ? '${minutosParoActivo}m' : null,
      operatorName: json['operador_asignado']?.toString() ?? 'operador01',
      operatorShift: 'Turno Actual',
      operatorState: status == MachineStatus.stopped ? 'En Espera' : 'Activo',
      order: json['codigo_orden']?.toString() ?? '#ORD',
      orderDesc: json['nombre_maquina']?.toString() ?? 'Producción',
      goal: 'N/A',
      stops: totalParos,
      stopMinutes: minutosParoActivo,
      scrapKg: mermaKg,
    );
  }
}

class MonitoreoInyectorasScreen extends StatefulWidget {
  const MonitoreoInyectorasScreen({super.key});

  @override
  State<MonitoreoInyectorasScreen> createState() =>
      _MonitoreoInyectorasScreenState();
}

class _MonitoreoInyectorasScreenState
    extends State<MonitoreoInyectorasScreen> {
  static const _logoUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBVdY4PDQ_q55Vc6-wgBJ57OTMwn8aDKQXAJFTM3AXUVDrjO4Za87fc7a8nBFvqLFn6nnDgXEUfvFaF_o2IZkU44JN47qgu2F-s046AuI-7O6DrtXpolxdS1CUqtfrwUcZO7_fdyX5qxPzU9KNfzBhYGOFt1xkTJsXcgBGfad156aK_V-Y7UEooRymJR3y2lUItBWRMiyPM4ZjAuEyvHXQkx0lUGtCJW4TI426xJgAbnSNs61kpMxpa';

  MachineStatus? _selectedFilter;
  int _syncSeconds = 0;
  Timer? _syncTimer;
  bool _isLoading = true;
  String? _errorMessage;
  List<Machine> _machines = [];

  // Rol del usuario activo en la sesión
  String _userRole = 'operador';
  
  // Lista de operadores disponibles en la base de datos mientras carga
  List<String> _operadoresDisponibles = ['operador01'];

  @override
  void initState() {
    super.initState();
    _obtenerRolUsuario();
    _cargarOperadoresActivos();
    _cargarOrdenesProduccion();
    
    // Refresco periódico cada minuto
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _syncSeconds = (_syncSeconds + 1) % 60;
          if (_syncSeconds == 0) {
            _cargarOperadoresActivos(); // <--- Revalida operadores activos
            _cargarOrdenesProduccion(mostrarCargando: false);
          }
        });
      }
    });
  }

  /// Extrae el rol del usuario directamente desde el token JWT almacenado
  Future<void> _obtenerRolUsuario() async {
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final Map<String, dynamic> payloadMap = jsonDecode(payload);
          if (mounted) {
            setState(() {
              _userRole = (payloadMap['rol'] ?? 'operador').toString().toLowerCase();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al leer el rol del token: $e');
    }
  }

  Future<void> _cargarOperadoresActivos() async {
  try {
    final token = await AuthService.getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/usuarios?rol=operador&activo=true');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List list = data['usuarios'] ?? [];

      final List<String> activos = list.where((u) {
        final rolStr = (u['rol'] ?? '').toString().toLowerCase();
        final activoRaw = u['activo'];
        final esActivo = activoRaw == 1 || 
                         activoRaw == true || 
                         activoRaw.toString() == '1' || 
                         activoRaw.toString().toLowerCase() == 'true';
        
        return rolStr == 'operador' && esActivo;
      }).map((u) => u['nombre_completo']?.toString() ?? 'Sin Nombre').toList();

      if (mounted) {
        setState(() {
          _operadoresDisponibles = activos;
        });
      }
    }
  } catch (e) {
    debugPrint('Error al cargar operadores activos: $e');
  }
}

  Future<void> _cargarOrdenesProduccion({bool mostrarCargando = true}) async {
    if (mostrarCargando && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await AuthService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}/produccion/ordenes');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 304) {
        final data = jsonDecode(response.body);
        final List<dynamic> ordenesJson = data['ordenes'] ?? data['data'] ?? [];

        setState(() {
          _machines = ordenesJson.map((j) => Machine.fromJson(j)).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        setState(() {
          _errorMessage = 'Respuesta inesperada del servidor (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Excepción al procesar órdenes de producción: $e');
      debugPrint('Detalle del error: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al procesar los datos recibidos ($e)';
        _isLoading = false;
      });
    }
  }

  void _cambiarOperadorAsignado(Machine machine, String nuevoOperador) {
    setState(() {
      machine.operatorName = nuevoOperador;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Operador $nuevoOperador asignado a ${machine.name}'),
        backgroundColor: StitchColors.statusSuccess,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _volverAlDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  List<Machine> get _filteredMachines {
    if (_selectedFilter == null) return _machines;
    return _machines.where((m) => m.status == _selectedFilter).toList();
  }

  int _countStatus(MachineStatus status) =>
      _machines.where((m) => m.status == status).length;

  bool get _esAdminOSupervisor =>
      _userRole == 'administrador' || _userRole == 'supervisor';

  @override
  Widget build(BuildContext context) {
    final visibleMachines = _filteredMachines;

    return Scaffold(
      backgroundColor: StitchColors.canvasBackground,
      appBar: _HeaderBar(
        logoUrl: _logoUrl,
        onBack: _volverAlDashboard,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _cargarOperadoresActivos(),
            _cargarOrdenesProduccion(mostrarCargando: true),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LiveStatusBar(
                syncSeconds: _syncSeconds,
                onBack: _volverAlDashboard,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'Todas',
                      count: _machines.length,
                      selected: _selectedFilter == null,
                      onTap: () => setState(() => _selectedFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Operando',
                      count: _countStatus(MachineStatus.running),
                      dotColor: StitchColors.statusSuccess,
                      selected: _selectedFilter == MachineStatus.running,
                      onTap: () => setState(
                          () => _selectedFilter = MachineStatus.running),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'En Paro',
                      count: _countStatus(MachineStatus.stopped),
                      dotColor: StitchColors.statusError,
                      selected: _selectedFilter == MachineStatus.stopped,
                      onTap: () => setState(
                          () => _selectedFilter = MachineStatus.stopped),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Alerta',
                      count: _countStatus(MachineStatus.alert),
                      dotColor: StitchColors.statusWarning,
                      selected: _selectedFilter == MachineStatus.alert,
                      onTap: () => setState(
                          () => _selectedFilter = MachineStatus.alert),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                            color: StitchColors.statusError, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _cargarOrdenesProduccion(),
                        child: const Text('Reintentar'),
                      )
                    ],
                  ),
                )
              else if (visibleMachines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No hay máquinas para mostrar',
                      style: GoogleFonts.inter(
                          color: StitchColors.textSecondary, fontSize: 14),
                    ),
                  ),
                )
              else
                for (final machine in visibleMachines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MachineCard(
                      machine: machine,
                      puedeModificarOperador: _esAdminOSupervisor,
                      operadoresDisponibles: _operadoresDisponibles,
                      onOperadorCambiado: (nuevoOperador) {
                        _cambiarOperadorAsignado(machine, nuevoOperador);
                      },
                      onToggleExpand: () {
                        setState(() => machine.expanded = !machine.expanded);
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _IndustrialBottomNav(),
    );
  }
}

class _HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String logoUrl;
  final VoidCallback onBack;
  const _HeaderBar({required this.logoUrl, required this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E3A5F),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
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
                  onTap: onBack,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: StitchColors.surface,
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
                    'Monitoreo de Inyectoras',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: StitchColors.surface,
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
    );
  }
}

class _LiveStatusBar extends StatelessWidget {
  final int syncSeconds;
  final VoidCallback? onBack;

  const _LiveStatusBar({required this.syncSeconds, this.onBack});

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
                  child: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 30, 58, 95), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monitoreo de Planta',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromARGB(255, 30, 58, 95),
                      ),
                    ),
                    Text(
                      'Piso de Moldeo - Nave Industrial A',
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: StitchColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync,
                  size: 16, color: StitchColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${syncSeconds.toString().padLeft(2, '0')}s',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: StitchColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? dotColor;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? StitchColors.primary : StitchColors.surface;
    final fg = selected ? StitchColors.onPrimary : StitchColors.textPrimary;

    return Material(
      color: bg,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : StitchColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? StitchColors.onPrimary
                        : StitchColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  final Machine machine;
  final bool puedeModificarOperador;
  final List<String> operadoresDisponibles;
  final ValueChanged<String> onOperadorCambiado;
  final VoidCallback onToggleExpand;

  const _MachineCard({
    required this.machine,
    required this.puedeModificarOperador,
    required this.operadoresDisponibles,
    required this.onOperadorCambiado,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final color = machine.status.color;
    final isStopped = machine.status == MachineStatus.stopped;

    return Container(
      decoration: BoxDecoration(
        color: StitchColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: color),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: machine.status.iconBoxColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.precision_manufacturing,
                          size: 22, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            machine.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: StitchColors.textPrimary,
                            ),
                          ),
                          Text(
                            machine.mold,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: StitchColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: AnimatedRotation(
                        turns: machine.expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more,
                          color: StitchColors.textSecondary,
                        ),
                      ),
                      onPressed: onToggleExpand,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isStopped
                        ? StitchColors.errorContainer.withValues(alpha: 0.25)
                        : StitchColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          machine.statusLabel.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: color,
                          ),
                        ),
                      ),
                      Icon(machine.status.statusIcon, size: 16, color: color),
                      if (machine.stopwatch != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          machine.stopwatch!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: machine.expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _MachineDetailsDrawer(
                            machine: machine,
                            puedeModificarOperador: puedeModificarOperador,
                            operadoresDisponibles: operadoresDisponibles,
                            onOperadorCambiado: onOperadorCambiado,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineDetailsDrawer extends StatelessWidget {
  final Machine machine;
  final bool puedeModificarOperador;
  final List<String> operadoresDisponibles;
  final ValueChanged<String> onOperadorCambiado;

  const _MachineDetailsDrawer({
    required this.machine,
    required this.puedeModificarOperador,
    required this.operadoresDisponibles,
    required this.onOperadorCambiado,
  });

  @override
  Widget build(BuildContext context) {
    final isStopped = machine.status == MachineStatus.stopped;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StitchColors.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila de Operador Asignado (Con edición si es Admin/Supervisor)
          _InfoRowOperador(
            icon: Icons.person,
            label: 'Operador Asignado',
            machine: machine,
            puedeModificar: puedeModificarOperador,
            operadoresDisponibles: operadoresDisponibles,
            onOperadorCambiado: onOperadorCambiado,
            badgeText: machine.operatorState,
            badgeColor: isStopped
                ? StitchColors.errorContainer.withValues(alpha: 0.4)
                : StitchColors.badgeSupervisor.withValues(alpha: 0.1),
            badgeTextColor: isStopped
                ? StitchColors.statusError
                : StitchColors.badgeSupervisor,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.assignment,
            label: 'Orden de Producción',
            value: '${machine.order} (${machine.orderDesc})',
            badgeText: 'Meta: ${machine.goal}',
            badgeColor: StitchColors.surfaceContainerHighest,
            badgeTextColor: StitchColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StitchColors.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning,
                        size: 18, color: StitchColors.statusError),
                    const SizedBox(width: 8),
                    Text(
                      'Resumen de Incidencias en Turno',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: StitchColors.onErrorContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCell(
                        label: 'Paros Mecánicos',
                        value: '${machine.stops}',
                        unit: '(${machine.stopMinutes} min)',
                        color: machine.stops > 0
                            ? StitchColors.statusError
                            : StitchColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCell(
                        label: 'Merma Acumulada',
                        value: machine.scrapKg.toStringAsFixed(1),
                        unit: 'kg',
                        color: machine.scrapKg > 1.0
                            ? StitchColors.statusWarning
                            : StitchColors.statusSuccess,
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
}

class _InfoRowOperador extends StatelessWidget {
  final IconData icon;
  final String label;
  final Machine machine;
  final bool puedeModificar;
  final List<String> operadoresDisponibles;
  final ValueChanged<String> onOperadorCambiado;
  final String badgeText;
  final Color badgeColor;
  final Color badgeTextColor;

  const _InfoRowOperador({
    super.key,
    required this.icon,
    required this.label,
    required this.machine,
    required this.puedeModificar,
    required this.operadoresDisponibles,
    required this.onOperadorCambiado,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    // Resguardo: si el operador asignado fue desactivado o la lista está cargando,
    // usamos una opción válida sin romper el DropdownButton.
    final String valorActual = operadoresDisponibles.contains(machine.operatorName)
        ? machine.operatorName
        : (operadoresDisponibles.isNotEmpty
            ? operadoresDisponibles.first
            : machine.operatorName);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: StitchColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: StitchColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: StitchColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: StitchColors.textSecondary,
                  ),
                ),
                if (puedeModificar && operadoresDisponibles.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: valorActual,
                      isDense: true,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: StitchColors.primary,
                      ),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: StitchColors.secondary,
                      ),
                      items: operadoresDisponibles.map((op) {
                        return DropdownMenuItem<String>(
                          value: op,
                          child: Text('$op (${machine.operatorShift})'),
                        );
                      }).toList(),
                      onChanged: (nuevo) {
                        if (nuevo != null) {
                          onOperadorCambiado(nuevo);
                        }
                      },
                    ),
                  )
                else
                  Text(
                    '${machine.operatorName} (${machine.operatorShift})',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: StitchColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badgeText.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String badgeText;
  final Color badgeColor;
  final Color badgeTextColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: StitchColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: StitchColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: StitchColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: StitchColors.textSecondary)),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: StitchColors.textPrimary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badgeText.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: StitchColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 11, color: StitchColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                    fontSize: 12, color: StitchColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndustrialBottomNav extends StatelessWidget {
  const _IndustrialBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: StitchColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(30, 58, 95, 0.08),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.scale_rounded,
                label: 'Merma',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/captura_merma');
                },
              ),
              _buildNavItem(
                icon: Icons.pause_circle_outline,
                label: 'Paros',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/captura_paros');
                },
              ),
              _buildNavItem(
                icon: Icons.grid_view_outlined,
                label: 'Monitoreo',
                isSelected: true,
                onTap: () {},
              ),
              _buildNavItem(
                icon: Icons.show_chart_outlined,
                label: 'Historial',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/historial');
                },
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
}
