USE banco_db;

-- La carga principal de los archivos CSV se realiza mediante:
-- docker compose exec python python migrate.py

-- Validación de registros cargados
SELECT 'Sucursal' AS Tabla, COUNT(*) AS Total FROM Sucursal
UNION ALL
SELECT 'Cliente', COUNT(*) FROM Cliente
UNION ALL
SELECT 'Empleado', COUNT(*) FROM Empleado
UNION ALL
SELECT 'Cuenta', COUNT(*) FROM Cuenta
UNION ALL
SELECT 'Movimiento', COUNT(*) FROM Movimiento;

-- Validar cuentas sin cliente
SELECT
    c.CuentaID,
    c.ClienteID
FROM Cuenta c
LEFT JOIN Cliente cl
    ON cl.ClienteID = c.ClienteID
WHERE cl.ClienteID IS NULL;

-- Validar cuentas sin sucursal
SELECT
    c.CuentaID,
    c.SucursalID
FROM Cuenta c
LEFT JOIN Sucursal s
    ON s.SucursalID = c.SucursalID
WHERE s.SucursalID IS NULL;

-- Validar empleados sin sucursal
SELECT
    e.EmpleadoID,
    e.SucursalID
FROM Empleado e
LEFT JOIN Sucursal s
    ON s.SucursalID = e.SucursalID
WHERE s.SucursalID IS NULL;

-- Validar movimientos sin cuenta
SELECT
    m.MovimientoID,
    m.CuentaID
FROM Movimiento m
LEFT JOIN Cuenta c
    ON c.CuentaID = m.CuentaID
WHERE c.CuentaID IS NULL;

-- Validar movimientos con montos inválidos
SELECT *
FROM Movimiento
WHERE Monto <= 0;

-- Validar transferencias incompletas
SELECT
    TransferenciaRef,
    COUNT(*) AS CantidadMovimientos,
    COUNT(DISTINCT TipoTransaccion) AS TiposRegistrados
FROM Movimiento
WHERE TransferenciaRef IS NOT NULL
GROUP BY TransferenciaRef
HAVING COUNT(*) <> 2
    OR COUNT(DISTINCT TipoTransaccion) <> 2;
