import os
import re
import sys
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

#  Variables de entorno 
load_dotenv()

DB_HOST     = os.getenv("MYSQL_HOST",     "mysql")
DB_PORT     = os.getenv("MYSQL_PORT",     "3306")
DB_NAME     = os.getenv("MYSQL_DATABASE", "banco_db")
DB_USER     = os.getenv("MYSQL_USER",     "bd2_user")
DB_PASSWORD = os.getenv("MYSQL_PASSWORD", "")

RAW       = "/data/raw"
PROCESSED = "/data/processed"

# Rutas de los cinco CSV
CSV_CLIENTES      = os.path.join(RAW, "clientes_raw.csv")
CSV_SUCURSALES    = os.path.join(RAW, "sucursales_raw.csv")
CSV_EMPLEADOS     = os.path.join(RAW, "empleados_raw.csv")
CSV_CUENTAS       = os.path.join(RAW, "cuentas_raw.csv")
CSV_TRANSACCIONES = os.path.join(RAW, "transacciones_raw.csv")

# Contadores globales del resumen final
stats = {
    "clientes_leidos":       0,
    "clientes_insertados":   0,
    "clientes_rechazados":   0,
    "sucursales_leidas":     0,
    "sucursales_insertadas": 0,
    "empleados_insertados":  0,
    "cuentas_insertadas":    0,
    "movimientos_insertados":0,
    "conflictos":            0,
    "errores":               0,
}

#  UTILIDADES GENERALES


def leer_csv(ruta):
    """Lee un CSV probando UTF-8 y luego latin-1."""
    if not os.path.exists(ruta):
        print(f"[ERROR] No se encontró: {ruta}")
        sys.exit(1)
    try:
        return pd.read_csv(ruta, encoding="utf-8")
    except UnicodeDecodeError:
        print(f"  [AVISO] {os.path.basename(ruta)}: usando latin-1")
        return pd.read_csv(ruta, encoding="latin-1")


def guardar_csv(df, nombre):
    """Guarda un DataFrame en data/processed/."""
    os.makedirs(PROCESSED, exist_ok=True)
    ruta = os.path.join(PROCESSED, nombre)
    df.to_csv(ruta, index=False, encoding="utf-8")
    print(f"  [GUARDADO] {nombre}  ({len(df)} filas)")


def limpiar_texto(v):
    return str(v).strip() if pd.notna(v) and str(v).strip() != "" else None

def limpiar_nombre(v):
    if pd.isna(v) or str(v).strip() == "":
        return None
    return " ".join(str(v).strip().title().split())

def limpiar_telefono(v):
    if pd.isna(v) or str(v).strip() == "":
        return None
    return re.sub(r"\D", "", str(v))

def limpiar_correo(v):
    if pd.isna(v) or str(v).strip() == "":
        return None
    return str(v).strip().lower()

def limpiar_fecha(v, campo="fecha"):
    if pd.isna(v) or str(v).strip() == "":
        return None
    try:
        return pd.to_datetime(str(v)).strftime("%Y-%m-%d")
    except Exception:
        print(f"  [ERROR] Fecha inválida en '{campo}': '{v}'")
        return None

def limpiar_monto(v, campo="monto"):
    """Convierte monto. Si falla lanza ValueError (no oculta con 0)."""
    if pd.isna(v):
        raise ValueError(f"Monto nulo en campo '{campo}'")
    limpio = re.sub(r"[Q$,\s]", "", str(v))
    try:
        resultado = float(limpio)
        if resultado <= 0:
            raise ValueError(f"Monto no positivo: {resultado}")
        return resultado
    except ValueError:
        raise ValueError(f"Monto inválido en '{campo}': '{v}'")

def registrar_conflicto(lista, llave, campo, valor_a, valor_b, elegido):
    lista.append({
        "llave":   llave,
        "campo":   campo,
        "valor_a": valor_a,
        "valor_b": valor_b,
        "elegido": elegido,
    })
    stats["conflictos"] += 1



