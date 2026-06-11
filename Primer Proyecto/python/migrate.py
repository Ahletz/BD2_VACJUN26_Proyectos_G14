import os
import re
import sys
from decimal import Decimal, InvalidOperation

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

load_dotenv()

DB_HOST = os.getenv("MYSQL_HOST", "mysql")
DB_PORT = os.getenv("MYSQL_PORT", "3306")
DB_NAME = os.getenv("MYSQL_DATABASE", "banco_db")
DB_USER = os.getenv("MYSQL_USER", "bd2_user")
DB_PASSWORD = os.getenv("MYSQL_PASSWORD", "")

RAW_DIR = os.getenv("RAW_DATA_DIR", "/data/raw")
PROCESSED_DIR = os.getenv("PROCESSED_DATA_DIR", "/data/processed")
RESET_DATA = os.getenv("RESET_DATA", "true").strip().lower() in {
    "1", "true", "yes", "si", "sí"
}

ARCHIVOS = {
    "Sucursal": "sucursales_raw.csv",
    "Cliente": "clientes_raw.csv",
    "Empleado": "empleados_raw.csv",
    "Cuenta": "cuentas_raw.csv",
    "Movimiento": "transacciones_raw.csv",
}

ORDEN_CARGA = ["Sucursal", "Cliente", "Empleado", "Cuenta", "Movimiento"]
ORDEN_LIMPIEZA = ["Movimiento", "Cuenta", "Empleado", "Cliente", "Sucursal"]

TIPOS_CUENTA = {"ahorro": "Ahorro", "corriente": "Corriente"}
ESTADOS_CUENTA = {"ACTIVA", "INACTIVA", "CERRADA"}
TIPOS_TRANSACCION = {
    "DEPOSITO",
    "RETIRO",
    "TRANSFERENCIA_SALIDA",
    "TRANSFERENCIA_ENTRADA",
}


def crear_engine():
    url = (
        f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
    )
    try:
        engine = create_engine(url, pool_pre_ping=True, future=True)
        with engine.connect() as conn:
            version = conn.execute(text("SELECT VERSION()")) .scalar_one()
        print(f"[OK] Conexión a MySQL {version}")
        return engine
    except SQLAlchemyError as exc:
        print(f"[ERROR] No fue posible conectar a MySQL: {exc}")
        sys.exit(1)


def leer_csv(nombre_archivo):
    ruta = os.path.join(RAW_DIR, nombre_archivo)
    if not os.path.exists(ruta):
        raise FileNotFoundError(f"No se encontró: {ruta}")

    try:
        df = pd.read_csv(ruta, dtype=str, encoding="utf-8")
    except UnicodeDecodeError:
        df = pd.read_csv(ruta, dtype=str, encoding="latin-1")

    df.columns = [str(col).strip() for col in df.columns]
    df.dropna(how="all", inplace=True)
    return df.reset_index(drop=True)


def texto(valor):
    if pd.isna(valor):
        return None
    valor = re.sub(r"\s+", " ", str(valor).strip())
    return valor or None


def nombre(valor):
    valor = texto(valor)
    return valor.title() if valor else None


def telefono(valor):
    valor = texto(valor)
    if not valor:
        return None
    limpio = re.sub(r"\D", "", valor)
    return limpio or None


def correo(valor):
    valor = texto(valor)
    return valor.lower() if valor else None


def entero(valor, campo):
    valor = texto(valor)
    if valor is None:
        return None
    try:
        return int(float(valor))
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Valor inválido en {campo}: {valor}") from exc


def monto(valor, campo="Monto"):
    valor = texto(valor)
    if valor is None:
        raise ValueError(f"El campo {campo} no puede estar vacío")
    limpio = re.sub(r"[Q$€,\s]", "", valor)
    try:
        numero = Decimal(limpio).quantize(Decimal("0.01"))
    except InvalidOperation as exc:
        raise ValueError(f"Valor monetario inválido en {campo}: {valor}") from exc
    return float(numero)


