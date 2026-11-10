import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import { cx } from './ui'

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [w, setW] = useState(0)
  useLayoutEffect(() => {
    if (!ref.current) return
    const el = ref.current
    const ro = new ResizeObserver(() => setW(el.clientWidth))
    ro.observe(el)
    setW(el.clientWidth)
    return () => ro.disconnect()
  }, [])
  return [ref, w] as const
}

function niceTicks(max: number, count = 4) {
  if (max <= 0) return [0, 1]
  const raw = max / count
  const mag = 10 ** Math.floor(Math.log10(raw))
  const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? 10 * mag
  const top = Math.ceil(max / step) * step
  const ticks: number[] = []
  for (let v = 0; v <= top + step / 2; v += step) ticks.push(v)
  return ticks
}

/* ───────────── column chart (one series) ───────────── */

export interface ColumnDatum {
  key: string
  label: string
  axisLabel: string
  value: number
  partial?: boolean
  detail?: [string, string][]
}

export function ColumnChart({ data, height = 220, format, axisFormat, ariaLabel }: { data: ColumnDatum[]; height?: number; format: (v: number) => string; axisFormat: (v: number) => string; ariaLabel: string }) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const [hover, setHover] = useState<number | null>(null)
  const padL = 52
  const padR = 8
  const padT = 10
  const axisH = 26
  const plotH = height - axisH - padT
  const plotW = Math.max(0, width - padL - padR)
  const ticks = niceTicks(Math.max(...data.map((d) => d.value), 1))
  const top = ticks[ticks.length - 1]
  const band = data.length ? plotW / data.length : 0
  const barW = Math.max(2, Math.min(24, band - 2, band * 0.66))
  const y = (v: number) => padT + plotH - (v / top) * plotH
  const every = data.length > 60 ? 15 : data.length > 20 ? 5 : 1
  const h = hover !== null ? data[hover] : null

  return (
    <div ref={ref} className="relative select-none" style={{ height }}>
      {width > 0 && (
        <svg width={width} height={height} role="img" aria-label={ariaLabel} className="block overflow-visible">
          {ticks.map((t) => (
            <g key={t}>
              <line x1={padL} x2={width - padR} y1={y(t)} y2={y(t)} stroke={t === 0 ? 'var(--color-axis)' : 'var(--color-grid)'} strokeWidth={1} shapeRendering="crispEdges" />
              <text x={padL - 10} y={y(t)} dy="0.32em" textAnchor="end" className="num" fontSize={11.5} fill="var(--color-faint)">
                {axisFormat(t)}
              </text>
            </g>
          ))}
          {data.map((d, i) => {
            const x = padL + i * band + (band - barW) / 2
            const bh = Math.max(0, plotH - (y(d.value) - padT))
            const r = Math.min(4, barW / 2, bh)
            const yy = y(d.value)
            const path = bh <= 0 ? '' : `M${x},${padT + plotH} V${yy + r} Q${x},${yy} ${x + r},${yy} H${x + barW - r} Q${x + barW},${yy} ${x + barW},${yy + r} V${padT + plotH} Z`
            const on = hover === i
            return (
              <g key={d.key}>
                {path && <path d={path} fill={d.partial ? 'var(--color-brand-tint-2)' : on ? 'var(--color-brand-deep)' : 'var(--color-brand)'} opacity={hover !== null && !on ? 0.55 : 1} />}
                {(i % every === 0 || i === data.length - 1) && (data.length - 1 - i >= every / 2 || i === data.length - 1) && (
                  <text x={padL + i * band + band / 2} y={height - 8} textAnchor="middle" fontSize={11.5} fill="var(--color-faint)" className="num">
                    {d.axisLabel}
                  </text>
                )}
                <rect
                  x={padL + i * band}
                  y={padT}
                  width={band}
                  height={plotH}
                  fill="transparent"
                  tabIndex={0}
                  aria-label={`${d.label}: ${format(d.value)}`}
                  onPointerEnter={() => setHover(i)}
                  onPointerLeave={() => setHover(null)}
                  onFocus={() => setHover(i)}
                  onBlur={() => setHover(null)}
                  style={{ outline: 'none' }}
                />
              </g>
            )
          })}
        </svg>
      )}
      {h && hover !== null && (
        <Tip x={padL + hover * band + band / 2} y={y(h.value)} width={width}>
          <div className="text-[15px] font-bold num">{format(h.value)}</div>
          <div className="text-[12px] text-muted mb-1">
            {h.label}
            {h.partial ? ' · so far' : ''}
          </div>
          {h.detail?.map(([k, v]) => (
            <div key={k} className="flex justify-between gap-6 text-[12px]">
              <span className="text-muted">{k}</span>
              <span className="font-semibold num">{v}</span>
            </div>
          ))}
        </Tip>
      )}
    </div>
  )
}

