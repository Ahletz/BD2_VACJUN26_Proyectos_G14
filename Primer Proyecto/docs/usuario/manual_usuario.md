# Manual de Usuario

## Sistema Bancario — Proyecto Base de Datos II

### 1. Objetivo

Este manual explica cómo iniciar el sistema, ejecutar los procedimientos almacenados, realizar pruebas, generar respaldos y restaurar la base de datos.

### 2. Requisitos

* Docker instalado.
* Docker Compose instalado.
* Terminal de Linux.
* Archivos CSV dentro de `data/raw/`.
* Archivo `.env` configurado.

### 3. Iniciar el sistema

Desde la raíz del proyecto ejecutar:

```bash
docker compose up -d --build
```

Verificar los contenedores:

```bash
docker ps
```

Deben estar activos:

```text
bd2_mysql
bd2_python
bd2_mysql_tools
```

### 4. Acceder a MySQL

Como usuario administrador raíz:

```bash
docker exec -it bd2_mysql mysql -uroot -p
```

Seleccionar la base:

```sql
USE banco_db;
```

### 5. Crear la base de datos

Ejecutar desde la raíz del proyecto:

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/ddl/01_create_database.sql
```

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/ddl/02_create_tables.sql
```

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/ddl/03_create_indexes.sql
```

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/dml/01_insert_catalogs.sql
```

### 6. Migrar los datos

Ejecutar:

```bash
docker compose exec python python migrate.py
```

El proceso limpia, transforma, carga y valida los archivos CSV.

### 7. Crear procedimientos almacenados

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/procedures/01_procedures_part_1.sql
```

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/procedures/02_procedures_part_2.sql
```

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/procedures/03_procedures_part_3.sql
```

### 8. Crear usuarios y permisos

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/users_permissions/01_create_users_and_grants.sql
```

Usuarios disponibles:

| Usuario | Contraseña     | Función                      |
| ------- | -------------- | ---------------------------- |
| cajero  | `Cajero#2026`  | Operaciones bancarias        |
| gerente | `Gerente#2026` | Clientes, cuentas y reportes |
| admin   | `Admin#2026`   | Administración completa      |

### 9. Procedimientos almacenados

## Registrar cliente

```sql
SET @ClienteID = NULL;

CALL SP_RegistrarCliente(
    '10010',
    'Carlos Pérez',
    '1990-01-15',
    'Zona 1, Guatemala',
    '55550000',
    'carlos@mail.com',
    @ClienteID
);

SELECT @ClienteID;
```

## Actualizar cliente

```sql
CALL SP_ActualizarCliente(
    1,
    '10001',
    'José Morales Actualizado',
    '1985-05-20',
    'Zona 10, Guatemala',
    '55551111',
    'jose.actualizado@mail.com'
);
```

## Abrir cuenta

```sql
SET @CuentaID = NULL;

CALL SP_AbrirCuenta(
    1,
    1,
    'Ahorro',
    1000.00,
    @CuentaID
);

SELECT @CuentaID;
```

## Registrar depósito

```sql
SET @MovimientoID = NULL;

CALL SP_RegistrarDeposito(
    1001,
    500.00,
    'Depósito en efectivo',
    NULL,
    @MovimientoID
);

SELECT @MovimientoID;
```

## Registrar retiro

```sql
SET @MovimientoID = NULL;

CALL SP_RegistrarRetiro(
    1001,
    100.00,
    'Retiro en ventanilla',
    NULL,
    @MovimientoID
);

SELECT @MovimientoID;
```

## Realizar transferencia

```sql
SET @TransferenciaRef = NULL;

CALL SP_RealizarTransferencia(
    1001,
    1002,
    200.00,
    'Transferencia entre cuentas',
    NULL,
    @TransferenciaRef
);

SELECT @TransferenciaRef;
```

## Cerrar cuenta

La cuenta debe tener saldo cero.

```sql
CALL SP_CerrarCuenta(1005);
```

## Reporte de clientes por sucursal

```sql
CALL SP_ReporteClientesSucursal(1);
```

## Reporte de movimientos

```sql
CALL SP_ReporteMovimientosCuenta(
    1001,
    '2026-01-01 00:00:00',
    '2026-12-31 23:59:59'
);
```

Para consultar todos los movimientos sin filtrar fechas:

```sql
CALL SP_ReporteMovimientosCuenta(
    1001,
    NULL,
    NULL
);
```

### 10. Ejecutar pruebas funcionales

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/tests/01_functional_tests.sql
```

### 11. Ejecutar pruebas de concurrencia

Desde una terminal:

```bash
docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/tests/02_concurrency_session_a.sql > /tmp/sesion_a.txt 2>&1 &

sleep 2

docker exec -i bd2_mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' \
< db/tests/03_concurrency_session_b.sql > /tmp/sesion_b.txt 2>&1

wait

echo "===== SESIÓN A ====="
cat /tmp/sesion_a.txt

echo "===== SESIÓN B ====="
cat /tmp/sesion_b.txt
```

### 12. Generar respaldo completo

```bash
./db/backups/01_full_backup.sh
```

El archivo se guarda en:

```text
db/backups/full_backup_FECHA.sql
```

### 13. Generar respaldo incremental

Primera ejecución:

```bash
./db/backups/02_incremental_backup.sh
```

Esta ejecución registra la posición inicial.

Después de realizar cambios:

```bash
./db/backups/02_incremental_backup.sh
```

El archivo se guarda como:

```text
db/backups/incremental_backup_FECHA.sql.gz
```

### 14. Restaurar la base de datos

Restaurar respaldo completo:

```bash
./db/backups/03_restore_backup.sh \
db/backups/full_backup_FECHA.sql
```

Restaurar respaldo completo e incrementales:

```bash
./db/backups/03_restore_backup.sh \
db/backups/full_backup_FECHA.sql \
db/backups/incremental_backup_1.sql.gz \
db/backups/incremental_backup_2.sql.gz \
db/backups/incremental_backup_3.sql.gz
```

Los incrementales deben aplicarse en orden cronológico.

### 15. Acceso con usuarios

## Cajero

```bash
docker exec -it bd2_mysql mysql \
-h127.0.0.1 \
-ucajero \
-p \
banco_db
```

## Gerente

```bash
docker exec -it bd2_mysql mysql \
-h127.0.0.1 \
-ugerente \
-p \
banco_db
```

## Administrador

```bash
docker exec -it bd2_mysql mysql \
-h127.0.0.1 \
-uadmin \
-p \
banco_db
```

### 16. Consultas de verificación

Consultar cuentas:

```sql
SELECT * FROM Cuenta;
```

Consultar movimientos:

```sql
SELECT * FROM Movimiento
ORDER BY Fecha DESC;
```

Consultar clientes:

```sql
SELECT * FROM Cliente;
```

Consultar procedimientos:

```sql
SHOW PROCEDURE STATUS
WHERE Db = 'banco_db';
```

Consultar usuarios:

```sql
SELECT User, Host
FROM mysql.user;
```

### 17. Detener el sistema

```bash
docker compose down
```

### 18. Eliminar contenedores y datos

```bash
docker compose down -v
```

Este comando elimina también el volumen de MySQL.

### 19. Recomendaciones

* No compartir el archivo `.env`.
* No eliminar respaldos sin verificar su contenido.
* Aplicar los respaldos incrementales en orden.
* No ejecutar retiros o transferencias sin validar el saldo.
* Utilizar el usuario correspondiente según la operación.
* Realizar un respaldo antes de modificar la estructura de la base.
