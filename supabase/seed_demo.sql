-- ============================================================
-- SFS - Datos de demostracion
-- Organizacion demo, sitio, indicadores en cascada y metas.
-- SOLO para entornos de demostracion, formacion o pruebas.
-- NUNCA en la instancia productiva de un cliente.
-- Requiere haber cargado antes seed_catalogo.sql.
-- ============================================================

-- ------------------------------------------------------------
-- Organización demo + sitio
-- ------------------------------------------------------------
insert into organizations (id, name, industry, active) values
  ('00000000-0000-0000-0000-000000000001', 'LeanProLogistic Demo', 'Logística', true)
on conflict (id) do nothing;

insert into sites (id, organization_id, name, address, active) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Planta Bogotá', 'Bogotá, Colombia', true)
on conflict (id) do nothing;

-- Todos los 7 ejes activos para la organización demo
insert into organization_axes (organization_id, axis_id, active)
select '00000000-0000-0000-0000-000000000001', id, true from axes
on conflict (organization_id, axis_id) do nothing;

-- ------------------------------------------------------------
-- Nota: los perfiles (profiles) se crean después de registrar
-- los usuarios en Supabase Auth — ver README del módulo Auth.
-- Los indicadores de ejemplo se crean sin responsable asignado
-- (responsible_id null) para no depender de usuarios existentes.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Cascada de ejemplo — eje Seguridad
-- Nivel 1 (operativo, por sitio) -> Nivel 2 (administrativo, por sitio) -> Nivel 3 (gerencial, corporativo)
-- ------------------------------------------------------------
insert into indicators (
  id, organization_id, site_id, axis_id, level, name, definition, calculation_formula,
  unit, frequency, improvement_direction, active
) values
  (
    'b0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    1,
    'Accidentes por turno',
    'Número de accidentes registrados en cada turno de producción.',
    'Conteo de accidentes reportados en el turno',
    'accidentes',
    'diaria',
    'menor_mejor',
    true
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    2,
    'Tasa de accidentalidad mensual',
    'Accidentes acumulados en el mes por cada 100 trabajadores.',
    '(accidentes del mes / trabajadores) * 100',
    '%',
    'mensual',
    'menor_mejor',
    true
  ),
  (
    'b0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    null,
    'a0000000-0000-0000-0000-000000000001',
    3,
    'Índice de seguridad corporativo anual',
    'Indicador gerencial (KBI) que consolida la accidentalidad de todas las plantas en el año.',
    'Promedio ponderado de la tasa de accidentalidad mensual de todos los sitios',
    '%',
    'mensual',
    'menor_mejor',
    true
  )
on conflict (id) do nothing;

insert into indicator_links (child_indicator_id, parent_indicator_id) values
  ('b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002'),
  ('b0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000003')
on conflict (child_indicator_id, parent_indicator_id) do nothing;

-- ------------------------------------------------------------
-- Un indicador Nivel 1 de ejemplo por cada uno de los otros 6 ejes
-- ------------------------------------------------------------
insert into indicators (
  id, organization_id, site_id, axis_id, level, name, definition, calculation_formula,
  unit, frequency, improvement_direction, active
) values
  (
    'b0000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000002',
    1,
    'Paradas no programadas por avería',
    'Número de paradas de línea no programadas por falla de equipo.',
    'Conteo de paradas por avería en el turno',
    'paradas',
    'diaria',
    'menor_mejor',
    true
  ),
  (
    'b0000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000003',
    1,
    'Unidades no conformes por turno',
    'Número de unidades rechazadas por control de calidad en el turno.',
    'Conteo de unidades no conformes',
    'unidades',
    'diaria',
    'menor_mejor',
    true
  ),
  (
    'b0000000-0000-0000-0000-000000000012',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000004',
    1,
    'Disponibilidad de línea',
    'Porcentaje de tiempo que la línea estuvo disponible para producir en el turno.',
    '(tiempo disponible / tiempo programado) * 100',
    '%',
    'diaria',
    'mayor_mejor',
    true
  ),
  (
    'b0000000-0000-0000-0000-000000000013',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000005',
    1,
    'Costo de reproceso diario',
    'Costo asociado a unidades reprocesadas en el turno.',
    'Suma del costo de reproceso del turno',
    'COP',
    'diaria',
    'menor_mejor',
    true
  ),
  (
    'b0000000-0000-0000-0000-000000000014',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000006',
    1,
    'Cumplimiento de auditoría 5S',
    'Porcentaje de cumplimiento del checklist 5S del puesto de trabajo.',
    '(ítems cumplidos / ítems evaluados) * 100',
    '%',
    'semanal',
    'mayor_mejor',
    true
  ),
  (
    'b0000000-0000-0000-0000-000000000015',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000007',
    1,
    'Ausentismo diario',
    'Porcentaje de trabajadores ausentes respecto al total programado en el turno.',
    '(ausentes / programados) * 100',
    '%',
    'diaria',
    'menor_mejor',
    true
  )
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- Targets de ejemplo (año en curso) para la cascada de Seguridad
-- ------------------------------------------------------------
insert into targets (indicator_id, period_year, period_month, target_value) values
  ('b0000000-0000-0000-0000-000000000001', 2026, null, 0),
  ('b0000000-0000-0000-0000-000000000002', 2026, null, 1.5),
  ('b0000000-0000-0000-0000-000000000003', 2026, null, 1.0)
on conflict do nothing;
