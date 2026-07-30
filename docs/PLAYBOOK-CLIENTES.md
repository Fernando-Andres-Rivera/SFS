# SFS — Playbook de comercialización e implantación

Cómo se vende, se instala, se entrega y se mantiene SFS en cada cliente.
Documento operativo: si un procedimiento no está aquí, no está estandarizado.

---

## 1. Modelo de distribución

**Decisión: una instancia dedicada por cliente.** Cada cliente recibe su propio
proyecto de Supabase (base de datos propia) y su propio despliegue en Vercel
(URL propia), servidos desde **un único repositorio de código**.

La alternativa —un solo despliegue compartido donde cada cliente es una
`organization`— es técnicamente viable, porque la app ya es multi-tenant con RLS
por organización. Se descarta por una razón concreta: **el objetivo declarado es
que el cliente termine gestionando su propia operación.** Una base de datos
compartida no se puede entregar. En cuanto un cliente pide administrar lo suyo,
auditar sus datos o exigir un contrato de tratamiento de datos sin terceros
mezclados, el modelo compartido se rompe y hay que migrar bajo presión.

El multi-tenant interno **no se desperdicia**: sigue siendo el mecanismo para un
cliente con varias plantas, filiales o unidades de negocio dentro de su propia
instancia.

### Topología

| Capa | Cuántas | Regla |
|---|---|---|
| Repositorio | **1** | Código único, versionado por tags. Nadie hace fork por cliente. |
| Proyecto Vercel | **1 por cliente** | Varios proyectos de Vercel pueden apuntar al mismo repositorio, cada uno con sus variables de entorno, su dominio y su rama/tag de producción. |
| Organización Supabase | **1 por cliente** | Contiene el proyecto del cliente. Es la unidad de facturación y de control de acceso. |
| Proyecto Supabase | **1 por cliente** | Base de datos, Auth y Edge Functions propios. |

**Por qué una organización de Supabase por cliente y no solo un proyecto:** la
organización es la frontera de permisos y de factura. Con una por cliente puedes
(a) facturarle a él directamente si algún día asume el costo, (b) darle acceso de
propietario cuando asuma la gestión, y (c) retirarte sin tocar a los demás
clientes. Mover un proyecto entre organizaciones que administras es viable;
mover datos entre cuentas distintas es doloroso. Empezar así es la opción de la
que es barato volver.

> **Prohibido**: hacer un fork del repositorio por cliente. En cuanto haya dos
> forks, cada corrección hay que aplicarla dos veces y en seis meses tienes N
> productos distintos que mantener en lugar de uno.

---

## 2. Prerrequisitos técnicos

Cosas que hoy funcionan porque hay **una** instancia y se opera a mano. Con
varios clientes dejan de funcionar. Ordenadas por urgencia.

### Bloqueantes antes del primer cliente

1. ~~**El primer `admin_consultora` no se puede crear en ninguna base nueva.**~~
   **Resuelto.** El trigger `prevent_admin_consultora_self_grant`
   (migración `20260714000000`) bloquea cualquier insert/update con
   `role = 'admin_consultora'` a menos que quien ejecuta ya tenga ese rol —
   pero esa comprobación depende de `auth.uid()`, que es `null` fuera de una
   sesión autenticada. Tanto el SQL Editor del panel como el Management API
   (`supabase db query --linked`, usado para aprovisionar) ejecutan sin esa
   sesión, así que el procedimiento que el propio README documentaba para
   crear el primer usuario **estaba roto** para cualquier base nueva desde
   esa migración — nunca se notó porque el primer `admin_consultora` de
   LPMS ya existía antes de que el trigger se agregara. Corregido en
   `20260812000000_fix_admin_consultora_bootstrap.sql`: se permite la única
   excepción legítima (crear el primero, cuando no existe *ningún*
   `admin_consultora` todavía); en cuanto existe uno, la protección original
   opera sin cambios.

