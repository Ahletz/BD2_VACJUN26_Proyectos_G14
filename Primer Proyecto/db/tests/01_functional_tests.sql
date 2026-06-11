USE banco_db;

-- ============================================================
-- PRUEBAS FUNCIONALES DE PROCEDIMIENTOS ALMACENADOS
-- ============================================================

-- Preparar una sucursal para las pruebas
INSERT IGNORE INTO Sucursal (
    SucursalNombre,
    SucursalDireccion,
    SucursalTelefono
)
VALUES (
    'Sucursal Pruebas',
    'Ciudad de Guatemala',
    '22220000'
);

SET @SucursalID = (
    SELECT SucursalID
    FROM Sucursal
    WHERE SucursalNombre = 'Sucursal Pruebas'
    LIMIT 1
);

SET @DNI = CONCAT(
    'TEST',
    DATE_FORMAT(NOW(), '%Y%m%d%H%i%s')
);

-- ============================================================
-- 1. SP_RegistrarCliente
-- ============================================================

SET @ClienteID = NULL;

CALL SP_RegistrarCliente(
    @DNI,
    'Cliente de Prueba',
    '1995-05-15',
    'Zona 1, Ciudad de Guatemala',
    '55551111',
    'cliente.prueba@correo.com',
    @ClienteID
);

SELECT
    'SP_RegistrarCliente' AS Prueba,
    @ClienteID AS ClienteGenerado;

SELECT *
FROM Cliente
WHERE ClienteID = @ClienteID;


-- ============================================================
-- 2. SP_ActualizarCliente
-- ============================================================

CALL SP_ActualizarCliente(
    @ClienteID,
    @DNI,
    'Cliente de Prueba Actualizado',
    '1995-05-15',
    'Zona 10, Ciudad de Guatemala',
    '55552222',
    'cliente.actualizado@correo.com'
);

SELECT
    'SP_ActualizarCliente' AS Prueba,
    ClienteID,
    ClienteNombre,
    ClienteDireccion,
    ClienteTelefono,
    ClienteCorreo
FROM Cliente
WHERE ClienteID = @ClienteID;


-- ============================================================
-- 3. SP_AbrirCuenta
-- ============================================================

SET @CuentaOrigenID = NULL;

CALL SP_AbrirCuenta(
    @ClienteID,
    @SucursalID,
    'Ahorro',
    1000.00,
    @CuentaOrigenID
);

SELECT
    'SP_AbrirCuenta - Cuenta origen' AS Prueba,
    @CuentaOrigenID AS CuentaGenerada;

SET @CuentaDestinoID = NULL;

CALL SP_AbrirCuenta(
    @ClienteID,
    @SucursalID,
    'Corriente',
    500.00,
    @CuentaDestinoID
);

SELECT
    'SP_AbrirCuenta - Cuenta destino' AS Prueba,
    @CuentaDestinoID AS CuentaGenerada;

SELECT *
FROM Cuenta
WHERE CuentaID IN (
    @CuentaOrigenID,
    @CuentaDestinoID
);


-- ============================================================
-- 4. SP_RegistrarDeposito
-- ============================================================

SET @MovimientoDepositoID = NULL;

CALL SP_RegistrarDeposito(
    @CuentaOrigenID,
    300.00,
    'Depósito de prueba',
    NULL,
    @MovimientoDepositoID
);

SELECT
    'SP_RegistrarDeposito' AS Prueba,
    @MovimientoDepositoID AS MovimientoGenerado;

SELECT
    CuentaID,
    SaldoActual
FROM Cuenta
WHERE CuentaID = @CuentaOrigenID;


-- ============================================================
-- 5. SP_RegistrarRetiro
-- ============================================================

SET @MovimientoRetiroID = NULL;

CALL SP_RegistrarRetiro(
    @CuentaOrigenID,
    100.00,
    'Retiro de prueba',
    NULL,
    @MovimientoRetiroID
);