def fecha(valor, campo):
    valor = texto(valor)
    if valor is None:
        return None
    convertido = pd.to_datetime(valor, errors="coerce")
    if pd.isna(convertido):
        raise ValueError(f"Fecha inválida en {campo}: {valor}")
    return convertido.strftime("%Y-%m-%d")


def fecha_hora(valor, campo):
    valor = texto(valor)
    if valor is None:
        return None
    convertido = pd.to_datetime(valor, errors="coerce")
    if pd.isna(convertido):
        raise ValueError(f"Fecha inválida en {campo}: {valor}")
    return convertido.strftime("%Y-%m-%d %H:%M:%S")


def registrar_duplicados(df, llave, archivo, anomalias, accion):
    duplicados = df[df.duplicated(subset=llave, keep=False)]
    if duplicados.empty:
        return

    for valores, grupo in duplicados.groupby(llave, dropna=False, sort=False):
        if not isinstance(valores, tuple):
            valores = (valores,)
        detalle = ", ".join(
            f"{campo}={valor}" for campo, valor in zip(llave, valores)
        )
        anomalias.append({
            "Archivo": archivo,
            "Tipo": "DUPLICADO",
            "Detalle": detalle,
            "Cantidad": len(grupo),
            "Accion": accion,
        })


def preparar_sucursales(df, anomalias):
    requeridas = {
        "SucursalID", "SucursalNombre", "SucursalDireccion", "SucursalTelefono"
    }
    validar_columnas(df, requeridas, ARCHIVOS["Sucursal"])

    resultado = pd.DataFrame({
        "SucursalID": df["SucursalID"].apply(lambda v: entero(v, "SucursalID")),
        "SucursalNombre": df["SucursalNombre"].apply(nombre),
        "SucursalDireccion": df["SucursalDireccion"].apply(texto),
        "SucursalTelefono": df["SucursalTelefono"].apply(telefono),
    })

    registrar_duplicados(
        resultado, ["SucursalID"], ARCHIVOS["Sucursal"], anomalias,
        "Se conserva la primera aparición por SucursalID",
    )
    resultado.drop_duplicates(subset=["SucursalID"], keep="first", inplace=True)
    return resultado.reset_index(drop=True)


def preparar_clientes(df, anomalias):
    requeridas = {
        "ClienteDNI", "ClienteNombre", "ClienteFechaNacimiento",
        "ClienteDireccion", "ClienteTelefono", "ClienteCorreo",
    }
    validar_columnas(df, requeridas, ARCHIVOS["Cliente"])

    resultado = pd.DataFrame({
        "ClienteDNI": df["ClienteDNI"].apply(texto),
        "ClienteNombre": df["ClienteNombre"].apply(nombre),
        "ClienteFechaNacimiento": df["ClienteFechaNacimiento"].apply(
            lambda v: fecha(v, "ClienteFechaNacimiento")
        ),
        "ClienteDireccion": df["ClienteDireccion"].apply(texto),
        "ClienteTelefono": df["ClienteTelefono"].apply(telefono),
        "ClienteCorreo": df["ClienteCorreo"].apply(correo),
    })

    registrar_duplicados(
        resultado, ["ClienteDNI"], ARCHIVOS["Cliente"], anomalias,
        "Se conserva la primera aparición por ClienteDNI",
    )
    resultado.drop_duplicates(subset=["ClienteDNI"], keep="first", inplace=True)
    resultado.reset_index(drop=True, inplace=True)
    resultado.insert(0, "ClienteID", range(1, len(resultado) + 1))
    return resultado


def preparar_empleados(df, anomalias):
    requeridas = {"EmpleadoID", "EmpleadoNombre", "EmpleadoCargo", "SucursalID"}
    validar_columnas(df, requeridas, ARCHIVOS["Empleado"])

    resultado = pd.DataFrame({
        "EmpleadoID": df["EmpleadoID"].apply(lambda v: entero(v, "EmpleadoID")),
        "EmpleadoNombre": df["EmpleadoNombre"].apply(nombre),
        "EmpleadoCargo": df["EmpleadoCargo"].apply(nombre),
        "SucursalID": df["SucursalID"].apply(lambda v: entero(v, "SucursalID")),
    })

    registrar_duplicados(
        resultado, ["EmpleadoID"], ARCHIVOS["Empleado"], anomalias,
        "Se conserva la primera aparición por EmpleadoID",
    )
    resultado.drop_duplicates(subset=["EmpleadoID"], keep="first", inplace=True)
    return resultado.reset_index(drop=True)


