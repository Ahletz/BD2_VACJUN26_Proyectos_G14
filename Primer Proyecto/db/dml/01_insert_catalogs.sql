
USE banco_db;

-- Evitar errores si ya existen estos datos
SET FOREIGN_KEY_CHECKS = 0;

-- ── Sucursales iniciales ──────────────────────────────────────
-- Ajusta o agrega sucursales según los datos de tu CSV
INSERT IGNORE INTO sucursal (nombre, direccion) VALUES
    ('Central',       'Zona 1, Ciudad de Guatemala'),
    ('Norte',         'Zona 6, Ciudad de Guatemala'),
    ('Sur',           'Zona 12, Ciudad de Guatemala'),
    ('Oriente',       'Zona 18, Ciudad de Guatemala'),
    ('Occidente',     'Zona 7, Ciudad de Guatemala');

-- ── Empleado de sistema (para transacciones automáticas) ──────
-- Este empleado se usa cuando una operación no tiene cajero asignado
INSERT IGNORE INTO empleado (nombre, cargo, sucursal_id) VALUES
    ('Sistema Bancario', 'SISTEMA', 1);

SET FOREIGN_KEY_CHECKS = 1;

-- Verificar inserciones
SELECT 'sucursal'  AS tabla, COUNT(*) AS filas FROM sucursal
UNION ALL
SELECT 'empleado'  AS tabla, COUNT(*) AS filas FROM empleado;