#  1. LIMPIAR SUCURSALES


def limpiar_sucursales(df_raw):
    print("\n── SUCURSALES ───────────────────────────────────────────")
    stats["sucursales_leidas"] = len(df_raw)
    print(f"  Leídas: {len(df_raw)}")

    conflictos = []
    limpias    = {}   # SucursalID → dict

    for _, row in df_raw.iterrows():
        sid = row.get("SucursalID")
        if pd.isna(sid):
            print("  [RECHAZADA] Fila sin SucursalID")
            stats["errores"] += 1
            continue
        sid = int(sid)

        nombre    = limpiar_nombre(row.get("SucursalNombre"))
        direccion = limpiar_texto(row.get("SucursalDireccion"))
        telefono  = limpiar_telefono(row.get("SucursalTelefono"))

        if not nombre or not direccion or not telefono:
            print(f"  [RECHAZADA] SucursalID={sid}: campos obligatorios vacíos")
            stats["errores"] += 1
            continue

        if sid not in limpias:
            limpias[sid] = {
                "SucursalID":        sid,
                "SucursalNombre":    nombre,
                "SucursalDireccion": direccion,
                "SucursalTelefono":  telefono,
            }
        else:
            # Resolver conflictos: ganadora = primera aparición (más antigua)
            prev = limpias[sid]
            if prev["SucursalDireccion"] != direccion:
                registrar_conflicto(conflictos, sid, "SucursalDireccion",
                                    prev["SucursalDireccion"], direccion,
                                    prev["SucursalDireccion"])
            if prev["SucursalTelefono"] != telefono:
                registrar_conflicto(conflictos, sid, "SucursalTelefono",
                                    prev["SucursalTelefono"], telefono,
                                    prev["SucursalTelefono"])

    df_limpias = pd.DataFrame(list(limpias.values()))
    print(f"  Únicas después de resolver: {len(df_limpias)}")

    guardar_csv(df_limpias, "sucursales_limpias.csv")
    if conflictos:
        guardar_csv(pd.DataFrame(conflictos), "conflictos_sucursales.csv")
        print(f"  [CONFLICTOS] {len(conflictos)} diferencias registradas")

    return df_limpias



#  2. LIMPIAR CLIENTES


def limpiar_clientes(df_raw):
    print("\n── CLIENTES ─────────────────────────────────────────────")
    stats["clientes_leidos"] = len(df_raw)
    print(f"  Leídos: {len(df_raw)}")

    conflictos = []
    limpios    = {}   # ClienteDNI → dict
    rechazados = []

    for _, row in df_raw.iterrows():
        dni = limpiar_texto(row.get("ClienteDNI"))
        if not dni:
            print("  [RECHAZADO] Fila sin ClienteDNI")
            rechazados.append(dict(row))
            stats["clientes_rechazados"] += 1
            continue

        nombre = limpiar_nombre(row.get("ClienteNombre"))
        if not nombre:
            print(f"  [RECHAZADO] DNI={dni}: nombre vacío")
            rechazados.append(dict(row))
            stats["clientes_rechazados"] += 1
            continue

        fecha = limpiar_fecha(row.get("ClienteFechaNacimiento"), "ClienteFechaNacimiento")
        if not fecha:
            print(f"  [RECHAZADO] DNI={dni}: fecha de nacimiento inválida")
            rechazados.append(dict(row))
            stats["clientes_rechazados"] += 1
            continue

        direccion = limpiar_texto(row.get("ClienteDireccion"))
        if not direccion:
            print(f"  [RECHAZADO] DNI={dni}: dirección vacía")
            rechazados.append(dict(row))
            stats["clientes_rechazados"] += 1
            continue

        telefono = limpiar_telefono(row.get("ClienteTelefono"))
        if not telefono:
            print(f"  [RECHAZADO] DNI={dni}: teléfono vacío")
            rechazados.append(dict(row))
            stats["clientes_rechazados"] += 1
            continue

        correo = limpiar_correo(row.get("ClienteCorreo"))  # puede ser None

        candidato = {
            "ClienteDNI":             dni,
            "ClienteNombre":          nombre,
            "ClienteFechaNacimiento": fecha,
            "ClienteDireccion":       direccion,
            "ClienteTelefono":        telefono,
            "ClienteCorreo":          correo,
        }

        if dni not in limpios:
            limpios[dni] = candidato
        else:
            prev = limpios[dni]
            for campo in ["ClienteDireccion", "ClienteTelefono", "ClienteCorreo"]:
                if prev[campo] != candidato[campo]:
                    # Regla: conservar el valor no nulo; si ambos son distintos, conservar primero
                    elegido = prev[campo] if prev[campo] is not None else candidato[campo]
                    registrar_conflicto(conflictos, dni, campo,
                                        prev[campo], candidato[campo], elegido)
                    limpios[dni][campo] = elegido

    df_limpios = pd.DataFrame(list(limpios.values()))
    stats["clientes_insertados"] = len(df_limpios)
    print(f"  Únicos después de resolver: {len(df_limpios)}")
    print(f"  Rechazados: {stats['clientes_rechazados']}")

    guardar_csv(df_limpios, "clientes_limpios.csv")
    if conflictos:
        guardar_csv(pd.DataFrame(conflictos), "conflictos_clientes.csv")
        print(f"  [CONFLICTOS] {len(conflictos)} diferencias registradas")
    if rechazados:
        guardar_csv(pd.DataFrame(rechazados), "rechazados_clientes.csv")

    return df_limpios