def preparar_cuentas(df, clientes, anomalias):
    requeridas = {
        "CuentaID", "TipoCuenta", "FechaApertura", "SaldoActual",
        "EstadoCuenta", "ClienteDNI", "SucursalID",
    }
    validar_columnas(df, requeridas, ARCHIVOS["Cuenta"])

    resultado = pd.DataFrame({
        "CuentaID": df["CuentaID"].apply(lambda v: entero(v, "CuentaID")),
        "TipoCuenta": df["TipoCuenta"].apply(
            lambda v: TIPOS_CUENTA.get((texto(v) or "").lower())
        ),
        "FechaApertura": df["FechaApertura"].apply(
            lambda v: fecha(v, "FechaApertura")
        ),
        "FechaCierre": None,
        "SaldoActual": df["SaldoActual"].apply(lambda v: monto(v, "SaldoActual")),
        "EstadoCuenta": df["EstadoCuenta"].apply(
            lambda v: (texto(v) or "").upper()
        ),
        "ClienteDNI": df["ClienteDNI"].apply(texto),
        "SucursalID": df["SucursalID"].apply(lambda v: entero(v, "SucursalID")),
    })

    registrar_duplicados(
        resultado, ["CuentaID"], ARCHIVOS["Cuenta"], anomalias,
        "Se conserva la primera aparición por CuentaID",
    )
    resultado.drop_duplicates(subset=["CuentaID"], keep="first", inplace=True)

    mapa_clientes = clientes.set_index("ClienteDNI")["ClienteID"].to_dict()
    resultado["ClienteID"] = resultado["ClienteDNI"].map(mapa_clientes)

    if resultado["ClienteID"].isna().any():
        faltantes = resultado.loc[resultado["ClienteID"].isna(), "ClienteDNI"].tolist()
        raise ValueError(f"Clientes no encontrados para las cuentas: {faltantes}")

    resultado["ClienteID"] = resultado["ClienteID"].astype(int)
    resultado.drop(columns=["ClienteDNI"], inplace=True)
    columnas = [
        "CuentaID", "TipoCuenta", "FechaApertura", "FechaCierre",
        "SaldoActual", "EstadoCuenta", "ClienteID", "SucursalID",
    ]
    return resultado[columnas].reset_index(drop=True)


def preparar_movimientos(df, anomalias):
    requeridas = {
        "MovimientoID", "TransferenciaID", "Fecha", "TipoTransaccion",
        "Monto", "Descripcion", "CuentaID", "EmpleadoID",
    }
    validar_columnas(df, requeridas, ARCHIVOS["Movimiento"])

    resultado = pd.DataFrame({
        "MovimientoID": df["MovimientoID"].apply(
            lambda v: entero(v, "MovimientoID")
        ),
        "TransferenciaRef": df["TransferenciaID"].apply(texto),
        "Fecha": df["Fecha"].apply(lambda v: fecha_hora(v, "Fecha")),
        "TipoTransaccion": df["TipoTransaccion"].apply(
            lambda v: (texto(v) or "").upper()
        ),
        "Monto": df["Monto"].apply(lambda v: monto(v, "Monto")),
        "Descripcion": df["Descripcion"].apply(texto),
        "CuentaID": df["CuentaID"].apply(lambda v: entero(v, "CuentaID")),
        "EmpleadoID": df["EmpleadoID"].apply(
            lambda v: entero(v, "EmpleadoID") if texto(v) is not None else None
        ),
    })

    resultado["ClaveNegocio"] = resultado.apply(clave_movimiento, axis=1)
    registrar_duplicados(
        resultado, ["ClaveNegocio"], ARCHIVOS["Movimiento"], anomalias,
        "Se conserva la primera aparición según la operación bancaria",
    )
    resultado.drop_duplicates(subset=["ClaveNegocio"], keep="first", inplace=True)
    resultado.drop(columns=["ClaveNegocio"], inplace=True)
    return resultado.reset_index(drop=True)