2. ~~**`invite-user` colisiona con el trigger de auto-registro (bug en
   producción, no solo de aprovisionamiento).**~~ **Resuelto.** Al crear el
   primer usuario de la instancia nueva con el mismo patrón que usa
   `invite-user` (`admin.createUser()` + `user_metadata.skip_demo_org =
   true`, perfil insertado después), la creación chocó con
   `duplicate key value violates unique constraint "profiles_pkey"`: el
   trigger `on_auth_user_created` ya había creado una organización
   "Demo — {nombre}" y un perfil `admin_cliente` para ese mismo id antes de
   que el insert propio de `invite-user` llegara a correr.

   La causa: `20260730000001_skip_demo_org_on_invited_users.sql` había
   agregado el chequeo de `skip_demo_org` a `handle_new_user()`
   precisamente para evitar esto, pero una migración posterior,
   `20260808000000_public_signup_demo_provisioning.sql` (que solo pretendía
   agregar la columna `is_demo`), redefinió la función completa
   (`CREATE OR REPLACE`) y **perdió ese chequeo sin querer** — al menos en
   el historial versionado de este repositorio.

   **Verificado en la base viva de LPMS antes de tocar nada**: su
   `handle_new_user()` actual **ya tiene el chequeo** — idéntico al que
   restaura `20260812000001`. El bug nunca estuvo en producción; alguien lo
   corrigió ahí directamente (SQL Editor, sin dejarlo como migración), el
   mismo patrón de *drift* que ya se había visto en las 3 funciones huérfanas
   y la política duplicada. Conclusión corregida: **el historial de
   migraciones de este repo no coincide con lo que realmente corre en
   LPMS** — no aplicar `20260812000001` allá, ya está de más. Sí queda
   pendiente, para quien administre LPMS, capturar como migración cualquier
   corrección que se sepa hecha a mano en el panel — si algún día se
   reconstruye esa base desde estos archivos, el bug reaparecería.

3. ~~**Sitekey de Cloudflare Turnstile hardcodeada (la de LPMS).**~~
   **Resuelto.** El login/registro/recuperación exige un token de Turnstile
   antes de habilitar el botón de envío; la sitekey estaba fija en
   `Turnstile.tsx` y atada al dominio de LPMS — en cualquier otro dominio,
   Cloudflare la rechaza (error 110200) y **nadie puede entrar a la app**. Se
   sacó a variable de entorno (`VITE_TURNSTILE_SITE_KEY`). Cada instancia
   sigue necesitando su **propio widget de Cloudflare**, registrado contra su
   propio dominio — eso no lo resuelve el código, es un paso manual por
   cliente (detallado en DEPLOYMENT.md §3.1 y en el checklist §3.4 de este
   documento). Descubierto al verificar el login end-to-end de la primera
   instancia nueva — es exactamente el tipo de dependencia oculta que
   "compartir infraestructura con LPMS" iba a seguir escondiendo.

4. ~~**Timestamps duplicados en migraciones.**~~ **Resuelto.** Los seis pares que
   compartían prefijo se renumeraron conservando el orden de aplicación previo.
   Hoy los 53 timestamps son únicos y ordenar por nombre de archivo da un orden
   inequívoco. **Regla a futuro**: una migración, un timestamp — si dos se crean
   el mismo día, se diferencian en el sufijo, nunca se repiten.

5. ~~**Separar catálogo de datos de demostración.**~~ **Resuelto.** `seed.sql`
   mezclaba el catálogo que todo cliente necesita (los 7 ejes) con datos
   ficticios (organización demo, sitio Planta Bogotá, indicadores de ejemplo).
   Se dividió en:
   - `seed_catalogo.sql` — los 7 ejes. **Siempre**, en toda instancia.
   - `seed_demo.sql` — organización y datos de ejemplo. **Solo en demos o
     formación**, nunca en la instancia productiva de un cliente.

   (Unidades y taxonomía de causas ya vivían en migraciones, no en el seed —
   no requirieron cambio.)