function Tip({ x, y, width, children }: { x: number; y: number; width: number; children: ReactNode }) {
  const tipW = 220
  const left = Math.min(Math.max(0, x - tipW / 2), Math.max(0, width - tipW))
  return (
    <div className="absolute z-10 pointer-events-none bg-surface border border-line rounded-xl shadow-[var(--shadow-pop)] px-3 py-2.5 animate-fade" style={{ left, top: Math.max(0, y - 12), width: tipW, transform: 'translateY(-100%)' }}>
      {children}
    </div>
  )
}

/* ───────────── line chart (one series) ───────────── */

export function LineChart({ points, height = 160, format, axisFormat, ariaLabel, dateLabel }: { points: { ts: number; value: number }[]; height?: number; format: (v: number) => string; axisFormat: (v: number) => string; ariaLabel: string; dateLabel: (ts: number) => string }) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const [hover, setHover] = useState<number | null>(null)
  const padL = 44
  const padR = 64
  const padT = 12
  const axisH = 24
  const plotH = height - axisH - padT
  const plotW = Math.max(0, width - padL - padR)
  const vals = points.map((p) => p.value)
  const lo = Math.floor(Math.min(...vals) - 0.5)
  const hi = Math.ceil(Math.max(...vals) + 0.5)
  const x = (i: number) => padL + (points.length > 1 ? (i / (points.length - 1)) * plotW : 0)
  const y = (v: number) => padT + plotH - ((v - lo) / (hi - lo || 1)) * plotH
  const ticks = [lo, (lo + hi) / 2, hi]
  const d = points.map((p, i) => `${i ? 'L' : 'M'}${x(i)},${y(p.value)}`).join(' ')
  const area = `${d} L${x(points.length - 1)},${padT + plotH} L${x(0)},${padT + plotH} Z`
  const last = points[points.length - 1]
  return (
    <div ref={ref} className="relative select-none" style={{ height }}
      onPointerMove={(e) => {
        const rect = (e.currentTarget as HTMLDivElement).getBoundingClientRect()
        const px = e.clientX - rect.left
        const i = Math.round(((px - padL) / (plotW || 1)) * (points.length - 1))
        setHover(Math.max(0, Math.min(points.length - 1, i)))
      }}
      onPointerLeave={() => setHover(null)}
    >
      {width > 0 && points.length > 1 && (
        <svg width={width} height={height} role="img" aria-label={ariaLabel} className="block overflow-visible">
          {ticks.map((t, i) => (
            <g key={i}>
              <line x1={padL} x2={padL + plotW} y1={y(t)} y2={y(t)} stroke="var(--color-grid)" strokeWidth={1} shapeRendering="crispEdges" />
              <text x={padL - 10} y={y(t)} dy="0.32em" textAnchor="end" fontSize={11.5} fill="var(--color-faint)" className="num">{axisFormat(t)}</text>
            </g>
          ))}
          <path d={area} fill="var(--color-brand)" opacity={0.1} />
          <path d={d} fill="none" stroke="var(--color-brand)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
          <circle cx={x(points.length - 1)} cy={y(last.value)} r={4} fill="var(--color-brand)" stroke="white" strokeWidth={2} />
          <text x={x(points.length - 1) + 10} y={y(last.value)} dy="0.32em" fontSize={12.5} fontWeight={700} fill="var(--color-ink)" className="num">{format(last.value)}</text>
          {[0, Math.floor((points.length - 1) / 2), points.length - 1].map((i) => (
            <text key={i} x={x(i)} y={height - 6} textAnchor={i === 0 ? 'start' : i === points.length - 1 ? 'end' : 'middle'} fontSize={11.5} fill="var(--color-faint)">{dateLabel(points[i].ts)}</text>
          ))}
          {hover !== null && (
            <g>
              <line x1={x(hover)} x2={x(hover)} y1={padT} y2={padT + plotH} stroke="var(--color-axis)" strokeWidth={1} />
              <circle cx={x(hover)} cy={y(points[hover].value)} r={4} fill="var(--color-brand)" stroke="white" strokeWidth={2} />
            </g>
          )}
        </svg>
      )}
      {hover !== null && (
        <Tip x={x(hover)} y={y(points[hover].value)} width={width}>
          <div className="text-[15px] font-bold num">{format(points[hover].value)}</div>
          <div className="text-[12px] text-muted">{dateLabel(points[hover].ts)}</div>
        </Tip>
      )}
    </div>
  )
}

