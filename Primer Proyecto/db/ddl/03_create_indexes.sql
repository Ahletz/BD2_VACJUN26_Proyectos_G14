USE banco_db;

CREATE INDEX idx_mov_cuenta_fecha  ON Movimiento(CuentaID, Fecha);
CREATE INDEX idx_mov_transferencia ON Movimiento(TransferenciaRef);