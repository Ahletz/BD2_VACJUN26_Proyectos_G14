# Documentación Técnica

## Sistema Bancario — Proyecto Base de Datos II

### 1. Información general

El proyecto implementa una base de datos bancaria normalizada utilizando MySQL 8.4, Python y Docker. El sistema administra clientes, empleados, sucursales, cuentas bancarias y movimientos financieros.

La solución incluye limpieza y migración de datos, procedimientos almacenados, control de concurrencia, usuarios con permisos específicos, respaldos completos e incrementales y restauración de la base de datos.

### 2. Tecnologías utilizadas

* MySQL 8.4
* Docker
* Docker Compose
* Python 3.12
* pandas
* SQLAlchemy
* PyMySQL
* mysqlbinlog
* Bash

### 3. Arquitectura de contenedores

El proyecto utiliza tres contenedores:

| Contenedor        | Función                                                     |
| ----------------- | ----------------------------------------------------------- |
| `bd2_mysql`       | Servidor de base de datos MySQL                             |
| `bd2_python`      | Limpieza, transformación y migración de datos               |
| `bd2_mysql_tools` | Herramientas para respaldos incrementales con `mysqlbinlog` |

Los contenedores se comunican mediante la red:

```text
bd2_network
```

La persistencia de MySQL se realiza con el volumen:

```text
mysql_data
```

### 4. Estructura de la base de datos

La base de datos utilizada es:

```text
banco_db
```

Las tablas implementadas son:

| Tabla             | Descripción                                      |
| ----------------- | ------------------------------------------------ |
| `TipoCuenta`      | Catálogo de tipos de cuenta                      |
| `EstadoCuenta`    | Catálogo de estados de cuenta                    |
| `TipoTransaccion` | Catálogo de operaciones bancarias                |
| `Sucursal`        | Información de las sucursales                    |
| `Cliente`         | Información personal de los clientes             |
| `Empleado`        | Empleados asociados a sucursales                 |
| `Cuenta`          | Cuentas bancarias de los clientes                |
| `Movimiento`      | Historial de depósitos, retiros y transferencias |

### 5. Normalización

Los archivos originales contenían datos distribuidos en archivos CSV relacionados con clientes, cuentas, empleados, sucursales y transacciones.

El modelo fue normalizado hasta Tercera Forma Normal.

#### Primera Forma Normal

Se verificó que:

* Cada columna contenga valores atómicos.
* No existan grupos repetitivos.
* Cada registro pueda identificarse individualmente.

#### Segunda Forma Normal

Se separaron las entidades independientes para evitar que atributos dependieran parcialmente de identificadores compuestos.

Las principales entidades obtenidas fueron:

* Cliente
* Cuenta
* Sucursal
* Empleado
* Movimiento

#### Tercera Forma Normal

Se eliminaron dependencias transitivas creando tablas catálogo para:

* Tipo de cuenta
* Estado de cuenta
* Tipo de transacción

De esta manera, los valores se almacenan una sola vez y se relacionan mediante llaves foráneas.

### 6. Relaciones principales

* Una sucursal puede tener varios empleados.
* Una sucursal puede administrar varias cuentas.
* Un cliente puede tener varias cuentas.
* Una cuenta puede registrar varios movimientos.
* Un empleado puede participar en varios movimientos.
* Cada cuenta pertenece a un tipo y estado.
* Cada movimiento pertenece a un tipo de transacción.

### 7. Restricciones de integridad

Se implementaron las siguientes restricciones:

* Llaves primarias autoincrementales.
* Llaves foráneas entre entidades.
* DNI único por cliente.
* Nombre único por sucursal.
* Saldo de cuenta no negativo.
* Monto de movimiento mayor que cero.
* Fecha de cierre posterior a la fecha de apertura.
* Una cuenta activa no puede tener fecha de cierre.
* Una transferencia debe poseer referencia.
* Los depósitos y retiros no deben poseer referencia de transferencia.
* Una transferencia genera un movimiento de salida y uno de entrada.

### 8. Índices

Se crearon índices para mejorar el rendimiento de búsquedas y reportes:

```text
idx_cliente_nombre
idx_empleado_sucursal_cargo
idx_cuenta_cliente_estado
idx_cuenta_sucursal_estado
idx_movimiento_cuenta_fecha
idx_movimiento_tipo_fecha
```

### 9. Migración de datos

La migración se realiza mediante:

```text
python/migrate.py
```

El proceso ejecuta las siguientes etapas:

1. Lectura de los archivos CSV.
2. Limpieza y estandarización de datos.
3. Transformación a la estructura normalizada.
4. Generación de archivos procesados.
5. Conexión con MySQL.
6. Eliminación de datos anteriores.
7. Carga respetando las llaves foráneas.
8. Validación de cantidades.

Los archivos originales se almacenan en:

```text
data/raw/
```

Los archivos procesados se generan en:

```text
data/processed/
```

Resultado obtenido durante la migración:

| Tabla      | Registros |
| ---------- | --------: |
| Sucursal   |         3 |
| Cliente    |         6 |
| Empleado   |         4 |
| Cuenta     |         6 |
| Movimiento |         6 |

También se generó un archivo con 15 anomalías agrupadas detectadas durante la limpieza.

### 10. Procedimientos almacenados

#### Administración de clientes y cuentas

