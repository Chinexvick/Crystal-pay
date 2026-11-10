import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { CoinsIcon, WarningIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { useNow } from '../lib/queues'
import { fmtDateTime, fmtDay, naira, num, shortHash, timeAgo } from '../lib/format'
import { Avatar, Button, Card, Empty, KV, Mono, PageHeader, Tabs } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { LineChart, Meter } from '../components/Charts'
import { Status } from '../components/status'
import { Drawer, confirm, toast } from '../components/overlays'
import type { CctDeposit } from '../data/types'

export default function Cct() {
  const db = useDb()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const [tab, setTab] = useState<'all' | 'confirming' | 'underpaid' | 'credited'>('all')
  const s = db.settings
  const rate = s.cctMode === 'market' ? s.cctMarketRate : s.cctRate
  const todayStart = new Date(now).setHours(0, 0, 0, 0)

  const counts = useMemo(() => ({
    confirming: db.cct.filter((d) => d.status === 'confirming' || d.status === 'converting').length,
    underpaid: db.cct.filter((d) => d.status === 'underpaid').length,
    credited: db.cct.filter((d) => d.status === 'credited').length,
  }), [db.cct])
  const today = db.cct.filter((d) => d.createdAt >= todayStart && d.status === 'credited')
  const rows = db.cct.filter((d) => tab === 'all' || (tab === 'confirming' ? d.status === 'confirming' || d.status === 'converting' : d.status === tab))
  const open = db.cct.find((d) => d.id === params.get('id')) ?? null
  const first = db.cctRates[0].rate
  const change = ((rate - first) / first) * 100

  const columns: Column<CctDeposit>[] = [
    { key: 'id', header: 'Deposit', cell: (d) => <span><Mono className="block text-ink">{d.id}</Mono><span className="block text-[12px] text-muted">{timeAgo(d.createdAt, now)}</span></span> },
    { key: 'who', header: 'Person', cell: (d) => { const u = db.users.find((x) => x.id === d.userId)!; return <span className="flex items-center gap-2.5 min-w-0"><Avatar name={u.name} src={u.avatar} size={26} /><span className="truncate font-semibold">{u.name}</span></span> } },
    { key: 'cct', header: 'Tokens', align: 'right', cell: (d) => <span className="num font-semibold">{num(d.amount)} CCT</span> },
    { key: 'ngn', header: 'Naira credited', align: 'right', cell: (d) => <span className="num font-semibold">{d.status === 'credited' ? naira(d.naira) : <span className="text-faint">—</span>}</span> },
    { key: 'conf', header: 'Confirmations', cell: (d) => <span className="flex items-center gap-2"><Meter value={d.confirmations / s.cctConfirmations} tone={d.confirmations >= s.cctConfirmations ? 'ok' : 'brand'} width={48} /><span className="num text-[12.5px] text-ink-2">{Math.min(d.confirmations, s.cctConfirmations)}/{s.cctConfirmations}</span></span> },
    { key: 'status', header: 'Status', cell: (d) => <Status kind="cct" value={d.status} /> },
    { key: 'hash', header: 'Transaction hash', cell: (d) => <Mono copy={d.txHash} className="text-ink-2">{shortHash(d.txHash)}</Mono> },
  ]

  return (
    <>
      <PageHeader title="CCT deposits" description={`Crystal Cat tokens sent to each person’s deposit address on BNB Smart Chain. Naira is credited after ${s.cctConfirmations} confirmations, at the rate locked when the deposit was seen.`} />
      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_320px] gap-5 mb-6">
        <Card title="CCT rate, last 30 days" subtitle={`${s.cctMode === 'market' ? 'Follows the market' : 'Fixed by staff'} · change it in Rates and fees`}>
          <LineChart ariaLabel="CCT to Naira rate over 30 days" points={db.cctRates.map((p, i) => ({ ts: p.at, value: i === db.cctRates.length - 1 ? rate : p.rate }))} height={170} format={(v) => `₦${v.toFixed(2)}`} axisFormat={(v) => `₦${v.toFixed(0)}`} dateLabel={(t) => fmtDay(t)} />
        </Card>
        <div className="grid grid-cols-1 gap-4">
          <div className="border border-line rounded-[var(--radius-card)] px-5 py-4">
            <div className="text-[12.5px] font-semibold text-muted">1 CCT is worth</div>
            <div className="text-[28px] font-bold tracking-[-0.025em] leading-tight mt-1">₦{rate.toFixed(2)}</div>
            <div className="text-[12px] text-muted mt-1"><span className={change >= 0 ? 'text-ok font-semibold' : 'text-bad font-semibold'}>{change >= 0 ? '+' : '−'}{Math.abs(change).toFixed(1)}%</span> over 30 days · {s.cctServicePct}% conversion fee</div>
          </div>
          <div className="border border-line rounded-[var(--radius-card)] px-5 py-4">
            <div className="text-[12.5px] font-semibold text-muted">Credited today</div>
            <div className="text-[28px] font-bold tracking-[-0.025em] leading-tight mt-1">{naira(today.reduce((a, d) => a + d.naira, 0))}</div>
            <div className="text-[12px] text-muted mt-1">{today.length} deposits · {num(today.reduce((a, d) => a + d.amount, 0))} CCT</div>
          </div>
        </div>
      </div>
      <Tabs value={tab} onChange={setTab} items={[{ value: 'all', label: 'All deposits' }, { value: 'confirming', label: 'On the way', count: counts.confirming }, { value: 'underpaid', label: 'Needs a decision', count: counts.underpaid, alert: true }, { value: 'credited', label: 'Credited', count: counts.credited }]} />
      <DataTable columns={columns} rows={rows} rowKey={(d) => d.id} activeKey={open?.id} onRowClick={(d) => setParams({ id: d.id }, { replace: true })} empty={<Empty icon={CoinsIcon} title="No deposits here" />} />
      <CctDrawer d={open} rate={rate} onClose={() => setParams({}, { replace: true })} />
    </>
  )
}

