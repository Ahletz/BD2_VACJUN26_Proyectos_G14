# Proceso de Normalización de la Base de Datos

## Sistema Bancario — Proyecto Base de Datos II

## 1. Introducción

Los datos originales del proyecto se encuentran distribuidos en archivos CSV correspondientes a clientes, cuentas, empleados, sucursales y transacciones. Aunque los archivos presentan una separación inicial de la información, fue necesario revisar su estructura para identificar redundancias, inconsistencias y dependencias entre los atributos.

El proceso de normalización permitió diseñar una base de datos relacional en MySQL que mantiene la integridad de los datos y reduce las anomalías de inserción, actualización y eliminación.

El modelo final fue normalizado hasta la Tercera Forma Normal.

---

## 2. Archivos de origen

Los archivos utilizados como fuente fueron:

```text
clientes_raw.csv
cuentas_raw.csv
empleados_raw.csv
sucursales_raw.csv
transacciones_raw.csv
```

Estos archivos contienen información relacionada con:

* Datos personales de clientes.
* Cuentas bancarias.
* Saldos y estados de cuenta.
* Sucursales.
* Empleados.
* Depósitos, retiros y transferencias.

Durante el proceso de limpieza se detectaron valores duplicados, diferencias en formatos de texto, fechas, teléfonos, correos electrónicos y otros datos que debían ser estandarizados antes de cargarse en la base de datos.

---

## 3. Modelo no normalizado

Antes de definir el modelo relacional, la información podía representarse conceptualmente mediante una estructura general como la siguiente:

```text
REGISTRO_BANCARIO(
    ClienteID,
    ClienteDNI,
    ClienteNombre,
    ClienteFechaNacimiento,
    ClienteDireccion,
    ClienteTelefono,
    ClienteCorreo,
    CuentaID,
    TipoCuenta,
    FechaApertura,
    FechaCierre,
    SaldoActual,
    EstadoCuenta,
    SucursalID,
    SucursalNombre,
    SucursalDireccion,
    SucursalTelefono,
    EmpleadoID,
    EmpleadoNombre,
    EmpleadoCargo,
    MovimientoID,
    TransferenciaRef,
    FechaMovimiento,
    TipoTransaccion,
    Monto,
    Descripcion
)
```

En esta estructura se presentan diferentes entidades dentro de un mismo conjunto de datos.

Por ejemplo:

* Los datos de un cliente se repetirían por cada cuenta.
* Los datos de una sucursal se repetirían por cada cliente, empleado o cuenta.
* Los datos de una cuenta se repetirían por cada movimiento.
* Los tipos de cuenta, estados y transacciones se almacenarían repetidamente.

Esta situación produciría redundancia y dificultaría el mantenimiento de la información.

---

## 4. Dependencias funcionales identificadas

Las principales dependencias funcionales encontradas fueron las siguientes:

### Cliente

```text
ClienteID → ClienteDNI
ClienteID → ClienteNombre
ClienteID → ClienteFechaNacimiento
ClienteID → ClienteDireccion
ClienteID → ClienteTelefono
ClienteID → ClienteCorreo
```

El identificador del cliente determina todos sus datos personales.

También se considera:

```text
ClienteDNI → ClienteID
```

Debido a que el documento de identificación debe ser único.

### Sucursal

```text
SucursalID → SucursalNombre
SucursalID → SucursalDireccion
SucursalID → SucursalTelefono
```

El identificador de la sucursal determina sus datos.

### Empleado

```text
EmpleadoID → EmpleadoNombre
EmpleadoID → EmpleadoCargo
EmpleadoID → SucursalID
```

El identificador del empleado determina su información y la sucursal donde trabaja.

### Cuenta

```text
CuentaID → TipoCuenta
CuentaID → FechaApertura
CuentaID → FechaCierre
CuentaID → SaldoActual
CuentaID → EstadoCuenta
CuentaID → ClienteID
CuentaID → SucursalID
```

El identificador de la cuenta determina sus características y relaciones.

### Movimiento

```text
MovimientoID → TransferenciaRef
MovimientoID → Fecha
MovimientoID → TipoTransaccion
MovimientoID → Monto
MovimientoID → Descripcion
MovimientoID → CuentaID
MovimientoID → EmpleadoID
```

El identificador del movimiento determina toda la información de la operación.

### Catálogos

```text
TipoCuenta → Descripción del tipo de cuenta
EstadoCuenta → Descripción del estado
TipoTransaccion → Descripción de la transacción
```

