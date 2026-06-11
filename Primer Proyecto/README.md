# Proyecto de Base de Datos II – Sistema Bancario

## Grupo 14

Proyecto desarrollado con MySQL 8.4, Python y Docker. El sistema permite administrar clientes, cuentas, sucursales, empleados y movimientos bancarios.

## Tecnologías utilizadas

* Docker
* Docker Compose
* MySQL 8.4
* Python 3
* pandas
* SQLAlchemy
* PyMySQL

## Estructura del proyecto

```text
Primer Proyecto/
├── data/
│   ├── raw/
│   └── processed/
├── db/
│   ├── backups/
│   ├── ddl/
│   ├── dml/
│   ├── procedures/
│   ├── tests/
│   └── users_permissions/
├── diagrams/
├── docs/
├── python/
├── docker-compose.yml
├── .env
├── .env.example
└── README.md
```

## Archivos de datos

Los archivos CSV originales deben colocarse dentro de:

```text
data/raw/
```

Archivos requeridos:

```text
clientes_raw.csv
cuentas_raw.csv
empleados_raw.csv
sucursales_raw.csv
transacciones_raw.csv
```

## Configuración

Crear el archivo `.env` tomando como referencia `.env.example`.

Ejemplo:

```env
MYSQL_ROOT_PASSWORD=root123
MYSQL_DATABASE=banco_db
MYSQL_USER=bd2_user
MYSQL_PASSWORD=bd2_password
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_HOST_PORT=3306
```

## Levantar los contenedores

Desde la raíz del proyecto:

```bash
docker compose up -d --build
```

Verificar los contenedores:

```bash
docker ps
```

## Crear la base de datos

Ejecutar los scripts en el siguiente orden:

```bash
docker exec -i bd2_mysql mysql -uroot -p < db/ddl/01_create_database.sql
docker exec -i bd2_mysql mysql -uroot -p < db/ddl/02_create_tables.sql
docker exec -i bd2_mysql mysql -uroot -p < db/ddl/03_create_indexes.sql
docker exec -i bd2_mysql mysql -uroot -p < db/dml/01_insert_catalogs.sql
```

El sistema solicitará la contraseña del usuario `root`.

También puede utilizarse:

```bash
docker exec -i bd2_mysql mysql \
    -uroot \
    -p"${MYSQL_ROOT_PASSWORD}" \
    < db/ddl/01_create_database.sql
```

## Migración de datos

Ejecutar:

```bash
docker compose exec python python migrate.py
```

El proceso realiza:

1. Lectura de archivos CSV.
2. Limpieza de datos.
3. Transformación.
4. Carga en MySQL.
5. Validación de registros.

Los archivos procesados se almacenan en:

```text
data/processed/
```

## Crear procedimientos almacenados

Ejecutar:

```bash
docker exec -i bd2_mysql mysql -uroot -p < db/procedures/01_procedures_part_1.sql
docker exec -i bd2_mysql mysql -uroot -p < db/procedures/02_procedures_part_2.sql
docker exec -i bd2_mysql mysql -uroot -p < db/procedures/03_procedures_part_3.sql
```

## Procedimientos disponibles

* `SP_RegistrarCliente`
* `SP_ActualizarCliente`
* `SP_AbrirCuenta`
* `SP_RegistrarDeposito`
* `SP_RegistrarRetiro`
* `SP_RealizarTransferencia`
* `SP_CerrarCuenta`
* `SP_ReporteClientesSucursal`
* `SP_ReporteMovimientosCuenta`

## Crear usuarios y permisos

Ejecutar:

```bash
docker exec -i bd2_mysql mysql -uroot -p < db/users_permissions/01_create_users_and_grants.sql
```

Usuarios creados:

| Usuario | Función                   |
| ------- | ------------------------- |
| cajero  | Operaciones bancarias     |
| gerente | Administración y reportes |
| admin   | Administración completa   |

## Ejecutar pruebas funcionales

```bash
docker exec -i bd2_mysql mysql -uroot -p < db/tests/01_functional_tests.sql
```

## Pruebas de concurrencia

Abrir dos terminales.

### Sesión A

```bash
docker exec -i bd2_mysql mysql -uroot -p < db/tests/02_concurrency_session_a.sql
```

### Sesión B

Ejecutar durante la espera de la sesión A:

```bash
docker exec -i bd2_mysql mysql -uroot -p < db/tests/03_concurrency_session_b.sql
```

## Respaldo completo

Dar permisos de ejecución:

```bash
chmod +x db/backups/01_full_backup.sh
```

Ejecutar:

```bash
./db/backups/01_full_backup.sh
```

## Respaldo incremental

Dar permisos:

```bash
chmod +x db/backups/02_incremental_backup.sh
```

Primera ejecución para registrar la posición inicial:

```bash
./db/backups/02_incremental_backup.sh
```

Después de realizar operaciones en la base:

```bash
./db/backups/02_incremental_backup.sh
```

## Restauración

Dar permisos:

```bash
chmod +x db/backups/03_restore_backup.sh
```

Restaurar solamente el respaldo completo:

```bash
./db/backups/03_restore_backup.sh \
db/backups/full_backup_FECHA.sql
```

Restaurar respaldo completo e incrementales:

```bash
./db/backups/03_restore_backup.sh \
db/backups/full_backup_FECHA.sql \
db/backups/incremental_backup_1.sql.gz \
db/backups/incremental_backup_2.sql.gz
```

## Acceso directo a MySQL

Como usuario root:

```bash
docker exec -it bd2_mysql mysql -uroot -p
```

Como usuario del proyecto:

```bash
docker exec -it bd2_mysql mysql -ubd2_user -p banco_db
```

## Apagar los contenedores

```bash
docker compose down
```

## Eliminar contenedores y datos persistentes

```bash
docker compose down -v
```

Este comando elimina también el volumen de la base de datos.
