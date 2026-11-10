import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { ArrowRightIcon, ChatCircleTextIcon, CheckCircleIcon, NoteIcon, ScalesIcon, ShieldCheckIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { SLA, useNow } from '../lib/queues'
import { T, fmtDate, fmtDateTime, naira, timeAgo } from '../lib/format'
import { Avatar, Button, Card, Empty, Field, Input, Mono, PageHeader, Tabs, Textarea, Thumb, cx } from '../components/ui'
import { Status } from '../components/status'
import { Wait } from '../components/Wait'
import { Modal, confirm, toast } from '../components/overlays'
import type { Dispute } from '../data/types'

export default function Disputes() {
  const db = useDb()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const [tab, setTab] = useState<'open' | 'resolved'>('open')
  const lists = useMemo(() => {
    const open = db.disputes.filter((d) => d.status === 'open' || d.status === 'awaiting_seller').sort((a, b) => a.openedAt - b.openedAt)
    const resolved = db.disputes.filter((d) => !(d.status === 'open' || d.status === 'awaiting_seller')).sort((a, b) => (b.resolvedAt ?? 0) - (a.resolvedAt ?? 0))
    return { open, resolved }
  }, [db.disputes])
  const list = lists[tab]
  const sel = db.disputes.find((d) => d.id === params.get('id')) ?? list[0]

  return (
    <>
      <PageHeader title="Disputes" description="When a buyer reports a problem, the payment stays held in Crystal Protect until you decide. Read both sides, then release, refund or split." />
      <Tabs value={tab} onChange={(t) => { setTab(t); setParams({}, { replace: true }) }} items={[{ value: 'open', label: 'Open', count: lists.open.length, alert: true }, { value: 'resolved', label: 'Resolved', count: lists.resolved.length }]} />
      {list.length === 0 ? (
        <div className="bg-surface border border-line rounded-[var(--radius-card)]"><Empty icon={ScalesIcon} title="No open disputes">Buyers can open one from an order within 72 hours of delivery.</Empty></div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-[320px_minmax(0,1fr)] gap-5 items-start">
          <ul className="bg-surface border border-line rounded-[var(--radius-card)] overflow-hidden">
            {list.map((d) => {
              const o = db.orders.find((x) => x.id === d.orderId)!
              const l = db.listings.find((x) => x.id === o.listingId)!
              const on = sel?.id === d.id
              return (
                <li key={d.id} className="border-b border-line-2 last:border-b-0">
                  <button type="button" onClick={() => setParams({ id: d.id }, { replace: true })} className={cx('w-full flex gap-3 px-4 py-3.5 text-left transition-colors', on ? 'bg-brand-tint/70' : 'hover:bg-hover')}>
                    <Thumb src={l.image} size={44} />
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2"><span className="font-semibold text-[13.5px] truncate">{d.reason}</span><span className="num text-[13px] font-bold">{naira(o.amount + o.deliveryFee)}</span></span>
                      <span className="block text-[12px] text-muted truncate">{l.title}</span>
                      <span className="block mt-1.5">{tab === 'open' ? <Wait since={d.openedAt} sla={SLA.dispute} width={44} /> : <Status kind="dispute" value={d.status} />}</span>
                    </span>
                  </button>
                </li>
              )
            })}
          </ul>
          {sel && <Detail key={sel.id} d={sel} now={now} />}
        </div>
      )}
    </>
  )
}

function Detail({ d, now }: { d: Dispute; now: number }) {
  const db = useDb()
  const dispatch = useDispatch()
  const [note, setNote] = useState('')
  const [split, setSplit] = useState(false)
  const o = db.orders.find((x) => x.id === d.orderId)!
  const l = db.listings.find((x) => x.id === o.listingId)!
  const buyer = db.users.find((x) => x.id === o.buyerId)!
  const seller = db.users.find((x) => x.id === o.sellerId)!
  const total = o.amount + o.deliveryFee
  const fee = Math.round((o.amount * o.serviceFeePct) / 100)
  const open = d.status === 'open' || d.status === 'awaiting_seller'

  const decide = async (outcome: 'refunded' | 'released') => {
    const r = await confirm({
      title: outcome === 'refunded' ? `Refund ${naira(total)} to ${buyer.name}?` : `Release ${naira(total - fee)} to ${seller.name}?`,
      message: outcome === 'refunded' ? 'The full amount, including delivery, goes back to the buyer’s wallet now. The order is cancelled.' : `The seller receives the payment minus the ${o.serviceFeePct}% sale fee (${naira(fee)}). The order is completed.`,
      confirmLabel: outcome === 'refunded' ? 'Refund buyer' : 'Release to seller',
      tone: outcome === 'refunded' ? 'danger' : 'primary',
      reason: { label: 'Why? Both sides see this message.', placeholder: 'For example: the rider receipt shows delivery to the buyer’s address' },
    })
    if (!r) return
    dispatch({ t: 'dispute/resolve', id: d.id, outcome, refund: outcome === 'refunded' ? total : 0, note: r.reason })
    toast(outcome === 'refunded' ? 'Buyer refunded' : 'Payment released to seller')
  }
  const ask = async (who: 'seller' | 'buyer') => {
    const r = await confirm({ title: `Message the ${who}`, message: `${who === 'seller' ? seller.name : buyer.name} gets this as a notification and in their order chat.`, confirmLabel: 'Send message', reason: { label: 'Message', placeholder: who === 'seller' ? 'Please share the rider receipt and the rider’s phone number within 24 hours.' : 'Please share a short video of the item.' } })
    if (!r) return
    dispatch({ t: 'dispute/ask', id: d.id, who, text: r.reason })
    toast('Message sent')
  }

  return (
    <div className="space-y-4 min-w-0">
      <Card pad={false}>
        <div className="flex flex-wrap items-start gap-4 px-6 py-5 border-b border-line">
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2 mb-1"><Mono className="text-[12.5px] text-muted">{d.id}</Mono><Status kind="dispute" value={d.status} /></div>
            <h2 className="h-title text-[20px]">{d.reason}</h2>
            <p className="text-[12.5px] text-muted mt-1">Opened {fmtDateTime(d.openedAt)} by the buyer</p>
          </div>
          <div className="text-right">
            <div className="text-[12px] text-muted flex items-center gap-1 justify-end"><ShieldCheckIcon size={14} weight="fill" className="text-brand" /> Held in Crystal Protect</div>
            <div className="text-[24px] font-bold tracking-[-0.02em] num">{open ? naira(total) : naira(0)}</div>
            {open && <Wait since={d.openedAt} sla={SLA.dispute} showTarget />}
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-4 px-6 py-4">
          <Thumb src={l.image} size={56} />
          <div className="min-w-0 flex-1">
            <div className="font-semibold truncate">{l.title}</div>
            <div className="text-[12.5px] text-muted">
              <Link to={`/orders?id=${o.id}`} className="mono hover:text-brand">{o.id}</Link> · {naira(o.amount)} + {naira(o.deliveryFee)} delivery · paid {fmtDate(o.createdAt)}
            </div>
          </div>
          <div className="flex items-center gap-2 text-[13px]">
            <Party name={buyer.name} src={buyer.avatar} role="Buyer" id={buyer.id} />
            <ArrowRightIcon size={14} className="text-faint" />
            <Party name={seller.name} src={seller.avatar} role="Seller" id={seller.id} />
          </div>
        </div>
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <Card title="Buyer says" subtitle={buyer.name}>
          <p className="text-[13.5px] leading-relaxed">{d.statement}</p>
          {d.evidence.length > 0 && (
            <div className="flex gap-2 mt-3">
              {d.evidence.map((src) => <a key={src} href={src} target="_blank" rel="noreferrer"><Thumb src={src} size={72} className="hover:opacity-90" /></a>)}
            </div>
          )}
        </Card>
        <Card title="Seller says" subtitle={seller.name}>
          {d.sellerResponse ? <p className="text-[13.5px] leading-relaxed">{d.sellerResponse}</p> : <p className="text-[13.5px] text-muted">No reply yet. Sellers have 24 hours to respond once asked.</p>}
        </Card>
      </div>

      <Card title="What happened">
        <ol className="relative">
          {d.timeline.map((t, i) => (
            <li key={i} className="flex gap-3 pb-4 last:pb-0">
              <span className="relative flex flex-col items-center">
                <span className={cx('w-2.5 h-2.5 rounded-full mt-1.5', t.text.startsWith('Note:') ? 'bg-warn-mark' : t.text.startsWith('Resolved') ? 'bg-ok-mark' : 'bg-[#cfc9de]')} />
                {i < d.timeline.length - 1 && <span className="flex-1 w-px bg-line mt-1" />}
              </span>
              <div className="min-w-0 pb-0.5">
                <p className="text-[13.5px]">{t.text}</p>
                <p className="text-[12px] text-faint">{fmtDateTime(t.at)}{t.by ? ` · ${t.by}` : ''}{now - t.at < 7 * T.DAY ? ` · ${timeAgo(t.at, now)}` : ''}</p>
              </div>
            </li>
          ))}
        </ol>
        {open && (
          <div className="mt-4 pt-4 border-t border-line-2">
            <Textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Add a private note for the team" rows={2} />
            <div className="flex flex-wrap items-center gap-2 mt-2">
              <Button size="sm" icon={NoteIcon} disabled={note.trim().length < 3} onClick={() => { dispatch({ t: 'dispute/note', id: d.id, text: note.trim() }); setNote(''); toast('Note added') }}>Add note</Button>
              <span className="flex-1" />
              <Button size="sm" icon={ChatCircleTextIcon} onClick={() => ask('buyer')}>Message buyer</Button>
              <Button size="sm" icon={ChatCircleTextIcon} onClick={() => ask('seller')}>Message seller</Button>
            </div>
          </div>
        )}
      </Card>

      {open ? (
        <div className="flex flex-wrap items-center gap-2 bg-sunken border border-line rounded-[var(--radius-card)] px-5 py-4">
          <p className="text-[13px] text-ink-2 mr-auto">Your decision moves the money straight away and cannot be undone.</p>
          <Button onClick={() => setSplit(true)}>Split</Button>
          <Button variant="danger-soft" onClick={() => decide('refunded')}>Refund buyer</Button>
          <Button variant="primary" onClick={() => decide('released')}>Release to seller</Button>
        </div>
      ) : (
        <div className="flex gap-2.5 bg-ok-tint/60 border border-[#cde9d7] rounded-[var(--radius-card)] px-5 py-4 text-[13.5px]">
          <CheckCircleIcon size={18} weight="fill" className="text-ok-mark shrink-0 mt-0.5" />
          <div><span className="font-semibold">Resolved {d.resolvedAt ? fmtDate(d.resolvedAt) : ''}.</span> {d.resolution}</div>
        </div>
      )}
      {split && <SplitModal d={d} total={total} feePct={o.serviceFeePct} deliveryFee={o.deliveryFee} onClose={() => setSplit(false)} />}
    </div>
  )
}

function Party({ name, src, role, id }: { name: string; src?: string; role: string; id: string }) {
  return (
    <Link to={`/users/${id}`} className="flex items-center gap-2 rounded-lg px-2 py-1 hover:bg-hover">
      <Avatar name={name} src={src} size={26} />
      <span className="leading-tight"><span className="block text-[11.5px] text-muted">{role}</span><span className="block font-semibold">{name}</span></span>
    </Link>
  )
}

function SplitModal({ d, total, feePct, deliveryFee, onClose }: { d: Dispute; total: number; feePct: number; deliveryFee: number; onClose: () => void }) {
  const dispatch = useDispatch()
  const [amount, setAmount] = useState('')
  const [why, setWhy] = useState('')
  const refund = Math.min(total, Math.max(0, Number(amount.replace(/[^\d]/g, '')) || 0))
  const toSeller = total - refund
  const fee = toSeller > 0 ? Math.round((Math.max(0, toSeller - deliveryFee) * feePct) / 100) : 0
  const valid = refund > 0 && refund < total && why.trim().length >= 3
  return (
    <Modal
      open
      onClose={onClose}
      title="Split the payment"
      footer={<><Button onClick={onClose}>Cancel</Button><Button variant="primary" disabled={!valid} onClick={() => { dispatch({ t: 'dispute/resolve', id: d.id, outcome: 'split', refund, note: why.trim() }); toast('Payment split'); onClose() }}>Split payment</Button></>}
    >
      <p className="text-[13.5px] text-ink-2 mb-4">Refund part of the {naira(total)} to the buyer. The rest goes to the seller.</p>
      <div className="space-y-3">
        <Field label="Refund to the buyer"><Input prefix="₦" inputMode="numeric" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0" autoFocus /></Field>
        <div className="rounded-xl bg-sunken border border-line-2 px-4 py-3 text-[13px] space-y-1">
          <div className="flex justify-between"><span className="text-muted">Buyer gets back</span><span className="num font-semibold">{naira(refund)}</span></div>
          <div className="flex justify-between"><span className="text-muted">Seller gets ({feePct}% fee taken)</span><span className="num font-semibold">{naira(Math.max(0, toSeller - fee))}</span></div>
        </div>
        <Field label="Why? Both sides see this message."><Textarea rows={2} value={why} onChange={(e) => setWhy(e.target.value)} placeholder="For example: item works but has a scratch the listing did not mention" /></Field>
      </div>
    </Modal>
  )
}
