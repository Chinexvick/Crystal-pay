const MIN = 60_000
const HOUR = 60 * MIN
const DAY = 24 * HOUR

const ng = new Intl.NumberFormat('en-NG')
const ng2 = new Intl.NumberFormat('en-NG', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

/** ₦12,500 — kobo shown only when present (or when `kobo` is forced). */
export function naira(n: number, opts: { kobo?: boolean; sign?: boolean } = {}) {
  const abs = Math.abs(n)
  const body = opts.kobo || abs % 1 !== 0 ? ng2.format(abs) : ng.format(Math.round(abs))
  const sign = n < 0 ? '−' : opts.sign ? '+' : ''
  return `${sign}₦${body}`
}

/** ₦12.9M, ₦480K, ₦9,200 */
export function nairaCompact(n: number) {
  const abs = Math.abs(n)
  const sign = n < 0 ? '−' : ''
  if (abs >= 1e9) return `${sign}₦${trim(abs / 1e9)}B`
  if (abs >= 1e6) return `${sign}₦${trim(abs / 1e6)}M`
  if (abs >= 1e4) return `${sign}₦${trim(abs / 1e3)}K`
  return `${sign}₦${ng.format(Math.round(abs))}`
}

function trim(v: number) {
  return v >= 100 ? v.toFixed(0) : v >= 10 ? v.toFixed(1).replace(/\.0$/, '') : v.toFixed(2).replace(/0$/, '').replace(/\.0$/, '')
}

export const num = (n: number) => ng.format(n)

export const pct = (n: number, digits = 1) => `${n.toFixed(digits).replace(/\.0+$/, '')}%`

export function duration(ms: number) {
  const m = Math.max(0, Math.floor(ms / MIN))
  if (m < 1) return 'under 1m'
  if (m < 60) return `${m}m`
  const h = Math.floor(m / 60)
  if (h <= 48) return m % 60 === 0 ? `${h}h` : `${h}h ${String(m % 60).padStart(2, '0')}m`
  const d = Math.floor(h / 24)
  return h % 24 === 0 ? `${d}d` : `${d}d ${h % 24}h`
}

export function timeAgo(ts: number, now = Date.now()) {
  const diff = now - ts
  if (diff < 0) return `in ${duration(-diff)}`
  if (diff < MIN) return 'just now'
  if (diff < HOUR) return `${Math.floor(diff / MIN)}m ago`
  if (diff < DAY) return `${Math.floor(diff / HOUR)}h ago`
  if (diff < 7 * DAY) return `${Math.floor(diff / DAY)}d ago`
  return fmtDate(ts)
}

const dFmt = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
const dShort = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short' })
const tFmt = new Intl.DateTimeFormat('en-GB', { hour: 'numeric', minute: '2-digit', hour12: true })
const wdFmt = new Intl.DateTimeFormat('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })

export const fmtDate = (ts: number) => dFmt.format(ts)
export const fmtDay = (ts: number) => dShort.format(ts)
export const fmtTime = (ts: number) => tFmt.format(ts).replace(' ', ' ').toLowerCase()
export const fmtDateTime = (ts: number) => {
  const sameYear = new Date(ts).getFullYear() === new Date().getFullYear()
  return `${sameYear ? dShort.format(ts) : dFmt.format(ts)}, ${fmtTime(ts)}`
}
export const fmtLongDay = (ts: number) => wdFmt.format(ts)

export function initials(name: string) {
  const parts = name.trim().split(/\s+/)
  return ((parts[0]?.[0] ?? '') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase()
}

export const lastFour = (s: string) => `•••• ${s.slice(-4)}`

export const groupDigits = (s: string, size = 4) => s.replace(new RegExp(`(.{${size}})(?=.)`, 'g'), '$1 ')

export const shortHash = (h: string, head = 6, tail = 4) => (h.length > head + tail + 1 ? `${h.slice(0, head)}…${h.slice(-tail)}` : h)

export function maskId(type: string, n: string) {
  if (type === 'Passport') return `${n.slice(0, 2)}•••••${n.slice(-2)}`
  return `•••••••${n.slice(-4)}`
}

export const plural = (n: number, one: string, many = `${one}s`) => `${num(n)} ${n === 1 ? one : many}`

export function downloadCsv(filename: string, rows: (string | number)[][]) {
  const esc = (v: string | number) => {
    const s = String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const blob = new Blob([rows.map((r) => r.map(esc).join(',')).join('\n')], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

export const T = { MIN, HOUR, DAY }
