// ============================================================
// 01_schema.cypher
// Proyecto 2 – Sistema de Recomendación de Restaurantes
// Grupo 14 – BD2 VACJUN26
//
// Crea constraints e índices para garantizar integridad
// y rendimiento en el modelo de grafos.
// Ejecutar PRIMERO antes de cualquier carga de datos.
// ============================================================

// ──────────────────────────────────────────────
// CONSTRAINTS (unicidad de IDs)
// ──────────────────────────────────────────────

CREATE CONSTRAINT constraint_usuario_id IF NOT EXISTS
FOR (u:Usuario) REQUIRE u.usuarioId IS UNIQUE;

CREATE CONSTRAINT constraint_restaurante_id IF NOT EXISTS
FOR (r:Restaurante) REQUIRE r.restauranteId IS UNIQUE;

CREATE CONSTRAINT constraint_tipo_cocina_id IF NOT EXISTS
FOR (t:TipoCocina) REQUIRE t.tipoCocinaId IS UNIQUE;

CREATE CONSTRAINT constraint_chef_id IF NOT EXISTS
FOR (c:Chef) REQUIRE c.chefId IS UNIQUE;

CREATE CONSTRAINT constraint_platillo_id IF NOT EXISTS
FOR (p:Platillo) REQUIRE p.platilloId IS UNIQUE;

// ──────────────────────────────────────────────
// ÍNDICES adicionales para consultas frecuentes
// ──────────────────────────────────────────────

CREATE INDEX index_usuario_nombre IF NOT EXISTS
FOR (u:Usuario) ON (u.nombre);

CREATE INDEX index_usuario_pais IF NOT EXISTS
FOR (u:Usuario) ON (u.pais);

CREATE INDEX index_restaurante_nombre IF NOT EXISTS
FOR (r:Restaurante) ON (r.nombre);

CREATE INDEX index_restaurante_precio IF NOT EXISTS
FOR (r:Restaurante) ON (r.rangoPrecio);

CREATE INDEX index_chef_nombre IF NOT EXISTS
FOR (c:Chef) ON (c.nombre);

CREATE INDEX index_platillo_nombre IF NOT EXISTS
FOR (p:Platillo) ON (p.nombre);

CREATE INDEX index_tipo_cocina_nombre IF NOT EXISTS
FOR (t:TipoCocina) ON (t.nombre);