6. ~~**Aprovisionamiento por CLI, no por SQL Editor.**~~ **Resuelto.** Supabase
   CLI se adoptó como dependencia de desarrollo. Flujo probado de punta a punta
   en la primera instancia nueva: `supabase login` → `supabase link
   --project-ref <ref>` → `supabase db push`.

   Aplicar las 53 migraciones desde cero, sobre un proyecto nunca antes
   tocado, sacó a la luz **4 bugs de las propias migraciones** que el SQL
   Editor había estado ocultando (porque ahí el operador corrige a mano sin
   dejar rastro). Ya corregidos en el historial:

   - **3 funciones "huérfanas"** (`fn_action_plan_reabrir`,
     `gemba_user_has_location_site`, `fn_gemba_generar_plan`): tres
     migraciones (`20260718044354`, `20260718050105`, `20260718050212`)
     hacían `ALTER`/`REVOKE`/`GRANT` sobre funciones que ninguna migración
     crea — existían solo en la base de LPMS, creadas a mano alguna vez y
     nunca capturadas en el historial. El frontend no las invoca (verificado
     por búsqueda en `src/`). Se envolvió cada sentencia en un `DO $$ ... $$`
     que comprueba `to_regprocedure(...)` antes de actuar, así que ahora son
     inocuas tanto en una base nueva como en una que sí las tenga.
   - **1 política duplicada sin `DROP` previo**: `20260728000000` recreaba
     `organizations_delete`, ya creada en `20260720000000`, sin el `DROP
     POLICY` que sí tienen las otras 6 tablas de ese mismo archivo — una
     inconsistencia dentro del propio archivo. Se agregó el `DROP POLICY IF
     EXISTS` que faltaba.

   **Lo importante**: esto no era un problema de LPMS — ahí nunca se manifestó
   porque su base ya tenía esas funciones y esa política de una carga anterior.
   Era un problema **latente en el código versionado**, invisible mientras solo
   existiera una base de datos ya viva. Aparece exactamente al primer intento
   de aprovisionar un cliente nuevo desde cero — que es lo que se acaba de
   hacer. Se verificó con un barrido completo de las 53 migraciones (funciones,
   políticas, tipos y tablas creadas más de una vez) que no queda ningún otro
   caso del mismo patrón.

### Antes del segundo o tercer cliente

7. **Versionado por tags.** Cada cliente corre una versión, no "lo último que
   haya en `main`". Sin esto, un push rompe cinco clientes a la vez.

8. **Suite de pruebas de regresión.** Hoy no hay pruebas automatizadas. Con una
   instancia el riesgo lo absorbe el usuario; con cinco, un fallo en RLS o en la
   captura se multiplica. Prioridad: aislamiento entre organizaciones, permisos
   por rol, y el upsert de mediciones.

9. **Respaldo y restauración documentados.** Qué se respalda, cada cuánto, y el
   procedimiento probado de restauración. Es la primera pregunta de cualquier
   área de TI del lado del cliente.

10. **Monitoreo.** Saber que la instancia de un cliente está caída antes de que
    te llame.

### Deuda menor conocida

- 13 hallazgos de ESLint preexistentes (10 errores `react-hooks/set-state-in-effect`).
- MFA obligatorio solo para `admin_consultora`; evaluar exigirlo también a
  `admin_cliente`, que en la instancia del cliente será el rol de mayor poder.

---

## 3. Procedimiento de aprovisionamiento

Checklist por cliente. No se salta ningún paso.

### 3.1 Infraestructura

- [ ] Crear organización de Supabase con el nombre del cliente.
- [ ] Crear el proyecto dentro de esa organización. Región: la más cercana a la
      operación del cliente.
- [ ] Guardar credenciales en el gestor de secretos de LeanProLogistic. **Nunca**
      en el repositorio ni en un chat.

### 3.2 Base de datos

- [ ] `supabase login` (una vez por máquina) → `supabase link --project-ref <ref>`
      → `supabase db push`. Probado de punta a punta en la primera instancia:
      las migraciones aplican limpio sobre un proyecto nuevo.
- [ ] `supabase db push` **no** aplica seeds contra un proyecto remoto (eso
      solo ocurre en `db reset`, que es local). Cargar cada seed con
      `supabase db query --linked --file supabase/seed_catalogo.sql` (los 7
      ejes — sin esto la app no tiene tableros) y, **solo** si es un entorno
      de demostración, igual con `seed_demo.sql`.
