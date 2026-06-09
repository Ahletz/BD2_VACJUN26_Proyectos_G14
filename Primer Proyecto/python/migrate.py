import os
import re
import sys
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# ── Cargar variables de entorno ──────────────────────────────
load_dotenv()

DB_HOST     = os.getenv("MYSQL_HOST",     "mysql")  
DB_PORT     = os.getenv("MYSQL_PORT",     "3306")
DB_NAME     = os.getenv("MYSQL_DATABASE", "banco_db")
DB_USER     = os.getenv("MYSQL_USER",     "bd2_user")
DB_PASSWORD = os.getenv("MYSQL_PASSWORD", "")

CSV_FILENAME = os.getenv("CSV_FILENAME", "datos_banco.csv")

# Rutas dentro del contenedor (mapeadas por docker-compose.yml)
RAW_PATH       = f"/data/raw/{CSV_FILENAME}"
PROCESSED_PATH = "/data/processed/"



#  1. CONEXIÓN


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


#  2. LIMPIEZA


def limpiar_texto(v):
    return str(v).strip() if pd.notna(v) else None

def limpiar_nombre(v):
    return " ".join(str(v).strip().title().split()) if pd.notna(v) else None

def limpiar_telefono(v):
    return re.sub(r'\D', '', str(v)) if pd.notna(v) else None

def limpiar_correo(v):
    return str(v).strip().lower() if pd.notna(v) else None

def limpiar_monto(v):
    if pd.isna(v):
        return 0.0
    limpio = re.sub(r'[Q$,\s]', '', str(v))
    try:
        return float(limpio)
    except ValueError:
        print(f"  [AVISO] Monto no convertible: '{v}' → 0.0")
        return 0.0

def limpiar_fecha(v):
    if pd.isna(v):
        return None
    try:
        return pd.to_datetime(str(v), dayfirst=False).strftime("%Y-%m-%d")
    except Exception:
        print(f"  [AVISO] Fecha no convertible: '{v}' → None")
        return None

def limpiar_dni(v):
    return re.sub(r'\s+', '', str(v).strip()) if pd.notna(v) else None


def limpiar(df):
    print("\n── FASE 1: LIMPIEZA ────────────────────────────────────")
    print(f"  Filas originales : {len(df)}")

    # Estandarizar nombres de columnas
    df.columns = (df.columns.str.strip().str.lower()
                  .str.replace(' ', '_').str.replace('-', '_'))

    # Eliminar filas vacías y duplicados exactos
    df.dropna(how='all', inplace=True)
    df.drop_duplicates(inplace=True)

    # ── Aplicar limpieza por tipo de columna ──────────────────
    # *** Ajusta los nombres si tu CSV tiene columnas distintas ***

    cols_nombre    = ['nombre_cliente', 'nombre_empleado', 'nombre']
    cols_dni       = ['cliente_dni', 'dni', 'dpi']
    cols_telefono  = ['telefono', 'telefono_cliente']
    cols_correo    = ['correo', 'correo_electronico', 'email']
    cols_monto     = ['saldo', 'monto', 'saldo_inicial', 'saldo_actual']
    cols_fecha     = ['fecha_nacimiento', 'fecha_apertura', 'fecha_transaccion']
    cols_texto     = ['tipo_cuenta', 'tipo_transaccion', 'descripcion',
                      'nombre_sucursal', 'direccion_sucursal', 'cargo']

    for c in cols_nombre:
        if c in df.columns: df[c] = df[c].apply(limpiar_nombre)
    for c in cols_dni:
        if c in df.columns: df[c] = df[c].apply(limpiar_dni)
    for c in cols_telefono:
        if c in df.columns: df[c] = df[c].apply(limpiar_telefono)
    for c in cols_correo:
        if c in df.columns: df[c] = df[c].apply(limpiar_correo)
    for c in cols_monto:
        if c in df.columns: df[c] = df[c].apply(limpiar_monto)
    for c in cols_fecha:
        if c in df.columns: df[c] = df[c].apply(limpiar_fecha)
    for c in cols_texto:
        if c in df.columns: df[c] = df[c].apply(limpiar_texto)

    # Montos negativos → 0
    for c in cols_monto:
        if c in df.columns:
            neg = (df[c] < 0).sum()
            if neg:
                print(f"  [AVISO] {neg} valores negativos en '{c}' → convertidos a 0")
                df.loc[df[c] < 0, c] = 0.0

    print(f"  Filas después de limpiar: {len(df)}")
    nulos = df.isnull().sum()
    nulos = nulos[nulos > 0]
    if not nulos.empty:
        print("  Nulos restantes:")
        print(nulos.to_string())
    print("  [OK] Limpieza completada.")
    return df