| Procedimiento          | Función                           |
| ---------------------- | --------------------------------- |
| `SP_RegistrarCliente`  | Registra un cliente nuevo         |
| `SP_ActualizarCliente` | Actualiza los datos de un cliente |
| `SP_AbrirCuenta`       | Crea una cuenta bancaria          |
| `SP_CerrarCuenta`      | Cierra una cuenta con saldo cero  |

#### Operaciones monetarias

| Procedimiento              | Función                                     |
| -------------------------- | ------------------------------------------- |
| `SP_RegistrarDeposito`     | Incrementa el saldo de una cuenta           |
| `SP_RegistrarRetiro`       | Disminuye el saldo validando disponibilidad |
| `SP_RealizarTransferencia` | Traslada fondos entre dos cuentas           |

#### Reportes

| Procedimiento                 | Función                                      |
| ----------------------------- | -------------------------------------------- |
| `SP_ReporteClientesSucursal`  | Muestra clientes y cuentas por sucursal      |
| `SP_ReporteMovimientosCuenta` | Muestra movimientos de una cuenta por fechas |

### 11. Manejo de transacciones

Los procedimientos críticos utilizan:

```sql
START TRANSACTION;
COMMIT;
ROLLBACK;
```

También utilizan manejadores de errores:

```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
```

Esto garantiza que una operación incompleta no modifique parcialmente la información.

En las operaciones concurrentes se utiliza:

```sql
SELECT ... FOR UPDATE;
```

Esto bloquea temporalmente la cuenta mientras se actualiza su saldo.

### 12. Validaciones implementadas

* Cliente existente.
* Sucursal existente.
* Empleado existente.
* Tipo de cuenta válido.
* Cuenta activa.
* Cuenta de origen diferente a cuenta de destino.
* Monto mayor que cero.
* Saldo suficiente.
* Cuenta con saldo cero antes del cierre.
* DNI no duplicado.
* Fechas válidas.
* Referencias de transferencia únicas.

### 13. Seguridad y permisos

Se crearon tres usuarios:

#### Usuario cajero

Puede ejecutar:

* Apertura de cuentas.
* Depósitos.
* Retiros.
* Transferencias.
* Reporte de movimientos.

No puede consultar directamente las tablas.

#### Usuario gerente

Puede ejecutar:

* Registro de clientes.
* Actualización de clientes.
* Apertura y cierre de cuentas.
* Reportes de clientes.
* Reportes de movimientos.

No puede ejecutar depósitos, retiros ni transferencias.

#### Usuario administrador

Posee todos los privilegios sobre:

```text
banco_db
```

### 14. Pruebas funcionales

Se probaron correctamente los nueve procedimientos almacenados.

Durante las pruebas se validó:

* Creación de clientes.
* Actualización de información.
* Apertura de cuentas.
* Depósitos.
* Retiros.
* Transferencias.
* Cierre de cuentas.
* Reportes por sucursal.
* Reportes de movimientos.

También se incluyeron pruebas de error para:

* DNI duplicado.
* Monto negativo.
* Saldo insuficiente.
* Transferencia hacia la misma cuenta.
* Cierre de una cuenta con saldo.

### 15. Prueba de concurrencia

La prueba se realizó mediante dos sesiones activas sobre la misma cuenta.

La cuenta inició con un saldo de:

```text
Q1,000.00
```

La sesión A bloqueó la cuenta y retiró:

```text
Q700.00
```

La sesión B esperó la liberación del bloqueo. Después de actualizarse el saldo a Q300.00, la segunda sesión rechazó el retiro por saldo insuficiente.

Resultado:

```text
Saldo inicial: Q1,000.00
Retiro sesión A: Q700.00
Retiro sesión B: rechazado
Saldo final: Q300.00
```

La prueba demuestra que el bloqueo evita sobregiros y pérdida de consistencia.

### 16. Respaldos

#### Respaldo completo

El respaldo completo se genera con:

```text
db/backups/01_full_backup.sh
```

Incluye:

* Base de datos.
* Tablas.
* Datos.
* Procedimientos almacenados.
* Triggers.
* Eventos.

#### Respaldos incrementales

Los respaldos incrementales se generan con:

```text
db/backups/02_incremental_backup.sh
```

El mecanismo utiliza los registros binarios de MySQL.

Se generaron tres respaldos incrementales correspondientes a diferentes operaciones realizadas después del respaldo completo.

#### Restauración

La restauración se realiza con:

```text
db/backups/03_restore_backup.sh
```

El procedimiento:

1. Elimina la base actual.
2. Restaura el respaldo completo.
3. Aplica los respaldos incrementales en orden.
4. Recupera las operaciones posteriores.

La restauración fue validada verificando los movimientos y saldos recuperados.

### 17. Orden de ejecución

```text
1. db/ddl/01_create_database.sql
2. db/ddl/02_create_tables.sql
3. db/ddl/03_create_indexes.sql
4. db/dml/01_insert_catalogs.sql
5. python/migrate.py
6. db/procedures/01_procedures_part_1.sql
7. db/procedures/02_procedures_part_2.sql
8. db/procedures/03_procedures_part_3.sql
9. db/users_permissions/01_create_users_and_grants.sql
10. db/tests/01_functional_tests.sql
11. db/tests/02_concurrency_session_a.sql
12. db/tests/03_concurrency_session_b.sql
```

### 18. Conclusión

La solución implementada permite administrar operaciones bancarias manteniendo integridad, consistencia y seguridad.

La utilización de transacciones, bloqueos, restricciones, procedimientos almacenados, respaldos y usuarios con permisos limitados permite proteger la información y reducir errores durante las operaciones financieras.