#  3. LIMPIAR EMPLEADOS


def limpiar_empleados(df_raw, ids_sucursales_validas):
    print("\n── EMPLEADOS ────────────────────────────────────────────")
    print(f"  Leídos: {len(df_raw)}")

    conflictos = []
    limpios    = {}

    for _, row in df_raw.iterrows():
        eid = row.get("EmpleadoID")
        if pd.isna(eid):
            print("  [RECHAZADO] Fila sin EmpleadoID")
            stats["errores"] += 1
            continue
        eid = int(eid)

        nombre = limpiar_nombre(row.get("EmpleadoNombre"))
        cargo  = limpiar_texto(row.get("EmpleadoCargo"))
        sid    = row.get("SucursalID")

        if not nombre or not cargo:
            print(f"  [RECHAZADO] EmpleadoID={eid}: nombre o cargo vacío")
            stats["errores"] += 1
            continue

        if pd.isna(sid) or int(sid) not in ids_sucursales_validas:
            print(f"  [RECHAZADO] EmpleadoID={eid}: SucursalID={sid} no existe")
            stats["errores"] += 1
            continue
        sid = int(sid)

        if eid not in limpios:
            limpios[eid] = {
                "EmpleadoID":     eid,
                "EmpleadoNombre": nombre,
                "EmpleadoCargo":  cargo,
                "SucursalID":     sid,
            }
        else:
            prev = limpios[eid]
            if prev["EmpleadoCargo"] != cargo:
                # Regla: conservar el cargo de la primera aparición
                registrar_conflicto(conflictos, eid, "EmpleadoCargo",
                                    prev["EmpleadoCargo"], cargo,
                                    prev["EmpleadoCargo"])

    df_limpios = pd.DataFrame(list(limpios.values()))
    stats["empleados_insertados"] = len(df_limpios)
    print(f"  Únicos después de resolver: {len(df_limpios)}")

    guardar_csv(df_limpios, "empleados_limpios.csv")
    if conflictos:
        guardar_csv(pd.DataFrame(conflictos), "conflictos_empleados.csv")
        print(f"  [CONFLICTOS] {len(conflictos)} diferencias registradas")

    return df_limpios

#  4. LIMPIAR CUENTAS

