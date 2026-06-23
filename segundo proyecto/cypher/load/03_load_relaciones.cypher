
// Ejecutar DESPUÉS de 02_load_nodos.cypher.
// ============================================================

// ──────────────────────────────────────────────
// CALIFICÓ: Usuario -[CALIFICÓ]-> Restaurante
// Propiedades: puntuacion, fecha, comentario
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///calificaciones.csv' AS row
CALL {
  WITH row
  MATCH (u:Usuario      {usuarioId:     row.usuarioId})
  MATCH (r:Restaurante  {restauranteId: row.restauranteId})
  MERGE (u)-[rel:CALIFICÓ {usuarioId: row.usuarioId, restauranteId: row.restauranteId}]->(r)
  SET rel.puntuacion = toInteger(row.puntuacion),
      rel.fecha      = date(row.fecha),
      rel.comentario = row.comentario
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// VISITÓ: Usuario -[VISITÓ]-> Restaurante
// Propiedades: fechaVisita, consumo, conReserva
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///visitas.csv' AS row
CALL {
  WITH row
  MATCH (u:Usuario      {usuarioId:     row.usuarioId})
  MATCH (r:Restaurante  {restauranteId: row.restauranteId})
  CREATE (u)-[:VISITÓ {
    fechaVisita: date(row.fechaVisita),
    consumo:     toFloat(row.consumo),
    conReserva:  (row.conReserva = 'true')
  }]->(r)
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// ES_AMIGO_DE: Usuario -[ES_AMIGO_DE]-> Usuario
// Propiedades: fechaAmistad
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///amistades.csv' AS row
CALL {
  WITH row
  MATCH (u1:Usuario {usuarioId: row.usuarioId1})
  MATCH (u2:Usuario {usuarioId: row.usuarioId2})
  MERGE (u1)-[rel:ES_AMIGO_DE]-(u2)
  SET rel.fechaAmistad = date(row.fechaAmistad)
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// PERTENECE_A: Restaurante -[PERTENECE_A]-> TipoCocina
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///pertenece_a.csv' AS row
CALL {
  WITH row
  MATCH (r:Restaurante {restauranteId: row.restauranteId})
  MATCH (t:TipoCocina  {tipoCocinaId:  row.tipoCocinaId})
  MERGE (r)-[:PERTENECE_A]->(t)
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// OFRECE: Restaurante -[OFRECE]-> Platillo
// Propiedades: precio, disponible
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///ofrece.csv' AS row
CALL {
  WITH row
  MATCH (r:Restaurante {restauranteId: row.restauranteId})
  MATCH (p:Platillo    {platilloId:    row.platilloId})
  MERGE (r)-[rel:OFRECE]->(p)
  SET rel.precio     = toFloat(row.precio),
      rel.disponible = (row.disponible = 'true')
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// PREPARA: Chef -[PREPARA]-> Platillo
// Propiedades: estilo, especialidad
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///prepara.csv' AS row
CALL {
  WITH row
  MATCH (c:Chef    {chefId:     row.chefId})
  MATCH (p:Platillo {platilloId: row.platilloId})
  MERGE (c)-[rel:PREPARA]->(p)
  SET rel.estilo      = row.estilo,
      rel.especialidad = (row.especialidad = 'true')
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// TRABAJA_EN: Chef -[TRABAJA_EN]-> Restaurante
// Propiedades: fechaInicio, puesto
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///trabaja_en.csv' AS row
CALL {
  WITH row
  MATCH (c:Chef        {chefId:        row.chefId})
  MATCH (r:Restaurante {restauranteId: row.restauranteId})
  MERGE (c)-[rel:TRABAJA_EN]->(r)
  SET rel.fechaInicio = date(row.fechaInicio),
      rel.puesto      = row.puesto
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// LE_GUSTA: Usuario -[LE_GUSTA]-> TipoCocina
// Propiedades: nivelInteres
// ──────────────────────────────────────────────
:auto LOAD CSV WITH HEADERS FROM 'file:///le_gusta.csv' AS row
CALL {
  WITH row
  MATCH (u:Usuario    {usuarioId:    row.usuarioId})
  MATCH (t:TipoCocina {tipoCocinaId: row.tipoCocinaId})
  MERGE (u)-[rel:LE_GUSTA]->(t)
  SET rel.nivelInteres = toInteger(row.nivelInteres)
} IN TRANSACTIONS OF 500 ROWS;

// ──────────────────────────────────────────────
// Validación de carga
// ──────────────────────────────────────────────
MATCH (n) RETURN labels(n)[0] AS Etiqueta, count(n) AS Total
ORDER BY Total DESC;

MATCH ()-[r]->() RETURN type(r) AS Relacion, count(r) AS Total
ORDER BY Total DESC;
