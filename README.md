# SFS — Systematic Form of Service

Sistema de gestión de desempeño para operaciones industriales: indicadores en
cascada por nivel, captura diaria de mediciones, análisis causal, planes de
acción y tableros de reunión. Multi-tenant, con aislamiento por organización
aplicado en la base de datos (RLS de Postgres), no en el frontend.

SFS es una réplica de LPMS y arranca con su mismo código base. Su
infraestructura, en cambio, es **independiente**: repositorio y proyecto de
Supabase propios. Ver [Estado actual](#estado-actual).

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | React 19 + TypeScript, Vite 8, React Router 7, Recharts |
| Backend | Supabase (Postgres + Auth + Edge Functions en Deno) |
| Autorización | Row Level Security por organización y rol |
| Hosting | Vercel (frontend estático) |

## Estado actual

- ✅ Código completo: ~20 módulos funcionales, 55 migraciones, 3 Edge Functions.
- ✅ **GitHub**: repositorio propio (`SFS`), distinto al de LPMS.
- ✅ **Supabase**: proyecto propio (`yjyvqvdyebbvftdniuax`, en una organización
  de Supabase distinta a la de LPMS). Las 55 migraciones están aplicadas y las
  3 Edge Functions desplegadas. **Las dos apps no comparten base de datos.**
- ✅ **Cloudflare Turnstile**: widget propio, atado a los dominios de SFS.
- ⚠️ **Vercel**: el proyecto `sfs` es propio, pero vive en la **misma cuenta de
  Vercel que `lpms`** (equipo `lean-performance-management-system`). Es el
  único punto que SFS todavía comparte con LPMS: facturación, miembros del
  equipo y, sobre todo, los dominios por defecto llevan el nombre de LPMS
  (`sfs-lean-performance-management-system.vercel.app`). Ver
  [DEPLOYMENT.md](DEPLOYMENT.md) §2.

El procedimiento de cada pieza está en [DEPLOYMENT.md](DEPLOYMENT.md).

Para vender e implantar SFS en clientes —topología por cliente, aprovisionamiento,
traspaso de la gestión, formación y empaquetado comercial— ver
[docs/PLAYBOOK-CLIENTES.md](docs/PLAYBOOK-CLIENTES.md).

Antes de poner la app delante de un cliente, recorrer
[docs/CHECKLIST-DEMO-CLIENTE.md](docs/CHECKLIST-DEMO-CLIENTE.md): verificación de
GitHub, Cloudflare, Vercel y Supabase, más la prueba de humo.

## Roles

Cinco roles, con visibilidad y permisos crecientes. La columna *Rol* es el
valor del enum `user_role` en Postgres; entre paréntesis, la etiqueta que ve el
usuario cuando difiere.

| Rol | Alcance |
|---|---|
| `operativo` | Captura mediciones de los sitios que tiene asignados |
| `administrativo` | Lo anterior + gestión de indicadores |
| `gerente` | Toda su organización: gestión, estructura y configuración |
| `admin_cliente` | Como gerente, más alta de usuarios |
| `admin_consultora` (*Admin Gestión*) | Todas las organizaciones; conmutador de tenant en la barra superior. Requiere MFA (AAL2) |

El identificador `admin_consultora` no se renombra a propósito: es un valor de
enum del que dependen las políticas RLS y varias funciones de la base. Lo que
cambia es la etiqueta, centralizada en `USER_ROLE_LABEL` (`src/lib/types.ts`).

## Módulos

**Diario** — el ciclo de reunión

- **Ejes** (`/`) — panorama de los 7 ejes con su semáforo.
- **Reunión por nivel** (`/niveles/:level`) — tablero de la reunión diaria
  Nivel 1 → 2 → 3.
- **Quick Win** (`/quick-win`) — tableros de mejora por pilar, con candidatos,
  evidencias y escalamiento entre niveles.
- **Captura de mediciones** (`/captura`) — captura por período con bloqueo por
  fecha de corte y autorización.
- **Seguridad y Salud en el Trabajo** (`/seguridad`) — cruz de seguridad,
  pirámide de Heinrich y calendario de exposición.

**Análisis**

- **Cascada** (`/cascada/:id`) — trazabilidad de un indicador hacia sus
  objetivos superiores y sus precursores.
- **Tablero de indicador** (`/tablero/:id`) — histórico, meta y tendencia.
- **Análisis causal** (`/analisis-causal/:id`) — causas raíz con taxonomía
  estándar y catálogo de causas por indicador.
- **Pareto de causas** (`/pareto`) — priorización por frecuencia e impacto.
- **Dashboard general** (`/dashboard`) y **Panorama global**
  (`/panorama-global`) — excepciones y consolidados.

**Gestión y configuración**

- **Indicadores** (`/indicadores`) — CRUD, unidades, metas, indicadores
  calculados, binarios y de razón.
- **Cumplimiento de captura** (`/cumplimiento-captura`).
- **Estructura organizacional** (`/estructura-organizacional`), **Resultados por
  organización**, **Horario de reuniones** (por sitio).
- **Clientes**, **Nuevo cliente**, **Usuarios**, **Autorizaciones de captura**,
  **Registros Demo** — onboarding y administración de la consultora.

**Cuenta** — **Seguridad de la cuenta** (`/seguridad-cuenta`): cambio de
contraseña y MFA.

## Estructura del proyecto

```
src/
  lib/            cliente de Supabase, tipos, períodos, semáforo, APP_URL
  hooks/          AuthContext / useAuth (sesión, perfil, sitios, tenant activo)
  components/
    ui/           Semaforo, IndicatorCard, ImprovementCycle, Turnstile, …
    layout/       AppLayout (sidebar + topbar + conmutador de organización)
  features/       un directorio por módulo, cada uno con su *Api.ts y su .css
supabase/
  migrations/     esquema SQL + políticas RLS (orden cronológico por nombre)
  functions/      Edge Functions: invite-user, create/delete-demo-signup
  seed_catalogo.sql   catálogo de ejes — se carga en toda instancia
  seed_demo.sql       organización y datos de ejemplo — solo demo/formación
```

Convención: cada feature agrupa página, acceso a datos (`*Api.ts`) y estilos.
Las consultas de tableros van por lote (sin N+1) y se apoyan en la vista
`indicator_status`.

## Puesta en marcha

### 1. Base de datos

En el **SQL Editor** de Supabase, corre en orden de nombre de archivo todo
`supabase/migrations/*.sql` y luego `supabase/seed_catalogo.sql` (los 7 ejes;
sin esto la app no tiene tableros ni permite crear indicadores).

Los timestamps son únicos, así que ordenar por nombre da un orden de aplicación
inequívoco. No los renumeres ni los reordenes: hay dependencias entre migraciones
(por ejemplo, `quick_win_level_escalation` modifica lo que crea
`quick_win_boards`).

`supabase/seed_demo.sql` agrega una organización y datos de ejemplo encima del
catálogo. **Solo para entornos de demostración o formación** — nunca en la
instancia productiva de un cliente.

### 2. Variables de entorno

Copia `.env.example` a `.env` y completa `VITE_SUPABASE_URL` y
`VITE_SUPABASE_ANON_KEY` (Project Settings → API). `VITE_APP_URL` es opcional:
es la dirección pública que se incluye en el texto de credenciales al crear un
usuario; si se omite, se usa el origen desde el que se abre la app.

`VITE_TURNSTILE_SITE_KEY` **no es opcional**: sin ella, el botón de
login/registro/recuperación queda deshabilitado (exige un token de Cloudflare
Turnstile antes de habilitarse). Necesitas tu propio widget de Turnstile,
registrado contra tu dominio — ver DEPLOYMENT.md §3.1. Para desarrollo local,
Cloudflare publica sitekeys de prueba que pasan siempre en cualquier dominio
(nunca en producción).

### 3. Usuarios

Los usuarios se crean desde la propia app (**Usuarios** → invitar), que llama a
la Edge Function `invite-user`: crea la cuenta en Auth, su fila en `profiles` y
sus sitios en `profile_sites`, y devuelve una contraseña temporal.

Para el **primer** `admin_consultora` (el rol que la interfaz llama *Admin
Gestión*) no hay quien invite todavía, así que se crea a mano. **No basta con
insertar la fila en `profiles`**: al crear el usuario desde el panel se dispara
el trigger `handle_new_user`, que toma la rama de auto-registro público y crea
por su cuenta una organización `Demo — {nombre}` y un perfil `admin_cliente`.
Ese trigger solo se salta si el usuario trae `invited_at` o
`skip_demo_org` en su metadata — cosas que pone `invite-user`, no el panel. Un
`insert` a ciegas choca contra el perfil ya creado y falla con `duplicate key`.

El procedimiento correcto:

1. **Authentication → Users → Add user**: correo, contraseña y **Auto Confirm
   User** marcado.
2. Comprobar qué dejó el trigger:

```sql
select p.id, p.email, p.role, o.name as organizacion, o.is_demo
from profiles p join organizations o on o.id = p.organization_id
where p.email = 'TU-CORREO';
```

3. Promoverlo. Si el paso 2 devolvió una fila (lo normal):

```sql
update profiles
set role = 'admin_consultora', full_name = 'Nombre Apellido',
    organization_id = (select id from organizations where is_demo is not true
                       order by created_at limit 1)
where email = 'TU-CORREO';
```

   Si no devolvió nada, insertarlo con el UUID que muestra el panel:

```sql
insert into profiles (id, organization_id, role, full_name, email)
values ('<uuid>',
        (select id from organizations where is_demo is not true
         order by created_at limit 1),
        'admin_consultora', 'Nombre Apellido', 'TU-CORREO');
```

   `organization_id` es `not null`, de ahí la subconsulta: tiene que existir ya
   una organización (la del cliente, o la de `seed_demo.sql`).

4. Borrar la organización que el trigger creó de más:

```sql
delete from organizations
where is_demo = true and name like 'Demo — %'
  and not exists (select 1 from profiles p where p.organization_id = organizations.id);
```

Esto funciona **solo para el primero**: el trigger
`prevent_admin_consultora_self_grant` permite crear un `admin_consultora` por
SQL únicamente mientras no exista ninguno. Después, los usuarios se crean desde
la app.

Ese rol exige MFA: al primer inicio de sesión, enrola el segundo factor desde
**Seguridad de la cuenta**.

### 4. Correr

```bash
npm install
npm run dev
```

La app queda en `http://localhost:5173`.

## Comandos

```bash
npm run dev       # servidor de desarrollo
npm run build     # tsc -b + build de producción (sin source maps)
npm run lint      # eslint
npm run preview   # sirve el build local
```

## Verificación rápida

- **Aislamiento multi-tenant**: con un usuario de otra organización, ningún
  indicador ni medición de la organización demo debe ser visible — ni en la app
  ni llamando directo a la API REST de Supabase con su JWT.
- **Roles**: con `operativo`, el menú "Indicadores" no aparece y entrar a
  `/indicadores` a mano redirige al inicio.
- **Captura**: guardar dos veces la misma fecha e indicador debe actualizar, no
  duplicar (es un upsert por indicador + fecha). Pasada la fecha de corte del
  nivel, la captura requiere autorización.
- **Cascada**: desde un indicador Nivel 1 se ven sus objetivos superiores;
  desde uno Nivel 3, todos sus precursores en árbol.