def limpiar_cuentas(df_raw, mapa_dni_a_id, ids_sucursales_validas):
    """
    mapa_dni_a_id: dict {ClienteDNI: ClienteID} obtenido de MySQL
                   después de insertar clientes.
    """
    print("\n── CUENTAS ──────────────────────────────────────────────")
    print(f"  Leídas: {len(df_raw)}")

    TIPOS_VALIDOS  = {"Ahorro", "Corriente"}
    ESTADOS_VALIDOS = {"ACTIVA", "INACTIVA"}

    conflictos = []
    limpias    = {}

    for _, row in df_raw.iterrows():
        cid = row.get("CuentaID")
        if pd.isna(cid):
            print("  [RECHAZADA] Fila sin CuentaID")
            stats["errores"] += 1
            continue
        cid = int(cid)

        tipo = limpiar_texto(row.get("TipoCuenta"))
        if tipo not in TIPOS_VALIDOS:
            print(f"  [RECHAZADA] CuentaID={cid}: TipoCuenta='{tipo}' inválido")
            stats["errores"] += 1
            continue

        estado = limpiar_texto(row.get("EstadoCuenta"))
        if estado:
            estado = estado.upper()
        if estado not in ESTADOS_VALIDOS:
            print(f"  [RECHAZADA] CuentaID={cid}: EstadoCuenta='{estado}' inválido")
            stats["errores"] += 1
            continue

        fecha_apertura = limpiar_fecha(row.get("FechaApertura"), "FechaApertura")
        if not fecha_apertura:
            print(f"  [RECHAZADA] CuentaID={cid}: FechaApertura inválida")
            stats["errores"] += 1
            continue

        # FechaCierre: NULL cuando no existe o está vacía
        fecha_cierre_raw = row.get("FechaCierre")
        if pd.isna(fecha_cierre_raw) or str(fecha_cierre_raw).strip() == "":
            fecha_cierre = None
        else:
            fecha_cierre = limpiar_fecha(fecha_cierre_raw, "FechaCierre")

        # Saldo
        saldo_raw = row.get("SaldoActual")
        try:
            saldo = float(re.sub(r"[Q$,\s]", "", str(saldo_raw)))
            if saldo < 0:
                raise ValueError("Saldo negativo")
        except (ValueError, TypeError):
            print(f"  [RECHAZADA] CuentaID={cid}: SaldoActual='{saldo_raw}' inválido")
            stats["errores"] += 1
            continue

        # Resolver ClienteDNI → ClienteID
        dni = limpiar_texto(row.get("ClienteDNI"))
        cliente_id = mapa_dni_a_id.get(dni)
        if cliente_id is None:
            print(f"  [RECHAZADA] CuentaID={cid}: ClienteDNI='{dni}' no existe en MySQL")
            stats["errores"] += 1
            continue

        sid = row.get("SucursalID")
        if pd.isna(sid) or int(sid) not in ids_sucursales_validas:
            print(f"  [RECHAZADA] CuentaID={cid}: SucursalID='{sid}' no existe")
            stats["errores"] += 1
            continue
        sid = int(sid)

        candidato = {
            "CuentaID":      cid,
            "TipoCuenta":    tipo,
            "FechaApertura": fecha_apertura,
            "FechaCierre":   fecha_cierre,
            "SaldoActual":   saldo,
            "EstadoCuenta":  estado,
            "ClienteID":     cliente_id,
            "SucursalID":    sid,
        }

        if cid not in limpias:
            limpias[cid] = candidato
        else:
            prev = limpias[cid]
            for campo in ["SaldoActual", "EstadoCuenta"]:
                if prev[campo] != candidato[campo]:
                    # Regla saldo: conservar el mayor; estado: conservar INACTIVA si aparece
                    if campo == "SaldoActual":
                        elegido = max(prev[campo], candidato[campo])
                    else:
                        elegido = "INACTIVA" if "INACTIVA" in (prev[campo], candidato[campo]) else prev[campo]
                    registrar_conflicto(conflictos, cid, campo,
                                        prev[campo], candidato[campo], elegido)
                    limpias[cid][campo] = elegido

    df_limpias = pd.DataFrame(list(limpias.values()))
    stats["cuentas_insertadas"] = len(df_limpias)
    print(f"  Únicas después de resolver: {len(df_limpias)}")

    guardar_csv(df_limpias, "cuentas_limpias.csv")
    if conflictos:
        guardar_csv(pd.DataFrame(conflictos), "conflictos_cuentas.csv")
        print(f"  [CONFLICTOS] {len(conflictos)} diferencias registradas")

    return df_limpias


