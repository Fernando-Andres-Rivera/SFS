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

1. ~~**Timestamps duplicados en migraciones.**~~ **Resuelto.** Los seis pares que
   compartían prefijo se renumeraron conservando el orden de aplicación previo.
   Hoy los 53 timestamps son únicos y ordenar por nombre de archivo da un orden
   inequívoco. **Regla a futuro**: una migración, un timestamp — si dos se crean
   el mismo día, se diferencian en el sufijo, nunca se repiten.

2. ~~**Separar catálogo de datos de demostración.**~~ **Resuelto.** `seed.sql`
   mezclaba el catálogo que todo cliente necesita (los 7 ejes) con datos
   ficticios (organización demo, sitio Planta Bogotá, indicadores de ejemplo).
   Se dividió en:
   - `seed_catalogo.sql` — los 7 ejes. **Siempre**, en toda instancia.
   - `seed_demo.sql` — organización y datos de ejemplo. **Solo en demos o
     formación**, nunca en la instancia productiva de un cliente.

   (Unidades y taxonomía de causas ya vivían en migraciones, no en el seed —
   no requirieron cambio.)

3. **Aprovisionamiento por CLI, no por SQL Editor.** Correr 53 archivos a mano
   en el panel es aceptable una vez; en cada cliente es una fuente garantizada de
   errores. Adoptar Supabase CLI: `supabase link` + `supabase db push`, con las
   Edge Functions desplegadas por comando.

### Antes del segundo o tercer cliente

4. **Versionado por tags.** Cada cliente corre una versión, no "lo último que
   haya en `main`". Sin esto, un push rompe cinco clientes a la vez.

5. **Suite de pruebas de regresión.** Hoy no hay pruebas automatizadas. Con una
   instancia el riesgo lo absorbe el usuario; con cinco, un fallo en RLS o en la
   captura se multiplica. Prioridad: aislamiento entre organizaciones, permisos
   por rol, y el upsert de mediciones.

6. **Respaldo y restauración documentados.** Qué se respalda, cada cuánto, y el
   procedimiento probado de restauración. Es la primera pregunta de cualquier
   área de TI del lado del cliente.

7. **Monitoreo.** Saber que la instancia de un cliente está caída antes de que
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

- [ ] Aplicar migraciones en orden (`supabase db push`).
- [ ] Aplicar `seed_catalogo.sql`.
- [ ] Verificar que RLS está activo en todas las tablas.

### 3.3 Edge Functions

- [ ] Desplegar `invite-user`, `create-demo-signup`, `delete-demo-signup`.
- [ ] Configurar los secretos del proyecto (service role key).

### 3.4 Frontend

- [ ] Crear proyecto en Vercel apuntando al repositorio, en el tag de la versión
      contratada.
- [ ] Variables: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_APP_URL`.
- [ ] Dominio: `<cliente>.sfs.<dominio-leanprologistic>` o el dominio propio del
      cliente si lo aporta.
- [ ] Registrar la URL en Supabase → Authentication → URL Configuration
      (Site URL y Redirect URLs).

### 3.5 Puesta a punto funcional

- [ ] Crear la organización del cliente y sus sitios.
- [ ] Crear el primer usuario `admin_cliente` y enrolar su MFA.
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