/* ───────────── ranked bars (part to whole) ───────────── */

export function RankedBars({ items, format }: { items: { label: string; value: number; note?: string }[]; format: (v: number) => string }) {
  const max = Math.max(...items.map((i) => i.value), 1)
  return (
    <ul className="space-y-3.5">
      {items.map((it) => (
        <li key={it.label}>
          <div className="flex items-baseline justify-between gap-3 mb-1.5">
            <span className="text-[13px] font-semibold">{it.label}</span>
            <span className="text-[13px] font-bold num">
              {format(it.value)}
              {it.note && <span className="text-muted font-medium ml-1.5">{it.note}</span>}
            </span>
          </div>
          <div className="h-2 rounded-full bg-line-2 overflow-hidden">
            <div className="h-full rounded-full bg-brand" style={{ width: `${(it.value / max) * 100}%` }} />
          </div>
        </li>
      ))}
    </ul>
  )
}

/* ───────────── thin segmented bar ───────────── */

export function SegmentedBar({ parts, label }: { parts: { label: string; value: number; color: string }[]; label: string }) {
  const total = parts.reduce((a, p) => a + p.value, 0) || 1
  return (
    <div className="flex h-2 gap-[2px]" role="img" aria-label={`${label}: ${parts.map((p) => `${p.label} ${p.value}`).join(', ')}`}>
      {parts.filter((p) => p.value > 0).map((p) => (
        <div key={p.label} title={`${p.label}: ${p.value}`} className="h-full first:rounded-l-full last:rounded-r-full" style={{ width: `${(p.value / total) * 100}%`, background: p.color }} />
      ))}
    </div>
  )
}

/* ───────────── meter ───────────── */

export function Meter({ value, tone, width = '100%' }: { value: number; tone: 'brand' | 'warn' | 'bad' | 'ok'; width?: number | string }) {
  const track = { brand: 'bg-brand-tint-2', ok: 'bg-[#cfeedb]', warn: 'bg-[#fbe3bd]', bad: 'bg-[#f9cfd6]' }[tone]
  const fill = { brand: 'bg-brand', ok: 'bg-ok-mark', warn: 'bg-warn-mark', bad: 'bg-bad-mark' }[tone]
  return (
    <div className={cx('h-1.5 rounded-full overflow-hidden', track)} style={{ width }}>
      <div className={cx('h-full rounded-full', fill)} style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%` }} />
    </div>
  )
}