En el proyecto, los valores de los catálogos funcionan directamente como llaves primarias.

---

## 5. Anomalías identificadas

## 5.1 Anomalía de inserción

En una tabla no normalizada no sería posible registrar una nueva sucursal sin registrar al mismo tiempo un cliente, una cuenta o un empleado.

También sería difícil registrar un tipo de cuenta nuevo sin asociarlo inmediatamente a una cuenta bancaria.

## 5.2 Anomalía de actualización

Si el nombre o dirección de una sucursal apareciera repetido en diferentes filas, sería necesario actualizar todos los registros.

Si una fila no fuera actualizada, quedarían datos inconsistentes para una misma sucursal.

La misma situación ocurriría con los datos de clientes, empleados y cuentas.

## 5.3 Anomalía de eliminación

Al eliminar el último movimiento de una cuenta, podría eliminarse también información relacionada con la cuenta o el cliente.

Al eliminar el último empleado de una sucursal, podrían perderse los datos generales de la sucursal.

La separación de entidades evita que la eliminación de un registro provoque la pérdida de información independiente.

---

## 6. Primera Forma Normal

Una relación cumple con la Primera Forma Normal cuando:

* Cada campo contiene un valor atómico.
* No existen columnas con grupos de valores.
* No existen grupos repetitivos.
* Cada registro puede identificarse mediante una llave primaria.

Para aplicar la Primera Forma Normal se realizaron las siguientes acciones:

* Se separaron los valores múltiples.
* Se estandarizaron los nombres de columnas.
* Se eliminaron filas completamente vacías.
* Se eliminaron duplicados exactos.
* Se estandarizaron fechas.
* Se limpiaron números telefónicos.
* Se normalizaron nombres y correos electrónicos.
* Se asignaron identificadores únicos a cada entidad.

Después de aplicar la Primera Forma Normal, cada registro representa un único cliente, cuenta, empleado, sucursal o movimiento.

---

## 7. Segunda Forma Normal

Una relación cumple con la Segunda Forma Normal cuando:

* Cumple con la Primera Forma Normal.
* Todos los atributos dependen completamente de la llave primaria.
* No existen dependencias parciales.

En la estructura inicial, los datos de clientes, sucursales, empleados y movimientos no dependían de una misma llave.

Por ejemplo:

```text
ClienteNombre depende de ClienteID.
SucursalNombre depende de SucursalID.
EmpleadoNombre depende de EmpleadoID.
SaldoActual depende de CuentaID.
Monto depende de MovimientoID.
```

Debido a estas dependencias, la información se separó en las siguientes entidades:

```text
Cliente
Sucursal
Empleado
Cuenta
Movimiento
```

Cada tabla posee una llave primaria propia y todos sus atributos dependen completamente de ella.

### Resultado de la Segunda Forma Normal

```text
Cliente(
    ClienteID,
    ClienteDNI,
    ClienteNombre,
    ClienteFechaNacimiento,
    ClienteDireccion,
    ClienteTelefono,
    ClienteCorreo
)
```

```text
Sucursal(
    SucursalID,
    SucursalNombre,
    SucursalDireccion,
    SucursalTelefono
)
```

```text
Empleado(
    EmpleadoID,
    EmpleadoNombre,
    EmpleadoCargo,
    SucursalID
)
```

```text
Cuenta(
    CuentaID,
    TipoCuenta,
    FechaApertura,
    FechaCierre,
    SaldoActual,
    EstadoCuenta,
    ClienteID,
    SucursalID
)
```

```text
Movimiento(
    MovimientoID,
    TransferenciaRef,
    Fecha,
    TipoTransaccion,
    Monto,
    Descripcion,
    CuentaID,
    EmpleadoID
)
```

---

## 8. Tercera Forma Normal

Una relación cumple con la Tercera Forma Normal cuando:

* Cumple con la Segunda Forma Normal.
* No existen dependencias transitivas.
* Los atributos que no son llave dependen únicamente de la llave primaria.

En la tabla `Cuenta`, los valores de tipo y estado representan catálogos independientes.

En la tabla `Movimiento`, el tipo de transacción también representa un catálogo independiente.

Para evitar valores escritos de diferentes maneras y mejorar la integridad de los datos, se crearon las siguientes tablas:

```text
TipoCuenta
EstadoCuenta
TipoTransaccion
```

### Tabla TipoCuenta

```text
TipoCuenta(
    TipoCuenta
)
```

Valores:

```text
Ahorro
Corriente
```

