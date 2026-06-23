// ============================================================
// 02_load_nodos.cypher
//  Sistema de Recomendación de Restaurantes
//
// Carga masiva de nodos desde archivos CSV.
// Requiere que los archivos CSV estén en el directorio
// import/ de Neo4j (neo4j/import/).
//
// Ejecutar 01_schema.cypher primero.
// Ajusta la ruta base si usas Neo4j Desktop:
//   File > Open Folder > Import
// ============================================================

// ──────────────────────────────────────────────
// TipoCocina
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///tipos_cocina.csv' AS row
CALL {
  WITH row
  MERGE (t:TipoCocina {tipoCocinaId: row.tipoCocinaId})
  SET t.nombre      = row.nombre,
      t.descripcion = row.descripcion
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// Usuario
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///usuarios.csv' AS row
CALL {
  WITH row
  MERGE (u:Usuario {usuarioId: row.usuarioId})
  SET u.nombre = row.nombre,
      u.email  = row.email,
      u.edad   = toInteger(row.edad),
      u.pais   = row.pais
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// Restaurante
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///restaurantes.csv' AS row
CALL {
  WITH row
  MERGE (r:Restaurante {restauranteId: row.restauranteId})
  SET r.nombre       = row.nombre,
      r.anioApertura = toInteger(row.anioApertura),
      r.rangoPrecio  = row.rangoPrecio,
      r.descripcion  = row.descripcion
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// Chef
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///chefs.csv' AS row
CALL {
  WITH row
  MERGE (c:Chef {chefId: row.chefId})
  SET c.nombre          = row.nombre,
      c.fechaNacimiento = date(row.fechaNacimiento),
      c.nacionalidad    = row.nacionalidad
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// Platillo
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///platillos.csv' AS row
CALL {
  WITH row
  MERGE (p:Platillo {platilloId: row.platilloId})
  SET p.nombre      = row.nombre,
      p.precio      = toFloat(row.precio),
      p.descripcion = row.descripcion
} IN TRANSACTIONS OF 500 ROWS;