#  5. LIMPIAR MOVIMIENTOS


def limpiar_movimientos(df_raw, ids_cuentas_validas, ids_empleados_validos):
    print("\n── MOVIMIENTOS ──────────────────────────────────────────")
    print(f"  Leídos: {len(df_raw)}")

    TIPOS_VALIDOS = {
        "DEPOSITO", "RETIRO",
        "TRANSFERENCIA_SALIDA", "TRANSFERENCIA_ENTRADA"
    }
    TIPOS_REQUIEREN_EMPLEADO    = {"DEPOSITO", "RETIRO"}
    TIPOS_REQUIEREN_TRANSFERENCIA = {"TRANSFERENCIA_SALIDA", "TRANSFERENCIA_ENTRADA"}

    conflictos = []
    limpios    = {}

    for _, row in df_raw.iterrows():
        mid = row.get("MovimientoID")
        if pd.isna(mid):
            print("  [RECHAZADO] Fila sin MovimientoID")
            stats["errores"] += 1
            continue
        mid = int(mid)

        tipo = limpiar_texto(row.get("TipoTransaccion"))
        if tipo:
            tipo = tipo.upper()
        if tipo not in TIPOS_VALIDOS:
            print(f"  [RECHAZADO] MovimientoID={mid}: TipoTransaccion='{tipo}' inválido")
            stats["errores"] += 1
            continue

        # Monto: rechazar si no es convertible o <= 0
        try:
            monto = limpiar_monto(row.get("Monto"), "Monto")
        except ValueError as e:
            print(f"  [RECHAZADO] MovimientoID={mid}: {e}")
            stats["errores"] += 1
            continue

        fecha = limpiar_fecha(row.get("Fecha"), "Fecha")
        if not fecha:
            print(f"  [RECHAZADO] MovimientoID={mid}: Fecha inválida")
            stats["errores"] += 1
            continue

        descripcion = limpiar_texto(row.get("Descripcion"))

        # CuentaID
        cid = row.get("CuentaID")
        if pd.isna(cid) or int(cid) not in ids_cuentas_validas:
            print(f"  [RECHAZADO] MovimientoID={mid}: CuentaID='{cid}' no existe")
            stats["errores"] += 1
            continue
        cid = int(cid)

        # EmpleadoID: obligatorio para DEPOSITO y RETIRO
        eid_raw = row.get("EmpleadoID")
        if pd.isna(eid_raw) or str(eid_raw).strip() == "":
            eid = None
        else:
            eid = int(eid_raw)
            if eid not in ids_empleados_validos:
                print(f"  [RECHAZADO] MovimientoID={mid}: EmpleadoID={eid} no existe")
                stats["errores"] += 1
                continue

        if tipo in TIPOS_REQUIEREN_EMPLEADO and eid is None:
            print(f"  [RECHAZADO] MovimientoID={mid}: {tipo} requiere EmpleadoID")
            stats["errores"] += 1
            continue

        # TransferenciaRef
        ref_raw = row.get("TransferenciaID") or row.get("TransferenciaRef")
        if pd.isna(ref_raw) or str(ref_raw).strip() == "":
            ref = None
        else:
            ref = str(ref_raw).strip()

        if tipo in TIPOS_REQUIEREN_TRANSFERENCIA and ref is None:
            print(f"  [RECHAZADO] MovimientoID={mid}: {tipo} requiere TransferenciaRef")
            stats["errores"] += 1
            continue

        if tipo in TIPOS_REQUIEREN_EMPLEADO and ref is not None:
            ref = None   # DEPOSITO/RETIRO no deben tener TransferenciaRef

        candidato = {
            "MovimientoID":    mid,
            "Fecha":           fecha,
            "TipoTransaccion": tipo,
            "Monto":           monto,
            "Descripcion":     descripcion,
            "TransferenciaRef": ref,
            "CuentaID":        cid,
            "EmpleadoID":      eid,
        }

        if mid not in limpios:
            limpios[mid] = candidato
        else:
            # MovimientoID duplicado con datos distintos → registrar y conservar primero
            registrar_conflicto(conflictos, mid, "duplicado_movimiento",
                                str(limpios[mid]), str(candidato),
                                "primer registro conservado")

    df_limpios = pd.DataFrame(list(limpios.values()))
    stats["movimientos_insertados"] = len(df_limpios)
    print(f"  Únicos después de resolver: {len(df_limpios)}")

    guardar_csv(df_limpios, "movimientos_limpios.csv")
    if conflictos:
        guardar_csv(pd.DataFrame(conflictos), "conflictos_movimientos.csv")
        print(f"  [CONFLICTOS] {len(conflictos)} diferencias registradas")

    return df_limpios



