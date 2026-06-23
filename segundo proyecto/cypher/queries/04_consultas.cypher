// ============================================================
// 04_consultas.cypher
//
// Las 9 consultas de negocio obligatorias.
// Cada consulta está documentada con propósito, parámetros
// y resultado esperado.
// ============================================================


// ──────────────────────────────────────────────
// CONSULTA 1: Diversidad de tipos de cocina por restaurante
//
// Propósito: Medir cuántos tipos de cocina distintos ofrece
//            cada restaurante, ordenados de mayor a menor.
// Resultado: restaurante, cantidadTipos
// ──────────────────────────────────────────────
MATCH (r:Restaurante)-[:PERTENECE_A]->(t:TipoCocina)
RETURN r.nombre        AS restaurante,
       count(t)        AS cantidadTipos,
       collect(t.nombre) AS tiposCocina
ORDER BY cantidadTipos DESC
LIMIT 20;


// ──────────────────────────────────────────────
// CONSULTA 2: Tasa de reservas por restaurante
//
// Propósito: Calcular el porcentaje de visitas que se
//            realizaron CON reserva previa en cada restaurante.
// Resultado: restaurante, totalVisitas, visitasConReserva, tasaReserva%
// ──────────────────────────────────────────────
MATCH (u:Usuario)-[v:VISITÓ]->(r:Restaurante)
WITH r,
     count(v)                                        AS totalVisitas,
     sum(CASE WHEN v.conReserva THEN 1 ELSE 0 END)  AS visitasConReserva
RETURN r.nombre       AS restaurante,
       totalVisitas,
       visitasConReserva,
       round(100.0 * visitasConReserva / totalVisitas, 2) AS tasaReservaPct
ORDER BY tasaReservaPct DESC
LIMIT 20;


// ──────────────────────────────────────────────
// CONSULTA 3: Usuarios con mayor gasto promedio por visita
//
// Propósito: Identificar los usuarios que tienen mayor
//            gasto promedio en sus visitas a restaurantes.
// Resultado: usuario, pais, totalVisitas, gastoPromedio
// ──────────────────────────────────────────────
MATCH (u:Usuario)-[v:VISITÓ]->(r:Restaurante)
WITH u,
     count(v)      AS totalVisitas,
     avg(v.consumo) AS gastoPromedio
WHERE totalVisitas >= 3
RETURN u.nombre       AS usuario,
       u.pais         AS pais,
       totalVisitas,
       round(gastoPromedio, 2) AS gastoPromedio
ORDER BY gastoPromedio DESC
LIMIT 20;


// ──────────────────────────────────────────────
// CONSULTA 4: Usuarios con mayor frecuencia de visitas
//             en un período de tiempo
//
// Propósito: Identificar los usuarios más frecuentes
//            dentro de un rango de fechas dado.
// Parámetros: fechaInicio = '2023-01-01', fechaFin = '2024-06-01'
// Resultado: usuario, visitasEnPeriodo
// ──────────────────────────────────────────────
WITH date('2023-01-01') AS fechaInicio,
     date('2024-06-01') AS fechaFin
MATCH (u:Usuario)-[v:VISITÓ]->(r:Restaurante)
WHERE v.fechaVisita >= fechaInicio
  AND v.fechaVisita <= fechaFin
WITH u, count(v) AS visitasEnPeriodo
RETURN u.nombre        AS usuario,
       u.pais          AS pais,
       visitasEnPeriodo
ORDER BY visitasEnPeriodo DESC
LIMIT 20;


// ──────────────────────────────────────────────
// CONSULTA 5: Restaurantes sin visitas en los últimos N días
//
// Propósito: Detectar restaurantes inactivos que no han
//            recibido ninguna visita en los últimos N días.
// Parámetro: N = 180 días (≈ 6 meses)
// Resultado: restaurante, ultimaVisita
// ──────────────────────────────────────────────
WITH date() - duration('P180D') AS fechaCorte
MATCH (r:Restaurante)
OPTIONAL MATCH (u:Usuario)-[v:VISITÓ]->(r)
WITH r,
     max(v.fechaVisita) AS ultimaVisita,
     fechaCorte
WHERE ultimaVisita IS NULL
   OR ultimaVisita < fechaCorte
RETURN r.nombre     AS restaurante,
       r.rangoPrecio AS precio,
       ultimaVisita
