-- ============================================================
-- Regresión: la migración 20260808000000_public_signup_demo_provisioning
-- redefinió handle_new_user() (create or replace function) para agregar
-- is_demo, pero al hacerlo perdió el chequeo de skip_demo_org que
-- 20260730000001_skip_demo_org_on_invited_users había agregado
-- específicamente para evitar que el trigger corriera para los usuarios
-- creados por invite-user.
--
-- Efecto en vivo: invite-user llama admin.createUser() (no
-- inviteUserByEmail, así que invited_at queda null) con
-- user_metadata.skip_demo_org = true, y LUEGO inserta el perfil en una
-- llamada aparte. Entre esas dos llamadas el trigger on_auth_user_created
-- ya se disparó y, sin el chequeo de skip_demo_org, tomó la rama de
-- auto-registro público: creó una organización "Demo — {nombre}" y un
-- perfil admin_cliente para ese id. El INSERT de invite-user choca después
-- con ese perfil ya creado (mismo id, unique constraint) y falla con
-- "duplicate key value violates unique constraint profiles_pkey" —
-- reproducido en vivo al crear el primer admin_consultora de esta
-- instancia con el mismo patrón que usa invite-user.
--
-- Se restaura el chequeo, conservando el resto del cuerpo (incluido
-- is_demo) tal como quedó en 20260808000000.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_org_id uuid;
  v_full_name text;
begin
  if new.invited_at is not null then
    return new;
  end if;

  if (new.raw_user_meta_data->>'skip_demo_org') = 'true' then
    return new;
  end if;

  if exists (select 1 from profiles where id = new.id) then
    return new;
  end if;

  v_full_name := coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), new.email);

  insert into organizations (name, industry, is_demo, active)
  values ('Demo — ' || v_full_name, 'Demo', true, true)
  returning id into v_org_id;

  insert into profiles (id, organization_id, role, full_name, email)
  values (new.id, v_org_id, 'admin_cliente', v_full_name, new.email);

  insert into sites (organization_id, name)
  values (v_org_id, 'Sitio Demo');

  insert into organization_axes (organization_id, axis_id, active)
  select v_org_id, id, true from axes;

  insert into units (organization_id, name, created_by)
  select v_org_id, u.name, new.id
  from (values ('%'),('horas'),('horas-hombre'),('días'),('turnos'),
    ('accidentes'),('defectos'),('unidades no conformes'),('paradas'),
    ('minutos'),('kg'),('litros'),('$'),('ppm'),('piezas'),('puntos')) as u(name);

  return new;
end;
$$;