- [ ] Verificar que RLS está activo en todas las tablas (`get_advisors` de
      seguridad, o revisar en el panel).

### 3.3 Edge Functions

- [ ] Desplegar con `supabase functions deploy <nombre>` — una por una o las
      3 en secuencia (`invite-user`, `create-demo-signup`,
      `delete-demo-signup`). No requieren configurar secretos: `SUPABASE_URL`,
      `SUPABASE_SERVICE_ROLE_KEY` y `SUPABASE_ANON_KEY` los inyecta Supabase
      automáticamente en cada función.
- [ ] Confirmar las 3 con `supabase functions list` — status `ACTIVE`.

### 3.4 Frontend

- [ ] Crear proyecto en Vercel apuntando al repositorio, en el tag de la versión
      contratada.
- [ ] Variables: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_APP_URL`,
      `VITE_TURNSTILE_SITE_KEY`.
- [ ] Dominio: `<cliente>.sfs.<dominio-leanprologistic>` o el dominio propio del
      cliente si lo aporta.
- [ ] Registrar la URL en Supabase → Authentication → URL Configuration
      (Site URL y Redirect URLs).
- [ ] **Cloudflare Turnstile propio para este dominio** (ver DEPLOYMENT.md
      §3.1): crear el widget, poner la sitekey en `VITE_TURNSTILE_SITE_KEY` y
      la secret key en Supabase → Authentication → Attack Protection. **Sin
      esto el botón de login queda deshabilitado — es bloqueante, no
      opcional.**

### 3.5 Puesta a punto funcional

- [ ] Crear el primer usuario `admin_consultora` (bootstrap; ya no es
      LeanProLogistic el único con este rol en la instancia): en Supabase →
      Authentication → Users → crear el usuario, y su fila en `profiles` vía
      `supabase db query --linked` con `role = 'admin_consultora'`. Requiere
      la migración `20260812000000` (ya en el historial) — sin ella, el
      trigger de anti-escalación bloquea incluso este primer insert.
- [ ] Crear la organización del cliente y sus sitios.
- [ ] Crear el primer usuario `admin_cliente` (desde la propia app, vía
      "Usuarios" → invitar, con el `admin_consultora` recién creado) y
      enrolar su MFA.
- [ ] Cargar estructura organizacional y responsables por pilar.
- [ ] Configurar horarios de reunión y fechas de corte de captura por nivel.
- [ ] Cargar el árbol de indicadores en cascada (Nivel 1 → 2 → 3) con sus metas.
- [ ] Cargar el catálogo de causas estándar por indicador.

### 3.6 Verificación de entrega

- [ ] Un `operativo` captura una medición y ve su semáforo.
- [ ] Un `operativo` **no** ve el menú Indicadores ni puede entrar por URL.
- [ ] La captura fuera de la fecha de corte exige autorización.
- [ ] La cascada trazada desde Nivel 1 llega a Nivel 3.
- [ ] Ningún usuario del cliente ve datos de otra organización.

---

## 4. Roles y traspaso de la gestión

La transición "lo gestionamos nosotros" → "lo gestiona el cliente" ya está
prevista en el modelo de roles de la aplicación. No requiere desarrollo.

| Fase | Quién opera | Rol usado |
|---|---|---|
| **Implantación** | LeanProLogistic configura todo | `admin_consultora` |
| **Acompañamiento** | El cliente opera, nosotros corregimos | `admin_cliente` del cliente, con nuestro `admin_consultora` disponible |
| **Autonomía** | El cliente gestiona; nosotros damos soporte a demanda | `admin_cliente` |

**Decisión pendiente — acceso de soporte.** Al llegar a autonomía, ¿mantenemos un
usuario `admin_consultora` en la instancia del cliente? Conviene para dar
soporte, pero es un usuario nuestro con acceso total a sus datos. Sea cual sea la
respuesta, **debe quedar escrita en el contrato**, no ser un hecho tácito. La
opción intermedia razonable: el usuario existe pero desactivado, y el cliente lo
activa cuando pide soporte.

El traspaso de la **infraestructura** (si el cliente asume el costo de Supabase y
Vercel) es un paso aparte: se le da propiedad de la organización de Supabase y se
transfiere o duplica el proyecto de Vercel.

---

## 5. Formación

La aplicación se aprende por rol, no de corrido. Currículo sugerido:

| Sesión | Audiencia | Contenido |
|---|---|---|
| **1 — Fundamento** | Todos | Por qué el sistema: cascada de niveles, ejes, semáforo, el ciclo de mejora. |
| **2 — Captura** | `operativo` | Captura por período, fechas de corte, autorizaciones. |
| **3 — Reunión diaria** | `operativo`, `administrativo` | Tablero por nivel, lectura del semáforo, disciplina de la reunión. |
| **4 — Análisis** | `administrativo`, `gerente` | Análisis causal, causas estándar, Pareto, planes de acción y evidencias. |
| **5 — Quick Win** | `gerente` | Tableros por pilar, candidatos, escalamiento entre niveles. |
| **6 — Administración** | `admin_cliente` | Indicadores y metas, estructura organizacional, usuarios y roles, horarios y cortes, seguridad de la cuenta y MFA. |

La sesión 6 es la que habilita la autonomía: mientras el cliente no sepa dar de
alta usuarios y ajustar indicadores, sigue dependiendo de nosotros.

Entregables de formación: manual por rol, grabaciones de las sesiones y un
entorno de práctica (una instancia demo con `seed_demo.sql`) separado del
productivo.

---

## 6. Actualizaciones y soporte

- **Correcciones**: se aplican en `main`, se etiquetan y se despliegan cliente
  por cliente, empezando por el de menor riesgo.
- **Migraciones de base de datos**: cada actualización que toque el esquema se
  aplica a cada instancia. Registrar en qué versión está cada cliente — sin ese
  registro, en seis meses nadie sabe qué corre dónde.
- **Ventanas de mantenimiento**: acordadas por contrato, fuera del horario de las
  reuniones diarias del cliente.

Registro mínimo de instancias (una tabla, donde sea, pero que exista):

| Cliente | Organización Supabase | Proyecto | URL | Versión | Fecha de alta |
|---|---|---|---|---|---|

---

## 7. Empaquetado comercial

Estructura de precio en tres componentes, que refleja los tres costos reales:

1. **Implantación** (pago único) — aprovisionamiento, carga de indicadores y
   estructura, y las 6 sesiones de formación. Es el grueso del trabajo y donde
   está el valor de la consultoría.
2. **Licencia y soporte** (recurrente) — derecho de uso, actualizaciones y
   soporte. Escalable por número de usuarios o de sitios.
3. **Infraestructura** (recurrente, repercutible) — Supabase y Vercel del
   cliente. Confirma el precio vigente de cada plataforma al cotizar; no lo des
   por sabido, cambian.

**Decisión pendiente — marca.** Hoy la app muestra "SFS" y "LeanProLogistic". Si
se vende como producto propio, se mantiene. Si algún cliente pide su marca, hay
que decidir si es un servicio con costo o si no se ofrece. Recomendación:
mantener la marca propia. Un producto reconocible vale más que un desarrollo a
medida invisible, y el white-label multiplica el mantenimiento.

**Contrato — mínimos que deben estar por escrito:**
- Propiedad de los datos (del cliente) y del software (nuestro).
- Tratamiento de datos personales, con la figura de encargado mientras nosotros
  operemos.
- Acceso de soporte: si existe, de qué tipo y bajo qué condiciones.
- Nivel de servicio y ventanas de mantenimiento.
- Qué pasa al terminar: entrega de un respaldo de sus datos y plazo de borrado.

---

## 8. Decisiones abiertas

| Tema | Decisión | Estado |
|---|---|---|
| Acceso de soporte tras la autonomía | ¿`admin_consultora` permanente, desactivado o ninguno? | Pendiente |
| Marca | ¿Se ofrece white-label? | Pendiente — recomendación: no |
| Infraestructura | ¿La paga el cliente directamente o se repercute? | Pendiente |
| MFA para `admin_cliente` | ¿Obligatorio? | Pendiente — recomendación: sí |
| Entorno de práctica | ¿Uno compartido para formación o uno por cliente? | Pendiente |