#  3. TRANSFORMACIÓN  (una tabla plana → tablas normalizadas)


def transformar(df):
    print("\n── FASE 2: TRANSFORMACIÓN ──────────────────────────────")

    tablas = {}

    # ── Sucursal ──────────────────────────────────────────────
    if 'nombre_sucursal' in df.columns:
        cols = ['nombre_sucursal']
        if 'direccion_sucursal' in df.columns:
            cols.append('direccion_sucursal')
        suc = (df[cols].drop_duplicates(subset=['nombre_sucursal'])
               .reset_index(drop=True))
        suc.insert(0, 'sucursal_id', range(1, len(suc) + 1))
        suc.rename(columns={'nombre_sucursal': 'nombre',
                             'direccion_sucursal': 'direccion'}, inplace=True)
        tablas['sucursal'] = suc
        print(f"  sucursal     : {len(suc)} filas")

    # ── Cliente ───────────────────────────────────────────────
    col_dni = next((c for c in ['cliente_dni', 'dni', 'dpi'] if c in df.columns), None)
    col_nom = next((c for c in ['nombre_cliente', 'nombre'] if c in df.columns), None)
    if col_dni and col_nom:
        cols = [col_dni, col_nom]
        for opt in ['fecha_nacimiento', 'direccion', 'telefono',
                    'correo', 'correo_electronico', 'email']:
            if opt in df.columns:
                cols.append(opt)
        cli = (df[cols].drop_duplicates(subset=[col_dni])
               .reset_index(drop=True))
        cli.rename(columns={col_dni: 'dni', col_nom: 'nombre'}, inplace=True)
        tablas['cliente'] = cli
        print(f"  cliente      : {len(cli)} filas")

    # ── Empleado ──────────────────────────────────────────────
    col_emp = next((c for c in ['nombre_empleado'] if c in df.columns), None)
    if col_emp:
        cols = [col_emp]
        for opt in ['empleado_id', 'cargo', 'nombre_sucursal']:
            if opt in df.columns:
                cols.append(opt)
        emp = (df[cols].drop_duplicates(subset=[col_emp])
               .reset_index(drop=True))
        if 'empleado_id' not in emp.columns:
            emp.insert(0, 'empleado_id', range(1, len(emp) + 1))
        emp.rename(columns={col_emp: 'nombre'}, inplace=True)
        # Mapear sucursal_id
        if 'nombre_sucursal' in emp.columns and 'sucursal' in tablas:
            emp = emp.merge(tablas['sucursal'][['sucursal_id', 'nombre']],
                            left_on='nombre_sucursal', right_on='nombre',
                            how='left', suffixes=('', '_suc'))
            emp.drop(columns=['nombre_sucursal', 'nombre_suc'], inplace=True)
        tablas['empleado'] = emp
        print(f"  empleado     : {len(emp)} filas")

    # ── Cuenta ────────────────────────────────────────────────
    if 'tipo_cuenta' in df.columns and col_dni:
        cols = [col_dni, 'tipo_cuenta']
        for opt in ['cuenta_id', 'numero_cuenta', 'saldo_inicial',
                    'saldo_actual', 'fecha_apertura', 'nombre_sucursal']:
            if opt in df.columns:
                cols.append(opt)
        cta = df[cols].drop_duplicates().reset_index(drop=True)
        if 'cuenta_id' not in cta.columns and 'numero_cuenta' not in cta.columns:
            cta.insert(0, 'cuenta_id', range(1, len(cta) + 1))
        cta.rename(columns={col_dni: 'cliente_dni'}, inplace=True)
        if 'nombre_sucursal' in cta.columns and 'sucursal' in tablas:
            cta = cta.merge(tablas['sucursal'][['sucursal_id', 'nombre']],
                            left_on='nombre_sucursal', right_on='nombre',
                            how='left')
            cta.drop(columns=['nombre', 'nombre_sucursal'], inplace=True)
        cta['estado'] = 'activa'
        if 'fecha_apertura' not in cta.columns:
            cta['fecha_apertura'] = pd.Timestamp.today().strftime('%Y-%m-%d')
        tablas['cuenta'] = cta
        print(f"  cuenta       : {len(cta)} filas")

    # ── Transaccion ───────────────────────────────────────────
    if 'tipo_transaccion' in df.columns and 'monto' in df.columns:
        cols = ['tipo_transaccion', 'monto']
        for opt in ['cuenta_id', 'numero_cuenta', 'descripcion',
                    'fecha_transaccion', 'empleado_id']:
            if opt in df.columns:
                cols.append(opt)
        trx = df[cols].copy().reset_index(drop=True)
        trx.insert(0, 'transaccion_id', range(1, len(trx) + 1))
        if 'fecha_transaccion' not in trx.columns:
            trx['fecha_transaccion'] = pd.Timestamp.today().strftime('%Y-%m-%d')
        if 'descripcion' not in trx.columns:
            trx['descripcion'] = trx['tipo_transaccion']
        tablas['transaccion'] = trx
        print(f"  transaccion  : {len(trx)} filas")

    # Guardar CSVs procesados
    os.makedirs(PROCESSED_PATH, exist_ok=True)
    for nombre, tabla in tablas.items():
        ruta = os.path.join(PROCESSED_PATH, f"{nombre}.csv")
        tabla.to_csv(ruta, index=False, encoding='utf-8')

    print("  [OK] Transformación completada. CSVs guardados en data/processed/")
    return tablas



