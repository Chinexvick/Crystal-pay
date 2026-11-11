import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { ArrowDownRightIcon, ArrowRightIcon, ArrowUpRightIcon, CheckCircleIcon, WarningCircleIcon, WarningIcon } from '@phosphor-icons/react'
import { useDb } from '../lib/store'
import { useNow, useQueues } from '../lib/queues'
import { T, duration, fmtDay, fmtLongDay, fmtTime, naira, nairaCompact, num, pct, timeAgo } from '../lib/format'
import { Avatar, Card, Logo, PageHeader, Segmented, cx } from '../components/ui'
import { ColumnChart, Meter, RankedBars } from '../components/Charts'
import { Wait } from '../components/Wait'
import type { Tx } from '../data/types'

const MOVED: Record<string, string> = {
  funding_card: 'Wallet funding',
  funding_transfer: 'Wallet funding',
  funding_cct: 'Wallet funding',
  bill: 'Bill payments',
  withdrawal: 'Withdrawals',
  transfer_out: 'Send money',
  purchase: 'Marketplace',
}

export function providerHealth(rate: number) {
  if (rate >= 95) return { tone: 'ok' as const, label: 'Healthy' }
  if (rate >= 88) return { tone: 'warn' as const, label: 'Degraded' }
  return { tone: 'bad' as const, label: 'Failing' }
}

