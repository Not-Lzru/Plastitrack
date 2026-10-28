import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberUser = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Petición Real al Backend
  Future<void> _handleAuthSubmit() async {
    final usuario = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (usuario.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Por favor ingresa usuario y contraseña.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Delegamos la autenticación al AuthService que ya tiene los nombres exactos
    final result = await AuthService.login(usuario, password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Credenciales incorrectas.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _olvideContrasena() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Solicita restablecimiento con tu supervisor de turno.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryContainer = Color(0xFF1E3A5F);
    const canvasBackground = Color(0xFFEAF2FB);
    const borderSubtle = Color(0xFFE2E5EA);
    const textPrimary = Color(0xFF1F2937);
    const textSecondary = Color(0xFF6B7280);
    const badgeSupervisor = Color(0xFF3B82C4);
    const surfaceContainerLow = Color(0xFFEFF4FF);

    return Scaffold(
      backgroundColor: canvasBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hero / Logo Section
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 24.0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 240),
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: Image.network(
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuCn-q-_HtiKCQIM1KwRWvnfW5lL4xYU4-bIGELT1rrRdDI2TitXp1O7Yp-serUY3eHlUE1-XwqnXB8bpiDjTRGcXfCu1B3hrGEt0V-irjuKg_Z33KZJZIUX6DN1YHwaPrRxYQReFai-a4Dw29FzR_mqPTe7IwBYdh6QHrSlqXAdQTVS7Z1Y19KMcZl3nEUkzvsc9STx3OVCP5M1pd0tuuR_LmJV_XvQGnlk3yA_JE5Pv2sBI_hMkklLBhcrIwTADHyCIw',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              'PLASTITRACK',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryContainer,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Inicia sesión',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Auth Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.06),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Campo Usuario
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Usuario:',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'ID de planta',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderSubtle),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.inter(fontSize: 14, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Ej. operador01@plastitrack.com',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF74777F)),
                              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF74777F), size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Campo Contraseña
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Contraseña:',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'PIN / Clave',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderSubtle),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.inter(fontSize: 14, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF74777F)),
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF74777F), size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFF74777F),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Botón Iniciar Sesión
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuthSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryContainer,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLoading ? 'Verificando estación...' : 'Iniciar Sesión',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Recordar mi usuario
                        Center(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _rememberUser = !_rememberUser;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: _rememberUser,
                                      activeColor: primaryContainer,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberUser = val ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recordar mi usuario',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: textPrimary,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ¿Olvidaste tu contraseña?
                        Center(
                          child: TextButton(
                            onPressed: _olvideContrasena,
                            child: Text(
                              '¿Olvidaste tu contraseña?',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: badgeSupervisor,
                              ),
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
        ),
      ),
    );
  }
}
