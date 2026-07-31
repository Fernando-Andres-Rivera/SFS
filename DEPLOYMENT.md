# Despliegue de SFS

La aplicación es un frontend estático (Vite + React) que habla directamente con
Supabase. No hay servidor propio que administrar: se compila a archivos estáticos
y se sirven desde Vercel. Toda la seguridad vive en las políticas RLS de Supabase.

> **Estado.** SFS nace como réplica de LPMS, pero su infraestructura es
> **independiente**: repositorio de GitHub propio ✅, proyecto de Supabase
> propio ✅ (55 migraciones aplicadas, verificadas contra la base), 3 Edge
> Functions desplegadas ✅, proyecto de Vercel propio ✅, widget de
> **Cloudflare Turnstile propio creado** ✅ (§3.1), secret key de Turnstile
> puesta en Supabase ✅ (verificado: el servidor rechaza con `captcha_failed`
> todo intento sin token válido).
>
> ⛔ **El despliegue no arranca todavía: faltan las variables de entorno en
> Vercel** (§3). Verificado descargando los cinco chunks de
> `sfs-lime.vercel.app`: ninguno contiene la URL de Supabase ni la sitekey de
> Turnstile, y el chunk de la app sí trae el texto *"Faltan las variables"* —
> el error que lanza `src/lib/supabase.ts` al cargar. En producción eso es
> pantalla en blanco, no un formulario que falla.
>
> ⚠️ **En local, con el `.env` de este repo, tampoco se puede entrar** — ver la
> nota de desarrollo local al final de §3.1.
>
> **Lo único que SFS todavía comparte con LPMS es la cuenta de Vercel** — ver
> §2. No comparten base de datos, repositorio ni widget de Turnstile.

## 1. Subir el código a GitHub — hecho ✅

El repositorio vive en su propio remoto, distinto al de LPMS:

```bash
git remote -v   # origin  https://github.com/Fernando-Andres-Rivera/SFS.git
```

> El `.env` con la llave de Supabase **no** se sube — está en `.gitignore`. Las
> variables de entorno se configuran directamente en Vercel (paso 3).

## 2. Importar el proyecto en Vercel — hecho ✅, con una salvedad

El proyecto `sfs` ya existe en Vercel y despliega desde `main`. La
configuración es la que Vercel detecta solo para Vite (Build Command
`npm run build`, Output Directory `dist`), y `vercel.json` redirige todas las
rutas a `index.html` para que los enlaces profundos y el "recargar página"
funcionen.

> ⚠️ **Salvedad — el único vínculo que queda con LPMS.** El proyecto `sfs` está
> dentro del equipo de Vercel `lean-performance-management-system`, el mismo
> que aloja `lpms`. Consecuencias: comparten facturación y miembros, y los
> dominios por defecto de SFS llevan el nombre de LPMS
> (`sfs-lean-performance-management-system.vercel.app`), que es lo que ve un
> cliente si no se le asigna un dominio propio.
>
> Para separarlo hay tres caminos, de menor a mayor esfuerzo:
>
> 1. **Asignar a SFS un dominio propio** (`sfs.midominio.com` o un
>    `.vercel.app` sin el slug del equipo). Oculta el nombre de LPMS de cara
>    al cliente, pero la cuenta sigue siendo compartida. Recordar agregar el
>    dominio nuevo al widget de Turnstile (§3.1) y a Supabase (§4).
> 2. **Renombrar el equipo** a algo neutro (ej. `leanprologistic`). Arregla los
>    dominios de ambos proyectos de una vez — **pero cambia también las URLs de
>    LPMS**, que ya está en producción con clientes. No hacerlo sin avisar.
> 3. **Crear un equipo de Vercel separado para SFS** y transferir el proyecto.
>    Es la separación real (facturación y accesos aparte). Implica reconfigurar
>    variables de entorno y volver a registrar dominios en Turnstile y Supabase.

## 3. Configurar las variables de entorno en Vercel — ⛔ pendiente

**Este es el paso que hoy tiene el despliegue caído.** Ninguna de las cuatro
variables está puesta en el proyecto `sfs`, así que el build publicado no sabe
a qué Supabase hablar y muere al cargar.

Cómo comprobarlo sin entrar al panel — si algún chunk trae la URL del proyecto,
las variables están puestas:

```bash
curl -s --compressed https://sfs-lime.vercel.app/assets/index-*.js | grep -o 'https://[a-z0-9]*\.supabase\.co' | head -1
```

En **Project Settings → Environment Variables**, agrega las del **proyecto de
Supabase propio de SFS** (no las de LPMS):