#  4. CARGA A MYSQL


# Orden de inserción respetando llaves foráneas
ORDEN_CARGA = ['sucursal', 'cliente', 'empleado', 'cuenta', 'transaccion']


def cargar(engine, tablas):
    print("\n── FASE 3: CARGA A MySQL ───────────────────────────────")
    for nombre in ORDEN_CARGA:
        df = tablas.get(nombre)
        if df is None or df.empty:
            print(f"  [OMITIDA] {nombre}")
            continue
        try:
            df.to_sql(nombre, con=engine, if_exists='append',
                      index=False, chunksize=500, method='multi')
            print(f"  [OK] {nombre:12s}: {len(df)} filas insertadas")
        except SQLAlchemyError as e:
            print(f"  [ERROR] {nombre}: {e}")
            raise



#  5. VALIDACIÓN


def validar(engine, tablas):
    print("\n── FASE 4: VALIDACIÓN ──────────────────────────────────")
    todos_ok = True
    for nombre in ORDEN_CARGA:
        df = tablas.get(nombre)
        if df is None:
            continue
        try:
            with engine.connect() as conn:
                en_bd = conn.execute(text(f"SELECT COUNT(*) FROM {nombre}")).scalar()
            esperadas = len(df)
            estado = "✓" if en_bd == esperadas else "✗ DIFERENCIA"
            if en_bd != esperadas:
                todos_ok = False
            print(f"  {nombre:12s}: esperadas={esperadas:5d}  en BD={en_bd:5d}  {estado}")
        except SQLAlchemyError as e:
            print(f"  [ERROR al validar] {nombre}: {e}")
            todos_ok = False

    if todos_ok:
        print("\n  [OK] Todos los datos migrados correctamente.")
    else:
        print("\n  [ADVERTENCIA] Hay diferencias. Revisar logs.")


#  MAIN

def main():
    print("=" * 55)
    print("  MIGRACIÓN DE DATOS — Proyecto BD2, Grupo 14")
    print("=" * 55)

    # Conexión
    engine = crear_engine()

    # Leer CSV original
    print(f"\n[INFO] Leyendo CSV: {RAW_PATH}")
    if not os.path.exists(RAW_PATH):
        print(f"[ERROR] No se encontró el archivo: {RAW_PATH}")
        print("  Coloca el CSV en data/raw/ con el nombre indicado en CSV_FILENAME del .env")
        sys.exit(1)

    try:
        df = pd.read_csv(RAW_PATH, encoding='utf-8')
    except UnicodeDecodeError:
        df = pd.read_csv(RAW_PATH, encoding='latin-1')
        print("[AVISO] Se usó encoding latin-1")

    print(f"  {len(df)} filas, {len(df.columns)} columnas")

    # Pipeline
    df_limpio = limpiar(df)
    tablas    = transformar(df_limpio)
    cargar(engine, tablas)
    validar(engine, tablas)

    print("\n" + "=" * 55)
    print("  Migración finalizada.")
    print("=" * 55)


if __name__ == "__main__":
    main()