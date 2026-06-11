USE banco_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS SP_RegistrarDeposito$$
CREATE PROCEDURE SP_RegistrarDeposito(
    IN p_CuentaID INT,
    IN p_Monto DECIMAL(15,2),
    IN p_Descripcion VARCHAR(255),
    IN p_EmpleadoID INT,
    OUT p_MovimientoID INT
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_cuenta_no_encontrada BOOLEAN DEFAULT FALSE;
    DECLARE v_empleado_existe INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_cuenta_no_encontrada = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_Monto IS NULL OR p_Monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto del depósito debe ser mayor que cero';
    END IF;

    IF p_EmpleadoID IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_empleado_existe
        FROM Empleado
        WHERE EmpleadoID = p_EmpleadoID;

        IF v_empleado_existe = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El empleado indicado no existe';
        END IF;
    END IF;

    START TRANSACTION;

    SET v_cuenta_no_encontrada = FALSE;

    SELECT EstadoCuenta
    INTO v_estado
    FROM Cuenta
    WHERE CuentaID = p_CuentaID
    FOR UPDATE;

    IF v_cuenta_no_encontrada THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta indicada no existe';
    END IF;

    IF v_estado <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta no se encuentra activa';
    END IF;

    UPDATE Cuenta
    SET SaldoActual = SaldoActual + p_Monto
    WHERE CuentaID = p_CuentaID;

    INSERT INTO Movimiento (
        TransferenciaRef,
        Fecha,
        TipoTransaccion,
        Monto,
        Descripcion,
        CuentaID,
        EmpleadoID
    )
    VALUES (
        NULL,
        NOW(),
        'DEPOSITO',
        p_Monto,
        COALESCE(
            NULLIF(TRIM(p_Descripcion), ''),
            'Depósito registrado'
        ),
        p_CuentaID,
        p_EmpleadoID
    );

    SET p_MovimientoID = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS SP_RegistrarRetiro$$
CREATE PROCEDURE SP_RegistrarRetiro(
    IN p_CuentaID INT,
    IN p_Monto DECIMAL(15,2),
    IN p_Descripcion VARCHAR(255),
    IN p_EmpleadoID INT,
    OUT p_MovimientoID INT
)
BEGIN
    DECLARE v_saldo DECIMAL(15,2);
    DECLARE v_estado VARCHAR(20);
    DECLARE v_cuenta_no_encontrada BOOLEAN DEFAULT FALSE;
    DECLARE v_empleado_existe INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_cuenta_no_encontrada = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_Monto IS NULL OR p_Monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto del retiro debe ser mayor que cero';
    END IF;

    IF p_EmpleadoID IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_empleado_existe
        FROM Empleado
        WHERE EmpleadoID = p_EmpleadoID;

        IF v_empleado_existe = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El empleado indicado no existe';
        END IF;
    END IF;

    START TRANSACTION;

    SET v_cuenta_no_encontrada = FALSE;

    SELECT SaldoActual, EstadoCuenta
    INTO v_saldo, v_estado
    FROM Cuenta
    WHERE CuentaID = p_CuentaID
    FOR UPDATE;

    IF v_cuenta_no_encontrada THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta indicada no existe';
    END IF;

    IF v_estado <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta no se encuentra activa';
    END IF;

    IF v_saldo < p_Monto THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta no tiene saldo suficiente';
    END IF;

    UPDATE Cuenta
    SET SaldoActual = SaldoActual - p_Monto
    WHERE CuentaID = p_CuentaID;

    INSERT INTO Movimiento (
        TransferenciaRef,
        Fecha,
        TipoTransaccion,
        Monto,
        Descripcion,
        CuentaID,
        EmpleadoID
    )
    VALUES (
        NULL,
        NOW(),
        'RETIRO',
        p_Monto,
        COALESCE(
            NULLIF(TRIM(p_Descripcion), ''),
            'Retiro registrado'
        ),
        p_CuentaID,
        p_EmpleadoID
    );

    SET p_MovimientoID = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS SP_RealizarTransferencia$$
CREATE PROCEDURE SP_RealizarTransferencia(
    IN p_CuentaOrigenID INT,
    IN p_CuentaDestinoID INT,
    IN p_Monto DECIMAL(15,2),
    IN p_Descripcion VARCHAR(255),
    IN p_EmpleadoID INT,
    OUT p_TransferenciaRef VARCHAR(30)
)
BEGIN
    DECLARE v_saldo_origen DECIMAL(15,2);
    DECLARE v_estado_origen VARCHAR(20);
    DECLARE v_estado_destino VARCHAR(20);
    DECLARE v_no_encontrada BOOLEAN DEFAULT FALSE;
    DECLARE v_empleado_existe INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_no_encontrada = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_CuentaOrigenID IS NULL OR p_CuentaDestinoID IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Las cuentas de origen y destino son obligatorias';
    END IF;

    IF p_CuentaOrigenID = p_CuentaDestinoID THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta de origen y destino no pueden ser iguales';
    END IF;

    IF p_Monto IS NULL OR p_Monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El monto de la transferencia debe ser mayor que cero';
    END IF;

    IF p_EmpleadoID IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_empleado_existe
        FROM Empleado
        WHERE EmpleadoID = p_EmpleadoID;

        IF v_empleado_existe = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El empleado indicado no existe';
        END IF;
    END IF;

    START TRANSACTION;

    IF p_CuentaOrigenID < p_CuentaDestinoID THEN

        SET v_no_encontrada = FALSE;

        SELECT SaldoActual, EstadoCuenta
        INTO v_saldo_origen, v_estado_origen
        FROM Cuenta
        WHERE CuentaID = p_CuentaOrigenID
        FOR UPDATE;

        IF v_no_encontrada THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cuenta de origen no existe';
        END IF;

        SET v_no_encontrada = FALSE;

        SELECT EstadoCuenta
        INTO v_estado_destino
        FROM Cuenta
        WHERE CuentaID = p_CuentaDestinoID
        FOR UPDATE;

        IF v_no_encontrada THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cuenta de destino no existe';
        END IF;

    ELSE

        SET v_no_encontrada = FALSE;

        SELECT EstadoCuenta
        INTO v_estado_destino
        FROM Cuenta
        WHERE CuentaID = p_CuentaDestinoID
        FOR UPDATE;

        IF v_no_encontrada THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cuenta de destino no existe';
        END IF;

        SET v_no_encontrada = FALSE;

        SELECT SaldoActual, EstadoCuenta
        INTO v_saldo_origen, v_estado_origen
        FROM Cuenta
        WHERE CuentaID = p_CuentaOrigenID
        FOR UPDATE;

        IF v_no_encontrada THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cuenta de origen no existe';
        END IF;

    END IF;

    IF v_estado_origen <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta de origen no se encuentra activa';
    END IF;

    IF v_estado_destino <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta de destino no se encuentra activa';
    END IF;

    IF v_saldo_origen < p_Monto THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta de origen no tiene saldo suficiente';
    END IF;

    SET p_TransferenciaRef =
        LEFT(REPLACE(UUID(), '-', ''), 30);

    UPDATE Cuenta
    SET SaldoActual = SaldoActual - p_Monto
    WHERE CuentaID = p_CuentaOrigenID;

    UPDATE Cuenta
    SET SaldoActual = SaldoActual + p_Monto
    WHERE CuentaID = p_CuentaDestinoID;

    INSERT INTO Movimiento (
        TransferenciaRef,
        Fecha,
        TipoTransaccion,
        Monto,
        Descripcion,
        CuentaID,
        EmpleadoID
    )
    VALUES (
        p_TransferenciaRef,
        NOW(),
        'TRANSFERENCIA_SALIDA',
        p_Monto,
        COALESCE(
            NULLIF(TRIM(p_Descripcion), ''),
            'Transferencia enviada'
        ),
        p_CuentaOrigenID,
        p_EmpleadoID
    );

    INSERT INTO Movimiento (
        TransferenciaRef,
        Fecha,
        TipoTransaccion,
        Monto,
        Descripcion,
        CuentaID,
        EmpleadoID
    )
    VALUES (
        p_TransferenciaRef,
        NOW(),
        'TRANSFERENCIA_ENTRADA',
        p_Monto,
        COALESCE(
            NULLIF(TRIM(p_Descripcion), ''),
            'Transferencia recibida'
        ),
        p_CuentaDestinoID,
        p_EmpleadoID
    );

    COMMIT;
END$$

DELIMITER ;