| Nombre | Valor |
|---|---|
| `VITE_SUPABASE_URL` | `https://<proyecto-sfs>.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | tu `sb_publishable_...` (la llave *publishable*, segura de exponer) |
| `VITE_APP_URL` | la URL pública de SFS (opcional; si se omite se usa el origen actual) |
| `VITE_TURNSTILE_SITE_KEY` | sitekey del widget Turnstile de **esta** instancia — ver sección siguiente |

Marca las cuatro para los entornos **Production**, **Preview** y **Development**.
Luego **redesplegar**: Vite hornea las `VITE_*` durante el build, así que
guardar las variables **no cambia el despliegue vigente**. Hasta el redespliegue
la app sigue publicada exactamente igual de rota.

`VITE_APP_URL` es el único lugar donde vive la dirección pública de la app: se
usa en el texto de credenciales que se copia al crear un usuario o un registro
demo. Sin ella, ese texto apunta al origen desde el que se abrió la app.

## 3.1 Cloudflare Turnstile (obligatorio — sin esto no hay login)

El formulario de login/registro/recuperación usa un widget anti-bots de
Cloudflare Turnstile; el botón de enviar queda **deshabilitado** hasta que el
widget entrega un token válido (`src/features/auth/LoginPage.tsx`, disabled
mientras no haya `captchaToken`). La sitekey de Turnstile está **atada al
dominio**: la de LPMS no sirve aquí y viceversa — cada instancia (cada dominio
de Vercel) necesita su propio widget.

Pasos, por instancia:

1. En el [dashboard de Cloudflare](https://dash.cloudflare.com) → **Turnstile**
   → **Add widget**. Dominio: el de esta instancia (ej. `sfs.vercel.app` o el
   dominio del cliente). Modo: *Managed*.
2. Cloudflare entrega dos valores:
   - **Site key** (pública) → variable `VITE_TURNSTILE_SITE_KEY` en Vercel.
   - **Secret key** → Supabase (proyecto de esta instancia) → **Authentication
     → Attack Protection → Enable CAPTCHA protection → Turnstile**, pégala ahí.
     Este paso es manual en el panel; ni el CLI ni las migraciones lo cubren.
3. Sin el paso 2 (secret key en Supabase), la protección solo es cosmética:
   el frontend exige un token, pero el servidor no lo valida. Con ambos
   configurados, un intento de login sin token válido lo rechaza también
   Supabase Auth, no solo la UI.

### Desarrollo local: la sitekey de prueba **no** sirve aquí

Cloudflare publica sitekeys de prueba que pasan siempre en cualquier dominio
(su [página de testing](https://developers.cloudflare.com/turnstile/troubleshooting/testing/)),
y el `.env` de este repo trae una (`1x00000000000000000000AA`). **Desde que la
secret key real está puesta en Supabase, esa combinación no funciona**: el
token de una sitekey de prueba solo valida contra la *secret key* de prueba que
le corresponde. Contra la real, Cloudflare responde `invalid-input-response` y
Supabase rechaza la petición.

El síntoma engaña: el widget se pinta en verde y el botón se habilita, porque
eso lo decide el navegador. Es el servidor el que rechaza, y la app muestra
*"No se pudo verificar la seguridad de este intento. Recarga la página"* —
mensaje correcto para un fallo real, pero aquí recargar no arregla nada, porque
no es transitorio sino un par de llaves que no coinciden. Afecta por igual a
**login, registro y recuperación de contraseña**: toda operación de auth.

Comprobarlo desde la terminal (no crea nada, es un login con credenciales
falsas):

```bash
curl -s -X POST -H "apikey: $VITE_SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d '{"email":"sonda@example.invalid","password":"x"}' "$VITE_SUPABASE_URL/auth/v1/token?grant_type=password"
```

Si responde `captcha_failed`, la protección está activa y exige un token válido.

**La salida limpia**: en Cloudflare → Turnstile → widget de SFS, agregar
`localhost` a la lista de hostnames, y poner la **sitekey real** en el `.env`
local. Así desarrollo y producción usan el mismo par de llaves.

Lo que **no** conviene hacer: poner la secret key de prueba en Supabase, o
apagar la protección CAPTCHA mientras se desarrolla. Las dos cosas son globales
al proyecto — dejarían producción sin protección para arreglar local.

### El widget de esta instancia (SFS)

Ya creado en Cloudflare, modo *Managed*:

| | |
|---|---|
| Site key | `0x4AAAAAAEC6rCRsRZ-pWqeP` (pública) |
| Secret key | solo en Supabase → Attack Protection; no vive en este repo |
| Hostnames | `sfs-lime.vercel.app`, `sfs-lean-performance-management-system.vercel.app`, `sfs-git-main-lean-performance-management-system.vercel.app` |

Los tres hostnames son los dominios estables del proyecto `sfs` en Vercel. Las
URLs de *preview* (`sfs-<hash>-lean-performance-management-system.vercel.app`)
cambian en cada despliegue y **no** están registradas: el login no funcionará en
un preview salvo que se agregue ese hostname al widget o se le asigne un dominio
fijo.

Al cambiar `VITE_TURNSTILE_SITE_KEY` en Vercel hace falta **redesplegar**. Vite
hornea las variables `VITE_*` durante el build; guardar la variable no altera un
despliegue ya compilado.

## 4. Registrar la URL de Vercel en Supabase

Cuando Vercel te dé la URL final (ej. `https://sfs.vercel.app`):