#  CONEXIÓN

def crear_engine():
    url = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    try:
        engine = create_engine(url, echo=False)
        with engine.connect() as conn:
            version = conn.execute(text("SELECT VERSION()")).scalar()
        print(f"Conexión exitosa a MySQL.")
        print(f"Versión del servidor: {version}")
        return engine
    except SQLAlchemyError as e:
        print(f"[ERROR] No se pudo conectar a MySQL: {e}")
        sys.exit(1)



#  VERIFICAR QUE LAS TABLAS ESTÉN VACÍAS


def verificar_tablas_vacias(conn):
    tablas = ["Sucursal", "Cliente", "Empleado", "Cuenta", "Movimiento"]
    for tabla in tablas:
        n = conn.execute(text(f"SELECT COUNT(*) FROM {tabla}")).scalar()
        if n > 0:
            print(f"[ERROR] La tabla '{tabla}' ya tiene {n} filas.")
            print("  Limpia la base antes de ejecutar la migración.")
            print("  Puedes usar: TRUNCATE TABLE nombre; o recrear la base.")
            return False
    return True



#  CARGA CON TRANSACCIÓN GLOBAL


def cargar_todo(engine, df_suc, df_cli, df_emp, df_cta, df_mov):
    print("\n── CARGA A MySQL (transacción global) ───────────────────")

    with engine.begin() as conn:   # begin() hace COMMIT al salir o ROLLBACK si hay excepción

        # Verificar tablas vacías dentro de la transacción
        if not verificar_tablas_vacias(conn):
            raise RuntimeError("Tablas no vacías, migración detenida.")

        # 1. Sucursal
        registros = df_suc.to_dict(orient="records")
        conn.execute(
            text("INSERT INTO Sucursal (SucursalID, SucursalNombre, SucursalDireccion, SucursalTelefono) "
                 "VALUES (:SucursalID, :SucursalNombre, :SucursalDireccion, :SucursalTelefono)"),
            registros
        )
        print(f"  [OK] Sucursal     : {len(registros)} filas")

        # 2. Cliente (ClienteID es AUTO_INCREMENT, no lo enviamos)
        registros = df_cli.to_dict(orient="records")
        conn.execute(
            text("INSERT INTO Cliente (ClienteDNI, ClienteNombre, ClienteFechaNacimiento, "
                 "ClienteDireccion, ClienteTelefono, ClienteCorreo) "
                 "VALUES (:ClienteDNI, :ClienteNombre, :ClienteFechaNacimiento, "
                 ":ClienteDireccion, :ClienteTelefono, :ClienteCorreo)"),
            registros
        )
        print(f"  [OK] Cliente      : {len(registros)} filas")

        # Obtener mapa DNI → ClienteID generado por MySQL
        resultado = conn.execute(text("SELECT ClienteID, ClienteDNI FROM Cliente"))
        mapa_dni_a_id = {row[1]: row[0] for row in resultado}

        # 3. Empleado
        registros = df_emp.to_dict(orient="records")
        conn.execute(
            text("INSERT INTO Empleado (EmpleadoID, EmpleadoNombre, EmpleadoCargo, SucursalID) "
                 "VALUES (:EmpleadoID, :EmpleadoNombre, :EmpleadoCargo, :SucursalID)"),
            registros
        )
        print(f"  [OK] Empleado     : {len(registros)} filas")

        # 4. Cuenta — reemplazar ClienteDNI por ClienteID
        # (La limpieza ya lo hizo, df_cta ya tiene ClienteID)
        registros = df_cta.to_dict(orient="records")
        conn.execute(
            text("INSERT INTO Cuenta (CuentaID, TipoCuenta, FechaApertura, FechaCierre, "
                 "SaldoActual, EstadoCuenta, ClienteID, SucursalID) "
                 "VALUES (:CuentaID, :TipoCuenta, :FechaApertura, :FechaCierre, "
                 ":SaldoActual, :EstadoCuenta, :ClienteID, :SucursalID)"),
            registros
        )
        print(f"  [OK] Cuenta       : {len(registros)} filas")

        # 5. Movimiento
        registros = df_mov.to_dict(orient="records")
        conn.execute(
            text("INSERT INTO Movimiento (MovimientoID, Fecha, TipoTransaccion, Monto, "
                 "Descripcion, TransferenciaRef, CuentaID, EmpleadoID) "
                 "VALUES (:MovimientoID, :Fecha, :TipoTransaccion, :Monto, "
                 ":Descripcion, :TransferenciaRef, :CuentaID, :EmpleadoID)"),
            registros
        )
        print(f"  [OK] Movimiento   : {len(registros)} filas")

    print("  [OK] COMMIT — todos los datos cargados correctamente.")
    return mapa_dni_a_id


