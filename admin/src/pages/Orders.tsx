import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { CheckIcon, PackageIcon, ShieldCheckIcon, XCircleIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { useNow } from '../lib/queues'
import { T, duration, fmtDate, fmtDateTime, naira, num } from '../lib/format'
import { Avatar, Button, Empty, KV, Mono, PageHeader, SearchInput, Tabs, Thumb, cx } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import { Drawer, confirm, toast } from '../components/overlays'
import type { Order } from '../data/types'

const inProgress = (o: Order) => o.stage === 'paid' || o.stage === 'shipped' || o.stage === 'delivered'

export default function Orders() {
  const db = useDb()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const linked = db.orders.find((o) => o.id === params.get('id'))
  const [tab, setTab] = useState<'progress' | 'disputed' | 'completed' | 'cancelled' | 'all'>(linked ? (inProgress(linked) ? 'progress' : linked.stage === 'disputed' ? 'disputed' : linked.stage === 'completed' ? 'completed' : 'cancelled') : 'progress')
  const [q, setQ] = useState('')

  const goods = db.orders
  const rows = useMemo(() => {
    const s = q.trim().toLowerCase()
    return goods
      .filter((o) => (tab === 'all' ? true : tab === 'progress' ? inProgress(o) : o.stage === tab))
      .filter((o) => {
        if (!s) return true
        const l = db.listings.find((x) => x.id === o.listingId)
        const b = db.users.find((x) => x.id === o.buyerId)
        const se = db.users.find((x) => x.id === o.sellerId)
        return o.id.toLowerCase().includes(s) || !!l?.title.toLowerCase().includes(s) || !!b?.name.toLowerCase().includes(s) || !!se?.name.toLowerCase().includes(s)
      })
      .sort((a, b) => b.createdAt - a.createdAt)
  }, [goods, tab, q, db])
  const held = goods.filter((o) => inProgress(o) || o.stage === 'disputed')
  const heldTotal = held.reduce((a, o) => a + o.amount + o.deliveryFee, 0)
  const open = linked ?? null

  const columns: Column<Order>[] = [
    { key: 'o', header: 'Order', cell: (o) => { const l = db.listings.find((x) => x.id === o.listingId)!; return <span className="flex items-center gap-3 min-w-0"><Thumb src={l.image} size={38} /><span className="min-w-0"><span className="block font-semibold truncate max-w-[260px]">{l.title}</span><Mono className="text-[12px] text-muted">{o.id}</Mono></span></span> } },
    { key: 'buyer', header: 'Buyer', cell: (o) => <Person id={o.buyerId} /> },
    { key: 'seller', header: 'Seller', cell: (o) => <Person id={o.sellerId} /> },
    { key: 'amt', header: 'Paid', align: 'right', cell: (o) => <span><span className="block num font-semibold">{naira(o.amount + o.deliveryFee)}</span><span className="block text-[12px] text-muted">{o.method}</span></span> },
    { key: 'stage', header: 'Status', cell: (o) => <Status kind="order" value={o.stage} /> },
    { key: 'release', header: 'Seller paid', cell: (o) => <ReleaseNote o={o} now={now} /> },
    { key: 'date', header: 'Ordered', cell: (o) => <span className="text-ink-2 whitespace-nowrap">{fmtDate(o.createdAt)}</span> },
  ]

  return (
    <>
      <PageHeader title="Orders" description="Marketplace orders paid through Crystal Protect. The seller is paid when the buyer confirms delivery, or automatically 72 hours after delivery." />
      <div className="flex flex-wrap items-center gap-3 mb-5 rounded-[var(--radius-card)] border border-line px-5 py-3.5">
        <ShieldCheckIcon size={20} weight="fill" className="text-brand" />
        <span className="text-[13.5px]"><span className="font-bold num">{naira(heldTotal)}</span> held for buyers across {num(held.length)} open orders</span>
      </div>
      <Tabs value={tab} onChange={(t) => { setTab(t); setParams({}, { replace: true }) }} items={[{ value: 'progress', label: 'In progress', count: goods.filter(inProgress).length }, { value: 'disputed', label: 'In dispute', count: goods.filter((o) => o.stage === 'disputed').length }, { value: 'completed', label: 'Completed', count: goods.filter((o) => o.stage === 'completed').length }, { value: 'cancelled', label: 'Cancelled', count: goods.filter((o) => o.stage === 'cancelled').length }, { value: 'all', label: 'All' }]} />
      <div className="flex flex-wrap items-center gap-2.5 mb-4"><SearchInput value={q} onChange={setQ} placeholder="Order number, item, buyer or seller" className="w-full sm:w-[320px]" /></div>
      <DataTable columns={columns} rows={rows} rowKey={(o) => o.id} activeKey={open?.id} onRowClick={(o) => setParams({ id: o.id }, { replace: true })} empty={<Empty icon={PackageIcon} title="No orders here" />} />
      <OrderDrawer o={open} now={now} onClose={() => setParams({}, { replace: true })} />
    </>
  )
}

function Person({ id }: { id: string }) {
  const db = useDb()
  const u = db.users.find((x) => x.id === id)!
  return <span className="flex items-center gap-2 min-w-0"><Avatar name={u.name} src={u.avatar} size={24} /><span className="truncate max-w-[140px]">{u.name}</span></span>
}

function ReleaseNote({ o, now }: { o: Order; now: number }) {
  if (o.stage === 'completed') return <span className="text-[12.5px] text-ink-2">{fmtDate(o.completedAt ?? o.createdAt)}</span>
  if (o.stage === 'cancelled') return <span className="text-[12.5px] text-faint">Refunded to buyer</span>
  if (o.stage === 'disputed') return <span className="text-[12.5px] text-bad font-semibold">Frozen by dispute</span>
  if (o.stage === 'delivered' && o.deliveredAt) {
    const left = o.deliveredAt + 72 * T.HOUR - now
    return <span className="text-[12.5px] text-ink-2">{left > 0 ? `Automatically in ${duration(left)}` : 'Releasing now'}</span>
  }
  return <span className="text-[12.5px] text-faint">After delivery</span>
}

function OrderDrawer({ o, now, onClose }: { o: Order | null; now: number; onClose: () => void }) {
  const db = useDb()
  const dispatch = useDispatch()
  if (!o) return null
  const l = db.listings.find((x) => x.id === o.listingId)!
  const buyer = db.users.find((x) => x.id === o.buyerId)!
  const seller = db.users.find((x) => x.id === o.sellerId)!
  const fee = Math.round((o.amount * o.serviceFeePct) / 100)
  const dispute = db.disputes.find((d) => d.orderId === o.id)
  const steps: [string, number | undefined][] = [['Paid', o.createdAt], [o.method === 'Pickup' ? 'Ready for pickup' : 'Shipped', o.shippedAt], ['Delivered', o.deliveredAt], ['Seller paid', o.completedAt]]
  return (
    <Drawer
      open
      onClose={onClose}
      title={l.title}
      subtitle={<span className="flex items-center gap-2"><Mono copy>{o.id}</Mono><span>· ordered {fmtDateTime(o.createdAt)}</span></span>}
      footer={inProgress(o) ? (
        <>
          <Button variant="danger-soft" icon={XCircleIcon} onClick={async () => {
            const r = await confirm({ title: `Cancel and refund ${naira(o.amount + o.deliveryFee)}?`, message: `The money goes back to ${buyer.name}’s wallet now. ${seller.name} is told the order was cancelled.`, confirmLabel: 'Cancel order', tone: 'danger', reason: { label: 'Reason', options: ['Seller did not ship within 48 hours', 'Seller asked to cancel', 'Buyer and seller agreed', 'Other'] } })
            if (r) { dispatch({ t: 'order/cancel', id: o.id, reason: r.reason }); toast('Order cancelled and buyer refunded') }
          }}>Cancel and refund</Button>
          <span className="flex-1" />
          <Button variant="primary" icon={CheckIcon} onClick={async () => {
            const ok = await confirm({ title: `Release ${naira(o.amount + o.deliveryFee - fee)} to ${seller.name}?`, message: 'Do this only when the buyer has the item. It cannot be undone.', confirmLabel: 'Release payment', reason: { label: 'Why release early?', placeholder: 'For example: buyer confirmed on a call', optional: o.stage === 'delivered' } })
            if (ok) { dispatch({ t: 'order/release', id: o.id }); toast('Payment released to seller') }
          }}>Release to seller</Button>
        </>
      ) : undefined}
    >
      <div className="flex gap-4 mb-5"><Thumb src={l.image} size={72} /><div><div className="text-[24px] font-bold num tracking-[-0.02em]">{naira(o.amount + o.deliveryFee)}</div><div className="mt-1"><Status kind="order" value={o.stage} /></div></div></div>
      {dispute && <Link to={`/disputes?id=${dispute.id}`} className="flex items-center justify-between rounded-xl bg-bad-tint/60 px-4 py-3 mb-5 text-[13px] text-bad font-semibold hover:bg-bad-tint">Dispute {dispute.id}: {dispute.reason}<span>Open</span></Link>}
      <ol className="grid grid-cols-4 gap-2 mb-6">
        {steps.map(([label, at], i) => (
          <li key={label} className="min-w-0">
            <div className={cx('h-1 rounded-full mb-2', at ? 'bg-brand' : 'bg-line')} />
            <div className={cx('text-[12.5px] font-semibold', at ? 'text-ink' : 'text-faint')}>{label}</div>
            <div className="text-[11.5px] text-muted">{at ? fmtDate(at) : i === 3 && o.stage === 'cancelled' ? 'Cancelled' : '—'}</div>
          </li>
        ))}
      </ol>
      <h3 className="text-[13px] font-bold mb-1">Money</h3>
      <KV rows={[
        ['Item', naira(o.amount)],
        ['Delivery', o.deliveryFee ? naira(o.deliveryFee) : 'Pickup, free'],
        ['Buyer paid', naira(o.amount + o.deliveryFee)],
        [`Sale fee (${o.serviceFeePct}%, ${seller.plan === 'none' ? 'no' : seller.plan} plan)`, `−${naira(fee)}`],
        ['Seller receives', naira(o.amount + o.deliveryFee - fee)],
      ]} />
      <h3 className="text-[13px] font-bold mt-6 mb-1">People</h3>
      <KV rows={[
        ['Buyer', <Link to={`/users/${buyer.id}`} className="text-brand hover:underline">{buyer.name}</Link>],
        ['Seller', <Link to={`/users/${seller.id}`} className="text-brand hover:underline">{seller.name}</Link>],
        [o.method === 'Pickup' ? 'Pickup at' : 'Deliver to', o.address],
      ]} />
      {o.stage === 'delivered' && o.deliveredAt && <p className="text-[12.5px] text-muted mt-4">Releases to the seller automatically in {duration(Math.max(0, o.deliveredAt + 72 * T.HOUR - now))} unless the buyer opens a dispute.</p>}
    </Drawer>
  )
}
