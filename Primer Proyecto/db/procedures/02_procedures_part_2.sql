
USE banco_db;

DELIMITER $$

--    1. SP_RegistrarDeposito

DROP PROCEDURE IF EXISTS SP_RegistrarDeposito$$

CREATE PROCEDURE SP_RegistrarDeposito(
    IN p_CuentaID    INT,
    IN p_Monto       DECIMAL(15,2),
    IN p_Descripcion VARCHAR(255),
    IN p_EmpleadoID  INT
)
BEGIN
    DECLARE v_existe  INT     DEFAULT 0;
    DECLARE v_estado  VARCHAR(20);
    DECLARE v_saldo   DECIMAL(15,2);

    -- Si ocurre cualquier error SQL → ROLLBACK automático
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarDeposito: error inesperado, transacción revertida.';
    END;

    -- ── Validaciones ─────────────────────────────────────────
    SELECT COUNT(*), estado, saldo_actual
    INTO   v_existe, v_estado, v_saldo
    FROM   cuenta
    WHERE  cuenta_id = p_CuentaID;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarDeposito: la cuenta no existe.';
    END IF;

    IF v_estado != 'activa' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarDeposito: la cuenta no está activa.';
    END IF;

    IF p_Monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarDeposito: el monto debe ser mayor a cero.';
    END IF;

    -- ── Transacción atómica ───────────────────────────────────
    START TRANSACTION;

        -- a) Registrar movimiento
        INSERT INTO transaccion (
            cuenta_id, empleado_id, tipo_transaccion,
            monto, descripcion, fecha_transaccion
        ) VALUES (
            p_CuentaID, p_EmpleadoID, 'DEPOSITO',
            p_Monto, p_Descripcion, NOW()
        );

        -- b) Actualizar saldo
        UPDATE cuenta
        SET    saldo_actual = saldo_actual + p_Monto
        WHERE  cuenta_id = p_CuentaID;

    COMMIT;

    SELECT CONCAT('Depósito de Q', FORMAT(p_Monto, 2),
                  ' registrado en cuenta ', p_CuentaID,
                  '. Nuevo saldo: Q', FORMAT(v_saldo + p_Monto, 2)) AS resultado;
END$$



--  2. SP_RegistrarRetiro

DROP PROCEDURE IF EXISTS SP_RegistrarRetiro$$

CREATE PROCEDURE SP_RegistrarRetiro(
    IN p_CuentaID    INT,
    IN p_Monto       DECIMAL(15,2),
    IN p_Descripcion VARCHAR(255),
    IN p_EmpleadoID  INT
)
BEGIN
    DECLARE v_existe  INT     DEFAULT 0;
    DECLARE v_estado  VARCHAR(20);
    DECLARE v_saldo   DECIMAL(15,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarRetiro: error inesperado, transacción revertida.';
    END;

    -- ── Validaciones ─────────────────────────────────────────
    SELECT COUNT(*), estado, saldo_actual
    INTO   v_existe, v_estado, v_saldo
    FROM   cuenta
    WHERE  cuenta_id = p_CuentaID;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarRetiro: la cuenta no existe.';
    END IF;

    IF v_estado != 'activa' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarRetiro: la cuenta no está activa.';
    END IF;

    IF p_Monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarRetiro: el monto debe ser mayor a cero.';
    END IF;

    IF v_saldo < p_Monto THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RegistrarRetiro: saldo insuficiente.';
    END IF;

    -- ── Transacción atómica ───────────────────────────────────
    START TRANSACTION;

        -- a) Registrar movimiento
        INSERT INTO transaccion (
            cuenta_id, empleado_id, tipo_transaccion,
            monto, descripcion, fecha_transaccion
        ) VALUES (
            p_CuentaID, p_EmpleadoID, 'RETIRO',
            p_Monto, p_Descripcion, NOW()
        );

        -- b) Actualizar saldo
        UPDATE cuenta
        SET    saldo_actual = saldo_actual - p_Monto
        WHERE  cuenta_id = p_CuentaID;

    COMMIT;

    SELECT CONCAT('Retiro de Q', FORMAT(p_Monto, 2),
                  ' realizado de cuenta ', p_CuentaID,
                  '. Nuevo saldo: Q', FORMAT(v_saldo - p_Monto, 2)) AS resultado;