export default function Overview() {
  const db = useDb()
  const now = useNow()
  const queues = useQueues()
  const [range, setRange] = useState<'7' | '30' | '90'>('30')
  const [view, setView] = useState<'chart' | 'table'>('chart')
  const todayStart = new Date(now).setHours(0, 0, 0, 0)

  const active = queues.filter((q) => q.count > 0).sort((a, b) => b.late - a.late || (now - (b.oldest ?? now)) / b.sla - (now - (a.oldest ?? now)) / a.sla)
  const clear = queues.filter((q) => q.count === 0)

  const stats = useMemo(() => {
    const days = Number(range)
    const start = todayStart - (days - 1) * T.DAY
    const prevStart = start - days * T.DAY
    const moved = (t: Tx) => t.status === 'successful' && MOVED[t.type]
    const inRange = (t: number, a: number, b: number) => t >= a && t < b
    const buckets = Array.from({ length: days }, (_, i) => ({ ts: start + i * T.DAY, total: 0, parts: {} as Record<string, number> }))
    let total = 0
    let prevTotal = 0
    const byCat: Record<string, number> = {}
    let revenue = 0
    let prevRevenue = 0
    for (const t of db.txs) {
      const isRev = t.status === 'successful' && (t.type === 'plan_fee' || ((t.type === 'sale_release' || t.type === 'withdrawal' || t.type === 'funding_cct') && t.fee > 0))
      const rev = t.type === 'plan_fee' ? t.amount : t.fee
      if (t.createdAt >= start) {
        if (moved(t)) {
          total += t.amount
          const cat = MOVED[t.type]
          byCat[cat] = (byCat[cat] ?? 0) + t.amount
          const b = buckets[Math.min(days - 1, Math.floor((t.createdAt - start) / T.DAY))]
          if (b) {
            b.total += t.amount
            b.parts[cat] = (b.parts[cat] ?? 0) + t.amount
          }
        }
        if (isRev) revenue += rev
      } else if (inRange(t.createdAt, prevStart, start)) {
        if (moved(t)) prevTotal += t.amount
        if (isRev) prevRevenue += rev
      }
    }
    const billStats = (a: number, b: number) => {
      let ok = 0
      let bad = 0
      for (const x of db.bills) {
        if (x.createdAt < a || x.createdAt >= b || x.status === 'pending') continue
        if (x.status === 'successful') ok++
        else bad++
      }
      return { rate: ok + bad ? (ok / (ok + bad)) * 100 : 100, count: ok + bad }
    }
    const bills = billStats(start, now + 1)
    const prevBills = billStats(prevStart, start)
    const newUsers = db.users.filter((u) => u.joinedAt >= start).length
    const prevUsers = db.users.filter((u) => inRange(u.joinedAt, prevStart, start)).length
    return { days, buckets, total, prevTotal, byCat, revenue, prevRevenue, bills, prevBills, newUsers, prevUsers }
  }, [db, range, todayStart, now])

  const today = useMemo(() => {
    const s = { card: 0, transfer: 0, cct: 0, bills: 0, withdrawals: 0 }
    for (const t of db.txs) {
      if (t.createdAt < todayStart) break
      if (t.status !== 'successful') continue
      if (t.type === 'funding_card') s.card += t.amount
      if (t.type === 'funding_transfer') s.transfer += t.amount
      if (t.type === 'funding_cct') s.cct += t.amount
      if (t.type === 'bill') s.bills += t.amount
      if (t.type === 'withdrawal') s.withdrawals += t.amount
    }
    const heldOrders = db.orders.filter((o) => ['paid', 'shipped', 'delivered', 'disputed'].includes(o.stage))
    const held = heldOrders.reduce((a, o) => a + o.amount + o.deliveryFee, 0)
    const wallets = db.users.reduce((a, u) => a + u.balance, 0)
    const payouts = db.withdrawals.filter((w) => w.status === 'processing')
    return { ...s, held, heldCount: heldOrders.length, wallets, inTotal: s.card + s.transfer + s.cct, outTotal: s.bills + s.withdrawals, payouts: payouts.reduce((a, w) => a + w.amount, 0), payoutCount: payouts.length }
  }, [db, todayStart])

  const providers = [...db.providers].filter((p) => p.enabled).sort((a, b) => a.rate1h - b.rate1h).slice(0, 6)
  const cats = Object.entries(stats.byCat).sort((a, b) => b[1] - a[1])
  const rangeLabel = range === '7' ? '7 days' : range === '30' ? '30 days' : '90 days'

  return (
    <>
      <PageHeader
        eyebrow={<span className="text-[12.5px] font-semibold text-muted">{fmtLongDay(now)} · {fmtTime(now)}</span>}
        title="Overview"
        description="What needs the team right now, and how money is moving through Crystal Pay."
      />

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-5 mb-9">
        <Card title="Waiting on the team" subtitle="Oldest item first. The bar fills toward the time we promise to act within." pad={false}>
          <ul>
            {active.map((q) => (
              <li key={q.key} className="border-t border-line-2">
                <Link to={q.to} className="group grid grid-cols-[minmax(0,1fr)_auto] sm:grid-cols-[minmax(0,1fr)_64px_minmax(170px,auto)_24px] items-center gap-x-4 gap-y-2 px-5 py-3.5 sm:py-0 sm:h-[60px] hover:bg-hover transition-colors">
                  <span className="min-w-0">
                    <span className="block text-[14px] font-bold truncate">{q.label}</span>
                    <span className="block text-[12.5px] text-muted sm:truncate">
                      {num(q.count)} {q.count === 1 ? q.what[0] : q.what[1]} · act within {duration(q.sla)}
                    </span>
                  </span>
                  <span className="text-right">
                    <span className="text-[22px] font-bold tracking-[-0.02em] leading-none">{num(q.count)}</span>
                    {q.late > 0 && <span className="block text-[11.5px] font-semibold text-bad mt-1">{q.late} late</span>}
                  </span>
                  <span className="col-span-2 sm:col-span-1 flex items-center gap-2 sm:flex-col sm:items-start sm:gap-0.5">
                    <span className="text-[11.5px] text-faint">Oldest</span>
                    <Wait since={q.oldest} sla={q.sla} width={72} />
                  </span>
                  <ArrowRightIcon size={16} className="hidden sm:block text-faint group-hover:text-ink transition-colors" />
                </Link>
              </li>
            ))}
          </ul>
          {clear.length > 0 && (
            <div className="flex items-center gap-2 px-5 py-3 min-h-12 border-t border-line-2 text-[13px] text-muted">
              <CheckCircleIcon size={16} weight="fill" className="text-ok-mark shrink-0" />
              Nothing waiting in {clear.map((q) => q.label.toLowerCase()).join(', ')}.
            </div>
          )}
        </Card>

        <Card title="Money today" subtitle={`Since midnight · ${fmtDay(now)}`}>
          <dl className="text-[13px]">
            <Row label="Card funding" value={today.card} />
            <Row label="Bank transfers in" value={today.transfer} />
            <Row label="CCT deposits" value={today.cct} />
            <Row label="Money in" value={today.inTotal} strong />
            <div className="h-3" />
            <Row label="Bills paid" value={today.bills} />
            <Row label="Withdrawals paid" value={today.withdrawals} />
            <Row label="Money out" value={today.outTotal} strong />
          </dl>
          <div className="mt-4 grid grid-cols-2 gap-3">
            <div className="rounded-xl bg-sunken border border-line-2 px-3.5 py-3">
              <div className="text-[12px] text-muted">Held for buyers</div>
              <div className="text-[16px] font-bold mt-0.5">{nairaCompact(today.held)}</div>
              <div className="text-[12px] text-faint">{today.heldCount} open orders</div>
            </div>
            <div className="rounded-xl bg-sunken border border-line-2 px-3.5 py-3">
              <div className="text-[12px] text-muted">In user wallets</div>
              <div className="text-[16px] font-bold mt-0.5">{nairaCompact(today.wallets)}</div>
              <div className="text-[12px] text-faint">{num(db.users.length)} wallets</div>
            </div>
            <Link to="/withdrawals" className="rounded-xl bg-sunken border border-line-2 px-3.5 py-3 hover:border-[#dcd8e7]">
              <div className="text-[12px] text-muted">Payouts on the way</div>
              <div className="text-[16px] font-bold mt-0.5">{nairaCompact(today.payouts)}</div>
              <div className="text-[12px] text-faint">{today.payoutCount} at the bank now</div>
            </Link>
            <Link to="/cct" className="rounded-xl bg-sunken border border-line-2 px-3.5 py-3 hover:border-[#dcd8e7]">
              <div className="text-[12px] text-muted">1 CCT is worth</div>
              <div className="text-[16px] font-bold mt-0.5">₦{(db.settings.cctMode === 'market' ? db.settings.cctMarketRate : db.settings.cctRate).toFixed(2)}</div>
              <div className="text-[12px] text-faint">{db.settings.cctMode === 'market' ? 'Follows the market' : 'Fixed by staff'}</div>
            </Link>
          </div>
        </Card>
      </div>

      <div className="flex flex-wrap items-center gap-3 mb-4">
        <h2 className="h-title text-[18px] flex-1">Activity</h2>
        <Segmented label="Time range" value={range} onChange={setRange} items={[{ value: '7', label: '7 days' }, { value: '30', label: '30 days' }, { value: '90', label: '90 days' }]} />
      </div>

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4 mb-5">
        <Stat label="Money moved" value={nairaCompact(stats.total)} now={stats.total} prev={stats.prevTotal} range={rangeLabel} />
        <Stat label="Bill payments delivered" value={pct(stats.bills.rate, 1)} now={stats.bills.rate} prev={stats.prevBills.rate} range={rangeLabel} points sub={`of ${num(stats.bills.count)} payments`} />
        <Stat label="New users" value={num(stats.newUsers)} now={stats.newUsers} prev={stats.prevUsers} range={rangeLabel} />
        <Stat label="Revenue" value={nairaCompact(stats.revenue)} now={stats.revenue} prev={stats.prevRevenue} range={rangeLabel} sub="plans, sale and payout fees" />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-5 mb-5">
        <Card
          title="Money moved per day"
          subtitle="Funding, bills, marketplace, transfers and withdrawals that went through."
          actions={<Segmented label="Show as" value={view} onChange={setView} items={[{ value: 'chart', label: 'Chart' }, { value: 'table', label: 'Table' }]} />}
        >
          {view === 'chart' ? (
            <ColumnChart
              ariaLabel={`Money moved per day, last ${rangeLabel}`}
              height={248}
              format={(v) => naira(v)}
              axisFormat={(v) => nairaCompact(v)}
              data={stats.buckets.map((b, i) => ({
                key: String(b.ts),
                label: fmtLongDay(b.ts),
                axisLabel: stats.days <= 7 ? new Date(b.ts).toLocaleDateString('en-GB', { weekday: 'short' }) : fmtDay(b.ts),
                value: b.total,
                partial: i === stats.buckets.length - 1,
                detail: Object.entries(b.parts).sort((x, y) => y[1] - x[1]).map(([k, v]) => [k, nairaCompact(v)] as [string, string]),
              }))}
            />
          ) : (
            <div className="max-h-[248px] overflow-y-auto -mx-5 border-t border-line-2">
              <table className="w-full text-[13px]">
                <thead className="sticky top-0 bg-sunken">
                  <tr className="text-[12px] text-muted"><th className="text-left font-semibold px-5 h-8">Day</th><th className="text-right font-semibold px-5">Money moved</th></tr>
                </thead>
                <tbody>
                  {[...stats.buckets].reverse().map((b) => (
                    <tr key={b.ts} className="border-t border-line-2"><td className="px-5 h-9">{fmtLongDay(b.ts)}</td><td className="px-5 text-right num font-semibold">{naira(b.total)}</td></tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
        <Card title="Where it went" subtitle={`Share of money moved, last ${rangeLabel}`}>
          <RankedBars format={(v) => nairaCompact(v)} items={cats.map(([label, value]) => ({ label, value, note: pct((value / (stats.total || 1)) * 100, 0) }))} />
        </Card>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-5">
        <Card title="Bill providers" subtitle="Payments delivered in the last hour, weakest first" actions={<Link to="/bills" className="text-[13px] font-semibold text-brand hover:underline">All providers</Link>} pad={false}>
          <ul>
            {providers.map((p) => {
              const h = providerHealth(p.rate1h)
              return (
                <li key={p.key} className="grid grid-cols-[28px_minmax(0,1fr)_auto] sm:grid-cols-[28px_minmax(0,1fr)_120px_92px] items-center gap-x-3 gap-y-1.5 px-5 py-3 sm:py-0 sm:h-[52px] border-t border-line-2">
                  <span className="row-span-2 sm:row-span-1">
                    <Logo src={p.logo} name={p.name} size={28} />
                  </span>
                  <span className="min-w-0">
                    <span className="block text-[13.5px] font-semibold truncate">{p.name}</span>
                    <span className="block text-[12px] text-muted truncate">{p.service} · {(p.avgMs / 1000).toFixed(1)}s average</span>
                  </span>
                  <span className="col-start-2 row-start-2 sm:col-start-auto sm:row-start-auto flex items-center gap-2">
                    <Meter value={p.rate1h / 100} tone={h.tone} width={64} />
                    <span className="text-[13px] font-semibold num">{pct(p.rate1h)}</span>
                  </span>
                  <span className={cx('col-start-3 row-start-1 sm:col-start-auto sm:row-start-auto inline-flex items-center gap-1 text-[12.5px] font-semibold justify-self-end', h.tone === 'ok' ? 'text-ok' : h.tone === 'warn' ? 'text-warn' : 'text-bad')}>
                    {h.tone === 'ok' ? <CheckCircleIcon size={14} weight="fill" /> : h.tone === 'warn' ? <WarningIcon size={14} weight="fill" /> : <WarningCircleIcon size={14} weight="fill" />}
                    {h.label}
                  </span>
                </li>
              )
            })}
          </ul>
        </Card>
        <Card title="Recent staff actions" actions={<Link to="/audit" className="text-[13px] font-semibold text-brand hover:underline">Audit log</Link>} pad={false}>
          <ul>
            {db.audit.slice(0, 6).map((a) => {
              const s = db.staff.find((x) => x.name === a.by)
              return (
                <li key={a.id} className="flex items-center gap-3 px-5 h-[52px] border-t border-line-2">
                  <Avatar name={a.by} src={s?.avatar} size={28} />
                  <span className="min-w-0 flex-1 text-[13px] truncate">
                    <span className="font-semibold">{a.by}</span> <span className="text-ink-2">{a.action.charAt(0).toLowerCase() + a.action.slice(1)}</span> <span className="font-semibold">{a.target}</span>
                  </span>
                  <span className="text-[12px] text-faint shrink-0">{timeAgo(a.at, now)}</span>
                </li>
              )
            })}
          </ul>
        </Card>
      </div>
    </>
  )
}

function Row({ label, value, strong }: { label: string; value: number; strong?: boolean }) {
  return (
    <div className={cx('flex items-baseline justify-between py-1.5', strong && 'border-t border-line mt-1 pt-2.5')}>
      <dt className={strong ? 'font-bold' : 'text-ink-2'}>{label}</dt>
      <dd className={cx('num', strong ? 'font-bold' : 'font-semibold')}>{naira(value)}</dd>
    </div>
  )
}

function Stat({ label, value, now, prev, range, points, sub }: { label: string; value: string; now: number; prev: number; range: string; points?: boolean; sub?: string }) {
  const diff = points ? now - prev : prev ? ((now - prev) / prev) * 100 : 0
  const up = diff >= 0
  return (
    <div className="bg-surface border border-line rounded-[var(--radius-card)] px-5 py-4">
      <div className="text-[12.5px] font-semibold text-muted">{label}</div>
      <div className="text-[26px] font-bold tracking-[-0.025em] mt-1 leading-tight">{value}</div>
      <div className="flex flex-wrap items-center gap-x-1 gap-y-0.5 mt-1.5 text-[12px]">
        {prev > 0 || points ? (
          <>
            <span className={cx('inline-flex items-center gap-0.5 font-semibold whitespace-nowrap', up ? 'text-ok' : 'text-bad')}>
              {up ? <ArrowUpRightIcon size={13} weight="bold" /> : <ArrowDownRightIcon size={13} weight="bold" />}
              {points ? `${Math.abs(diff).toFixed(1)} pts` : pct(Math.abs(diff), 0)}
            </span>
            <span className="text-faint">vs previous {range}</span>
          </>
        ) : (
          <span className="text-faint">No earlier data</span>
        )}
      </div>
      {sub && <div className="text-[12px] text-faint mt-0.5">{sub}</div>}
    </div>
  )
}
