import { useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { ArrowClockwiseIcon, ArrowCounterClockwiseIcon, CheckCircleIcon, ReceiptIcon, WarningCircleIcon, WarningIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { useNow } from '../lib/queues'
import { fmtDateTime, groupDigits, naira, num, pct, timeAgo } from '../lib/format'
import { Button, Card, CopyButton, Empty, KV, Logo, Mono, PageHeader, SearchInput, Select, Tabs, Toggle, cx } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Meter } from '../components/Charts'
import { Status } from '../components/status'
import { Drawer, confirm, toast } from '../components/overlays'
import { providerHealth } from './Overview'
import type { Bill, BillService } from '../data/types'

const services: BillService[] = ['Airtime', 'Data', 'Electricity', 'Cable TV', 'Betting', 'Internet']

export default function Bills() {
  const db = useDb()
  const dispatch = useDispatch()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const [tab, setTab] = useState<'all' | 'failed' | 'pending' | 'refunded'>((params.get('tab') as 'failed') ?? 'all')
  const [q, setQ] = useState('')
  const [svc, setSvc] = useState<'all' | BillService>('all')
  const [allProviders, setAllProviders] = useState(false)

  useEffect(() => {
    const t = params.get('tab')
    if (t === 'failed' || t === 'pending' || t === 'refunded') setTab(t)
  }, [params])

  const counts = useMemo(() => ({ failed: db.bills.filter((b) => b.status === 'failed').length, pending: db.bills.filter((b) => b.status === 'pending').length, refunded: db.bills.filter((b) => b.status === 'refunded').length }), [db.bills])
  const rows = useMemo(() => {
    const s = q.trim().toLowerCase()
    const digits = s.replace(/\D/g, '')
    return db.bills.filter((b) => {
      if (tab !== 'all' && b.status !== tab) return false
      if (svc !== 'all' && b.service !== svc) return false
      if (!s) return true
      const u = db.users.find((x) => x.id === b.userId)
      return b.id.toLowerCase().includes(s) || (digits.length >= 4 && b.recipient.replace(/\D/g, '').includes(digits)) || !!u?.name.toLowerCase().includes(s)
    })
  }, [db, tab, svc, q])

  const providers = [...db.providers].sort((a, b) => a.rate1h - b.rate1h)
  const shown = allProviders ? providers : providers.slice(0, 7)
  const open = db.bills.find((b) => b.id === params.get('id')) ?? null

  const columns: Column<Bill>[] = [
    {
      key: 'svc', header: 'Payment',
      cell: (b) => {
        const p = db.providers.find((x) => x.key === b.providerKey)!
        return (
          <span className="flex items-center gap-2.5 min-w-0">
            <Logo src={p.logo} name={p.name} size={28} />
            <span className="min-w-0"><span className="block font-semibold truncate">{b.service} · {p.name}</span><span className="block text-[12px] text-muted truncate">{b.plan ?? '—'}</span></span>
          </span>
        )
      },
    },
    { key: 'user', header: 'User', cell: (b) => <span className="truncate">{db.users.find((u) => u.id === b.userId)?.name}</span> },
    { key: 'to', header: 'Recipient', cell: (b) => <Mono className="text-ink-2">{b.service === 'Electricity' ? groupDigits(b.recipient) : b.recipient}</Mono> },
    { key: 'amount', header: 'Amount', align: 'right', cell: (b) => <span className="num font-semibold">{naira(b.amount)}</span> },
    { key: 'status', header: 'Status', cell: (b) => <Status kind="bill" value={b.status} /> },
    { key: 'when', header: 'Time', cell: (b) => <span className="text-ink-2 whitespace-nowrap" title={fmtDateTime(b.createdAt)}>{timeAgo(b.createdAt, now)}</span> },
  ]

  return (
    <>
      <PageHeader title="Bill payments" description="Failed payments refund automatically within minutes. Anything marked “Failed, not refunded” got stuck and needs a person." />
      <Card
        title="Providers"
        subtitle="Share of payments delivered. Pause a provider to show “temporarily unavailable” in the app instead of failing."
        className="mb-6"
        pad={false}
        actions={<button type="button" onClick={() => setAllProviders((v) => !v)} className="text-[13px] font-semibold text-brand hover:underline">{allProviders ? 'Show fewer' : `Show all ${providers.length}`}</button>}
      >
        <div className="overflow-x-auto">
          <table className="w-full text-[13px]">
            <thead>
              <tr className="text-[12px] text-muted border-y border-line bg-sunken">
                <th className="text-left font-semibold px-5 h-8">Provider</th>
                <th className="text-left font-semibold px-4">Last hour</th>
                <th className="text-right font-semibold px-4">Last 24 hours</th>
                <th className="text-right font-semibold px-4">Average time</th>
                <th className="text-right font-semibold px-4">Payments today</th>
                <th className="text-left font-semibold px-4">Health</th>
                <th className="text-right font-semibold px-5">On</th>
              </tr>
            </thead>
            <tbody>
              {shown.map((p) => {
                const h = providerHealth(p.rate1h)
                return (
                  <tr key={p.key} className={cx('border-b border-line-2 last:border-b-0', !p.enabled && 'opacity-60')}>
                    <td className="px-5 h-12"><span className="flex items-center gap-2.5"><Logo src={p.logo} name={p.name} size={26} /><span><span className="block font-semibold">{p.name}</span><span className="block text-[12px] text-muted">{p.service === 'Airtime' ? 'Airtime and data' : p.service}</span></span></span></td>
                    <td className="px-4"><span className="flex items-center gap-2"><Meter value={p.rate1h / 100} tone={h.tone} width={72} /><span className="num font-semibold">{pct(p.rate1h)}</span></span></td>
                    <td className="px-4 text-right num text-ink-2">{pct(p.rate24h)}</td>
                    <td className="px-4 text-right num text-ink-2">{(p.avgMs / 1000).toFixed(1)}s</td>
                    <td className="px-4 text-right num text-ink-2">{num(p.volume24h)}</td>
                    <td className="px-4">
                      {p.enabled ? (
                        <span className={cx('inline-flex items-center gap-1 text-[12.5px] font-semibold', h.tone === 'ok' ? 'text-ok' : h.tone === 'warn' ? 'text-warn' : 'text-bad')}>
                          {h.tone === 'ok' ? <CheckCircleIcon size={14} weight="fill" /> : h.tone === 'warn' ? <WarningIcon size={14} weight="fill" /> : <WarningCircleIcon size={14} weight="fill" />}{h.label}
                        </span>
                      ) : <span className="text-[12.5px] font-semibold text-muted">Paused</span>}
                    </td>
                    <td className="px-5 text-right">
                      <Toggle
                        label={`${p.name} on`}
                        on={p.enabled}
                        onChange={async (v) => {
                          if (!v) {
                            const ok = await confirm({ title: `Pause ${p.name}?`, message: `People will see “${p.name} is temporarily unavailable” and cannot pay until you turn it back on.`, confirmLabel: 'Pause provider', tone: 'danger' })
                            if (!ok) return
                          }
                          dispatch({ t: 'provider/toggle', key: p.key, enabled: v })
                          toast(v ? `${p.name} is back on` : `${p.name} paused`)
                        }}
                      />
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </Card>

      <Tabs value={tab} onChange={(t) => { setTab(t); setParams(t === 'all' ? {} : { tab: t }, { replace: true }) }} items={[{ value: 'all', label: 'All payments' }, { value: 'failed', label: 'Failed, not refunded', count: counts.failed, alert: true }, { value: 'pending', label: 'Waiting on provider', count: counts.pending }, { value: 'refunded', label: 'Refunded', count: counts.refunded }]} />
      <div className="flex flex-wrap items-center gap-2.5 mb-4">
        <SearchInput value={q} onChange={setQ} placeholder="Phone, meter, smartcard, reference or name" className="w-full sm:w-[340px]" />
        <Select value={svc} onChange={(e) => setSvc(e.target.value as 'all' | BillService)} aria-label="Service" className="w-auto">
          <option value="all">All services</option>
          {services.map((s) => <option key={s}>{s}</option>)}
        </Select>
        <span className="text-[12.5px] text-muted ml-auto">{num(rows.length)} payments</span>
      </div>
      <DataTable columns={columns} rows={rows} rowKey={(b) => b.id} activeKey={open?.id} onRowClick={(b) => setParams({ ...(tab !== 'all' ? { tab } : {}), id: b.id }, { replace: true })} empty={<Empty icon={ReceiptIcon} title={tab === 'failed' ? 'No stuck payments' : 'No payments match'}>{tab === 'failed' ? 'Every failed payment has been refunded.' : 'Try another search or service.'}</Empty>} />
      <BillDrawer bill={open} onClose={() => setParams(tab !== 'all' ? { tab } : {}, { replace: true })} />
    </>
  )
}

function BillDrawer({ bill, onClose }: { bill: Bill | null; onClose: () => void }) {
  const db = useDb()
  const dispatch = useDispatch()
  if (!bill) return null
  const p = db.providers.find((x) => x.key === bill.providerKey)!
  const u = db.users.find((x) => x.id === bill.userId)!
  const stuck = bill.status === 'failed' || bill.status === 'pending'
  return (
    <Drawer
      open
      onClose={onClose}
      title={`${bill.service} · ${p.name}`}
      subtitle={<Mono copy>{bill.id}</Mono>}
      footer={stuck ? (
        <>
          <Button icon={ArrowClockwiseIcon} onClick={() => { dispatch({ t: 'bill/requery', id: bill.id }); toast(bill.status === 'pending' ? 'Provider confirmed: delivered' : 'Provider still reports it as failed') }}>Check with provider</Button>
          <span className="flex-1" />
          <Button
            variant="primary"
            icon={ArrowCounterClockwiseIcon}
            onClick={async () => {
              const ok = await confirm({ title: `Refund ${naira(bill.amount)} to ${u.name}?`, message: 'The money goes back to their wallet now. Only refund if the provider confirms the payment did not go through.', confirmLabel: 'Refund to wallet' })
              if (ok) { dispatch({ t: 'bill/refund', id: bill.id }); toast('Refunded to wallet') }
            }}
          >
            Refund to wallet
          </Button>
        </>
      ) : undefined}
    >
      <div className="flex items-end justify-between gap-4 mb-5">
        <div className="flex items-center gap-3"><Logo src={p.logo} name={p.name} size={40} /><span className="text-[28px] font-bold num tracking-[-0.02em]">{naira(bill.amount)}</span></div>
        <Status kind="bill" value={bill.status} />
      </div>
      {bill.failureReason && (
        <div className={cx('flex gap-2 rounded-xl px-4 py-3 mb-5 text-[13px]', bill.status === 'failed' ? 'bg-bad-tint/70 text-bad' : 'bg-[#f1f0f5] text-ink-2')}>
          <WarningCircleIcon size={17} weight="fill" className="shrink-0 mt-px" />
          <span><span className="font-semibold">{bill.status === 'refunded' ? 'Failed and refunded:' : 'Failed:'}</span> {bill.failureReason}</span>
        </div>
      )}
      {bill.token && (
        <div className="rounded-xl border border-line bg-sunken px-4 py-3.5 mb-5">
          <div className="text-[12px] text-muted mb-1">Electricity token · {bill.units}</div>
          <div className="flex items-center justify-between gap-2"><span className="mono text-[19px] tracking-[0.04em] text-ink">{groupDigits(bill.token)}</span><CopyButton value={bill.token} /></div>
        </div>
      )}
      <KV rows={[
        ['User', <Link to={`/users/${u.id}`} className="text-brand hover:underline">{u.name}</Link>],
        ['Recipient', <Mono>{bill.service === 'Electricity' ? groupDigits(bill.recipient) : bill.recipient}</Mono>],
        ...(bill.recipientName ? [['Name on account', bill.recipientName] as [string, string]] : []),
        ['Plan', bill.plan ?? '—'],
        ['Provider reference', <Mono copy>{bill.providerRef}</Mono>],
        ['Paid at', fmtDateTime(bill.createdAt)],
      ]} />
    </Drawer>
  )
}