#  VALIDACIÓN DE RELACIONES

def validar(engine):
    print("\n── VALIDACIÓN DE RELACIONES ─────────────────────────────")
    errores = []

    with engine.connect() as conn:
        def check(descripcion, query):
            n = conn.execute(text(query)).scalar()
            if n > 0:
                errores.append(f"  [FALLA] {descripcion}: {n} registros problemáticos")
            else:
                print(f"  [OK] {descripcion}")

        check("Cuentas sin cliente",
              "SELECT COUNT(*) FROM Cuenta c "
              "LEFT JOIN Cliente cl ON c.ClienteID = cl.ClienteID "
              "WHERE cl.ClienteID IS NULL")

        check("Cuentas sin sucursal",
              "SELECT COUNT(*) FROM Cuenta c "
              "LEFT JOIN Sucursal s ON c.SucursalID = s.SucursalID "
              "WHERE s.SucursalID IS NULL")

        check("Empleados sin sucursal",
              "SELECT COUNT(*) FROM Empleado e "
              "LEFT JOIN Sucursal s ON e.SucursalID = s.SucursalID "
              "WHERE s.SucursalID IS NULL")

        check("Movimientos sin cuenta",
              "SELECT COUNT(*) FROM Movimiento m "
              "LEFT JOIN Cuenta c ON m.CuentaID = c.CuentaID "
              "WHERE c.CuentaID IS NULL")

        check("Depósitos/retiros sin empleado",
              "SELECT COUNT(*) FROM Movimiento "
              "WHERE TipoTransaccion IN ('DEPOSITO','RETIRO') AND EmpleadoID IS NULL")

        check("Transferencias sin TransferenciaRef",
              "SELECT COUNT(*) FROM Movimiento "
              "WHERE TipoTransaccion IN ('TRANSFERENCIA_SALIDA','TRANSFERENCIA_ENTRADA') "
              "AND TransferenciaRef IS NULL")

        check("Montos no positivos",
              "SELECT COUNT(*) FROM Movimiento WHERE Monto <= 0")

        check("Saldos negativos",
              "SELECT COUNT(*) FROM Cuenta WHERE SaldoActual < 0")

    if errores:
        print("\n  PROBLEMAS ENCONTRADOS:")
        for e in errores:
            print(e)
        stats["errores"] += len(errores)
    else:
        print("\n  Todas las validaciones pasaron correctamente.")


