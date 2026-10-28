import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../widgets/app_menu_button.dart';

// ============================ COLORES (locales) ============================
class _C {
  static const canvas = Color(0xFFEAF2FB);
  static const header = Color(0xFF1E3A5F);
  static const primary = Color(0xFF022448);
  static const secondary = Color(0xFF0162A2);
  static const secondaryContainer = Color(0xFF76B8FD);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const onSurface = Color(0xFF121C2A);
  static const textSecondary = Color(0xFF6B7280);
  static const outline = Color(0xFF74777F);
  static const borderSubtle = Color(0xFFE2E5EA);
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFE0A526);
  static const error = Color(0xFFD64545);
  static const badgeSupervisor = Color(0xFF3B82C4);
  static const pillBg = Color(0xFFEBF4FB);
}

class ConfiguracionPerfilScreen extends StatefulWidget {
  const ConfiguracionPerfilScreen({super.key});

  @override
  State<ConfiguracionPerfilScreen> createState() => _ConfiguracionPerfilScreenState();
}

class _ConfiguracionPerfilScreenState extends State<ConfiguracionPerfilScreen> {
  String _nombre = 'Cargando...';
  String _idUsuario = '---';
  String _rol = '---';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  // Carga los datos guardados en el inicio de sesión desde AuthService
  Future<void> _cargarDatosUsuario() async {
    final userData = await AuthService.getUser();
    if (userData != null) {
      setState(() {
        _nombre = userData['nombre_completo'] ?? 'Usuario Plastitrack';
        _idUsuario = userData['id_usuario']?.toString() ?? 'N/A';
        _rol = (userData['rol'] ?? 'OPERADOR').toString().toUpperCase();
        _isLoading = false;
      });
    } else {
      setState(() {
        _nombre = 'Usuario no identificado';
        _isLoading = false;
      });
    }
  }

  // Cierre de sesión eliminando tokens y credenciales locales
  Future<void> _confirmarLogout(BuildContext context) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Text(
          '¿Deseas cerrar la sesión de turno de $_nombre?',
          style: GoogleFonts.inter(fontSize: 14, height: 20 / 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión', style: TextStyle(color: _C.error)),
          ),
        ],
      ),
    );

    if (salir == true && context.mounted) {
      await AuthService.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  // Diálogo interactivo para cambiar la contraseña mediante API REST
  void _mostrarDialogoCambiarContrasena(BuildContext context) {
    final actualController = TextEditingController();
    final nuevaController = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _C.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(
                'Cambiar Contraseña',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _C.onSurface),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: actualController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña Actual',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nuevaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva Contraseña',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
                  onPressed: enviando
                      ? null
                      : () async {
                          final actual = actualController.text.trim();
                          final nueva = nuevaController.text.trim();

                          if (actual.isEmpty || nueva.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ingresa ambas contraseñas')),
                            );
                            return;
                          }

                          setDialogState(() => enviando = true);

                          try {
                            final token = await AuthService.getToken();
                            final response = await http.put(
                              Uri.parse('${ApiConfig.baseUrl}/auth/cambiar-contrasena'),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: jsonEncode({
                                'contrasena_actual': actual,
                                'nueva_contrasena': nueva,
                              }),
                            );

                            final resData = jsonDecode(response.body);

                            if (response.statusCode == 200) {
                              if (context.mounted) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(resData['mensaje'] ?? 'Contraseña actualizada correctamente'),
                                    backgroundColor: _C.success,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() => enviando = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(resData['error'] ?? 'Error al actualizar contraseña'),
                                    backgroundColor: _C.error,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => enviando = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error de conexión con el servidor')),
                              );
                            }
                          }
                        },
                  child: enviando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.canvas,
      appBar: _buildHeader(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 20),
                  _buildPreferencias(context),
                  const SizedBox(height: 20),
                  _buildLogoutButton(context),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(104),
      child: Container(
        decoration: const BoxDecoration(
          color: _C.header,
          boxShadow: [
            BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFFFFFFF),
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
                        'Configuración de Perfil',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFFFFFFF),
                        ),
                      ),
                    ),
                    AppMenuButton(current: AppMenuItem.perfil),
                    SizedBox(width: 1),
                  ],
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: _C.header.withValues(alpha: 0.95),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Volver',
                      child: InkWell(
                        onTap:  () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(4),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.arrow_back, size: 22, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Perfil',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    // Generar iniciales para el avatar
    final iniciales = _nombre.trim().isNotEmpty
        ? _nombre.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase()
        : 'PT';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -48,
            child: _GlowCircle(size: 144, color: _C.secondaryContainer.withValues(alpha: 0.2)),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: _GlowCircle(size: 112, color: _C.primary.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: _C.surfaceContainer,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_nombre)}&background=022448&color=fff&size=128',
                              fit: BoxFit.cover,
                              width: 88,
                              height: 88,
                              errorBuilder: (_, __, ___) => Container(
                                color: _C.surfaceContainer,
                                alignment: Alignment.center,
                                child: Text(
                                  iniciales,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: _C.header,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Tooltip(
                            message: 'Operativo Activo',
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: _C.success,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nombre,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      height: 26 / 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: _C.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _C.pillBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user, size: 16, color: _C.badgeSupervisor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'ID: $_idUsuario | $_rol',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 14 / 11,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                              color: _C.badgeSupervisor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencias(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'PREFERENCIAS Y SEGURIDAD',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w500,
              color: _C.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            children: [
              _SettingsItem(
                icon: Icons.lock_reset,
                title: 'Cambiar Contraseña',
                subtitle: 'Actualización de credenciales',
                onTap: () => _mostrarDialogoCambiarContrasena(context),
              ),
              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: _C.borderSubtle),
              _SettingsItem(
                icon: Icons.notifications_active,
                title: 'Notificaciones y Alertas',
                subtitle: 'Alertas sonoras de merma, paros críticos e inyección',
                warningDot: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificaciones configuradas activas')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => _confirmarLogout(context),
          icon: const Icon(Icons.logout, size: 20),
          label: Text(
            'Cerrar Sesión',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.error,
            foregroundColor: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
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
                onTap: () => Navigator.pushReplacementNamed(context, '/historial'),
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
                color: isSelected ? _C.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              icon,
              size: 22,
              color: isSelected ? _C.primary : _C.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _C.primary : _C.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool warningDot;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.warningDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 22, color: _C.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 20 / 14,
                            fontWeight: FontWeight.w600,
                            color: _C.onSurface,
                          ),
                        ),
                      ),
                      if (warningDot) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Alertas de merma activas',
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _C.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: 0.12,
                      color: _C.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20, color: _C.outline),
          ],
        ),
      ),
    );
  }
}
