const db = require('../config/db');
const jwt = require('jsonwebtoken');

// Endpoint de Inicio de Sesión
const login = async (req, res) => {
  const { nombre_completo, contrasena } = req.body;

  if (!nombre_completo || !contrasena) {
    return res.status(400).json({ error: 'Por favor proporciona usuario y contraseña.' });
  }

  try {
    const [rows] = await db.query('SELECT * FROM usuario WHERE nombre_completo = ? AND activo = TRUE', [nombre_completo]);

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado o inactivo.' });
    }

    const usuario = rows[0];

    const passwordValida = (contrasena === usuario.contrasena);

    if (!passwordValida) {
      return res.status(401).json({ error: 'Contraseña incorrecta.' });
    }

    const idUsuarioNum = Number(usuario.id_usuario);

    const token = jwt.sign(
      {
        id_usuario: idUsuarioNum,
        nombre_completo: usuario.nombre_completo,
        rol: usuario.rol,
      },
      process.env.JWT_SECRET || 'plastitrack_secreto_desarrollo_2026',
      { expiresIn: '8h' }
    );

    res.json({
      mensaje: 'Inicio de sesión exitoso',
      token,
      usuario: {
        id_usuario: idUsuarioNum,
        nombre_completo: usuario.nombre_completo,
        rol: usuario.rol,
      },
    });
  } catch (error) {
    console.error('❌ Error en authController:', error);
    res.status(500).json({ error: 'Error interno del servidor al iniciar sesión.', detalle: error.message });
  }
};

// Endpoint para Cambiar Contraseña del Usuario Logueado
const cambiarContrasena = async (req, res) => {
  const { contrasena_actual, nueva_contrasena } = req.body;
  const id_usuario = req.usuario.id_usuario;

  if (!contrasena_actual || !nueva_contrasena) {
    return res.status(400).json({ error: 'Debes proporcionar la contraseña actual y la nueva contraseña.' });
  }

  try {
    const [rows] = await db.query('SELECT contrasena FROM usuario WHERE id_usuario = ?', [id_usuario]);

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado.' });
    }

    if (rows[0].contrasena !== contrasena_actual) {
      return res.status(400).json({ error: 'La contraseña actual no es correcta.' });
    }

    await db.query('UPDATE usuario SET contrasena = ? WHERE id_usuario = ?', [nueva_contrasena, id_usuario]);

    res.json({ mensaje: 'Contraseña actualizada exitosamente.' });
  } catch (error) {
    res.status(500).json({ error: 'Error interno al cambiar la contraseña.', detalle: error.message });
  }
};

module.exports = {
  login,
  cambiarContrasena,
};
