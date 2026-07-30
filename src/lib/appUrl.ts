/**
 * URL pública de SFS, la que se le dicta a un usuario nuevo junto con su
 * contraseña temporal.
 *
 * Mientras no exista el despliegue propio, cae en `window.location.origin`:
 * el correo apunta al mismo sitio desde el que el administrador está creando
 * al usuario, que siempre es la respuesta correcta. Al publicar el dominio
 * definitivo basta con definir `VITE_APP_URL` en Vercel — es el único valor
 * que hay que tocar.
 */
export const APP_URL = import.meta.env.VITE_APP_URL || window.location.origin
