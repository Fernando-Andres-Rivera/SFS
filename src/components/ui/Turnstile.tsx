import { useEffect, useRef } from 'react'

declare global {
  interface Window {
    turnstile?: {
      render: (
        container: HTMLElement,
        options: {
          sitekey: string
          callback: (token: string) => void
          'expired-callback'?: () => void
          'error-callback'?: () => void
        },
      ) => string
      reset: (widgetId?: string) => void
      remove: (widgetId?: string) => void
    }
  }
}

// Site key — es pública por diseño (va embebida en cualquier página que use
// Turnstile), la que protege de verdad es la Secret Key, que solo vive en la
// configuración de Supabase Auth y nunca en el código del cliente. Depende
// del dominio: cada despliegue (cada instancia de cliente) necesita su
// propia sitekey de Turnstile, registrada contra su propio dominio — de ahí
// que venga por variable de entorno y no hardcodeada.
const TURNSTILE_SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY

interface TurnstileProps {
  onToken: (token: string | null) => void
  /** Incrementar este número fuerza un widget nuevo (token nuevo) — los
   * tokens de Turnstile son de un solo uso, así que hay que renovarlo
   * después de cada intento de envío, exitoso o no. */
  resetSignal: number
}

/** Widget de verificación anti-bots de Cloudflare Turnstile. El script se
 * carga una sola vez desde index.html; este componente solo lo renderiza
 * dentro de su contenedor y expone el token vía onToken. */
export function Turnstile({ onToken, resetSignal }: TurnstileProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const widgetIdRef = useRef<string | null>(null)
  const onTokenRef = useRef(onToken)

  // Escribir la ref durante el render rompe las garantías de React (el render
  // debe ser puro y puede descartarse). Se sincroniza después de cada render,
  // que es lo que necesitan los callbacks de Turnstile: se invocan siempre
  // más tarde, nunca durante este render.
  useEffect(() => {
    onTokenRef.current = onToken
  })

  useEffect(() => {
    let cancelled = false
    let pollId: ReturnType<typeof setInterval> | undefined

    function renderWidget() {
      if (cancelled || !containerRef.current || !window.turnstile) return
      widgetIdRef.current = window.turnstile.render(containerRef.current, {
        sitekey: TURNSTILE_SITE_KEY,
        callback: (token) => onTokenRef.current(token),
        'expired-callback': () => onTokenRef.current(null),
        'error-callback': () => onTokenRef.current(null),
      })
    }

    if (window.turnstile) {
      renderWidget()
    } else {
      // El script en index.html tiene async/defer — puede no estar listo
      // todavía la primera vez que este componente monta.
      pollId = setInterval(() => {
        if (window.turnstile) {
          clearInterval(pollId)
          renderWidget()
        }
      }, 100)
    }

    return () => {
      cancelled = true
      if (pollId) clearInterval(pollId)
      if (widgetIdRef.current && window.turnstile) window.turnstile.remove(widgetIdRef.current)
    }
    // Solo se monta/desmonta una vez por instancia — resetSignal se maneja
    // en el efecto de abajo para no re-crear el widget completo cada vez.
  }, [])

  useEffect(() => {
    if (resetSignal === 0) return
    if (widgetIdRef.current && window.turnstile) {
      window.turnstile.reset(widgetIdRef.current)
      onTokenRef.current(null)
    }
  }, [resetSignal])

  return <div ref={containerRef} className="turnstile-widget" />
}
