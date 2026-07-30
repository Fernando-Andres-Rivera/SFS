import { IndicatorCard } from '../../components/ui/IndicatorCard'

const trend = [
  { period_date: '2026-07-01', value: 82 },
  { period_date: '2026-07-02', value: 90 },
  { period_date: '2026-07-03', value: null },
  { period_date: '2026-07-04', value: 76 },
  { period_date: '2026-07-05', value: 95 },
  { period_date: '2026-07-06', value: 88 },
  { period_date: '2026-07-07', value: 100 },
]

export function DesignPreviewPage() {
  return (
    <div style={{ padding: 24, background: '#f4f5f7' }}>
      <h2>Seguridad amarillo, objetivo en todas, foco azure, alineación</h2>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16, maxWidth: 1100 }}>
        <IndicatorCard
          id="1"
          name="Seguridad — Uso de EPP'S (binario, con tendencia)"
          unit="Sí/No"
          level={1}
          improvementDirection="mayor_mejor"
          valueType="binario"
          latestValue={0.95}
          breakdown={{ count: 19, total: 20 }}
          targetValue={1}
          trend={trend}
          axisColor="#FBC02D"
        />
        <IndicatorCard
          id="2"
          name="Calidad — Razón (sin tendencia, debe alinear igual)"
          unit="%"
          level={1}
          improvementDirection="mayor_mejor"
          valueType="razon"
          latestValue={93.4}
          breakdown={{ count: 217, total: 244 }}
          targetValue={100}
          trend={[]}
          axisColor="#26A69A"
        />
        <IndicatorCard
          id="3"
          name="Mantenimiento — Numérico (con tendencia)"
          unit="ton"
          level={2}
          improvementDirection="mayor_mejor"
          valueType="numerico"
          latestValue={120}
          breakdown={null}
          targetValue={150}
          trend={trend}
          axisColor="#1B365D"
        />
        <IndicatorCard
          id="4"
          name="Foco — debe verse Azure, no el navy corporativo"
          unit=""
          level={2}
          improvementDirection="mayor_mejor"
          valueType="binario"
          latestValue={1}
          breakdown={{ count: 20, total: 20 }}
          targetValue={1}
          trend={trend}
          axisColor="#1B365D"
          isFocus
        />
      </div>
    </div>
  )
}