# =============================================================
#  RESUMEN FINAL
# =============================================================

def mostrar_resumen():
    print("\n" + "=" * 55)
    print("  RESUMEN FINAL")
    print("=" * 55)
    print(f"  Clientes leídos          : {stats['clientes_leidos']}")
    print(f"  Clientes insertados      : {stats['clientes_insertados']}")
    print(f"  Clientes rechazados      : {stats['clientes_rechazados']}")
    print(f"  Sucursales leídas        : {stats['sucursales_leidas']}")
    print(f"  Sucursales insertadas    : {stats['sucursales_insertadas']}")
    print(f"  Empleados insertados     : {stats['empleados_insertados']}")
    print(f"  Cuentas insertadas       : {stats['cuentas_insertadas']}")
    print(f"  Movimientos insertados   : {stats['movimientos_insertados']}")
    print(f"  Conflictos encontrados   : {stats['conflictos']}")
    print(f"  Errores encontrados      : {stats['errores']}")
    estado = "ÉXITO" if stats["errores"] == 0 else "COMPLETADO CON ADVERTENCIAS"
    print(f"\n  Estado final             : {estado}")
    print("=" * 55)


# =============================================================
#  MAIN
# =============================================================

def main():
    print("=" * 55)
    print("  MIGRACIÓN DE DATOS — Proyecto BD2, Grupo 14")
    print("=" * 55)

    engine = crear_engine()

    # ── Leer los cinco CSV ────────────────────────────────────
    print("\n── LECTURA DE ARCHIVOS ──────────────────────────────────")
    df_suc_raw = leer_csv(CSV_SUCURSALES)
    df_cli_raw = leer_csv(CSV_CLIENTES)
    df_emp_raw = leer_csv(CSV_EMPLEADOS)
    df_cta_raw = leer_csv(CSV_CUENTAS)
    df_mov_raw = leer_csv(CSV_TRANSACCIONES)
    print("  [OK] Cinco archivos leídos.")

    # ── Limpiar cada entidad ──────────────────────────────────
    df_suc = limpiar_sucursales(df_suc_raw)
    df_cli = limpiar_clientes(df_cli_raw)

    ids_sucursales = set(df_suc["SucursalID"].tolist())
    df_emp = limpiar_empleados(df_emp_raw, ids_sucursales)

    # Para cuentas necesitamos el mapa DNI→ID, pero ClienteID lo genera
    # MySQL. Hacemos la limpieza de cuentas con DNI primero; el reemplazo
    # real ocurre dentro de cargar_todo() después del INSERT de clientes.
    # Aquí pasamos un mapa vacío; limpiar_cuentas lo usará solo para validar
    # que el DNI exista entre los clientes limpios.
    mapa_dni_previo = {row["ClienteDNI"]: 0 for _, row in df_cli.iterrows()}

    df_cta = limpiar_cuentas(df_cta_raw, mapa_dni_previo, ids_sucursales)

    ids_cuentas   = set(df_cta["CuentaID"].tolist())
    ids_empleados = set(df_emp["EmpleadoID"].tolist())
    df_mov = limpiar_movimientos(df_mov_raw, ids_cuentas, ids_empleados)

    # ── Cargar con transacción global ─────────────────────────
    try:
        mapa_dni_real = cargar_todo(engine, df_suc, df_cli, df_emp, df_cta, df_mov)
        stats["sucursales_insertadas"] = len(df_suc)
    except Exception as e:
        print(f"\n[ERROR CRÍTICO] ROLLBACK automático: {e}")
        stats["errores"] += 1
        mostrar_resumen()
        sys.exit(1)

    # ── Validar relaciones ────────────────────────────────────
    validar(engine)

    mostrar_resumen()


if __name__ == "__main__":
    main()