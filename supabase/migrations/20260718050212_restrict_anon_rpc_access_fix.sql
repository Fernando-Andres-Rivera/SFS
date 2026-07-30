-- ============================================================
-- Corrige 20260718050105_restrict_anon_rpc_access.sql: esa migración
-- revocó EXECUTE solo del rol `anon`, pero Postgres otorga EXECUTE a
-- PUBLIC (todos los roles) por defecto al crear una función — revocar de
-- un rol puntual no quita el acceso heredado vía PUBLIC. Hay que revocar
-- de PUBLIC explícitamente y re-otorgar solo a `authenticated` donde
-- corresponde (las políticas RLS lo ejecutan en su nombre).
--
-- gemba_user_has_location_site y fn_gemba_generar_plan no las crea ninguna
-- migración: son funciones creadas a mano en el proyecto original, nunca
-- capturadas en el historial, y el frontend no las invoca. Se condicionan
-- a que existan, para que una instalación nueva no falle.
-- ============================================================

revoke execute on function public.current_org_id() from public;
grant execute on function public.current_org_id() to authenticated;

revoke execute on function public.current_role_name() from public;
grant execute on function public.current_role_name() to authenticated;

revoke execute on function public.user_has_site(uuid) from public;
grant execute on function public.user_has_site(uuid) to authenticated;

-- Funciones de trigger: nadie debe poder invocarlas directo por API.
revoke execute on function public.prevent_admin_consultora_self_grant() from public;

do $$
begin
  if to_regprocedure('public.gemba_user_has_location_site(uuid)') is not null then
    revoke execute on function public.gemba_user_has_location_site(uuid) from public;
    grant execute on function public.gemba_user_has_location_site(uuid) to authenticated;
  end if;
  if to_regprocedure('public.fn_gemba_generar_plan()') is not null then
    revoke execute on function public.fn_gemba_generar_plan() from public;
  end if;
end $$;
