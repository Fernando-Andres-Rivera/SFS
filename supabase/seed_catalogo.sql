-- ============================================================
-- SFS - Catalogo base
-- Los 7 ejes de la metodologia. Es estructura, no datos de
-- ejemplo: sin esto la aplicacion no tiene tableros ni permite
-- crear indicadores. Se carga en TODA instancia, incluidas las
-- productivas de cliente.
-- ============================================================

-- ------------------------------------------------------------
-- Catálogo de ejes (compartido entre todos los tenants)
-- ------------------------------------------------------------
insert into axes (id, code, name, color, icon, sort_order) values
  ('a0000000-0000-0000-0000-000000000001', 'seguridad',     'Seguridad',      '#F57C00', 'shield',     1),
  ('a0000000-0000-0000-0000-000000000002', 'mantenimiento', 'Mantenimiento',  '#1B365D', 'wrench',     2),
  ('a0000000-0000-0000-0000-000000000003', 'calidad',       'Calidad',        '#26A69A', 'check-circle',3),
  ('a0000000-0000-0000-0000-000000000004', 'disponibilidad','Disponibilidad', '#1B365D', 'activity',   4),
  ('a0000000-0000-0000-0000-000000000005', 'costos',        'Costos',         '#F57C00', 'dollar-sign',5),
  ('a0000000-0000-0000-0000-000000000006', 'estandar',      'Estándar',       '#B0B6BD', 'list-checks',6),
  ('a0000000-0000-0000-0000-000000000007', 'personas',      'Personas',       '#26A69A', 'users',      7)
on conflict (id) do nothing;
