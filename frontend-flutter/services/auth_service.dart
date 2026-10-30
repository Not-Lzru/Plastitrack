import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  // Se lee dinámicamente desde ApiConfig para adaptarse a Web, Emulador o Celular Físico
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre_completo': username,
          'contrasena': password,
        }),
      ).timeout(ApiConfig.timeoutDuration);

      final data = jsonDecode(response.body);

      // Busca el token en cualquiera de las propiedades comunes que devuelva el backend
      final String? tokenRecibido = data['token'] ?? data['jwt_token'] ?? data['tokenAcceso'];

      if (response.statusCode == 200 && tokenRecibido != null) {
        final prefs = await SharedPreferences.getInstance();
        
        // 1. Guardamos el token
        await prefs.setString('token', tokenRecibido);
        await prefs.setString('jwt_token', tokenRecibido);

        // 2. Guardamos los datos del usuario y su rol enviado por el backend
        if (data['usuario'] != null) {
          final usuario = data['usuario'];
          final String? rol = usuario['rol'];
          
          if (rol != null) {
            await prefs.setString('user_role', rol);
          }
          await prefs.setString('user_data', jsonEncode(usuario));
        }

        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['mensaje'] ?? 'Credenciales incorrectas'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'El servidor en la nube está despertando. Por favor, intenta iniciar sesión nuevamente en unos segundos.'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión con el servidor backend: $e'
      };
    }
  }

  /// Método para obtener el token guardado
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? prefs.getString('jwt_token');
  }

  /// Método para obtener el rol del usuario logueado ('operador', 'supervisor', 'administrador')
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  /// Método auxiliar para obtener la información completa del usuario
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  /// Método para cerrar sesión y borrar los datos almacenados
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_data');
  }
}
