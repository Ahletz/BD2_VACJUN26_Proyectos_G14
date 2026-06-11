USE banco_db;

START TRANSACTION;

INSERT IGNORE INTO TipoCuenta (TipoCuenta)
VALUES
    ('Ahorro'),
    ('Corriente');

INSERT IGNORE INTO EstadoCuenta (EstadoCuenta)
VALUES
    ('ACTIVA'),
    ('INACTIVA'),
    ('CERRADA');

INSERT IGNORE INTO TipoTransaccion (TipoTransaccion)
VALUES
    ('DEPOSITO'),
    ('RETIRO'),
    ('TRANSFERENCIA_SALIDA'),
    ('TRANSFERENCIA_ENTRADA');

COMMIT;