END$$



--  3. SP_RealizarTransferencia


DROP PROCEDURE IF EXISTS SP_RealizarTransferencia$$

CREATE PROCEDURE SP_RealizarTransferencia(
    IN p_CuentaOrigenID  INT,
    IN p_CuentaDestinoID INT,
    IN p_Monto           DECIMAL(15,2)
)
BEGIN
    DECLARE v_existe_origen  INT     DEFAULT 0;
    DECLARE v_existe_destino INT     DEFAULT 0;
    DECLARE v_estado_origen  VARCHAR(20);
    DECLARE v_estado_destino VARCHAR(20);
    DECLARE v_saldo_origen   DECIMAL(15,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: error inesperado, transacción revertida.';
    END;

    -- ── Validaciones ─────────────────────────────────────────
    IF p_CuentaOrigenID = p_CuentaDestinoID THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: origen y destino no pueden ser iguales.';
    END IF;

    IF p_Monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: el monto debe ser mayor a cero.';
    END IF;

    -- Verificar cuenta origen
    SELECT COUNT(*), estado, saldo_actual
    INTO   v_existe_origen, v_estado_origen, v_saldo_origen
    FROM   cuenta WHERE cuenta_id = p_CuentaOrigenID;

    IF v_existe_origen = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: cuenta origen no existe.';
    END IF;

    IF v_estado_origen != 'activa' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: cuenta origen no está activa.';
    END IF;

    IF v_saldo_origen < p_Monto THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: saldo insuficiente en cuenta origen.';
    END IF;

    -- Verificar cuenta destino
    SELECT COUNT(*), estado
    INTO   v_existe_destino, v_estado_destino
    FROM   cuenta WHERE cuenta_id = p_CuentaDestinoID;

    IF v_existe_destino = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: cuenta destino no existe.';
    END IF;

    IF v_estado_destino != 'activa' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SP_RealizarTransferencia: cuenta destino no está activa.';
    END IF;

    -- ── Transacción atómica (4 operaciones, todo o nada) ─────
    START TRANSACTION;

        -- a) Registrar salida en origen
        INSERT INTO transaccion (
            cuenta_id, empleado_id, tipo_transaccion,
            monto, descripcion, fecha_transaccion
        ) VALUES (
            p_CuentaOrigenID, NULL, 'TRANSFERENCIA_SALIDA',
            p_Monto,
            CONCAT('Transferencia hacia cuenta ', p_CuentaDestinoID),
            NOW()
        );

        -- b) Descontar saldo en origen
        UPDATE cuenta
        SET    saldo_actual = saldo_actual - p_Monto
        WHERE  cuenta_id = p_CuentaOrigenID;

        -- c) Registrar entrada en destino
        INSERT INTO transaccion (
            cuenta_id, empleado_id, tipo_transaccion,
            monto, descripcion, fecha_transaccion
        ) VALUES (
            p_CuentaDestinoID, NULL, 'TRANSFERENCIA_ENTRADA',
            p_Monto,
            CONCAT('Transferencia desde cuenta ', p_CuentaOrigenID),
            NOW()
        );

        -- d) Sumar saldo en destino
        UPDATE cuenta
        SET    saldo_actual = saldo_actual + p_Monto
        WHERE  cuenta_id = p_CuentaDestinoID;

    COMMIT;

    SELECT CONCAT('Transferencia de Q', FORMAT(p_Monto, 2),
                  ' de cuenta ', p_CuentaOrigenID,
                  ' a cuenta ', p_CuentaDestinoID,
                  ' completada exitosamente.') AS resultado;
END$$


DELIMITER ;


