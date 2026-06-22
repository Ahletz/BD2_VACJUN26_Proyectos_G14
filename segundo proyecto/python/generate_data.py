import csv
import os
import random
from datetime import date, timedelta

from faker import Faker

# ──────────────────────────────────────────────
# Configuración
# ──────────────────────────────────────────────
SEED = 42
random.seed(SEED)
fake = Faker(["es_MX", "es_ES", "en_US"])
Faker.seed(SEED)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "csv")
os.makedirs(OUTPUT_DIR, exist_ok=True)

N_USUARIOS     = 500
N_RESTAURANTES = 200
N_CHEFS        = 100
N_PLATILLOS    = 50
N_TIPOS_COCINA = 15

# ──────────────────────────────────────────────
# Datos de dominio
# ──────────────────────────────────────────────
TIPOS_COCINA = [
    ("Italiana",     "Pastas, pizzas y risottos con ingredientes mediterráneos."),
    ("Mexicana",     "Tacos, enchiladas y mole con sabores picantes y coloridos."),
    ("Japonesa",     "Sushi, ramen y tempura con presentación minimalista."),
    ("Francesa",     "Alta cocina clásica con salsas elaboradas y repostería fina."),
    ("China",        "Woks, dim sum y sopas con cinco sabores equilibrados."),
    ("Griega",       "Kebabs, tzatziki y ensalada griega con aceite de oliva."),
    ("Española",     "Tapas, paella y tortilla con ingredientes ibéricos."),
    ("India",        "Currys, biryanis y naan con especias aromáticas intensas."),
    ("Peruana",      "Ceviche, lomo saltado y anticuchos con fusión andina."),
    ("Americana",    "Hamburguesas, barbacoa y comfort food de gran tamaño."),
    ("Tailandesa",   "Pad thai, curries verdes y sopas con leche de coco."),
    ("Árabe",        "Falafel, hummus y shawarma con especias del Oriente Medio."),
    ("Guatemalteca", "Pepián, kaq ik y tamales con sabores mayas ancestrales."),
    ("Coreana",      "Bibimbap, bulgogi y kimchi con fermentados tradicionales."),
    ("Mediterránea", "Mariscos, aceitunas y hierbas frescas del mar interior."),
]

RANGOS_PRECIO = ["$", "$$", "$$$", "$$$$"]

PAISES = [
    "Guatemala", "México", "España", "Argentina", "Colombia",
    "Chile", "Perú", "Honduras", "El Salvador", "Costa Rica",
    "Estados Unidos", "Francia", "Italia", "Japón", "China",
]

NACIONALIDADES = [
    "Guatemalteca", "Mexicana", "Española", "Argentina", "Colombiana",
    "Chilena", "Peruana", "Francesa", "Italiana", "Japonesa",
    "Estadounidense", "Coreana", "China", "Tailandesa", "India",
]

PUESTOS_CHEF = [
    "Chef Ejecutivo", "Sous Chef", "Chef de Partie",
    "Chef Pastelero", "Chef de Línea", "Chef Consultor",
]

ESTILOS_PREPARACION = [
    "Tradicional", "Fusión", "Contemporáneo", "Clásico",
    "Minimalista", "Molecular", "Artesanal",
]

NOMBRES_PLATILLOS = [
    "Pasta Carbonara", "Pizza Margherita", "Tacos al Pastor",
    "Sushi Variado", "Ramen de Pollo", "Paella Valenciana",
    "Curry de Cordero", "Ceviche Clásico", "Hamburguesa Gourmet",
    "Pad Thai", "Shawarma de Pollo", "Bibimbap Tradicional",
    "Pepián Rojo", "Croissant de Mantequilla", "Dim Sum Variado",
    "Tortilla Española", "Kebab Mixto", "Biryani de Pollo",
    "Lomo Saltado", "Pollo a la Parmesana", "Risotto de Hongos",
    "Tiramisú", "Crème Brûlée", "Mole Poblano", "Enchiladas Verdes",
    "Tempura de Camarones", "Gyoza de Cerdo", "Falafel con Hummus",
    "Kaq Ik de Chompipe", "Ensalada Griega", "Boeuf Bourguignon",
    "Coq au Vin", "Tostadas de Ceviche", "Chow Mein",
    "Bulgogi Coreano", "Kimchi Jjigae", "Tom Yum de Camarones",
    "Green Curry", "Naan con Tikka Masala", "Bruschetta al Tomate",
    "Carpaccio de Res", "Gazpacho Andaluz", "Paté de Campaña",
    "Fondue Suizo", "Chiles en Nogada", "Pozole Rojo",
    "Caldo de Pollo", "Arroz con Leche", "Churros con Chocolate",
    "Banana Foster",
]

