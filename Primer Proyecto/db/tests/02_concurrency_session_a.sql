USE banco_db;

-- Ejecutar esta sesión primero.
-- Durante la espera de 15 segundos, ejecutar la sesión B.

SET @CuentaPrueba = (
    SELECT CuentaID
    FROM Cuenta
    WHERE EstadoCuenta = 'ACTIVA'
    ORDER BY CuentaID
    LIMIT 1
);

SET @MontoRetiro = 700.00;

SELECT
    'SESIÓN A - INICIO' AS Estado,
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
    'SESIÓN A - CUENTA BLOQUEADA DURANTE 15 SEGUNDOS' AS Estado;

DO SLEEP(15);

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
    'Prueba de concurrencia - Sesión A',
    @CuentaPrueba,
    NULL
WHERE @OperacionRealizada = 1;

COMMIT;

SELECT
    CASE
        WHEN @OperacionRealizada = 1
            THEN 'SESIÓN A - RETIRO REALIZADO'
        ELSE 'SESIÓN A - SALDO INSUFICIENTE'
    END AS Resultado;

SELECT
    CuentaID,
    SaldoActual
FROM Cuenta
WHERE CuentaID = @CuentaPrueba;

SET autocommit = 1;
