USE banco_db;

DROP USER IF EXISTS 'cajero'@'%';
DROP USER IF EXISTS 'gerente'@'%';
DROP USER IF EXISTS 'admin'@'%';

CREATE USER 'cajero'@'%'
IDENTIFIED BY 'Cajero#2026';

CREATE USER 'gerente'@'%'
IDENTIFIED BY 'Gerente#2026';

CREATE USER 'admin'@'%'
IDENTIFIED BY 'Admin#2026';

-- Permisos del cajero
GRANT EXECUTE ON PROCEDURE banco_db.SP_AbrirCuenta
TO 'cajero'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_RegistrarDeposito
TO 'cajero'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_RegistrarRetiro
TO 'cajero'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_RealizarTransferencia
TO 'cajero'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_ReporteMovimientosCuenta
TO 'cajero'@'%';

-- Permisos del gerente
GRANT EXECUTE ON PROCEDURE banco_db.SP_RegistrarCliente
TO 'gerente'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_ActualizarCliente
TO 'gerente'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_AbrirCuenta
TO 'gerente'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_CerrarCuenta
TO 'gerente'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_ReporteClientesSucursal
TO 'gerente'@'%';

GRANT EXECUTE ON PROCEDURE banco_db.SP_ReporteMovimientosCuenta
TO 'gerente'@'%';

-- Permisos del administrador
GRANT ALL PRIVILEGES ON banco_db.*
TO 'admin'@'%'
WITH GRANT OPTION;

FLUSH PRIVILEGES;

SHOW GRANTS FOR 'cajero'@'%';
SHOW GRANTS FOR 'gerente'@'%';
SHOW GRANTS FOR 'admin'@'%';
