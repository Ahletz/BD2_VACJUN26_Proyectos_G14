USE banco_db;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS Movimiento;
DROP TABLE IF EXISTS Cuenta;
DROP TABLE IF EXISTS Empleado;
DROP TABLE IF EXISTS Cliente;
DROP TABLE IF EXISTS Sucursal;
DROP TABLE IF EXISTS TipoTransaccion;
DROP TABLE IF EXISTS EstadoCuenta;
DROP TABLE IF EXISTS TipoCuenta;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE TipoCuenta (
    TipoCuenta VARCHAR(50) NOT NULL,
    PRIMARY KEY (TipoCuenta)
) ENGINE = InnoDB;

CREATE TABLE EstadoCuenta (
    EstadoCuenta VARCHAR(20) NOT NULL,
    PRIMARY KEY (EstadoCuenta)
) ENGINE = InnoDB;

CREATE TABLE TipoTransaccion (
    TipoTransaccion VARCHAR(30) NOT NULL,
    PRIMARY KEY (TipoTransaccion)
) ENGINE = InnoDB;

CREATE TABLE Sucursal (
    SucursalID        INT          NOT NULL AUTO_INCREMENT,
    SucursalNombre    VARCHAR(100) NOT NULL,
    SucursalDireccion VARCHAR(200) NOT NULL,
    SucursalTelefono  VARCHAR(20)  NOT NULL,
    PRIMARY KEY (SucursalID),
    CONSTRAINT uq_sucursal_nombre UNIQUE (SucursalNombre)
) ENGINE = InnoDB;

CREATE TABLE Cliente (
    ClienteID              INT          NOT NULL AUTO_INCREMENT,
    ClienteDNI             VARCHAR(20)  NOT NULL,
    ClienteNombre          VARCHAR(150) NOT NULL,
    ClienteFechaNacimiento DATE         NOT NULL,
    ClienteDireccion       VARCHAR(200) NOT NULL,
    ClienteTelefono        VARCHAR(20)  NOT NULL,
    ClienteCorreo          VARCHAR(150) NULL,
    PRIMARY KEY (ClienteID),
    CONSTRAINT uq_cliente_dni UNIQUE (ClienteDNI)
) ENGINE = InnoDB;

CREATE TABLE Empleado (
    EmpleadoID     INT          NOT NULL AUTO_INCREMENT,
    EmpleadoNombre VARCHAR(150) NOT NULL,
    EmpleadoCargo  VARCHAR(100) NOT NULL,
    SucursalID     INT          NOT NULL,
    PRIMARY KEY (EmpleadoID),
    CONSTRAINT fk_empleado_sucursal
        FOREIGN KEY (SucursalID)
        REFERENCES Sucursal (SucursalID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE Cuenta (
    CuentaID      INT           NOT NULL AUTO_INCREMENT,
    TipoCuenta    VARCHAR(50)   NOT NULL,
    FechaApertura DATE          NOT NULL,
    FechaCierre   DATE          NULL,
    SaldoActual   DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    EstadoCuenta  VARCHAR(20)   NOT NULL DEFAULT 'ACTIVA',
    ClienteID     INT           NOT NULL,
    SucursalID    INT           NOT NULL,
    PRIMARY KEY (CuentaID),

    CONSTRAINT chk_cuenta_saldo
        CHECK (SaldoActual >= 0),

    CONSTRAINT chk_cuenta_fechas
        CHECK (
            FechaCierre IS NULL
            OR FechaCierre >= FechaApertura
        ),

    CONSTRAINT chk_cuenta_activa
        CHECK (
            EstadoCuenta <> 'ACTIVA'
            OR FechaCierre IS NULL
        ),

    CONSTRAINT fk_cuenta_tipo
        FOREIGN KEY (TipoCuenta)
        REFERENCES TipoCuenta (TipoCuenta)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_cuenta_estado
        FOREIGN KEY (EstadoCuenta)
        REFERENCES EstadoCuenta (EstadoCuenta),

    CONSTRAINT fk_cuenta_cliente
        FOREIGN KEY (ClienteID)
        REFERENCES Cliente (ClienteID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_cuenta_sucursal
        FOREIGN KEY (SucursalID)
        REFERENCES Sucursal (SucursalID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE Movimiento (
    MovimientoID     INT           NOT NULL AUTO_INCREMENT,
    TransferenciaRef VARCHAR(30)   NULL,
    Fecha            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    TipoTransaccion  VARCHAR(30)   NOT NULL,
    Monto            DECIMAL(15,2) NOT NULL,
    Descripcion      VARCHAR(255)  NULL,
    CuentaID         INT           NOT NULL,
    EmpleadoID       INT           NULL,
    PRIMARY KEY (MovimientoID),

    CONSTRAINT uq_movimiento_transferencia
        UNIQUE (TransferenciaRef, TipoTransaccion),

    CONSTRAINT chk_movimiento_monto
        CHECK (Monto > 0),

    CONSTRAINT chk_movimiento_transferencia
        CHECK (
            (
                TipoTransaccion IN ('DEPOSITO', 'RETIRO')
                AND TransferenciaRef IS NULL
            )
            OR
            (
                TipoTransaccion IN (
                    'TRANSFERENCIA_SALIDA',
                    'TRANSFERENCIA_ENTRADA'
                )
                AND TransferenciaRef IS NOT NULL
            )
        ),

    CONSTRAINT fk_movimiento_tipo
        FOREIGN KEY (TipoTransaccion)
        REFERENCES TipoTransaccion (TipoTransaccion),

    CONSTRAINT fk_movimiento_cuenta
        FOREIGN KEY (CuentaID)
        REFERENCES Cuenta (CuentaID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_movimiento_empleado
        FOREIGN KEY (EmpleadoID)
        REFERENCES Empleado (EmpleadoID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;
