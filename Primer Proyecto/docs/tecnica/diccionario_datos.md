# Diccionario de Datos

## Sistema Bancario — Proyecto Base de Datos II

## 1. Tabla `TipoCuenta`

Almacena los tipos de cuenta permitidos en el sistema.

| Campo        | Tipo          | Nulo | Llave | Descripción                      |
| ------------ | ------------- | ---: | ----- | -------------------------------- |
| `TipoCuenta` | `VARCHAR(50)` |   No | PK    | Nombre único del tipo de cuenta. |

Valores iniciales:

* Ahorro
* Corriente

---

## 2. Tabla `EstadoCuenta`

Almacena los estados disponibles para una cuenta bancaria.

| Campo          | Tipo          | Nulo | Llave | Descripción                 |
| -------------- | ------------- | ---: | ----- | --------------------------- |
| `EstadoCuenta` | `VARCHAR(20)` |   No | PK    | Estado actual de la cuenta. |

Valores iniciales:

* ACTIVA
* INACTIVA
* CERRADA

---

## 3. Tabla `TipoTransaccion`

Almacena los tipos de movimientos financieros permitidos.

| Campo             | Tipo          | Nulo | Llave | Descripción                   |
| ----------------- | ------------- | ---: | ----- | ----------------------------- |
| `TipoTransaccion` | `VARCHAR(30)` |   No | PK    | Tipo de operación registrada. |

Valores iniciales:

* DEPOSITO
* RETIRO
* TRANSFERENCIA_SALIDA
* TRANSFERENCIA_ENTRADA

---

## 4. Tabla `Sucursal`

Almacena la información de las sucursales bancarias.

| Campo               | Tipo           | Nulo | Llave | Descripción                                         |
| ------------------- | -------------- | ---: | ----- | --------------------------------------------------- |
| `SucursalID`        | `INT`          |   No | PK    | Identificador único autoincremental de la sucursal. |
| `SucursalNombre`    | `VARCHAR(100)` |   No | UQ    | Nombre único de la sucursal.                        |
| `SucursalDireccion` | `VARCHAR(200)` |   No |       | Dirección física de la sucursal.                    |
| `SucursalTelefono`  | `VARCHAR(20)`  |   No |       | Número telefónico de la sucursal.                   |

Restricciones:

* `SucursalID` es autoincremental.
* `SucursalNombre` no puede repetirse.

---

## 5. Tabla `Cliente`

Almacena la información personal de los clientes.

| Campo                    | Tipo           | Nulo | Llave | Descripción                                      |
| ------------------------ | -------------- | ---: | ----- | ------------------------------------------------ |
| `ClienteID`              | `INT`          |   No | PK    | Identificador único autoincremental del cliente. |
| `ClienteDNI`             | `VARCHAR(20)`  |   No | UQ    | Documento de identificación único del cliente.   |
| `ClienteNombre`          | `VARCHAR(150)` |   No |       | Nombre completo del cliente.                     |
| `ClienteFechaNacimiento` | `DATE`         |   No |       | Fecha de nacimiento del cliente.                 |
| `ClienteDireccion`       | `VARCHAR(200)` |   No |       | Dirección de residencia.                         |
| `ClienteTelefono`        | `VARCHAR(20)`  |   No |       | Número telefónico del cliente.                   |
| `ClienteCorreo`          | `VARCHAR(150)` |   Sí |       | Correo electrónico del cliente.                  |

Restricciones:

* `ClienteID` es autoincremental.
* `ClienteDNI` debe ser único.
* La fecha de nacimiento debe ser anterior a la fecha actual.

---

## 6. Tabla `Empleado`

Almacena los empleados asociados a las sucursales.

| Campo            | Tipo           | Nulo | Llave | Descripción                                       |
| ---------------- | -------------- | ---: | ----- | ------------------------------------------------- |
| `EmpleadoID`     | `INT`          |   No | PK    | Identificador único autoincremental del empleado. |
| `EmpleadoNombre` | `VARCHAR(150)` |   No |       | Nombre completo del empleado.                     |
| `EmpleadoCargo`  | `VARCHAR(100)` |   No |       | Cargo que desempeña el empleado.                  |
| `SucursalID`     | `INT`          |   No | FK    | Sucursal donde trabaja el empleado.               |

Relación:

```text
Empleado.SucursalID → Sucursal.SucursalID
```

Regla de integridad:

* No se puede registrar un empleado en una sucursal inexistente.
* No se puede eliminar una sucursal que tenga empleados asociados.

---

## 7. Tabla `Cuenta`

Almacena las cuentas bancarias pertenecientes a los clientes.

| Campo           | Tipo            | Nulo | Llave | Descripción                                       |
| --------------- | --------------- | ---: | ----- | ------------------------------------------------- |
| `CuentaID`      | `INT`           |   No | PK    | Identificador único autoincremental de la cuenta. |
| `TipoCuenta`    | `VARCHAR(50)`   |   No | FK    | Tipo de cuenta bancaria.                          |
| `FechaApertura` | `DATE`          |   No |       | Fecha en la que se abrió la cuenta.               |
| `FechaCierre`   | `DATE`          |   Sí |       | Fecha en la que se cerró la cuenta.               |
| `SaldoActual`   | `DECIMAL(15,2)` |   No |       | Saldo disponible en la cuenta.                    |
| `EstadoCuenta`  | `VARCHAR(20)`   |   No | FK    | Estado actual de la cuenta.                       |
| `ClienteID`     | `INT`           |   No | FK    | Cliente propietario de la cuenta.                 |
| `SucursalID`    | `INT`           |   No | FK    | Sucursal donde se abrió la cuenta.                |

