const express = require('express');
const router = express.Router();
const { verificarToken, verificarRol } = require('../middlewares/authMiddleware');

// Ruta pública para autenticación
const { login, cambiarContrasena } = require('../controllers/authController');

// Ruta protegida de prueba (Solo requiere estar logueado)
router.get('/perfil', verificarToken, (req, res) => {
  res.json({
    mensaje: 'Acceso concedido a perfil privado',
    usuarioLogueado: req.usuario,
  });
});

// Ruta para cambiar contraseña propia
router.put('/cambiar-contrasena', verificarToken, cambiarContrasena);

// Ruta protegida exclusiva para supervisores y administradores
router.get('/panel-supervisor', verificarToken, verificarRol(['supervisor', 'Supervisor', 'administrador', 'Administrador']), (req, res) => {
  res.json({
    mensaje: 'Bienvenido al panel exclusivo para Supervisores de planta.',
  });
});

module.exports = router;
