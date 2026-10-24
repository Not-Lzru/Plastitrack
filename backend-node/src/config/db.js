const mysql = require('mysql2/promise');
require('dotenv').config();

// Crear el pool de conexiones
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'plastitrack_DB',
  port: process.env.DB_PORT || 3306,
  ssl: {
    rejectUnauthorized: false // Requerido por la mayoría de BD externas en la nube por seguridad
  },
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// Función para verificar la conexión al iniciar el servidor
const testConnection = async () => {
  try {
    const connection = await pool.getConnection();
    console.log('Conexión exitosa a la base de datos MySQL (plastitrack)');
    connection.release(); // Liberar la conexión de prueba
  } catch (error) {
    console.error('Error al conectar a la base de datos MySQL:', error.message);
  }
};

testConnection();

module.exports = pool;