def clave_movimiento(fila):
    if fila["TransferenciaRef"]:
        return f"TR|{fila['TransferenciaRef']}|{fila['TipoTransaccion']}"
    return "|".join([
        "OP",
        str(fila["Fecha"]),
        str(fila["TipoTransaccion"]),
        f"{fila['Monto']:.2f}",
        str(fila["Descripcion"]),
        str(fila["CuentaID"]),
        str(fila["EmpleadoID"]),
    ])


def validar_columnas(df, requeridas, archivo):
    faltantes = sorted(requeridas.difference(df.columns))
    if faltantes:
        raise ValueError(f"Columnas faltantes en {archivo}: {', '.join(faltantes)}")


def validar_integridad(tablas):
    sucursales = set(tablas["Sucursal"]["SucursalID"])
    clientes = set(tablas["Cliente"]["ClienteID"])
    empleados = set(tablas["Empleado"]["EmpleadoID"])
    cuentas = set(tablas["Cuenta"]["CuentaID"])

    if not set(tablas["Empleado"]["SucursalID"]).issubset(sucursales):
        raise ValueError("Existen empleados asociados a sucursales inexistentes")

    if not set(tablas["Cuenta"]["SucursalID"]).issubset(sucursales):
        raise ValueError("Existen cuentas asociadas a sucursales inexistentes")

    if not set(tablas["Cuenta"]["ClienteID"]).issubset(clientes):
        raise ValueError("Existen cuentas asociadas a clientes inexistentes")

    if not set(tablas["Cuenta"]["TipoCuenta"]).issubset(set(TIPOS_CUENTA.values())):
        raise ValueError("Existen tipos de cuenta inválidos")

    if not set(tablas["Cuenta"]["EstadoCuenta"]).issubset(ESTADOS_CUENTA):
        raise ValueError("Existen estados de cuenta inválidos")

    movimientos = tablas["Movimiento"]
    if not set(movimientos["CuentaID"]).issubset(cuentas):
        raise ValueError("Existen movimientos asociados a cuentas inexistentes")

    ids_empleados = set(movimientos["EmpleadoID"].dropna().astype(int))
    if not ids_empleados.issubset(empleados):
        raise ValueError("Existen movimientos asociados a empleados inexistentes")

    if not set(movimientos["TipoTransaccion"]).issubset(TIPOS_TRANSACCION):
        raise ValueError("Existen tipos de transacción inválidos")

    if (movimientos["Monto"] <= 0).any():
        raise ValueError("Todos los movimientos deben tener monto positivo")

    es_transferencia = movimientos["TipoTransaccion"].str.startswith("TRANSFERENCIA_")
    if movimientos.loc[es_transferencia, "TransferenciaRef"].isna().any():
        raise ValueError("Toda transferencia debe tener referencia")
    if movimientos.loc[~es_transferencia, "TransferenciaRef"].notna().any():
        raise ValueError("Los depósitos y retiros no deben tener referencia")

    transferencias = movimientos[es_transferencia]
    for referencia, grupo in transferencias.groupby("TransferenciaRef"):
        tipos = set(grupo["TipoTransaccion"])
        if tipos != {"TRANSFERENCIA_SALIDA", "TRANSFERENCIA_ENTRADA"}:
            raise ValueError(f"Transferencia incompleta: {referencia}")
        if grupo["Monto"].nunique() != 1:
            raise ValueError(f"Montos inconsistentes en transferencia: {referencia}")


