import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CrownIcon, PencilSimpleIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { fmtDate, naira, num } from '../lib/format'
import { Avatar, Button, Card, Empty, Field, Input, PageHeader, Pill, Tabs, Textarea } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Meter, SegmentedBar } from '../components/Charts'
import { Status } from '../components/status'
import { Modal, toast } from '../components/overlays'
import type { PlanConfig, Subscription } from '../data/types'

const planColor: Record<PlanConfig['key'], string> = { basic: 'var(--color-series-1)', pro: 'var(--color-series-2)', business: 'var(--color-series-3)' }

export default function Plans() {
  const db = useDb()
  const nav = useNavigate()
  const [edit, setEdit] = useState<PlanConfig | null>(null)
  const [tab, setTab] = useState<'active' | 'past_due' | 'cancelled'>('active')

  const per = useMemo(() => {
    const m: Record<string, number> = { basic: 0, pro: 0, business: 0 }
    db.subscriptions.filter((s) => s.status === 'active').forEach((s) => m[s.plan]++)
    return m
  }, [db.subscriptions])
  const mrr = db.plans.reduce((a, p) => a + p.price * per[p.key], 0)
  const rows = db.subscriptions.filter((s) => s.status === tab).sort((a, b) => a.renewsAt - b.renewsAt)

  const columns: Column<Subscription>[] = [
    { key: 'who', header: 'Seller', cell: (s) => { const u = db.users.find((x) => x.id === s.userId)!; return <span className="flex items-center gap-2.5 min-w-0"><Avatar name={u.name} src={u.avatar} size={28} verified={u.kyc === 'verified'} /><span className="min-w-0"><span className="block font-semibold truncate">{u.name}</span><span className="block text-[12px] text-muted">@{u.username}</span></span></span> } },
    { key: 'plan', header: 'Plan', cell: (s) => <span className="inline-flex items-center gap-2 font-semibold"><span className="w-2 h-2 rounded-full" style={{ background: planColor[s.plan] }} />{db.plans.find((p) => p.key === s.plan)?.name}</span> },
    { key: 'used', header: 'Live listings', cell: (s) => { const p = db.plans.find((x) => x.key === s.plan)!; return <span className="flex items-center gap-2"><Meter value={s.listingsUsed / p.listings} tone={s.listingsUsed >= p.listings ? 'warn' : 'brand'} width={64} /><span className="num text-[12.5px] text-ink-2">{s.listingsUsed} of {p.listings}</span></span> } },
    { key: 'status', header: 'Status', cell: (s) => <Status kind="sub" value={s.status} /> },
    { key: 'renews', header: tab === 'cancelled' ? 'Ended' : tab === 'past_due' ? 'Was due' : 'Renews', cell: (s) => <span className="text-ink-2">{fmtDate(s.renewsAt)}</span> },
    { key: 'since', header: 'Seller since', cell: (s) => <span className="text-ink-2">{fmtDate(s.startedAt)}</span> },
  ]

  return (
    <>
      <PageHeader title="Seller plans" description="Sellers pay every 30 days from their wallet to keep listings live. Buying, bill payments and the wallet stay free." />
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-5">
        {db.plans.map((p) => (
          <div key={p.key} className="border border-line rounded-[var(--radius-card)] p-5 flex flex-col">
            <div className="flex items-center gap-2 mb-3">
              <span className="w-2.5 h-2.5 rounded-full" style={{ background: planColor[p.key] }} />
              <h2 className="font-bold text-[15px]">{p.name}</h2>
              {p.key === 'basic' ? <Pill tone="ok">Confirmed</Pill> : <Pill tone="neutral">Proposed</Pill>}
              <span className="flex-1" />
              <Button size="sm" variant="ghost" icon={PencilSimpleIcon} onClick={() => setEdit(p)}>Edit</Button>
            </div>
            <div className="text-[26px] font-bold tracking-[-0.025em] leading-none">{naira(p.price)}<span className="text-[13px] font-semibold text-muted tracking-normal"> / 30 days</span></div>
            <ul className="mt-4 mb-5 space-y-1.5 text-[13px] text-ink-2">
              <li>Up to <span className="font-semibold text-ink">{p.listings}</span> live listings</li>
              <li><span className="font-semibold text-ink">{p.feePct}%</span> fee on each completed sale</li>
              <li>{p.boosts ? <><span className="font-semibold text-ink">{p.boosts}</span> boosts a month</> : 'No boosts'}</li>
            </ul>
            <div className="mt-auto pt-4 border-t border-line-2 flex justify-between text-[13px]">
              <span className="text-muted">{num(per[p.key])} sellers</span>
              <span className="font-semibold num">{naira(p.price * per[p.key])} a month</span>
            </div>
          </div>
        ))}
      </div>
      <Card className="mb-7">
        <div className="flex flex-wrap items-baseline justify-between gap-2 mb-3">
          <div className="text-[13.5px]"><span className="font-bold">{num(per.basic + per.pro + per.business)} active sellers</span> <span className="text-muted">bring in</span> <span className="font-bold num">{naira(mrr)}</span> <span className="text-muted">every 30 days</span></div>
          <ul className="flex flex-wrap gap-4 text-[12.5px]">{db.plans.map((p) => <li key={p.key} className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-[3px]" style={{ background: planColor[p.key] }} /><span className="font-semibold">{p.name}</span><span className="text-muted num">{per[p.key]}</span></li>)}</ul>
        </div>
        <SegmentedBar label="Active sellers by plan" parts={db.plans.map((p) => ({ label: p.name, value: per[p.key], color: planColor[p.key] }))} />
      </Card>
      <Tabs value={tab} onChange={setTab} items={[{ value: 'active', label: 'Active', count: db.subscriptions.filter((s) => s.status === 'active').length }, { value: 'past_due', label: 'Payment due', count: db.subscriptions.filter((s) => s.status === 'past_due').length }, { value: 'cancelled', label: 'Cancelled', count: db.subscriptions.filter((s) => s.status === 'cancelled').length }]} />
      <DataTable columns={columns} rows={rows} rowKey={(s) => s.userId} onRowClick={(s) => nav(`/users/${s.userId}`)} empty={<Empty icon={CrownIcon} title="No sellers here" />} />
      {edit && <EditPlan plan={edit} onClose={() => setEdit(null)} />}
    </>
  )
}

function EditPlan({ plan, onClose }: { plan: PlanConfig; onClose: () => void }) {
  const dispatch = useDispatch()
  const [price, setPrice] = useState(String(plan.price))
  const [listings, setListings] = useState(String(plan.listings))
  const [fee, setFee] = useState(String(plan.feePct))
  const [boosts, setBoosts] = useState(String(plan.boosts))
  const [why, setWhy] = useState('')
  const next: PlanConfig = { ...plan, price: Number(price) || 0, listings: Number(listings) || 0, feePct: Number(fee) || 0, boosts: Number(boosts) || 0 }
  const changed = next.price !== plan.price || next.listings !== plan.listings || next.feePct !== plan.feePct || next.boosts !== plan.boosts
  const valid = changed && next.price > 0 && next.listings > 0 && next.feePct >= 0 && next.feePct < 30 && why.trim().length >= 3
  return (
    <Modal
      open
      onClose={onClose}
      title={`Edit the ${plan.name} plan`}
      footer={<><Button onClick={onClose}>Cancel</Button><Button variant="primary" disabled={!valid} onClick={() => { dispatch({ t: 'plan/update', plan: next, reason: why.trim() }); toast(`${plan.name} plan updated`); onClose() }}>Save changes</Button></>}
    >
      <p className="text-[13px] text-ink-2 mb-4">New prices apply at each seller’s next renewal. Sellers get a notice 7 days before.</p>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Price every 30 days"><Input prefix="₦" inputMode="numeric" value={price} onChange={(e) => setPrice(e.target.value.replace(/\D/g, ''))} /></Field>
        <Field label="Live listings allowed"><Input inputMode="numeric" value={listings} onChange={(e) => setListings(e.target.value.replace(/\D/g, ''))} /></Field>
        <Field label="Fee on each sale"><Input suffix="%" inputMode="decimal" value={fee} onChange={(e) => setFee(e.target.value.replace(/[^\d.]/g, ''))} /></Field>
        <Field label="Boosts a month"><Input inputMode="numeric" value={boosts} onChange={(e) => setBoosts(e.target.value.replace(/\D/g, ''))} /></Field>
      </div>
      <div className="mt-3"><Field label="Reason for the change" hint="Saved to the audit log."><Textarea rows={2} value={why} onChange={(e) => setWhy(e.target.value)} placeholder="For example: owners approved new prices" /></Field></div>
    </Modal>
  )
}