DESCRIPCION_RESTAURANTE_FRASES = [
    "Un lugar donde la tradición y la innovación se fusionan en cada plato.",
    "Sabores auténticos preparados con ingredientes de temporada locales.",
    "Ambiente acogedor ideal para reuniones familiares y cenas románticas.",
    "Cocina de autor con técnicas contemporáneas y raíces tradicionales.",
    "El punto de encuentro de los amantes de la buena mesa.",
    "Una experiencia gastronómica única en el corazón de la ciudad.",
    "Ingredientes frescos, recetas de familia y pasión por la cocina.",
    "Donde cada visita se convierte en un viaje culinario inolvidable.",
    "Alta cocina accesible para todos los paladares.",
    "Menú de temporada con productos locales y sostenibles.",
]


# ──────────────────────────────────────────────
# Utilidades
# ──────────────────────────────────────────────
def rand_date(start: date, end: date) -> str:
    delta = (end - start).days
    return (start + timedelta(days=random.randint(0, delta))).isoformat()


def write_csv(filename: str, fieldnames: list, rows: list) -> None:
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[OK] {filename}: {len(rows)} filas → {path}")


# ──────────────────────────────────────────────
# Generadores de nodos
# ──────────────────────────────────────────────
def gen_tipos_cocina() -> list:
    rows = []
    for i, (nombre, descripcion) in enumerate(TIPOS_COCINA, start=1):
        rows.append({
            "tipoCocinaId": f"TC{i:03d}",
            "nombre":       nombre,
            "descripcion":  descripcion,
        })
    return rows


def gen_usuarios() -> list:
    rows = []
    emails_vistos = set()
    for i in range(1, N_USUARIOS + 1):
        email = fake.unique.email()
        while email in emails_vistos:
            email = fake.email()
        emails_vistos.add(email)
        rows.append({
            "usuarioId": f"U{i:04d}",
            "nombre":    fake.name(),
            "email":     email,
            "edad":      random.randint(18, 70),
            "pais":      random.choice(PAISES),
        })
    return rows


def gen_restaurantes() -> list:
    rows = []
    for i in range(1, N_RESTAURANTES + 1):
        rows.append({
            "restauranteId":  f"R{i:03d}",
            "nombre":         f"Restaurante {fake.company().split(',')[0]}",
            "anioApertura":   random.randint(1990, 2023),
            "rangoPrecio":    random.choice(RANGOS_PRECIO),
            "descripcion":    random.choice(DESCRIPCION_RESTAURANTE_FRASES),
        })
    return rows


def gen_chefs() -> list:
    rows = []
    for i in range(1, N_CHEFS + 1):
        fecha_nac = rand_date(date(1960, 1, 1), date(1998, 12, 31))
        rows.append({
            "chefId":         f"CH{i:03d}",
            "nombre":         fake.name(),
            "fechaNacimiento": fecha_nac,
            "nacionalidad":   random.choice(NACIONALIDADES),
        })
    return rows


def gen_platillos() -> list:
    rows = []
    for i, nombre in enumerate(NOMBRES_PLATILLOS[:N_PLATILLOS], start=1):
        rows.append({
            "platilloId":  f"P{i:03d}",
            "nombre":      nombre,
            "precio":      round(random.uniform(35.0, 350.0), 2),
            "descripcion": fake.sentence(nb_words=10),
        })
    return rows


# ──────────────────────────────────────────────
# Generadores de relaciones
# ──────────────────────────────────────────────
def gen_calificaciones(usuarios: list, restaurantes: list) -> list:
    """CALIFICO: usuario → restaurante"""
    rows = []
    vistos = set()
    for usuario in usuarios:
        n = random.randint(1, 8)
        muestras = random.sample(restaurantes, min(n, len(restaurantes)))
        for rest in muestras:
            clave = (usuario["usuarioId"], rest["restauranteId"])
            if clave in vistos:
                continue
            vistos.add(clave)
            rows.append({
                "usuarioId":     usuario["usuarioId"],
                "restauranteId": rest["restauranteId"],
                "puntuacion":    random.randint(1, 5),
                "fecha":         rand_date(date(2020, 1, 1), date(2024, 6, 1)),
                "comentario":    fake.sentence(nb_words=8),
            })
    return rows


