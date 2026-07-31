# Checklist previo a una prueba con cliente

Verificación de extremo a extremo antes de poner SFS delante de alguien. No es
el aprovisionamiento de una instancia nueva — eso está en
[PLAYBOOK-CLIENTES.md](PLAYBOOK-CLIENTES.md) §3. Esto es lo que se revisa
**cuando ya está todo montado**, para que el día de la demo no aparezca una
sorpresa.

El orden importa: cada sección depende de que la anterior esté bien. Se recorre
completo, sin saltarse pasos, en incógnito y contra el dominio exacto que verá
el cliente.

## Estado verificado el 31 de julio de 2026

| Pieza | Estado |
|---|---|
| GitHub — `main` local vs remoto | ✅ sincronizado en `5848168` |
| Vercel — último despliegue | ✅ READY (producción) |
| Vercel — variables de entorno | ⛔ **ausentes** — el bundle vivo trae *"Faltan las variables"* |
| Supabase — CAPTCHA | ✅ activo con la secret key real |
| Supabase — confirmación de correo | ✅ desactivada |
| Turnstile — hostnames | ⚠️ 3 registrados; no cubren previews ni `localhost` |

Mientras la fila de variables siga en ⛔, el despliegue es una pantalla en
blanco. Ver [DEPLOYMENT.md](../DEPLOYMENT.md) §3.

## 1. GitHub

- [ ] El remoto es el de SFS, no el de LPMS:

```bash
git remote get-url origin
```

- [ ] Local y remoto en el mismo commit — si los hashes coinciden, lo desplegado
      es lo que tienes:

```bash
git ls-remote origin main && git rev-parse HEAD
```

- [ ] **Settings → General**: el repositorio es **privado**. Si es público, la
      estructura de la base y las Edge Functions quedan a la vista.
- [ ] **Settings → Branches**: confirmado desde qué rama despliega Vercel
      (`main`).

## 2. Cloudflare Turnstile

En [dash.cloudflare.com](https://dash.cloudflare.com) → **Turnstile** → widget
de esta instancia.

- [ ] La **sitekey** coincide con la que está en Vercel. La de SFS es
      `0x4AAAAAAEC6rCRsRZ-pWqeP`.
- [ ] En **Hostnames** está **el dominio exacto que verá el cliente**. Los de
      SFS hoy: `sfs-lime.vercel.app`,
      `sfs-lean-performance-management-system.vercel.app`,
      `sfs-git-main-lean-performance-management-system.vercel.app`.
- [ ] Modo **Managed**.

> ⚠️ **El fallo más probable el día de la demo.** Una URL de *preview*
> (`sfs-<hash>-….vercel.app`) no está en la lista de hostnames y el login falla
> ahí. Usar siempre el dominio estable, o registrar el hostname antes.

## 3. Vercel

**Settings → Environment Variables:**

- [ ] Las cuatro puestas: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`,
      `VITE_APP_URL`, `VITE_TURNSTILE_SITE_KEY`.
- [ ] `VITE_SUPABASE_URL` apunta al proyecto de **esta** instancia
      (SFS: `yjyvqvdyebbvftdniuax`), no al de LPMS.
- [ ] Marcadas para **Production**, **Preview** y **Development**.
- [ ] **Redesplegado después de guardarlas.** Vite hornea las `VITE_*` en el
      build: guardar la variable no cambia el despliegue vigente.
- [ ] Verificado que quedaron horneadas — si imprime la URL de Supabase, están:

```bash
curl -s --compressed "https://sfs-lime.vercel.app$(curl -s https://sfs-lime.vercel.app/ | grep -o '/assets/index-[A-Za-z0-9_-]*\.js' | head -1)" | grep -o 'https://[a-z0-9]*\.supabase\.co' | head -1
```

**Settings → Deployment Protection:**

- [ ] Revisado **Vercel Authentication**. En SFS está activada en modo
      `all_except_custom_domains`: el dominio de producción abre sin iniciar
      sesión, pero **las URLs de preview quedan detrás del muro de login de
      Vercel** — el cliente vería una pantalla de Vercel, no la app.

## 4. Supabase

Proyecto de esta instancia:

- [ ] **Authentication → URL Configuration**: `Site URL` y `Redirect URLs` con
      el dominio real. Si apuntan a otro lado, el enlace de recuperación de
      contraseña lleva al cliente a la URL equivocada.
- [ ] **Authentication → Attack Protection**: CAPTCHA activo con la secret key
      del widget de **esta** instancia. Comprobable sin crear nada — debe
      responder `captcha_failed`:

```bash
curl -s -X POST -H "apikey: $VITE_SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d '{"email":"sonda@example.invalid","password":"x"}' "$VITE_SUPABASE_URL/auth/v1/token?grant_type=password"
```

- [ ] **Providers → Email**: "Confirm email" en el estado que corresponda. Sin
      SMTP propio debe estar **desmarcado**, o nadie podrá confirmar su cuenta.
- [ ] Existe el `admin_consultora` (*Admin Gestión* en la interfaz) y la
      organización tiene datos que mostrar.

## 5. Prueba de humo

En **ventana de incógnito**, contra el dominio exacto que verá el cliente:

- [ ] La página carga. Si sale en blanco, faltan variables → volver a §3.
- [ ] El widget de Turnstile aparece y el botón "Ingresar" se habilita.
- [ ] **Se inicia sesión de verdad.** Es la única prueba de que las dos llaves
      coinciden: la interfaz se ve idéntica si la secret key está mal puesta.
- [ ] La barra superior muestra el rol correcto (**Admin Gestión** para el rol
      de gestión).
- [ ] Se abren las pantallas que se van a mostrar, incluidas evidencia de plan
      de acción, evidencia de Quick Win, usuarios y horarios de reunión.
- [ ] Recargar con `F5` estando dentro de una ruta profunda — valida que el
      `vercel.json` reescribe las rutas al `index.html`.

## Dos trampas que no aparecen en ningún panel

**El rol de gestión exige MFA en cada inicio de sesión.** Si la demo se hace con
esa cuenta, hay que tener a mano el dispositivo con la app de autenticación. Si
el cliente va a probar por su cuenta, conviene darle un usuario `gerente` o
`admin_cliente`, que no lo exigen.

**El correo tiene límite.** Supabase en plan gratuito permite pocos correos por
hora. Varias recuperaciones de contraseña seguidas durante una demo empiezan a
fallar con `over_email_send_rate_limit`. Con SMTP propio configurado, deja de
ser un problema.