ORDER BY ultimaVisita ASC
LIMIT 20;


// ──────────────────────────────────────────────
// CONSULTA 6: Chefs con mayor movilidad laboral
//
// Propósito: Determinar qué chefs han trabajado en más
//            restaurantes distintos a lo largo del tiempo.
// Resultado: chef, nacionalidad, cantidadRestaurantes, restaurantes
// ──────────────────────────────────────────────
MATCH (c:Chef)-[:TRABAJA_EN]->(r:Restaurante)
WITH c, count(r) AS cantidadRestaurantes, collect(r.nombre) AS restaurantes
RETURN c.nombre             AS chef,
       c.nacionalidad        AS nacionalidad,
       cantidadRestaurantes,
       restaurantes
ORDER BY cantidadRestaurantes DESC
LIMIT 15;


// ──────────────────────────────────────────────
// CONSULTA 7: Platillos con mayor variación de precio
//             entre restaurantes
//
// Propósito: Detectar platillos cuyo precio varía más
//            entre los distintos restaurantes que lo ofrecen.
// Resultado: platillo, precioMin, precioMax, variacion, cantRestaurantes
// ──────────────────────────────────────────────
MATCH (r:Restaurante)-[o:OFRECE]->(p:Platillo)
WITH p,
     min(o.precio)  AS precioMin,
     max(o.precio)  AS precioMax,
     count(r)       AS cantRestaurantes
WHERE cantRestaurantes >= 2
RETURN p.nombre           AS platillo,
       round(precioMin, 2) AS precioMin,
       round(precioMax, 2) AS precioMax,
       round(precioMax - precioMin, 2) AS variacionPrecio,
       cantRestaurantes
ORDER BY variacionPrecio DESC
LIMIT 15;


// ──────────────────────────────────────────────
// CONSULTA 8: Crecimiento de visitas por tipo de cocina
//             entre dos períodos
//
// Propósito: Comparar el volumen de visitas a restaurantes
//            de cada tipo de cocina entre dos períodos distintos.
// Períodos:  Período A: 2022 | Período B: 2023
// Resultado: tipoCocina, visitasPeriodoA, visitasPeriodoB, crecimiento%
// ──────────────────────────────────────────────
MATCH (u:Usuario)-[v:VISITÓ]->(r:Restaurante)-[:PERTENECE_A]->(t:TipoCocina)
WITH t,
     sum(CASE WHEN v.fechaVisita.year = 2022 THEN 1 ELSE 0 END) AS visitasA,
     sum(CASE WHEN v.fechaVisita.year = 2023 THEN 1 ELSE 0 END) AS visitasB
WHERE visitasA > 0
RETURN t.nombre  AS tipoCocina,
       visitasA  AS visitas2022,
       visitasB  AS visitas2023,
       round(100.0 * (visitasB - visitasA) / visitasA, 2) AS crecimientoPct
ORDER BY crecimientoPct DESC;


// ──────────────────────────────────────────────
// CONSULTA 9: Recomendación de restaurantes basada en
//             chefs compartidos
//
// Propósito: Recomendar restaurantes a un usuario basándose
//            en chefs que trabajan en restaurantes que el usuario
//            calificó bien (≥ 4), pero que aún no ha visitado.
// Parámetro: usuarioId = 'U0001' (cambiar por el ID deseado)
// Resultado: restauranteRecomendado, chefCompartido, puntuacionOrigen
// ──────────────────────────────────────────────
WITH 'U0001' AS uid
MATCH (u:Usuario {usuarioId: uid})-[cal:CALIFICÓ]->(rBien:Restaurante)
WHERE cal.puntuacion >= 4
MATCH (chef:Chef)-[:TRABAJA_EN]->(rBien)
MATCH (chef)-[:TRABAJA_EN]->(rRec:Restaurante)
WHERE rRec <> rBien
  AND NOT (u)-[:VISITÓ]->(rRec)
RETURN DISTINCT
       rRec.nombre        AS restauranteRecomendado,
       rRec.rangoPrecio   AS precio,
       chef.nombre        AS chefCompartido,
       rBien.nombre       AS restauranteOrigenCalificado,
       cal.puntuacion     AS puntuacionOrigen
ORDER BY puntuacionOrigen DESC, restauranteRecomendado
LIMIT 10;
