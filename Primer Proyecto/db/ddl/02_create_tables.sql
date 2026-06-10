USE banco_db;

CREATE TABLE IF NOT EXISTS Sucursal (
  SucursalID        INT          NOT NULL AUTO_INCREMENT,
  SucursalNombre    VARCHAR(100) NOT NULL,
  SucursalDireccion VARCHAR(200) NOT NULL,
  SucursalTelefono  VARCHAR(20)  NOT NULL,
  PRIMARY KEY (SucursalID),
  UNIQUE KEY uq_sucursal_nombre (SucursalNombre)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Cliente (
  ClienteID              INT          NOT NULL AUTO_INCREMENT,
  ClienteDNI             VARCHAR(20)  NOT NULL,
  ClienteNombre          VARCHAR(150) NOT NULL,
  ClienteFechaNacimiento DATE         NOT NULL,
  ClienteDireccion       VARCHAR(200) NOT NULL,
  ClienteTelefono        VARCHAR(20)  NOT NULL,
  ClienteCorreo          VARCHAR(150) NULL,
  PRIMARY KEY (ClienteID),
  UNIQUE KEY uq_cliente_dni (ClienteDNI)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Empleado (
  EmpleadoID     INT          NOT NULL AUTO_INCREMENT,
  EmpleadoNombre VARCHAR(150) NOT NULL,
  EmpleadoCargo  VARCHAR(100) NOT NULL,
  SucursalID     INT          NOT NULL,
  PRIMARY KEY (EmpleadoID),
  CONSTRAINT fk_empleado_sucursal
    FOREIGN KEY (SucursalID) REFERENCES Sucursal(SucursalID)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Cuenta (
  CuentaID      INT           NOT NULL AUTO_INCREMENT,
  TipoCuenta    VARCHAR(50)   NOT NULL,
  FechaApertura DATE          NOT NULL,
  FechaCierre   DATE          NULL DEFAULT NULL,
  SaldoActual   DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  EstadoCuenta  VARCHAR(20)   NOT NULL DEFAULT 'ACTIVA',
  ClienteID     INT           NOT NULL,
  SucursalID    INT           NOT NULL,
  PRIMARY KEY (CuentaID),
  CONSTRAINT chk_saldo_no_negativo
    CHECK (SaldoActual >= 0),
  CONSTRAINT chk_estado_cuenta
    CHECK (EstadoCuenta IN ('ACTIVA', 'INACTIVA')),
  CONSTRAINT chk_tipo_cuenta
    CHECK (TipoCuenta IN ('Ahorro', 'Corriente')),
  CONSTRAINT chk_fecha_cierre
    CHECK (FechaCierre IS NULL OR FechaCierre >= FechaApertura),
  CONSTRAINT chk_estado_fecha_cierre
    CHECK (
      (EstadoCuenta = 'ACTIVA'   AND FechaCierre IS NULL) OR
      (EstadoCuenta = 'INACTIVA' AND FechaCierre IS NOT NULL) OR
      (EstadoCuenta = 'INACTIVA' AND FechaCierre IS NULL)
    ),
  CONSTRAINT fk_cuenta_cliente
    FOREIGN KEY (ClienteID)  REFERENCES Cliente(ClienteID)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_cuenta_sucursal
    FOREIGN KEY (SucursalID) REFERENCES Sucursal(SucursalID)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Movimiento (
  MovimientoID     INT           NOT NULL AUTO_INCREMENT,
  Fecha            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  TipoTransaccion  VARCHAR(30)   NOT NULL,
  Monto            DECIMAL(15,2) NOT NULL,
  Descripcion      VARCHAR(255)  NULL,
  TransferenciaRef VARCHAR(20)   NULL DEFAULT NULL,
  CuentaID         INT           NOT NULL,
  EmpleadoID       INT           NULL,
  PRIMARY KEY (MovimientoID),
  CONSTRAINT chk_monto_positivo
    CHECK (Monto > 0),
  CONSTRAINT chk_tipo_transaccion
    CHECK (TipoTransaccion IN (
      'DEPOSITO', 'RETIRO',
      'TRANSFERENCIA_SALIDA', 'TRANSFERENCIA_ENTRADA'
    )),
  CONSTRAINT chk_transferencia_ref
    CHECK (
      (TipoTransaccion IN ('DEPOSITO', 'RETIRO') AND TransferenciaRef IS NULL) OR
      (TipoTransaccion IN ('TRANSFERENCIA_SALIDA', 'TRANSFERENCIA_ENTRADA') AND TransferenciaRef IS NOT NULL)
    ),
  CONSTRAINT chk_empleado_operativo
    CHECK (
      (TipoTransaccion IN ('DEPOSITO', 'RETIRO') AND EmpleadoID IS NOT NULL) OR
      (TipoTransaccion IN ('TRANSFERENCIA_SALIDA', 'TRANSFERENCIA_ENTRADA'))
    ),
  CONSTRAINT fk_mov_cuenta
    FOREIGN KEY (CuentaID)   REFERENCES Cuenta(CuentaID)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_mov_empleado
    FOREIGN KEY (EmpleadoID) REFERENCES Empleado(EmpleadoID)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;