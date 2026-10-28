import 'dart:convert';
// Para Uint8List
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../widgets/app_menu_button.dart';

class CapturaMermaScreen extends StatefulWidget {
  const CapturaMermaScreen({super.key});

  @override
  State<CapturaMermaScreen> createState() => _CapturaMermaScreenState();
}

class _CapturaMermaScreenState extends State<CapturaMermaScreen> {
  final String _baseUrl = ApiConfig.baseUrl;

  bool _isLoading = false;

  String? _selectedInyectora = '1';
  String? _selectedDefecto = '1';
  String _unidades = 'kg';

  // Manejo de la imagen seleccionada
  XFile? _imagenEvidencia;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _cantidadController = TextEditingController(text: '14.50');
  final TextEditingController _observacionesController = TextEditingController();

  final List<Map<String, dynamic>> _inyectoras = [
    {'id': '1', 'nombre': 'Inyectora 01 - Molde Tapa Frontal (ABS)'},
    {'id': '2', 'nombre': 'Inyectora 02 - Molde Carcasa A (PP Copo)'},
    {'id': '3', 'nombre': 'Inyectora 03 - Molde Base Reforzada (PA66)'},
    {'id': '4', 'nombre': 'Inyectora 04 - Molde Difusor Óptico (PC)'},
    {'id': '5', 'nombre': 'Inyectora 05 - Purga / Cambio de Molde'},
  ];

  final List<Map<String, dynamic>> _defectos = [
    {'id': '1', 'nombre': 'Rechupados (Hundimiento por enfriamiento)'},
    {'id': '2', 'nombre': 'Ráfagas plateadas (Humedad / gas atrapado)'},
    {'id': '3', 'nombre': 'Pieza incompleta (Tiro corto / falta presión)'},
    {'id': '4', 'nombre': 'Rebabas (Exceso de presión o desajuste)'},
    {'id': '5', 'nombre': 'Purga inicial (Arranque / cambio de resina)'},
  ];

  @override
  void dispose() {
    _cantidadController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  double get _cantidadActual {
    return double.tryParse(_cantidadController.text) ?? 0.0;
  }

  void _ajustarCantidad(double delta) {
    double nuevaCantidad = (_cantidadActual + delta).clamp(0.0, 9999.0);
    setState(() {
      _cantidadController.text = _unidades == 'kg'
          ? nuevaCantidad.toStringAsFixed(2)
          : nuevaCantidad.round().toString();
    });
  }

  // Selección de Foto (Cámara o Galería)
  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1024,
      );