def gen_visitas(usuarios: list, restaurantes: list) -> list:
    """VISITO: usuario → restaurante"""
    rows = []
    for usuario in usuarios:
        n = random.randint(1, 12)
        for _ in range(n):
            rest = random.choice(restaurantes)
            rows.append({
                "usuarioId":     usuario["usuarioId"],
                "restauranteId": rest["restauranteId"],
                "fechaVisita":   rand_date(date(2019, 1, 1), date(2024, 6, 1)),
                "consumo":       round(random.uniform(50.0, 800.0), 2),
                "conReserva":    random.choice(["true", "false"]),
            })
    return rows


def gen_amistades(usuarios: list) -> list:
    """ES_AMIGO_DE: usuario ↔ usuario (no dirigida, sin duplicados)"""
    rows = []
    vistos = set()
    ids = [u["usuarioId"] for u in usuarios]
    for uid in ids:
        n = random.randint(1, 10)
        amigos = random.sample([x for x in ids if x != uid], min(n, len(ids) - 1))
        for amigo in amigos:
            clave = tuple(sorted([uid, amigo]))
            if clave in vistos:
                continue
            vistos.add(clave)
            rows.append({
                "usuarioId1":   uid,
                "usuarioId2":   amigo,
                "fechaAmistad": rand_date(date(2015, 1, 1), date(2024, 1, 1)),
            })
    return rows


def gen_pertenece_a(restaurantes: list, tipos_cocina: list) -> list:
    """PERTENECE_A: restaurante → tipoCocina"""
    rows = []
    tc_ids = [t["tipoCocinaId"] for t in tipos_cocina]
    for rest in restaurantes:
        n = random.randint(1, 3)
        for tc in random.sample(tc_ids, n):
            rows.append({
                "restauranteId": rest["restauranteId"],
                "tipoCocinaId":  tc,
            })
    return rows


def gen_ofrece(restaurantes: list, platillos: list) -> list:
    """OFRECE: restaurante → platillo (sin duplicados por restaurante)"""
    rows = []
    p_ids = [p["platilloId"] for p in platillos]
    for rest in restaurantes:
        n = random.randint(3, min(15, len(p_ids)))
        seleccion = random.sample(p_ids, n)
        for pid in seleccion:
            precio_local = round(random.uniform(35.0, 400.0), 2)
            rows.append({
                "restauranteId": rest["restauranteId"],
                "platilloId":    pid,
                "precio":        precio_local,
                "disponible":    random.choice(["true", "false"]),
            })
    return rows


def gen_prepara(chefs: list, platillos: list) -> list:
    """PREPARA: chef → platillo"""
    rows = []
    p_ids = [p["platilloId"] for p in platillos]
    vistos = set()
    for chef in chefs:
        n = random.randint(2, 8)
        for pid in random.sample(p_ids, min(n, len(p_ids))):
            clave = (chef["chefId"], pid)
            if clave in vistos:
                continue
            vistos.add(clave)
            rows.append({
                "chefId":       chef["chefId"],
                "platilloId":   pid,
                "estilo":       random.choice(ESTILOS_PREPARACION),
                "especialidad": random.choice(["true", "false"]),
            })
    return rows


def gen_trabaja_en(chefs: list, restaurantes: list) -> list:
    """TRABAJA_EN: chef → restaurante"""
    rows = []
    r_ids = [r["restauranteId"] for r in restaurantes]
    vistos = set()
    for chef in chefs:
        n = random.randint(1, 5)
        for rid in random.sample(r_ids, min(n, len(r_ids))):
            clave = (chef["chefId"], rid)
            if clave in vistos:
                continue
            vistos.add(clave)
            fecha_inicio = rand_date(date(2000, 1, 1), date(2023, 1, 1))
            rows.append({
                "chefId":       chef["chefId"],
                "restauranteId": rid,
                "fechaInicio":  fecha_inicio,
                "puesto":       random.choice(PUESTOS_CHEF),
            })
    return rows