- Supabase → **Authentication → URL Configuration** → agrega esa URL en
  **Site URL** y en **Redirect URLs**.

Sin esto, el login por correo/contraseña funciona igual, pero cualquier flujo
futuro de recuperación de contraseña o confirmación por correo apuntaría a la
URL equivocada.

## 5. Despliegues siguientes

Cada `git push` a `main` dispara un despliegue automático en producción. Cada
push a otra rama genera una **Preview** con su propia URL — útil para revisar un
cambio con un cliente antes de publicarlo.

## Nota sobre las migraciones de base de datos

Las migraciones en `supabase/migrations/` se corren manualmente en el **SQL
Editor** de Supabase (no las aplica Vercel). El orden es por fecha en el nombre
del archivo. Al montar un entorno nuevo desde cero, se corren en ese orden, más
`supabase/seed_catalogo.sql` para el catálogo de ejes (estructural, en toda
instancia). `supabase/seed_demo.sql` es aparte y **solo** para entornos de
demostración o formación — nunca en la instancia productiva de un cliente.

---

# Buenas prácticas — dónde vive cada una

Referencia rápida de cómo está cubierta cada práctica y qué archivo o
plataforma la controla.

## Frontend comprimido, sin source maps

- **Source maps**: apagados explícitamente en `vite.config.ts`
  (`build.sourcemap: false`). El código fuente original nunca se publica.
- **Minificación**: Vite minifica JS y CSS en cada `npm run build`.
- **Compresión (gzip/brotli)**: la aplica Vercel automáticamente al servir —
  no requiere configuración en el repo.
- **División de chunks**: `vite.config.ts` separa React, Recharts y Supabase
  en archivos propios con hash. Al desplegar una nueva versión, el navegador
  del usuario solo descarga el chunk de la app (~27 KB gzip); las librerías
  (~235 KB gzip) quedan cacheadas hasta que actualicemos sus versiones.

## Seguridad de datos (RLS)

Toda la autorización vive en Postgres, no en el frontend: cada tabla tiene
políticas RLS por organización y rol (`supabase/migrations/*rls*.sql` y
posteriores). Un usuario autenticado solo puede leer/escribir datos de su
organización según su rol, sin importar desde qué herramienta llame a la API.
El aislamiento de escritura entre organizaciones se verificó con un ataque
simulado (migración `20260714000001_cross_org_write_isolation.sql`).

## Control de versiones

Git con despliegue continuo: cada push a `main` publica a producción; cada
rama genera una Preview URL en Vercel. Las migraciones de base de datos están
versionadas en `supabase/migrations/` con orden cronológico en el nombre.

## API para integraciones externas

Supabase expone automáticamente una **API REST (PostgREST)** sobre el esquema:
`https://<proyecto>.supabase.co/rest/v1/<tabla>`. Es la misma API que usa la
app, así que **hereda las políticas RLS** — una herramienta externa (Power BI,
un ERP, un script) necesita:

1. La URL del proyecto y la llave *publishable* (las mismas del `.env`).
2. Un usuario de la app (email/contraseña) con el rol adecuado; la herramienta
   se autentica contra `/auth/v1/token` y usa el JWT resultante.

La herramienta externa solo ve lo que ese usuario vería en la app. Para
integraciones de solo lectura conviene crear un usuario dedicado con rol
`operativo` o `administrativo` limitado a los sitios necesarios.

## Hosting y deployment

Frontend estático en Vercel (CDN global, HTTPS automático), base de datos y
auth en Supabase. No hay servidores propios que parchar. Los headers de
seguridad (HSTS, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
`Referrer-Policy`, `Permissions-Policy`) se inyectan desde `vercel.json`.

## Rate limiting

Opera en dos capas de plataforma (no en el repo):

- **Supabase Auth**: límites por IP para login, registro y recuperación de
  contraseña, configurables en **Authentication → Rate Limits** del dashboard.
- **Vercel**: mitigación DDoS automática en el CDN para el frontend.

La API de datos (PostgREST) no tiene rate limiting por usuario en el plan
gratuito; si un cliente integra herramientas de alto volumen, el control es
el plan de Supabase (que limita conexiones y recursos del proyecto).

## Caché (rendimiento)

- **Assets estáticos**: `vercel.json` los sirve con
  `Cache-Control: immutable` por 1 año — es seguro porque Vite les pone hash
  al nombre; un archivo nuevo siempre tiene URL nueva.
- **`index.html`**: `no-cache`, para que cada despliegue llegue al instante a
  todos los usuarios.
- **Datos**: se consultan en vivo a Supabase en cada carga de página — es la
  decisión correcta para tableros de gestión diaria, donde ver una medición
  vieja es peor que esperar unos cientos de milisegundos. Las consultas
  pesadas de tableros ya están optimizadas con la vista `indicator_status` y
  consultas por lote (sin patrón N+1). Si con muchos clientes se sintiera
  lentitud, el siguiente paso sería una capa de caché de datos en el cliente
  (React Query/SWR) — no es necesaria hoy.
