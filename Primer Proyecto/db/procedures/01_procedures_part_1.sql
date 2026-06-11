USE banco_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS SP_RegistrarCliente$$
CREATE PROCEDURE SP_RegistrarCliente(
    IN p_ClienteDNI VARCHAR(20),
    IN p_ClienteNombre VARCHAR(150),
    IN p_ClienteFechaNacimiento DATE,
    IN p_ClienteDireccion VARCHAR(200),
    IN p_ClienteTelefono VARCHAR(20),
    IN p_ClienteCorreo VARCHAR(150),
    OUT p_ClienteID INT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_ClienteDNI IS NULL OR TRIM(p_ClienteDNI) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El DNI del cliente es obligatorio';
    END IF;

    IF p_ClienteNombre IS NULL OR TRIM(p_ClienteNombre) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El nombre del cliente es obligatorio';
    END IF;

    IF p_ClienteFechaNacimiento IS NULL
       OR p_ClienteFechaNacimiento >= CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha de nacimiento no es válida';
    END IF;

    IF p_ClienteDireccion IS NULL OR TRIM(p_ClienteDireccion) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La dirección del cliente es obligatoria';
    END IF;

    IF p_ClienteTelefono IS NULL OR TRIM(p_ClienteTelefono) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El teléfono del cliente es obligatorio';
    END IF;

    SELECT COUNT(*)
    INTO v_existe
    FROM Cliente
    WHERE ClienteDNI = TRIM(p_ClienteDNI);

    IF v_existe > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ya existe un cliente con el DNI proporcionado';
    END IF;

    START TRANSACTION;

    INSERT INTO Cliente (
        ClienteDNI,
        ClienteNombre,
        ClienteFechaNacimiento,
        ClienteDireccion,
        ClienteTelefono,
        ClienteCorreo
    )
    VALUES (
        TRIM(p_ClienteDNI),
        TRIM(p_ClienteNombre),
        p_ClienteFechaNacimiento,
        TRIM(p_ClienteDireccion),
        TRIM(p_ClienteTelefono),
        NULLIF(TRIM(p_ClienteCorreo), '')
    );

    SET p_ClienteID = LAST_INSERT_ID();

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS SP_ActualizarCliente$$
CREATE PROCEDURE SP_ActualizarCliente(
    IN p_ClienteID INT,
    IN p_ClienteDNI VARCHAR(20),
    IN p_ClienteNombre VARCHAR(150),
    IN p_ClienteFechaNacimiento DATE,
    IN p_ClienteDireccion VARCHAR(200),
    IN p_ClienteTelefono VARCHAR(20),
    IN p_ClienteCorreo VARCHAR(150)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_dni_duplicado INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*)
    INTO v_existe
    FROM Cliente
    WHERE ClienteID = p_ClienteID;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El cliente indicado no existe';
    END IF;

    IF p_ClienteDNI IS NULL OR TRIM(p_ClienteDNI) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El DNI del cliente es obligatorio';
    END IF;

    IF p_ClienteNombre IS NULL OR TRIM(p_ClienteNombre) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El nombre del cliente es obligatorio';
    END IF;

    IF p_ClienteFechaNacimiento IS NULL
       OR p_ClienteFechaNacimiento >= CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha de nacimiento no es válida';
    END IF;

    SELECT COUNT(*)
    INTO v_dni_duplicado
    FROM Cliente
    WHERE ClienteDNI = TRIM(p_ClienteDNI)
      AND ClienteID <> p_ClienteID;

    IF v_dni_duplicado > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El DNI ya está asignado a otro cliente';
    END IF;

    START TRANSACTION;

    UPDATE Cliente
    SET
        ClienteDNI = TRIM(p_ClienteDNI),
        ClienteNombre = TRIM(p_ClienteNombre),
        ClienteFechaNacimiento = p_ClienteFechaNacimiento,
        ClienteDireccion = TRIM(p_ClienteDireccion),
        ClienteTelefono = TRIM(p_ClienteTelefono),
        ClienteCorreo = NULLIF(TRIM(p_ClienteCorreo), '')
    WHERE ClienteID = p_ClienteID;

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS SP_AbrirCuenta$$
CREATE PROCEDURE SP_AbrirCuenta(
    IN p_ClienteID INT,
    IN p_SucursalID INT,
    IN p_TipoCuenta VARCHAR(50),
    IN p_SaldoInicial DECIMAL(15,2),
    OUT p_CuentaID INT
)
BEGIN
    DECLARE v_cliente_existe INT DEFAULT 0;
    DECLARE v_sucursal_existe INT DEFAULT 0;
    DECLARE v_tipo_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*)
    INTO v_cliente_existe
    FROM Cliente
    WHERE ClienteID = p_ClienteID;

    IF v_cliente_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El cliente indicado no existe';
    END IF;

    SELECT COUNT(*)
    INTO v_sucursal_existe
    FROM Sucursal
    WHERE SucursalID = p_SucursalID;

    IF v_sucursal_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La sucursal indicada no existe';
    END IF;

    SELECT COUNT(*)
    INTO v_tipo_existe
    FROM TipoCuenta
    WHERE TipoCuenta = p_TipoCuenta;

    IF v_tipo_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El tipo de cuenta indicado no existe';
    END IF;

    IF p_SaldoInicial IS NULL OR p_SaldoInicial < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El saldo inicial no puede ser negativo';
    END IF;

    START TRANSACTION;

    INSERT INTO Cuenta (
        TipoCuenta,
        FechaApertura,
        FechaCierre,
        SaldoActual,
        EstadoCuenta,
        ClienteID,
        SucursalID
    )
    VALUES (
        p_TipoCuenta,
        CURDATE(),
        NULL,
        p_SaldoInicial,
        'ACTIVA',
        p_ClienteID,
        p_SucursalID
    );

    SET p_CuentaID = LAST_INSERT_ID();

    IF p_SaldoInicial > 0 THEN
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
            p_SaldoInicial,
            'Depósito de apertura de cuenta',
            p_CuentaID,
            NULL
        );
    END IF;

    COMMIT;
END$$

DELIMITER ;
