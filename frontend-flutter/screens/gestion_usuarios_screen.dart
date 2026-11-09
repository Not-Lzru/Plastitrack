import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart'; // Asegúrate de tener la configuración de API
import '../services/auth_service.dart'; // Servicio donde guardas el Token JWT y datos del usuario
import '../widgets/app_menu_button.dart';

class StitchColors {
  static const canvasBackground = Color(0xFFEAF2FB);
  static const primaryContainer = Color(0xFF1E3A5F);
  static const primary = Color(0xFF022448);
  static const onPrimary = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainerHighest = Color(0xFFD9E3F6);
  static const surfaceDim = Color(0xFFD0DBED);
  static const onSurface = Color(0xFF121C2A);
  static const textSecondary = Color(0xFF6B7280);
  static const secondary = Color(0xFF0162A2);
  static const outline = Color(0xFF74777F);
  static const statusSuccess = Color(0xFF2E9E5B);
  static const statusError = Color(0xFFD64545);
  static const badgeAdmin = Color(0xFF1E3A5F);
  static const badgeSupervisor = Color(0xFF3B82C4);
  static const badgeOperator = Color(0xFF6B7280);
}

enum UserRole { operador, supervisor, administrador }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.operador => 'OPERADOR',
        UserRole.supervisor => 'SUPERVISOR',
        UserRole.administrador => 'ADMINISTRADOR',
      };

  IconData get icon => switch (this) {
        UserRole.operador => Icons.engineering,
        UserRole.supervisor => Icons.supervisor_account,
        UserRole.administrador => Icons.security,
      };

  Color get color => switch (this) {
        UserRole.operador => StitchColors.badgeOperator,
        UserRole.supervisor => StitchColors.badgeSupervisor,
        UserRole.administrador => StitchColors.badgeAdmin,
      };

  static UserRole fromString(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'administrador':
      case 'admin':
        return UserRole.administrador;
      case 'supervisor':
        return UserRole.supervisor;
      default:
        return UserRole.operador;
    }
  }
}

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String photoUrl;
  bool active;

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.photoUrl,
    this.active = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id_usuario'].toString(),
      name: json['nombre_completo'] ?? 'Sin Nombre',
      role: UserRoleX.fromString(json['rol'] ?? 'operador'),
      photoUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(json['nombre_completo'] ?? 'U')}&background=022448&color=fff',
      active: json['activo'] == 1 || json['activo'] == true,
    );
  }
}

class GestionUsuariosScreen extends StatefulWidget {
  const GestionUsuariosScreen({super.key});

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  UserRole? _selectedRoleFilter;

