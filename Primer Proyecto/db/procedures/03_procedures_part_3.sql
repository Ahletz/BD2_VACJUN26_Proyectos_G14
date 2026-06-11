USE banco_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS SP_CerrarCuenta$$
CREATE PROCEDURE SP_CerrarCuenta(
    IN p_CuentaID INT
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_saldo DECIMAL(15,2);
    DECLARE v_no_encontrada BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_no_encontrada = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_CuentaID IS NULL OR p_CuentaID <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El identificador de la cuenta no es válido';
    END IF;

    START TRANSACTION;

    SELECT EstadoCuenta, SaldoActual
    INTO v_estado, v_saldo
    FROM Cuenta
    WHERE CuentaID = p_CuentaID
    FOR UPDATE;

    IF v_no_encontrada THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta indicada no existe';
    END IF;

    IF v_estado = 'CERRADA' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta ya se encuentra cerrada';
    END IF;

    IF v_saldo <> 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta debe tener saldo cero para poder cerrarse';
    END IF;

    UPDATE Cuenta
    SET
        EstadoCuenta = 'CERRADA',
        FechaCierre = CURDATE()
    WHERE CuentaID = p_CuentaID;

    COMMIT;
END$$


DROP PROCEDURE IF EXISTS SP_ReporteClientesSucursal$$
CREATE PROCEDURE SP_ReporteClientesSucursal(
    IN p_SucursalID INT
)
BEGIN
    DECLARE v_sucursal_existe INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_sucursal_existe
    FROM Sucursal
    WHERE SucursalID = p_SucursalID;

    IF v_sucursal_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La sucursal indicada no existe';
    END IF;

    SELECT
        s.SucursalID,
        s.SucursalNombre,
        c.ClienteID,
        c.ClienteDNI,
        c.ClienteNombre,
        c.ClienteTelefono,
        c.ClienteCorreo,
        COUNT(ct.CuentaID) AS CantidadCuentas,
        SUM(
            CASE
                WHEN ct.EstadoCuenta = 'ACTIVA' THEN 1
                ELSE 0
            END
        ) AS CuentasActivas,
        COALESCE(SUM(ct.SaldoActual), 0.00) AS SaldoTotal
    FROM Sucursal s
    INNER JOIN Cuenta ct
        ON ct.SucursalID = s.SucursalID
    INNER JOIN Cliente c
        ON c.ClienteID = ct.ClienteID
    WHERE s.SucursalID = p_SucursalID
    GROUP BY
        s.SucursalID,
        s.SucursalNombre,
        c.ClienteID,
        c.ClienteDNI,
        c.ClienteNombre,
        c.ClienteTelefono,
        c.ClienteCorreo
    ORDER BY c.ClienteNombre;
END$$


DROP PROCEDURE IF EXISTS SP_ReporteMovimientosCuenta$$
CREATE PROCEDURE SP_ReporteMovimientosCuenta(
    IN p_CuentaID INT,
    IN p_FechaInicio DATETIME,
    IN p_FechaFin DATETIME
)
BEGIN
    DECLARE v_cuenta_existe INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_cuenta_existe
    FROM Cuenta
    WHERE CuentaID = p_CuentaID;

    IF v_cuenta_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cuenta indicada no existe';
    END IF;

    IF p_FechaInicio IS NOT NULL
       AND p_FechaFin IS NOT NULL
       AND p_FechaInicio > p_FechaFin THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha inicial no puede ser mayor que la fecha final';
    END IF;

    SELECT
        c.CuentaID,
        c.TipoCuenta,
        c.EstadoCuenta,
        c.SaldoActual,
        cl.ClienteID,
        cl.ClienteDNI,
        cl.ClienteNombre,
        s.SucursalID,
        s.SucursalNombre,
        m.MovimientoID,
        m.TransferenciaRef,
        m.Fecha,
        m.TipoTransaccion,
        m.Monto,
        CASE
            WHEN m.TipoTransaccion IN (
                'RETIRO',
                'TRANSFERENCIA_SALIDA'
            )
            THEN m.Monto * -1
            ELSE m.Monto
        END AS MontoAplicado,
        m.Descripcion,
        m.EmpleadoID,
        e.EmpleadoNombre
    FROM Cuenta c
    INNER JOIN Cliente cl
        ON cl.ClienteID = c.ClienteID
    INNER JOIN Sucursal s
        ON s.SucursalID = c.SucursalID
    LEFT JOIN Movimiento m
        ON m.CuentaID = c.CuentaID
    LEFT JOIN Empleado e
        ON e.EmpleadoID = m.EmpleadoID
    WHERE c.CuentaID = p_CuentaID
      AND (
          p_FechaInicio IS NULL
          OR m.Fecha >= p_FechaInicio
      )
      AND (
          p_FechaFin IS NULL
          OR m.Fecha <= p_FechaFin
      )
    ORDER BY m.Fecha DESC, m.MovimientoID DESC;
END$$

DELIMITER ;