def gen_le_gusta(usuarios: list, tipos_cocina: list) -> list:
    """LE_GUSTA: usuario → tipoCocina"""
    rows = []
    tc_ids = [t["tipoCocinaId"] for t in tipos_cocina]
    vistos = set()
    for usuario in usuarios:
        n = random.randint(1, 5)
        for tc in random.sample(tc_ids, n):
            clave = (usuario["usuarioId"], tc)
            if clave in vistos:
                continue
            vistos.add(clave)
            rows.append({
                "usuarioId":    usuario["usuarioId"],
                "tipoCocinaId": tc,
                "nivelInteres": random.randint(1, 5),
            })
    return rows


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
def main():
    print("=" * 60)
    print("GENERACIÓN DE DATOS CSV – PROYECTO 2 BD2 GRUPO 14")
    print("=" * 60)

    # Nodos
    tipos_cocina  = gen_tipos_cocina()
    usuarios      = gen_usuarios()
    restaurantes  = gen_restaurantes()
    chefs         = gen_chefs()
    platillos     = gen_platillos()

    write_csv("tipos_cocina.csv",
              ["tipoCocinaId", "nombre", "descripcion"],
              tipos_cocina)

    write_csv("usuarios.csv",
              ["usuarioId", "nombre", "email", "edad", "pais"],
              usuarios)

    write_csv("restaurantes.csv",
              ["restauranteId", "nombre", "anioApertura", "rangoPrecio", "descripcion"],
              restaurantes)

    write_csv("chefs.csv",
              ["chefId", "nombre", "fechaNacimiento", "nacionalidad"],
              chefs)

    write_csv("platillos.csv",
              ["platilloId", "nombre", "precio", "descripcion"],
              platillos)

    # Relaciones
    calificaciones = gen_calificaciones(usuarios, restaurantes)
    write_csv("calificaciones.csv",
              ["usuarioId", "restauranteId", "puntuacion", "fecha", "comentario"],
              calificaciones)

    visitas = gen_visitas(usuarios, restaurantes)
    write_csv("visitas.csv",
              ["usuarioId", "restauranteId", "fechaVisita", "consumo", "conReserva"],
              visitas)

    amistades = gen_amistades(usuarios)
    write_csv("amistades.csv",
              ["usuarioId1", "usuarioId2", "fechaAmistad"],
              amistades)

    pertenece = gen_pertenece_a(restaurantes, tipos_cocina)
    write_csv("pertenece_a.csv",
              ["restauranteId", "tipoCocinaId"],
              pertenece)

    ofrece = gen_ofrece(restaurantes, platillos)
    write_csv("ofrece.csv",
              ["restauranteId", "platilloId", "precio", "disponible"],
              ofrece)

    prepara = gen_prepara(chefs, platillos)
    write_csv("prepara.csv",
              ["chefId", "platilloId", "estilo", "especialidad"],
              prepara)

    trabaja = gen_trabaja_en(chefs, restaurantes)
    write_csv("trabaja_en.csv",
              ["chefId", "restauranteId", "fechaInicio", "puesto"],
              trabaja)

    le_gusta = gen_le_gusta(usuarios, tipos_cocina)
    write_csv("le_gusta.csv",
              ["usuarioId", "tipoCocinaId", "nivelInteres"],
              le_gusta)

    print("=" * 60)
    print("RESUMEN")
    print(f"  Tipos de cocina : {len(tipos_cocina)}")
    print(f"  Usuarios        : {len(usuarios)}")
    print(f"  Restaurantes    : {len(restaurantes)}")
    print(f"  Chefs           : {len(chefs)}")
    print(f"  Platillos       : {len(platillos)}")
    print(f"  CALIFICÓ        : {len(calificaciones)}")
    print(f"  VISITÓ          : {len(visitas)}")
    print(f"  ES_AMIGO_DE     : {len(amistades)}")
    print(f"  PERTENECE_A     : {len(pertenece)}")
    print(f"  OFRECE          : {len(ofrece)}")
    print(f"  PREPARA         : {len(prepara)}")
    print(f"  TRABAJA_EN      : {len(trabaja)}")
    print(f"  LE_GUSTA        : {len(le_gusta)}")
    print("=" * 60)
    print("CSVs generados en: data/csv/")


if __name__ == "__main__":
    main()