import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../widgets/app_menu_button.dart';
import '../services/auth_service.dart';

class CapturaParosScreen extends StatefulWidget {
  const CapturaParosScreen({super.key});

  @override
  State<CapturaParosScreen> createState() => _CapturaParosScreenState();
}

class _CapturaParosScreenState extends State<CapturaParosScreen> {
  final String _baseUrl = '${ApiConfig.baseUrl}/paros';

  // Control de pestaña seleccionada en el BottomNavigationBar (1 por defecto: Paros)
  int _selectedIndex = 1;

  int _secondsElapsed = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _isLoading = false;
  int? _activeParoId;

  int? _selectedOrdenId = 1;
  String? _selectedMotivo;
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _ordenesProduccion = [
    {'id_orden': 1, 'label': 'ORD-001 - Inyectora 01 (Molde Tapa Frontal)'},
    {'id_orden': 2, 'label': 'ORD-002 - Inyectora 02 (Molde Carcasa A)'},
    {'id_orden': 3, 'label': 'ORD-003 - Inyectora 03 (Molde Base Reforzada)'},
    {'id_orden': 4, 'label': 'ORD-004 - Inyectora 04 (Molde Difusor Óptico)'},
    {'id_orden': 5, 'label': 'ORD-005 - Inyectora 05 (Purga / Cambio de Molde)'},
  ];

  final List<String> _motivosParo = [
    'Falla Mecánica (Atoramiento husillo)',
    'Mantenimiento Preventivo / Ajuste',
    'Falta de Material / Resina PP 5050',
    'Cambio y Set-up de Molde',
    'Falta de Personal / Operador',
    'Falla Eléctrica / Neumática',
  ];

  List<dynamic> _historialParos = [];

