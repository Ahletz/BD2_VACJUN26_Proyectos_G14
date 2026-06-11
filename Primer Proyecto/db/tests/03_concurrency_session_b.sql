USE banco_db;

-- Ejecutar mientras la sesión A mantiene bloqueada la cuenta.
-- Esta sesión esperará hasta que la sesión A finalice.

SET @CuentaPrueba = (
    SELECT CuentaID
    FROM Cuenta
    WHERE EstadoCuenta = 'ACTIVA'
    ORDER BY CuentaID
    LIMIT 1
);

SET @MontoRetiro = 700.00;

SELECT
    'SESIÓN B - INICIO' AS Estado,
    @CuentaPrueba AS CuentaID,
    SaldoActual
FROM Cuenta
WHERE CuentaID = @CuentaPrueba;

SET autocommit = 0;

START TRANSACTION;

SELECT
    CuentaID,
    SaldoActual,
    EstadoCuenta
FROM Cuenta
WHERE CuentaID = @CuentaPrueba
FOR UPDATE;

SELECT
    'SESIÓN B - BLOQUEO OBTENIDO DESPUÉS DE SESIÓN A' AS Estado;

UPDATE Cuenta
SET SaldoActual = SaldoActual - @MontoRetiro
WHERE CuentaID = @CuentaPrueba
  AND EstadoCuenta = 'ACTIVA'
  AND SaldoActual >= @MontoRetiro;

SET @OperacionRealizada = ROW_COUNT();

INSERT INTO Movimiento (
    TransferenciaRef,
    Fecha,
    TipoTransaccion,
    Monto,
    Descripcion,
    CuentaID,
    EmpleadoID
)
SELECT
    NULL,
    NOW(),
    'RETIRO',
    @MontoRetiro,
    'Prueba de concurrencia - Sesión B',
    @CuentaPrueba,
    NULL
WHERE @OperacionRealizada = 1;

COMMIT;

SELECT
    CASE
        WHEN @OperacionRealizada = 1
            THEN 'SESIÓN B - RETIRO REALIZADO'
        ELSE 'SESIÓN B - SALDO INSUFICIENTE'
    END AS Resultado;

SELECT
    CuentaID,
    SaldoActual
FROM Cuenta
WHERE CuentaID = @CuentaPrueba;

SELECT
    MovimientoID,
    Fecha,
    TipoTransaccion,
    Monto,
    Descripcion
FROM Movimiento
WHERE CuentaID = @CuentaPrueba
  AND Descripcion LIKE 'Prueba de concurrencia%'
ORDER BY MovimientoID;

SET autocommit = 1;