Relaciones:

```text
Cuenta.TipoCuenta → TipoCuenta.TipoCuenta
Cuenta.EstadoCuenta → EstadoCuenta.EstadoCuenta
Cuenta.ClienteID → Cliente.ClienteID
Cuenta.SucursalID → Sucursal.SucursalID
```

Valores predeterminados:

| Campo          | Valor    |
| -------------- | -------- |
| `SaldoActual`  | `0.00`   |
| `EstadoCuenta` | `ACTIVA` |
| `FechaCierre`  | `NULL`   |

Restricciones:

* El saldo no puede ser negativo.
* La fecha de cierre no puede ser anterior a la fecha de apertura.
* Una cuenta activa no puede tener fecha de cierre.
* El cliente debe existir.
* La sucursal debe existir.
* El tipo de cuenta debe existir.
* El estado de la cuenta debe existir.

---

## 8. Tabla `Movimiento`

Almacena los depósitos, retiros y transferencias realizadas sobre las cuentas.

| Campo              | Tipo            | Nulo | Llave      | Descripción                                                                    |
| ------------------ | --------------- | ---: | ---------- | ------------------------------------------------------------------------------ |
| `MovimientoID`     | `INT`           |   No | PK         | Identificador único autoincremental del movimiento.                            |
| `TransferenciaRef` | `VARCHAR(30)`   |   Sí | UQ parcial | Referencia utilizada para relacionar los dos movimientos de una transferencia. |
| `Fecha`            | `DATETIME`      |   No |            | Fecha y hora del movimiento.                                                   |
| `TipoTransaccion`  | `VARCHAR(30)`   |   No | FK         | Tipo de operación financiera.                                                  |
| `Monto`            | `DECIMAL(15,2)` |   No |            | Monto involucrado en la operación.                                             |
| `Descripcion`      | `VARCHAR(255)`  |   Sí |            | Descripción adicional del movimiento.                                          |
| `CuentaID`         | `INT`           |   No | FK         | Cuenta afectada por el movimiento.                                             |
| `EmpleadoID`       | `INT`           |   Sí | FK         | Empleado que registró la operación.                                            |

Relaciones:

```text
Movimiento.TipoTransaccion → TipoTransaccion.TipoTransaccion
Movimiento.CuentaID → Cuenta.CuentaID
Movimiento.EmpleadoID → Empleado.EmpleadoID
```

Valor predeterminado:

| Campo   | Valor               |
| ------- | ------------------- |
| `Fecha` | `CURRENT_TIMESTAMP` |

Restricciones:

* El monto debe ser mayor que cero.
* La cuenta debe existir.
* El tipo de transacción debe existir.
* El empleado debe existir cuando se proporcione.
* Los depósitos y retiros no utilizan referencia de transferencia.
* Las transferencias de entrada y salida requieren una referencia.
* Una misma referencia no puede repetir el mismo tipo de movimiento.

---

## 9. Relaciones del modelo

| Tabla origen | Campo             | Tabla destino     | Campo             | Cardinalidad |
| ------------ | ----------------- | ----------------- | ----------------- | ------------ |
| `Empleado`   | `SucursalID`      | `Sucursal`        | `SucursalID`      | Muchos a uno |
| `Cuenta`     | `ClienteID`       | `Cliente`         | `ClienteID`       | Muchos a uno |
| `Cuenta`     | `SucursalID`      | `Sucursal`        | `SucursalID`      | Muchos a uno |
| `Cuenta`     | `TipoCuenta`      | `TipoCuenta`      | `TipoCuenta`      | Muchos a uno |
| `Cuenta`     | `EstadoCuenta`    | `EstadoCuenta`    | `EstadoCuenta`    | Muchos a uno |
| `Movimiento` | `CuentaID`        | `Cuenta`          | `CuentaID`        | Muchos a uno |
| `Movimiento` | `EmpleadoID`      | `Empleado`        | `EmpleadoID`      | Muchos a uno |
| `Movimiento` | `TipoTransaccion` | `TipoTransaccion` | `TipoTransaccion` | Muchos a uno |

## 10. Índices

| Índice                        | Tabla        | Campos                        | Propósito                                        |
| ----------------------------- | ------------ | ----------------------------- | ------------------------------------------------ |
| `idx_cliente_nombre`          | `Cliente`    | `ClienteNombre`               | Buscar clientes por nombre.                      |
| `idx_empleado_sucursal_cargo` | `Empleado`   | `SucursalID`, `EmpleadoCargo` | Consultar empleados por sucursal y cargo.        |
| `idx_cuenta_cliente_estado`   | `Cuenta`     | `ClienteID`, `EstadoCuenta`   | Consultar cuentas de un cliente según su estado. |
| `idx_cuenta_sucursal_estado`  | `Cuenta`     | `SucursalID`, `EstadoCuenta`  | Generar reportes de cuentas por sucursal.        |
| `idx_movimiento_cuenta_fecha` | `Movimiento` | `CuentaID`, `Fecha`           | Consultar movimientos de una cuenta por fecha.   |
| `idx_movimiento_tipo_fecha`   | `Movimiento` | `TipoTransaccion`, `Fecha`    | Consultar movimientos según su tipo y fecha.     |

## 11. Abreviaturas

| Abreviatura | Significado                      |
| ----------- | -------------------------------- |
| PK          | Llave primaria                   |
| FK          | Llave foránea                    |
| UQ          | Restricción única                |
| NULL        | Campo que puede permanecer vacío |
| AI          | Valor autoincremental            |