  // Método auxiliar para obtener los headers con el Token JWT de AuthService
Future<Map<String, String>> _getHeaders() async {
  final token = await AuthService.getToken();

  return {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

  @override
  void initState() {
    super.initState();
    _selectedMotivo = _motivosParo.first;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _checkParoActivo();
    await _fetchHistorialParos();
  }

  // GET /api/paros/activos (Verificación de estado)
  Future<void> _checkParoActivo() async {
    if (_selectedOrdenId == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/activos'),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List? paros = data['parosActivos'] ?? data['data'] ?? data['paros'];

        if (data['success'] == true && paros != null) {
          final paro = paros.firstWhere(
            (p) => p['id_orden'] == _selectedOrdenId,
            orElse: () => null,
          );

          if (paro != null) {
            DateTime horaInicio = DateTime.parse(paro['hora_inicio']);
            int diffSeconds = DateTime.now().difference(horaInicio).inSeconds;

            if (mounted) {
              setState(() {
                _activeParoId = paro['id_paro'];
                _selectedMotivo = paro['motivo'];
                _notesController.text = paro['observaciones'] ?? '';
                _secondsElapsed = diffSeconds > 0 ? diffSeconds : 0;
                _isRunning = true;
              });
            }
            _startTimer();
          } else {
            _resetState();
          }
        }
      }
    } catch (e) {
      debugPrint('Excepción de conexión al verificar paro activo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // GET /api/paros (Historial completo o paros recientes)
  Future<void> _fetchHistorialParos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List? listaParos = data['paros'] ?? data['parosActivos'] ?? data['data'];

        if (data['success'] == true && listaParos != null) {
          if (mounted) {
            setState(() {
              _historialParos = listaParos;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar historial de paros: $e');
    }
  }

  void _resetState() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _secondsElapsed = 0;
        _activeParoId = null;
        _notesController.clear();
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning && mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleParoState() async {
    if (mounted) setState(() => _isLoading = true);

    final headers = await _getHeaders();

    if (_isRunning) {
      // PUT /api/paros/:id_paro/finalizar
      try {
        final response = await http.put(
          Uri.parse('$_baseUrl/$_activeParoId/finalizar'),
          headers: headers,
          body: json.encode({
            'observaciones': _notesController.text,
          }),
        );

        if (!mounted) return;

        final data = json.decode(response.body);

        if (response.statusCode == 200 && data['success'] == true) {
          _timer?.cancel();
          if (mounted) {
            setState(() {
              _isRunning = false;
              _activeParoId = null;
              _secondsElapsed = 0;
              _notesController.clear();
            });
          }

          await _fetchHistorialParos();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Paro Finalizado - Línea Reanudada con Éxito'),
                backgroundColor: Color(0xFF2E9E5B),
              ),
            );
          }
        } else {
          _showErrorSnackBar(data['message'] ?? data['error'] ?? 'Error al finalizar el paro');
        }
      } catch (e) {
        _showErrorSnackBar('Error de conexión con el backend');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // POST /api/paros
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: headers,
          body: json.encode({
            'id_orden': _selectedOrdenId,
            'motivo': _selectedMotivo,
            'observaciones': _notesController.text,
          }),
        );

        if (!mounted) return;

        final data = json.decode(response.body);

        if ((response.statusCode == 201 || response.statusCode == 200) && data['success'] == true) {
          if (mounted) {
            setState(() {
              _activeParoId = data['id_paro'];
              _secondsElapsed = 0;
              _isRunning = true;
            });
          }
          _startTimer();
          await _fetchHistorialParos();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registro de Paro Iniciado'),
                backgroundColor: Color(0xFF0162A2),
              ),
            );
          }
        } else {
          _showErrorSnackBar(data['message'] ?? data['error'] ?? 'No se pudo registrar el inicio del paro');
        }
      } catch (e) {
        _showErrorSnackBar('Error de conexión al servidor');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD64545),
        ),
      );
    }
  }

  void _volverAlDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Widget _buildBodyContent() {
    const primaryColor = Color(0xFF1E3A5F);
    const primaryContainer = Color(0xFF1E3A5F);
    const statusError = Color(0xFFD64545);
    const statusSuccess = Color(0xFF2E9E5B);

    switch (_selectedIndex) {
      case 2:
        return const Center(child: Text('Vista de Monitoreo de Inyectoras'));
      case 3:
        return const Center(child: Text('Vista de Historial y Reportes'));
      case 0:
      case 1:
      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: _volverAlDashboard,
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
                          child: const Icon(Icons.arrow_back, color: primaryColor, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Captura de Paro',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            'Registro de Tiempos Muertos',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isRunning ? const Color(0xFFFFDAD6) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isRunning ? statusError : statusSuccess,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRunning ? 'LÍNEA DETENIDA' : 'LÍNEA ACTIVA',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isRunning ? const Color(0xFF93000A) : const Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Cronómetro
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isRunning ? statusError : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRunning ? 'TIEMPO TRANSCURRIDO DE PARO' : 'SIN PARO EN CURSO',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFADC8F5),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF022448),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _formatTime(_secondsElapsed),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text('HORAS', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFADC8F5), letterSpacing: 1.2)),
                              Text('MINUTOS', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFADC8F5), letterSpacing: 1.2)),
                              Text('SEGUNDOS', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFADC8F5), letterSpacing: 1.2)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Formulario
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 6),
                            Text('Orden de Producción (id_orden)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1F2937))),
                          ],
                        ),
                        Text('* Requerido', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusError)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedOrdenId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFEFF4FF),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1F2937), fontWeight: FontWeight.w500),
                      isExpanded: true,
                      items: _ordenesProduccion.map((ord) {
                        return DropdownMenuItem<int>(
                          value: ord['id_orden'] as int,
                          child: Text(ord['label'].toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _isRunning ? null : (val) {
                        setState(() => _selectedOrdenId = val);
                        _checkParoActivo();
                      },
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 6),
                        Text('Motivo del Paro (motivo)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1F2937))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMotivo,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFEFF4FF),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1F2937), fontWeight: FontWeight.w500),
                      isExpanded: true,
                      items: _motivosParo.map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _isRunning ? null : (val) => setState(() => _selectedMotivo = val),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 6),
                        Text('Observaciones (observaciones)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1F2937))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1F2937)),
                      decoration: InputDecoration(
                        hintText: 'Detalles sobre la falla, reparaciones o notas adicionales...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                        filled: true,
                        fillColor: const Color(0xFFEFF4FF),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _toggleParoState,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Icon(
                                _isRunning ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                        label: Text(
                          _isLoading
                              ? 'Procesando...'
                              : (_isRunning ? 'Finalizar Paro / Reanudar Línea' : 'Iniciar Nuevo Paro'),
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? statusError : statusSuccess,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Historial de Paros Recientes
              if (_historialParos.isNotEmpty) ...[
                Text(
                  'Historial Reciente de Paros',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _historialParos.length > 5 ? 5 : _historialParos.length,
                  itemBuilder: (context, index) {
                    final item = _historialParos[index];
                    final bool enCurso = item['hora_fin'] == null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          enCurso ? Icons.play_circle_fill_rounded : Icons.check_circle_rounded,
                          color: enCurso ? statusError : statusSuccess,
                        ),
                        title: Text(
                          '${item['motivo'] ?? 'Paro'} (Orden #${item['id_orden']})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Inicio: ${item['hora_inicio']?.toString().split('T').join(' ').substring(0, 16) ?? 'N/A'}'
                          '${item['duracion_minutos'] != null ? ' • ${item['duracion_minutos']} min' : ''}',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700]),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: enCurso ? const Color(0xFFFFDAD6) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            enCurso ? 'En Curso' : 'Finalizado',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: enCurso ? const Color(0xFF93000A) : const Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
    }
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
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/captura_merma');
              break;
            case 1:
              if (mounted) setState(() => _selectedIndex = 1);
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/monitoreo');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/historial');
              break;
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

  @override
  Widget build(BuildContext context) {
    const primaryContainer = Color(0xFF1E3A5F);
    const canvasBackground = Color(0xFFEAF2FB);

    return Scaffold(
      backgroundColor: canvasBackground,
      appBar: AppBar(
        backgroundColor: primaryContainer,
        elevation: 2,
        toolbarHeight: 56,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            InkWell(
              onTap: _volverAlDashboard,
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
              'Paros de Línea',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: const [
          AppMenuButton(),
          SizedBox(width: 8),
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
            _buildNavItem(index: 0, icon: Icons.scale_rounded, activeIcon: Icons.scale_rounded, label: 'Merma'),
            _buildNavItem(index: 1, icon: Icons.pause_circle_outline, activeIcon: Icons.pause_circle_rounded, label: 'Paros'),
            _buildNavItem(index: 2, icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Monitoreo'),
            _buildNavItem(index: 3, icon: Icons.show_chart_outlined, activeIcon: Icons.show_chart_rounded, label: 'Historial'),
          ],
        ),
      ),
    );
  }
}