SELECT
    'SP_RegistrarRetiro' AS Prueba,
    @MovimientoRetiroID AS MovimientoGenerado;

SELECT
    CuentaID,
    SaldoActual
FROM Cuenta
WHERE CuentaID = @CuentaOrigenID;


-- ============================================================
-- 6. SP_RealizarTransferencia
-- ============================================================

SET @TransferenciaRef = NULL;

CALL SP_RealizarTransferencia(
    @CuentaOrigenID,
    @CuentaDestinoID,
    200.00,
    'Transferencia de prueba',
    NULL,
    @TransferenciaRef
);

SELECT
    'SP_RealizarTransferencia' AS Prueba,
    @TransferenciaRef AS ReferenciaGenerada;

SELECT
    CuentaID,
    SaldoActual
FROM Cuenta
WHERE CuentaID IN (
    @CuentaOrigenID,
    @CuentaDestinoID
);

SELECT *
FROM Movimiento
WHERE TransferenciaRef = @TransferenciaRef;


-- ============================================================
-- 7. SP_CerrarCuenta
-- ============================================================

SET @CuentaCerrarID = NULL;

CALL SP_AbrirCuenta(
    @ClienteID,
    @SucursalID,
    'Ahorro',
    0.00,
    @CuentaCerrarID
);

CALL SP_CerrarCuenta(
    @CuentaCerrarID
);

SELECT
    'SP_CerrarCuenta' AS Prueba,
    CuentaID,
    EstadoCuenta,
    FechaCierre,
    SaldoActual
FROM Cuenta
WHERE CuentaID = @CuentaCerrarID;


-- ============================================================
-- 8. SP_ReporteClientesSucursal
-- ============================================================

CALL SP_ReporteClientesSucursal(
    @SucursalID
);


-- ============================================================
-- 9. SP_ReporteMovimientosCuenta
-- ============================================================

CALL SP_ReporteMovimientosCuenta(
    @CuentaOrigenID,
    DATE_SUB(NOW(), INTERVAL 1 DAY),
    DATE_ADD(NOW(), INTERVAL 1 DAY)
);


-- ============================================================
-- RESUMEN FINAL
-- ============================================================

SELECT
    'RESUMEN DE PRUEBAS' AS Resultado,
    @ClienteID AS ClienteID,
    @CuentaOrigenID AS CuentaOrigenID,
    @CuentaDestinoID AS CuentaDestinoID,
    @CuentaCerrarID AS CuentaCerradaID,
    @MovimientoDepositoID AS DepositoID,
    @MovimientoRetiroID AS RetiroID,
    @TransferenciaRef AS TransferenciaRef;


-- ============================================================
-- PRUEBAS DE ERROR
-- Ejecutar individualmente porque generan errores intencionales.
-- ============================================================

-- Cliente con DNI duplicado
-- CALL SP_RegistrarCliente(
--     @DNI,
--     'Cliente Duplicado',
--     '1990-01-01',
--     'Dirección de prueba',
--     '55553333',
--     NULL,
--     @ClienteDuplicado
-- );

-- Depósito con monto negativo
-- CALL SP_RegistrarDeposito(
--     @CuentaOrigenID,
--     -100.00,
--     'Monto inválido',
--     NULL,
--     @MovimientoError
-- );

-- Retiro mayor al saldo disponible
-- CALL SP_RegistrarRetiro(
--     @CuentaOrigenID,
--     999999.00,
--     'Saldo insuficiente',
--     NULL,
--     @MovimientoError
-- );

-- Transferencia hacia la misma cuenta
-- CALL SP_RealizarTransferencia(
--     @CuentaOrigenID,
--     @CuentaOrigenID,
--     50.00,
--     'Transferencia inválida',
--     NULL,
--     @TransferenciaError
-- );

-- Cierre de cuenta con saldo disponible
-- CALL SP_CerrarCuenta(
--     @CuentaOrigenID
-- );
