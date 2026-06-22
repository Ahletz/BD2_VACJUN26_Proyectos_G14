// ============================================================
// 05_analisis_redes.cypher
// Proyecto 2 – Sistema de Recomendación de Restaurantes
// Grupo 14 – BD2 VACJUN26
//
// Análisis de redes requeridos:
//   1. Rutas más cortas entre usuarios (grados de separación)
//   2. Restaurantes altamente conectados
// ============================================================


// ──────────────────────────────────────────────
// ANÁLISIS 1: Ruta más corta entre dos usuarios
//             (grados de separación)
//
// Propósito: Encontrar cuántos "saltos" de amistad
//            separan a dos usuarios en la red social.
// Parámetros: Cambiar U0001 y U0050 por los IDs deseados.
//
// El shortestPath considera relaciones ES_AMIGO_DE
// con profundidad máxima de 10 saltos.
// ──────────────────────────────────────────────

// Ejemplo 1: Ruta más corta entre dos usuarios específicos
MATCH (u1:Usuario {usuarioId: 'U0001'}),
      (u2:Usuario {usuarioId: 'U0050'})
MATCH path = shortestPath((u1)-[:ES_AMIGO_DE*1..10]-(u2))
RETURN u1.nombre             AS origen,
       u2.nombre             AS destino,
       length(path)          AS gradosSeparacion,
       [n IN nodes(path) | n.nombre] AS rutaNombres;


// Ejemplo 2: Ruta más corta entre dos usuarios diferentes
MATCH (u1:Usuario {usuarioId: 'U0100'}),
      (u2:Usuario {usuarioId: 'U0300'})
MATCH path = shortestPath((u1)-[:ES_AMIGO_DE*1..10]-(u2))
RETURN u1.nombre             AS origen,
       u2.nombre             AS destino,
       length(path)          AS gradosSeparacion,
       [n IN nodes(path) | n.nombre] AS rutaNombres;


// Ejemplo 3: Distribución de grados de separación en la red
// (muestra cuán conectada está la red de usuarios)
MATCH (u1:Usuario), (u2:Usuario)
WHERE u1.usuarioId < u2.usuarioId
WITH u1, u2
LIMIT 200
MATCH path = shortestPath((u1)-[:ES_AMIGO_DE*1..6]-(u2))
RETURN length(path)      AS gradosSeparacion,
       count(path)       AS parejas
ORDER BY gradosSeparacion;


// ──────────────────────────────────────────────
// ANÁLISIS 2: Restaurantes altamente conectados
//
// Propósito: Identificar los restaurantes con mayor
//            número de conexiones en el grafo:
//            - chefs que trabajan en ellos
//            - platillos que ofrecen
//            - tipos de cocina que representan
//            - visitas y calificaciones recibidas
//
// Resultado: restaurante, puntajeConectividad y métricas
// ──────────────────────────────────────────────

// Métrica de conectividad compuesta
MATCH (r:Restaurante)
OPTIONAL MATCH (c:Chef)-[:TRABAJA_EN]->(r)
WITH r, count(DISTINCT c) AS numChefs
OPTIONAL MATCH (r)-[:OFRECE]->(p:Platillo)
WITH r, numChefs, count(DISTINCT p) AS numPlatillos
OPTIONAL MATCH (r)-[:PERTENECE_A]->(t:TipoCocina)
WITH r, numChefs, numPlatillos, count(DISTINCT t) AS numTiposCocina
OPTIONAL MATCH (u:Usuario)-[:VISITÓ]->(r)
WITH r, numChefs, numPlatillos, numTiposCocina, count(*) AS numVisitas
OPTIONAL MATCH (u2:Usuario)-[cal:CALIFICÓ]->(r)
WITH r, numChefs, numPlatillos, numTiposCocina, numVisitas,
     count(cal)   AS numCalificaciones,
     round(avg(cal.puntuacion), 2) AS puntuacionPromedio
RETURN r.nombre        AS restaurante,
       r.rangoPrecio   AS precio,
       numChefs,
       numPlatillos,
       numTiposCocina,
       numVisitas,
       numCalificaciones,
       coalesce(puntuacionPromedio, 0) AS puntuacionPromedio,
       // Puntaje de conectividad: ponderación de todas las métricas
       (numChefs * 3 + numPlatillos * 2 + numTiposCocina * 2
        + numVisitas + numCalificaciones) AS puntajeConectividad
ORDER BY puntajeConectividad DESC
LIMIT 15;


// Top restaurantes por número de chefs (movilidad de talento)
MATCH (c:Chef)-[:TRABAJA_EN]->(r:Restaurante)
WITH r, count(DISTINCT c) AS numChefs, collect(DISTINCT c.nombre) AS chefs
ORDER BY numChefs DESC
LIMIT 10
RETURN r.nombre AS restaurante,
       numChefs,
       chefs;


// Top restaurantes por número de platillos destacados
// (platillos preparados por chefs especializados)
MATCH (c:Chef)-[prep:PREPARA {especialidad: true}]->(p:Platillo)
MATCH (r:Restaurante)-[:OFRECE]->(p)
MATCH (c)-[:TRABAJA_EN]->(r)
WITH r, count(DISTINCT p) AS platillosDestacados,
     collect(DISTINCT p.nombre) AS nombresPlatillos
ORDER BY platillosDestacados DESC
LIMIT 10
RETURN r.nombre            AS restaurante,
       platillosDestacados,
       nombresPlatillos;