      if (foto != null) {
        setState(() {
          _imagenEvidencia = foto;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar la imagen: $e')),
      );
    }
  }

  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF1E3A5F)),
                title: const Text('Tomar Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF1E3A5F)),
                title: const Text('Elegir de Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _volverAlDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Widget _unitButton(String unit, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _unidades = unit;
          double val = _cantidadActual;
          _cantidadController.text =
              unit == 'kg' ? val.toStringAsFixed(2) : val.round().toString();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
          ),
        ),
      ),
    );
  }

  Widget _presetButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        padding: EdgeInsets.zero,
        side: const BorderSide(color: Color(0xFFD9E3F6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _taraButton() {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _cantidadController.text = _unidades == 'kg' ? '0.00' : '0';
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFEE2E2),
        foregroundColor: Colors.red[700],
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Tara', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // Petición HTTP Multipart para enviar Form/Foto al Backend Express
  Future<void> _guardarMerma() async {
    final cantidad = _cantidadActual;
    if (cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa una cantidad válida mayor a 0.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/mermas'));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Campos de formulario en texto
      request.fields['id_orden'] = _selectedInyectora ?? '1';
      request.fields['tipo_defecto'] = _selectedDefecto ?? '1';
      request.fields['unidad_medida'] = _unidades;
      if (_unidades == 'kg') {
        request.fields['peso_kilogramos'] = cantidad.toString();
      } else {
        request.fields['piezas'] = cantidad.round().toString();
      }
      request.fields['observaciones'] = _observacionesController.text.trim();

      // Adjuntar archivo de imagen si está disponible
      if (_imagenEvidencia != null) {
        if (kIsWeb) {
          final bytes = await _imagenEvidencia!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'imagen',
            bytes,
            filename: _imagenEvidencia!.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'imagen',
            _imagenEvidencia!.path,
          ));
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Registro de Merma guardado exitosamente en Plastitrack!'),
            backgroundColor: Colors.green,
          ),
        );
        _observacionesController.clear();
        setState(() {
          _imagenEvidencia = null;
          _cantidadController.text = _unidades == 'kg' ? '0.00' : '0';
        });
      } else {
        final resData = jsonDecode(response.body);
        final errorMsg = resData['error'] ?? resData['message'] ?? 'Error al registrar la merma';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error (${response.statusCode}): $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excepción de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E3A5F);
    const canvasBackground = Color(0xFFEAF2FB);

    return Scaffold(
      backgroundColor: canvasBackground,
      appBar: AppBar(
        backgroundColor: primaryColor,
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
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuDT_PO_yb536wEWKJTFIc7YJmRePEWyFwxrgJoy61wsyil9FwDZBIn9wpZCi3_uq9xtbgqMFRY07A3_RLxmGns660e6-XI8WD34SLBfW4LGLtyOZXisObxOOG8pK2jhsRQbU_u3l7p4InDk2Uk6L1vVHqhJtnWJfQara0INIpvuBGmrgbxUC9nKm8fb_dVMz9r1Zs7uwHhcwiffMoYZKCEKrWq2z-AC5rrV8VeXg8eOmyKN5OhF7nV8CVAFHV8XdYAMPw',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.precision_manufacturing_rounded,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Captura de Merma',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          const AppMenuButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
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
                          'Reporte de Merma',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          'Plastitrack • Nave A',
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
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0162A2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'REGISTRO ACTIVO',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00497B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

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
                  const Text('INYECTORA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedInyectora,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.build, color: primaryColor),
                      filled: true,
                      fillColor: const Color(0xFFEFF4FF),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                    isExpanded: true,
                    items: _inyectoras.map((inj) {
                      return DropdownMenuItem<String>(
                        value: inj['id'].toString(),
                        child: Text(inj['nombre']!, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedInyectora = val),
                  ),

                  const SizedBox(height: 16),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TIPO DE DEFECTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text('* REQUERIDO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDefecto,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.warning, color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFFEFF4FF),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                    isExpanded: true,
                    items: _defectos.map((def) {
                      return DropdownMenuItem<String>(
                        value: def['id'].toString(),
                        child: Text(def['nombre']!, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedDefecto = val),
                  ),

                  const SizedBox(height: 16),

                  // Magnitud
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('MAGNITUD DE MERMA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9E3F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  _unitButton('kg', _unidades == 'kg'),
                                  _unitButton('piezas', _unidades == 'piezas'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: primaryColor),
                                onPressed: () => _ajustarCantidad(-0.5),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IntrinsicWidth(
                                      child: TextField(
                                        controller: _cantidadController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(_unidades, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: primaryColor),
                                onPressed: () => _ajustarCantidad(0.5),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(child: _presetButton('+1.0', () => _ajustarCantidad(1.0))),
                            const SizedBox(width: 6),
                            Expanded(child: _presetButton('+5.0', () => _ajustarCantidad(5.0))),
                            const SizedBox(width: 6),
                            Expanded(child: _presetButton('+10.0', () => _ajustarCantidad(10.0))),
                            const SizedBox(width: 6),
                            Expanded(child: _taraButton()),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Evidencia Fotográfica Dinámica
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('EVIDENCIA FOTOGRÁFICA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: _imagenEvidencia != null ? Colors.green : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _imagenEvidencia != null ? '1 foto adjunta' : 'Sin foto',
                            style: TextStyle(
                              fontSize: 11,
                              color: _imagenEvidencia != null ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_imagenEvidencia != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: const Color(0xFFEFF4FF),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 160,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: _buildPreviewImagen(),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.red,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _imagenEvidencia = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _imagenEvidencia!.name,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _mostrarOpcionesFoto,
                                    icon: const Icon(Icons.photo_camera, size: 16),
                                    label: const Text('Cambiar Foto', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _mostrarOpcionesFoto,
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adjuntar Evidencia Fotográfica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Tomar foto o elegir desde la galería', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                  const SizedBox(height: 16),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('NOTAS ADICIONALES / OBSERVACIONES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text('OPCIONAL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _observacionesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Describe condiciones anómalas de presión o temperatura...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFEFF4FF),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _guardarMerma,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      _isLoading ? 'Guardando...' : 'Guardar Registro',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
            _buildNavItem( icon: Icons.scale_rounded, label: 'Merma', isSelected: true, onTap: () {}, ),
            _buildNavItem( icon: Icons.pause_circle_outline, label: 'Paros', isSelected: false, onTap: () => Navigator.pushReplacementNamed(context, '/captura_paros') ,),
            _buildNavItem( icon: Icons.grid_view_outlined, label: 'Monitoreo', isSelected: false, onTap: () => Navigator.pushReplacementNamed(context, '/monitoreo'), ),
            _buildNavItem( icon: Icons.show_chart_outlined, label: 'Historial', isSelected: false, onTap: () => Navigator.pushReplacementNamed(context, '/historial'), ),
          ],
        ),
      ),
    );
  }

  // 2. Para renderizar la imagen sin depender de 'dart:io', usa FutureBuilder + readAsBytes():
  Widget _buildPreviewImagen() {
    return FutureBuilder<Uint8List>(
      future: _imagenEvidencia!.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
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