  List<AppUser> _users = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndFetchData();
  }

  // Comprobar privilegios y cargar la lista de usuarios
  Future<void> _checkPermissionAndFetchData() async {
    final userRole = await AuthService.getUserRole(); // Muestra el rol guardado en SharedPreferences/SecureStorage
    
    if (userRole?.toLowerCase() != 'administrador') {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
        _errorMessage = 'Acceso denegado. Se requieren privilegios de Administrador para acceder a este módulo.';
      });
      return;
    }

    setState(() {
      _isAdmin = true;
    });

    await _fetchUsersFromBackend();
  }

  // Cargar lista desde Node.js
  Future<void> _fetchUsersFromBackend() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/usuarios'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List list = data['usuarios'] ?? [];
        setState(() {
          _users = list.map((json) => AppUser.fromJson(json)).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar usuarios (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo conectar con el servidor backend.';
        _isLoading = false;
      });
    }
  }

  // Cambiar estado activo en la BD
  Future<void> _toggleUserActiveStatus(AppUser user, bool newValue) async {
    final originalValue = user.active;
    setState(() => user.active = newValue);

    try {
      final token = await AuthService.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/usuarios/${user.id}/estado'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'activo': newValue}),
      );

      if (response.statusCode != 200) {
        setState(() => user.active = originalValue);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar el estado en el servidor')),
          );
        }
      }
    } catch (e) {
      setState(() => user.active = originalValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión con el backend')),
        );
      }
    }
  }

  List<AppUser> get _filteredUsers {
    final query = _searchQuery.toLowerCase().trim();
    return _users.where((user) {
      final matchesRole =
          _selectedRoleFilter == null || user.role == _selectedRoleFilter;
      final matchesQuery = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.id.contains(query);
      return matchesRole && matchesQuery;
    }).toList();
  }

  int get _activeCount => _users.where((u) => u.active).length;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin && !_isLoading) {
      return Scaffold(
        backgroundColor: StitchColors.canvasBackground,
        appBar: const _HeaderBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 64, color: StitchColors.statusError),
                const SizedBox(height: 16),
                Text(
                  'Acceso Restringido',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: StitchColors.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Solo los administradores pueden gestionar usuarios.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: StitchColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: StitchColors.primaryContainer),
                  child: const Text('Volver al Inicio', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final visibleUsers = _filteredUsers;

    return Scaffold(
      backgroundColor: StitchColors.canvasBackground,
      appBar: const _HeaderBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: StitchColors.primary))
          : RefreshIndicator(
              onRefresh: _fetchUsersFromBackend,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _showAddUserDialog,
                        icon: const Icon(Icons.person_add, size: 20),
                        label: Text(
                          'Nuevo Usuario',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StitchColors.primaryContainer,
                          foregroundColor: StitchColors.onPrimary,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SearchBox(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Todos',
                            count: _users.length,
                            selected: _selectedRoleFilter == null,
                            onTap: () => setState(() => _selectedRoleFilter = null),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Operadores',
                            selected: _selectedRoleFilter == UserRole.operador,
                            onTap: () => setState(
                                () => _selectedRoleFilter = UserRole.operador),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Supervisores',
                            selected: _selectedRoleFilter == UserRole.supervisor,
                            onTap: () => setState(
                                () => _selectedRoleFilter = UserRole.supervisor),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Administración',
                            selected: _selectedRoleFilter == UserRole.administrador,
                            onTap: () => setState(
                                () => _selectedRoleFilter = UserRole.administrador),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PersonnelMetricBanner(
                      activeCount: _activeCount,
                      totalCount: _users.length,
                    ),
                    const SizedBox(height: 16),
                    if (visibleUsers.isEmpty)
                      const _EmptySearchState()
                    else
                      ...visibleUsers.map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UserCard(
                            user: user,
                            onToggleActive: (newValue) => _toggleUserActiveStatus(user, newValue),
                            onEdit: () => _showEditUserDialog(user),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const _IndustrialBottomNav(),
    );
  }

  // Abrir diálogo para registrar un nuevo usuario
  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.operador;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: StitchColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Nuevo Usuario',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: StitchColors.onSurface),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo o Email',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol de Usuario',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: UserRole.operador, child: Text('Operador')),
                        DropdownMenuItem(value: UserRole.supervisor, child: Text('Supervisor')),
                        DropdownMenuItem(value: UserRole.administrador, child: Text('Administrador')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: StitchColors.primaryContainer),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final nombre = nameController.text.trim();
                          final pass = passwordController.text.trim();

                          if (nombre.isEmpty || pass.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor llena todos los campos')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            final token = await AuthService.getToken();
                            final response = await http.post(
                              Uri.parse('${ApiConfig.baseUrl}/usuarios'),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: json.encode({
                                'nombre_completo': nombre,
                                'contrasena': pass,
                                'rol': selectedRole.name, // 'operador', 'supervisor', 'administrador'
                              }),
                            );

                            if (response.statusCode == 201) {
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Usuario registrado con éxito')),
                                );
                                _fetchUsersFromBackend(); // Recargar la lista
                              }
                            } else {
                              final err = json.decode(response.body);
                              setDialogState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err['error'] ?? 'Error al guardar')),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error de conexión con el servidor')),
                              );
                            }
                          }
                        },
                  child: isSaving
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
  // Abrir diálogo para editar los datos de un usuario
  void _showEditUserDialog(AppUser user) {
    final nameController = TextEditingController(text: user.name);
    final passwordController = TextEditingController(); // Opcional (dejar vacío si no cambia)
    UserRole selectedRole = user.role;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: StitchColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Editar Usuario (ID: ${user.id})',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: StitchColors.onSurface),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo o Email',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva Contraseña (Opcional)',
                        hintText: 'Dejar en blanco para mantener la actual',
                        prefixIcon: Icon(Icons.lock_reset),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol de Usuario',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: UserRole.operador, child: Text('Operador')),
                        DropdownMenuItem(value: UserRole.supervisor, child: Text('Supervisor')),
                        DropdownMenuItem(value: UserRole.administrador, child: Text('Administrador')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: StitchColors.primaryContainer),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final nombre = nameController.text.trim();
                          final pass = passwordController.text.trim();

                          if (nombre.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('El nombre de usuario es obligatorio')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            final token = await AuthService.getToken();
                            final bodyData = {
                              'nombre_completo': nombre,
                              'rol': selectedRole.name,
                            };

                            if (pass.isNotEmpty) {
                              bodyData['contrasena'] = pass;
                            }

                            final response = await http.put(
                              Uri.parse('${ApiConfig.baseUrl}/usuarios/${user.id}'),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': 'Bearer $token',
                              },
                              body: json.encode(bodyData),
                            );

                            if (response.statusCode == 200) {
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Usuario actualizado con éxito')),
                                );
                                _fetchUsersFromBackend(); // Recargar lista
                              }
                            } else {
                              final err = json.decode(response.body);
                              setDialogState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err['error'] ?? 'Error al actualizar usuario')),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error de conexión con el servidor')),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Actualizar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const _HeaderBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E3A5F),
        boxShadow: const [
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
                    'Gestión de Usuarios',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFFFF),
                    ),
                  ),
                ),
                AppMenuButton(current: AppMenuItem.usuarios),
                SizedBox(width: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
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
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 14, color: StitchColors.onSurface),
        decoration: InputDecoration(
          hintText: 'Buscar usuario o ID...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: StitchColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 22,
            color: StitchColors.textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? StitchColors.primaryContainer
        : StitchColors.surface;
    final fgColor = selected
        ? StitchColors.onPrimary
        : StitchColors.textSecondary;

    return Material(
      color: bgColor,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fgColor,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: fgColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonnelMetricBanner extends StatelessWidget {
  final int activeCount;
  final int totalCount;

  const _PersonnelMetricBanner({
    required this.activeCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StitchColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
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
          const Icon(
            Icons.verified_user,
            size: 20,
            color: StitchColors.statusSuccess,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$activeCount de $totalCount usuarios activos en planta',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: StitchColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: StitchColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Turno Matutino',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: StitchColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;

  const _UserCard({
    required this.user,
    required this.onToggleActive,
    required this.onEdit,
  });

  static const _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final active = user.active;

    Widget avatarWidget = ClipOval(
      child: Image.network(
        user.photoUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: StitchColors.surfaceDim,
          child: const Icon(Icons.person, color: StitchColors.textSecondary),
        ),
      ),
    );

    if (!active) {
      avatarWidget = ColorFiltered(
        colorFilter: _grayscaleFilter,
        child: avatarWidget,
      );
    }

    return Opacity(
      opacity: active ? 1.0 : 0.85,
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  avatarWidget,
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: active
                            ? StitchColors.statusSuccess
                            : StitchColors.outline,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: StitchColors.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? StitchColors.onSurface
                          : StitchColors.textSecondary,
                    ),
                  ),
                  Text(
                    'ID: ${user.id}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: active
                          ? StitchColors.textSecondary
                          : StitchColors.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      _RoleBadge(user: user),
                      if (!active)
                        Text(
                          'Inactivo',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: StitchColors.statusError,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TactileSwitch(
              value: active,
              onChanged: onToggleActive,
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit,
                size: 22,
                color: StitchColors.secondary,
              ),
              tooltip: 'Editar datos de ${user.name}',
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final AppUser user;

  const _RoleBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    final active = user.active;
    final bg = active
        ? user.role.color
        : StitchColors.surfaceContainerHighest;
    final fg = active
        ? StitchColors.onPrimary
        : StitchColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(user.role.icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            user.role.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _TactileSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TactileSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? StitchColors.statusSuccess
              : StitchColors.surfaceDim,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: StitchColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: StitchColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: StitchColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search,
              size: 32,
              color: StitchColors.primaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin resultados',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: StitchColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No se encontraron usuarios que coincidan con la búsqueda.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: StitchColors.textSecondary,
            ),
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
            color: Color(0x141E3A5F),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.scale,
                label: 'Merma',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/captura_merma');
                },
              ),
              _NavItem(
                icon: Icons.pause_circle,
                label: 'Paros',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/captura_paros');
                },
              ),
              _NavItem(
                icon: Icons.precision_manufacturing,
                label: 'Monitoreo',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/monitoreo');
                },
              ),
              _NavItem(
                icon: Icons.show_chart,
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
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? StitchColors.primary : StitchColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