### Tabla EstadoCuenta

```text
EstadoCuenta(
    EstadoCuenta
)
```

Valores:

```text
ACTIVA
INACTIVA
CERRADA
```

### Tabla TipoTransaccion

```text
TipoTransaccion(
    TipoTransaccion
)
```

Valores:

```text
DEPOSITO
RETIRO
TRANSFERENCIA_SALIDA
TRANSFERENCIA_ENTRADA
```

Las tablas `Cuenta` y `Movimiento` hacen referencia a estos catálogos mediante llaves foráneas.

De esta forma se evita almacenar valores inválidos o inconsistentes.

---

## 9. Modelo final normalizado

El modelo final está compuesto por las siguientes tablas:

```text
TipoCuenta
EstadoCuenta
TipoTransaccion
Sucursal
Cliente
Empleado
Cuenta
Movimiento
```

### Relaciones principales

```text
Sucursal 1 ─── N Empleado
Sucursal 1 ─── N Cuenta
Cliente 1 ─── N Cuenta
TipoCuenta 1 ─── N Cuenta
EstadoCuenta 1 ─── N Cuenta
Cuenta 1 ─── N Movimiento
Empleado 1 ─── N Movimiento
TipoTransaccion 1 ─── N Movimiento
```

---

## 10. Integridad referencial

Las relaciones se implementaron mediante llaves foráneas.

### Empleado y Sucursal

```text
Empleado.SucursalID → Sucursal.SucursalID
```

### Cuenta y Cliente

```text
Cuenta.ClienteID → Cliente.ClienteID
```

### Cuenta y Sucursal

```text
Cuenta.SucursalID → Sucursal.SucursalID
```

### Cuenta y TipoCuenta

```text
Cuenta.TipoCuenta → TipoCuenta.TipoCuenta
```

### Cuenta y EstadoCuenta

```text
Cuenta.EstadoCuenta → EstadoCuenta.EstadoCuenta
```

### Movimiento y Cuenta

```text
Movimiento.CuentaID → Cuenta.CuentaID
```

### Movimiento y Empleado

```text
Movimiento.EmpleadoID → Empleado.EmpleadoID
```

### Movimiento y TipoTransaccion

```text
Movimiento.TipoTransaccion → TipoTransaccion.TipoTransaccion
```

Estas relaciones impiden registrar cuentas, empleados o movimientos relacionados con entidades inexistentes.

---

## 11. Restricciones adicionales

Además de la normalización, se aplicaron restricciones para proteger la integridad de los datos.

* El DNI del cliente debe ser único.
* El nombre de la sucursal debe ser único.
* El saldo de una cuenta no puede ser negativo.
* El monto de un movimiento debe ser mayor que cero.
* Una cuenta activa no puede tener fecha de cierre.
* La fecha de cierre no puede ser anterior a la fecha de apertura.
* Una transferencia debe tener una referencia.
* Los depósitos y retiros no utilizan referencia de transferencia.
* Una referencia de transferencia no puede repetir el mismo tipo de movimiento.

---

## 12. Resultados obtenidos

Después del proceso de limpieza, transformación y carga se obtuvieron los siguientes registros:

| Tabla      | Registros cargados |
| ---------- | -----------------: |
| Sucursal   |                  3 |
| Cliente    |                  6 |
| Empleado   |                  4 |
| Cuenta     |                  6 |
| Movimiento |                  6 |

El proceso también generó un archivo de anomalías con 15 agrupaciones detectadas durante la limpieza.

Este archivo permite conservar evidencia de los datos que necesitaron corrección, transformación o validación.

---

## 13. Beneficios del modelo normalizado

La normalización aplicada proporciona los siguientes beneficios:

* Reduce la duplicación de datos.
* Evita inconsistencias.
* Facilita la actualización de información.
* Protege la integridad referencial.
* Permite identificar claramente cada entidad.
* Facilita la creación de reportes.
* Mejora el mantenimiento de la base de datos.
* Permite aplicar permisos y procedimientos almacenados de forma organizada.
* Reduce las anomalías de inserción, actualización y eliminación.

---

## 14. Conclusión

La estructura original fue revisada para identificar entidades, atributos, dependencias funcionales y posibles anomalías.

La aplicación de la Primera, Segunda y Tercera Forma Normal permitió obtener un modelo relacional organizado y consistente.

El modelo final separa correctamente clientes, cuentas, sucursales, empleados, movimientos y catálogos, manteniendo sus relaciones mediante llaves foráneas y restricciones de integridad.
