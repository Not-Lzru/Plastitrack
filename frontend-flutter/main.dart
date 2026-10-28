import 'package:flutter/material.dart';
import 'package:plastitrack_frontend/screens/historial_reportes_screen.dart';

// Importaciones de todas tus pantallas (Asegúrate de tenerlas guardadas en lib/screens/)
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/captura_merma_screen.dart';
import 'screens/captura_paros_screen.dart';
import 'screens/gestion_usuarios_screen.dart';
import 'screens/monitoreo_inyectoras_screen.dart';
import 'screens/configuracion_perfil_screen.dart';
import 'screens/historial_reportes_screen.dart';

void main() {
  runApp(const PlastitrackApp());
}

class PlastitrackApp extends StatelessWidget {
  const PlastitrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plastitrack',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1E3A5F),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/captura_merma': (context) => CapturaMermaScreen(),
        '/captura_paros': (context) => CapturaParosScreen(),
        '/usuarios': (context) => GestionUsuariosScreen(),
        '/monitoreo': (context) => MonitoreoInyectorasScreen(),
        '/perfil': (context) => ConfiguracionPerfilScreen(),
        '/historial': (context) => HistorialReportesScreen(),


      },
    );
  }
}