function CctDrawer({ d, rate, onClose }: { d: CctDeposit | null; rate: number; onClose: () => void }) {
  const db = useDb()
  const dispatch = useDispatch()
  if (!d) return null
  const u = db.users.find((x) => x.id === d.userId)!
  const s = db.settings
  const gross = d.amount * rate
  const fee = Math.round(gross * (s.cctServicePct / 100))
  return (
    <Drawer
      open
      onClose={onClose}
      title={`${num(d.amount)} CCT from ${u.name}`}
      subtitle={<Mono copy>{d.id}</Mono>}
      footer={d.status === 'underpaid' ? (
        <>
          <Button variant="danger-soft" onClick={async () => {
            const r = await confirm({ title: 'Do not credit this deposit?', message: 'The tokens stay in the company wallet and the person sees “below minimum, not credited”. Support can explain the minimum.', confirmLabel: 'Do not credit', tone: 'danger', reason: { label: 'Reason', placeholder: 'For example: below minimum, user told in chat' } })
            if (r) { dispatch({ t: 'cct/fail', id: d.id, reason: r.reason }); toast('Marked as not credited') }
          }}>Do not credit</Button>
          <span className="flex-1" />
          <Button variant="primary" onClick={async () => {
            const r = await confirm({ title: `Credit ${naira(Math.round(gross - fee))}?`, message: `${num(d.amount)} CCT at ₦${rate.toFixed(2)}, minus the ${s.cctServicePct}% fee, goes to ${u.name}’s wallet now.`, confirmLabel: 'Credit wallet', reason: { label: 'Why make an exception?', placeholder: 'For example: first deposit, user did not know the minimum' } })
            if (r) { dispatch({ t: 'cct/credit', id: d.id, reason: r.reason }); toast('Wallet credited') }
          }}>Credit at today’s rate</Button>
        </>
      ) : undefined}
    >
      <div className="flex items-center justify-between mb-5">
        <div className="text-[28px] font-bold num tracking-[-0.02em]">{d.status === 'credited' ? naira(d.naira) : `${num(d.amount)} CCT`}</div>
        <Status kind="cct" value={d.status} />
      </div>
      {d.status === 'underpaid' && (
        <div className="rounded-xl bg-warn-tint/70 border border-[#f6dcb0] px-4 py-3 mb-5 text-[13px] text-ink-2">
          <div className="flex items-center gap-1.5 font-bold text-warn mb-0.5"><WarningIcon size={16} weight="fill" /> Below the {s.cctMinDeposit} CCT minimum</div>
          Automatic crediting skipped it. Credit it as an exception or leave it uncredited.
        </div>
      )}
      <KV rows={[
        ['Person', <Link to={`/users/${u.id}`} className="text-brand hover:underline">{u.name}</Link>],
        ['Tokens received', `${num(d.amount)} CCT`],
        ['Rate', `₦${(d.status === 'credited' ? d.rate : rate).toFixed(2)} per CCT`],
        ['Conversion fee', d.status === 'credited' ? naira(d.fee) : `${s.cctServicePct}%`],
        ['Confirmations', `${Math.min(d.confirmations, s.cctConfirmations)} of ${s.cctConfirmations}`],
        ['Seen on chain', fmtDateTime(d.createdAt)],
        ['Block', num(d.block)],
      ]} />
      <div className="mt-5 space-y-3">
        <div><div className="text-[12px] text-muted mb-1">Deposit address</div><Mono copy className="text-[12.5px] break-all">{d.address}</Mono></div>
        <div><div className="text-[12px] text-muted mb-1">Transaction hash</div><Mono copy={d.txHash} className="text-[12.5px] break-all">{shortHash(d.txHash, 18, 10)}</Mono></div>
      </div>
    </Drawer>
  )
}
