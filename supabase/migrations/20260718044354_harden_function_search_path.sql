-- ============================================================
-- Endurecimiento de seguridad: 2 funciones (set_updated_at,
-- fn_action_plan_reabrir) no tenían search_path fijo — el linter de
-- Supabase lo marca porque una función sin search_path fijo puede
-- resolver referencias a objetos de un esquema distinto al esperado si
-- alguien manipula el search_path de la sesión. No cambia ningún
-- comportamiento (ambas solo referencian objetos de public).
--
-- fn_action_plan_reabrir no la crea ninguna migración: es una función
-- creada a mano en el proyecto original, nunca capturada en el historial,
-- y el frontend no la invoca (sin referencias en src/). El ALTER se
-- condiciona a que exista, para que una instalación nueva no falle.
-- ============================================================

alter function public.set_updated_at() set search_path = public;

do $$
begin
  if to_regprocedure('public.fn_action_plan_reabrir()') is not null then
    alter function public.fn_action_plan_reabrir() set search_path = public;
  end if;
end $$;
