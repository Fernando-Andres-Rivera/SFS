-- ============================================================
-- prevent_admin_consultora_self_grant (migración 20260714000000) bloquea
-- CUALQUIER insert/update con role = 'admin_consultora' a menos que quien
-- ejecuta ya tenga ese rol (current_role_name() = 'admin_consultora').
-- current_role_name() depende de auth.uid(), que es null fuera de una
-- sesión autenticada — exactamente el caso al crear el primer usuario de
-- una base nueva, ya sea vía SQL Editor o vía el Management API. El
-- procedimiento de bootstrap documentado en el README quedaba roto para
-- toda instalación nueva desde esa migración: nadie puede crear el primer
-- admin_consultora, porque hace falta un admin_consultora para crearlo.
--
-- En LPMS nunca se manifestó porque su primer admin_consultora ya existía
-- antes de que este trigger se agregara.
--
-- Se agrega la única excepción legítima: si todavía no existe NINGÚN
-- admin_consultora en toda la base, se permite crear el primero. En cuanto
-- exista uno, esta condición es falsa y la protección original opera sin
-- cambios — nadie más puede auto-otorgarse el rol.
-- ============================================================

create or replace function prevent_admin_consultora_self_grant()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.role = 'admin_consultora'
     and current_role_name() is distinct from 'admin_consultora'
     and exists (select 1 from profiles where role = 'admin_consultora')
  then
    raise exception 'Solo un usuario admin_consultora puede asignar el rol admin_consultora.';
  end if;
  return NEW;
end;
$$;