def preparar_datos():
    anomalias = []

    raw_sucursales = leer_csv(ARCHIVOS["Sucursal"])
    raw_clientes = leer_csv(ARCHIVOS["Cliente"])
    raw_empleados = leer_csv(ARCHIVOS["Empleado"])
    raw_cuentas = leer_csv(ARCHIVOS["Cuenta"])
    raw_movimientos = leer_csv(ARCHIVOS["Movimiento"])

    tablas = {}
    tablas["Sucursal"] = preparar_sucursales(raw_sucursales, anomalias)
    tablas["Cliente"] = preparar_clientes(raw_clientes, anomalias)
    tablas["Empleado"] = preparar_empleados(raw_empleados, anomalias)
    tablas["Cuenta"] = preparar_cuentas(raw_cuentas, tablas["Cliente"], anomalias)
    tablas["Movimiento"] = preparar_movimientos(raw_movimientos, anomalias)

    validar_integridad(tablas)
    guardar_procesados(tablas, anomalias)
    return tablas


def guardar_procesados(tablas, anomalias):
    os.makedirs(PROCESSED_DIR, exist_ok=True)

    for nombre, df in tablas.items():
        ruta = os.path.join(PROCESSED_DIR, f"{nombre.lower()}.csv")
        df.to_csv(ruta, index=False, encoding="utf-8", na_rep="")
        print(f"[OK] {ruta}: {len(df)} filas")

    columnas = ["Archivo", "Tipo", "Detalle", "Cantidad", "Accion"]
    reporte = pd.DataFrame(anomalias, columns=columnas)
    ruta_anomalias = os.path.join(PROCESSED_DIR, "anomalias.csv")
    reporte.to_csv(ruta_anomalias, index=False, encoding="utf-8")
    print(f"[OK] {ruta_anomalias}: {len(reporte)} anomalías agrupadas")


def validar_catalogos(conn):
    catalogos = {
        "TipoCuenta": ("TipoCuenta", set(TIPOS_CUENTA.values())),
        "EstadoCuenta": ("EstadoCuenta", ESTADOS_CUENTA),
        "TipoTransaccion": ("TipoTransaccion", TIPOS_TRANSACCION),
    }

    for tabla, (columna, esperados) in catalogos.items():
        encontrados = {
            fila[0]
            for fila in conn.execute(text(f"SELECT {columna} FROM {tabla}"))
        }
        faltantes = esperados.difference(encontrados)
        if faltantes:
            raise ValueError(
                f"Faltan valores en {tabla}: {', '.join(sorted(faltantes))}. "
                "Ejecuta db/dml/01_insert_catalogs.sql antes de migrar."
            )


def cargar_datos(engine, tablas):
    try:
        with engine.begin() as conn:
            validar_catalogos(conn)

            if RESET_DATA:
                for tabla in ORDEN_LIMPIEZA:
                    conn.execute(text(f"DELETE FROM {tabla}"))
                print("[OK] Datos anteriores eliminados")

            for tabla in ORDEN_CARGA:
                tablas[tabla].to_sql(
                    tabla,
                    con=conn,
                    if_exists="append",
                    index=False,
                    chunksize=500,
                    method="multi",
                )
                print(f"[OK] {tabla}: {len(tablas[tabla])} filas cargadas")
    except (SQLAlchemyError, ValueError) as exc:
        print(f"[ERROR] Falló la carga: {exc}")
        raise


def validar_carga(engine, tablas):
    todo_correcto = True
    with engine.connect() as conn:
        for tabla in ORDEN_CARGA:
            total_bd = conn.execute(text(f"SELECT COUNT(*) FROM {tabla}")) .scalar_one()
            total_esperado = len(tablas[tabla])
            estado = "OK" if total_bd == total_esperado else "DIFERENCIA"
            print(
                f"[{estado}] {tabla}: esperado={total_esperado}, base={total_bd}"
            )
            if total_bd != total_esperado:
                todo_correcto = False

    if not todo_correcto:
        raise RuntimeError("La validación detectó diferencias en la carga")


def main():
    print("=" * 60)
    print("MIGRACIÓN DE DATOS - PROYECTO BD2 GRUPO 14")
    print("=" * 60)

    try:
        tablas = preparar_datos()
        engine = crear_engine()
        cargar_datos(engine, tablas)
        validar_carga(engine, tablas)
    except (FileNotFoundError, ValueError, RuntimeError, SQLAlchemyError) as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)

    print("=" * 60)
    print("MIGRACIÓN FINALIZADA CORRECTAMENTE")
    print("=" * 60)


if __name__ == "__main__":
    main()