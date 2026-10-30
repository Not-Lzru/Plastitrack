import 'package:flutter/foundation.dart';

class ApiConfig {
  // 1. Activa esta bandera cuando enciendas tu túnel (ngrok / Cloudflare)
  static const bool _usarTunnel = true;
  
  // 2. URL del túnel cuando esté activo
  static const String _urlTunnel = 'https://plastitrack.onrender.com/api';

  // 3. Configuración para pruebas en red local
  static const String _ipLaptop = '000.000.000.000';
  static const String _puerto = '3000';

  static const Duration timeoutDuration = Duration(seconds: 60);

  static String get baseUrl {
    if (_usarTunnel) {
      return _urlTunnel;
    }

    if (kIsWeb) {
      return 'http://$_ipLaptop:$_puerto/api';
    }

    return 'http://$_ipLaptop:$_puerto/api';
  }

  // Encabezados globales para evitar la pantalla de advertencia de ngrok
  static Map<String, String> get headersBase => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}
