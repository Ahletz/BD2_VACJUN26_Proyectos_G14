USE banco_db;

CREATE INDEX idx_cliente_nombre
    ON Cliente (ClienteNombre);

CREATE INDEX idx_empleado_sucursal_cargo
    ON Empleado (SucursalID, EmpleadoCargo);

CREATE INDEX idx_cuenta_cliente_estado
    ON Cuenta (ClienteID, EstadoCuenta);

CREATE INDEX idx_cuenta_sucursal_estado
    ON Cuenta (SucursalID, EstadoCuenta);

CREATE INDEX idx_movimiento_cuenta_fecha
    ON Movimiento (CuentaID, Fecha);

CREATE INDEX idx_movimiento_tipo_fecha
    ON Movimiento (TipoTransaccion, Fecha);
