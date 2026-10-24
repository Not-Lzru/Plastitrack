-- =========================================================
-- BASE DE DATOS PLASTITRACK_DB
-- =========================================================

DROP DATABASE IF EXISTS plastitrack_db;
CREATE DATABASE plastitrack_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE plastitrack_db;

-- 2. Tabla de Usuarios
CREATE TABLE usuario (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nombre_completo VARCHAR(100) NOT NULL UNIQUE,
  contrasena VARCHAR(100) NOT NULL,
  rol ENUM('operador', 'supervisor', 'administrador') DEFAULT 'operador',
  activo BOOLEAN DEFAULT TRUE,
  fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabla de Órdenes de Producción
CREATE TABLE orden_produccion (
  id_orden INT AUTO_INCREMENT PRIMARY KEY,
  codigo_orden VARCHAR(50) NOT NULL,
  nombre_maquina VARCHAR(100) NOT NULL,
  estado VARCHAR(20) DEFAULT 'activa'
);

-- 4. Tabla Merma
CREATE TABLE merma (
  id_merma INT AUTO_INCREMENT PRIMARY KEY,
  id_orden INT NOT NULL,
  tipo_defecto VARCHAR(100) NOT NULL,
  observaciones TEXT NULL,
  peso_kilogramos DECIMAL(10,2) NULL,
  piezas INT NULL,
  unidad_medida VARCHAR(10) DEFAULT 'kg',
  imagen_url VARCHAR(255) NULL,
  fecha_hora DATETIME NOT NULL,
  id_usuario INT NOT NULL,
  FOREIGN KEY (id_orden) REFERENCES orden_produccion(id_orden) ON DELETE CASCADE,
  FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE
);

-- 5. Tabla Paro de Línea
CREATE TABLE paro_linea (
  id_paro INT AUTO_INCREMENT PRIMARY KEY,
  id_orden INT NOT NULL,
  motivo VARCHAR(255) NOT NULL,
  observaciones TEXT NULL,
  hora_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  hora_fin DATETIME NULL,
  duracion_segundos INT NULL,
  id_usuario INT NOT NULL,
  FOREIGN KEY (id_orden) REFERENCES orden_produccion(id_orden) ON DELETE CASCADE,
  FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE
);

-- DATOS INICIALES DE PRUEBA
INSERT INTO usuario (nombre_completo, contrasena, rol) VALUES
('Lázaro Admin', 'admin123', 'administrador'),
('Maya Admin', 'admin123', 'administrador'),
('David Admin', 'admin123', 'administrador'),
('Alexa Admin', 'admin123', 'administrador'),
('Estefanía Admin', 'admin123', 'administrador'),
('operador01', '123456', 'operador'),
('operador02', '123456', 'operador'),
('operador03', '123456', 'operador'),
('supervisor01', '123456', 'supervisor'),
('supervisor02', '123456', 'supervisor');

INSERT INTO orden_produccion (id_orden, codigo_orden, nombre_maquina) VALUES
(1, 'ORD-001', 'Inyectora 01 - Molde Tapa Frontal'),
(2, 'ORD-002', 'Inyectora 02 - Molde Carcasa A'),
(3, 'ORD-003', 'Inyectora 03 - Molde Base Reforzada'),
(4, 'ORD-004', 'Inyectora 04 - Molde Difusor Óptico'),
(5, 'ORD-005', 'Inyectora 05 - Purga / Cambio de Molde');

INSERT INTO merma (id_orden, tipo_defecto, observaciones, peso_kilogramos, piezas, unidad_medida, imagen_url, fecha_hora, id_usuario) VALUES
(1, 'Rechupados (Hundimiento por enfriamiento)', 'Mal ajuste de temperatura', 12.50, NULL, 'kg', NULL, '2026-03-01 08:30:00', 2),
(2, 'Ráfagas plateadas (Humedad / gas atrapado)', 'Humedad dentro de la máquina', 8.75, NULL, 'kg', NULL, '2026-03-01 10:15:00', 2),
(3, 'Pieza incompleta (Tiro corto / falta presión)', 'Falta de presión en el armado', 15.20, NULL, 'kg', NULL, '2026-03-01 12:00:00', 2),
(4, 'Rebabas (Exceso de presión o desajuste)', 'Presión excesiva', 5.40, NULL, 'kg', NULL, '2026-03-01 14:45:00', 2),
(5, 'Purga inicial (Arranque / cambio de resina)', 'Cambio de resina necesario', 22.10, NULL, 'kg', NULL, '2026-03-01 16:30:00', 2);

INSERT INTO merma (id_orden, tipo_defecto, observaciones, peso_kilogramos, piezas, unidad_medida, imagen_url, fecha_hora, id_usuario) VALUES
(5, 'Rechupados (Hundimiento por enfriamiento)', 'Mal ajuste de temperatura', NULL, 45, 'piezas', NULL, '2026-03-02 09:10:00', 2),
(4, 'Ráfagas plateadas (Humedad / gas atrapado)', 'Humedad dentro de la máquina', NULL, 30, 'piezas', NULL, '2026-03-02 11:25:00', 2),
(3, 'Pieza incompleta (Tiro corto / falta presión)', 'Falta de presión en el armado', NULL, 60, 'piezas', NULL, '2026-03-02 13:40:00', 2),
(2, 'Rebabas (Exceso de presión o desajuste)', 'Presión excesiva', NULL, 25, 'piezas', NULL, '2026-03-02 15:15:00', 2),
(1, 'Purga inicial (Arranque / cambio de resina)', 'Cambio de resina necesario', NULL, 80, 'piezas', NULL, '2026-03-02 17:00:00', 2);

INSERT INTO paro_linea (id_orden, motivo, observaciones, hora_inicio, hora_fin, duracion_segundos, id_usuario) VALUES
(1, 'Falla Mecánica (Atoramiento husillo)', 'Atasco en el sistema de expulsión del molde', '2026-03-01 09:00:00', '2026-03-01 09:45:00', 2700, 2),
(2, 'Mantenimiento Preventivo / Ajuste', 'Corrección de temperatura en zonas 2 y 3 del cañón', '2026-03-01 11:30:00', '2026-03-01 12:00:00', 1800, 2),
(3, 'Falta de Material / Resina PP 5050', 'Espera de liberación de resina en almacén', '2026-03-01 14:00:00', '2026-03-01 14:50:00', 3000, 2),
(4, 'Cambio y Set-up de Molde', 'Fuga de aceite hidráulico en pistón de cierre', '2026-03-02 08:00:00', '2026-03-02 09:30:00', 5400, 2),
(5, 'Falla Mecánica (Atoramiento husillo)', 'Desmontaje de molde Tapa y revisión de conector', '2026-03-02 10:00:00', '2026-03-02 12:00:00', 7200, 2);
