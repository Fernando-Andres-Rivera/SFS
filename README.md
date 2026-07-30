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

- ✅ Código completo: ~20 módulos funcionales, 63 migraciones, 3 Edge Functions.
- ⏳ **GitHub**: sin remoto configurado. Va a un repositorio propio, distinto al
  de LPMS.
- ⏳ **Supabase**: el `.env` local todavía apunta al proyecto de LPMS, así que
  **hoy ambas apps comparten la misma base de datos**. Falta crear el proyecto
  de Supabase de SFS, correr las migraciones y cambiar el `.env`.

El procedimiento de ambos pasos está en [DEPLOYMENT.md](DEPLOYMENT.md).

## Roles

Cinco roles, con visibilidad y permisos crecientes:

| Rol | Alcance |
|---|---|
| `operativo` | Captura mediciones de los sitios que tiene asignados |
| `administrativo` | Lo anterior + gestión de indicadores |
| `gerente` | Toda su organización: gestión, estructura y configuración |
| `admin_cliente` | Como gerente, más alta de usuarios |
| `admin_consultora` | Todas las organizaciones; conmutador de tenant en la barra superior. Requiere MFA (AAL2) |

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
  seed.sql        catálogo de ejes y datos de demostración
```

Convención: cada feature agrupa página, acceso a datos (`*Api.ts`) y estilos.
Las consultas de tableros van por lote (sin N+1) y se apoyan en la vista
`indicator_status`.

## Puesta en marcha

### 1. Base de datos

En el **SQL Editor** de Supabase, corre en orden cronológico todo
`supabase/migrations/*.sql` y luego `supabase/seed.sql`.

> ⚠️ Seis pares de migraciones comparten el mismo timestamp (`20260722000000`,
> `20260725000000`, `20260726000000`, `20260727000000`, `20260729000000`,
> `20260730000000`). Al montar un entorno desde cero, aplícalas en orden
> alfabético completo del nombre de archivo.

### 2. Variables de entorno

Copia `.env.example` a `.env` y completa `VITE_SUPABASE_URL` y
`VITE_SUPABASE_ANON_KEY` (Project Settings → API). `VITE_APP_URL` es opcional:
es la dirección pública que se incluye en el texto de credenciales al crear un
usuario; si se omite, se usa el origen desde el que se abre la app.

### 3. Usuarios

Los usuarios se crean desde la propia app (**Usuarios** → invitar), que llama a
la Edge Function `invite-user`: crea la cuenta en Auth, su fila en `profiles` y
sus sitios en `profile_sites`, y devuelve una contraseña temporal.

Para el **primer** `admin_consultora` no hay quien invite todavía: créalo en
**Authentication → Users** del panel de Supabase, copia su UUID y ejecuta:

```sql
insert into profiles (id, organization_id, role, full_name, email)
values ('<uuid>', '00000000-0000-0000-0000-000000000001', 'admin_consultora',
        'Admin Consultora', 'admin.consultora@leanprologistic.com');
```

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
