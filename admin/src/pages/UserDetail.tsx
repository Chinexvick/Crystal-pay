import { useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { CaretLeftIcon, ChatsCircleIcon, KeyIcon, LockIcon, LockOpenIcon, NoteIcon, PackageIcon, ReceiptIcon, StorefrontIcon, WarningIcon, XCircleIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { useNow } from '../lib/queues'
import { fmtDate, fmtDateTime, maskId, naira, num, timeAgo } from '../lib/format'
import { Avatar, Button, Card, Empty, KV, Mono, Pill, Tabs, Textarea, Thumb } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import { TxDrawer, useTxColumns } from '../components/tx'
import { confirm, toast } from '../components/overlays'
import { planName } from './Users'
import type { Listing, Order, Tx } from '../data/types'

export default function UserDetail() {
  const { id } = useParams()
  const db = useDb()
  const dispatch = useDispatch()
  const now = useNow()
  const nav = useNavigate()
  const [tab, setTab] = useState<'activity' | 'orders' | 'listings' | 'notes'>('activity')
  const [tx, setTx] = useState<Tx | null>(null)
  const [note, setNote] = useState('')
  const u = db.users.find((x) => x.id === id)
  const txColumns = useTxColumns({ showUser: false, showRef: false })

  const data = useMemo(() => {
    if (!u) return null
    const txs = db.txs.filter((t) => t.userId === u.id)
    const orders = db.orders.filter((o) => o.buyerId === u.id || o.sellerId === u.id).sort((a, b) => b.createdAt - a.createdAt)
    const listings = db.listings.filter((l) => l.sellerId === u.id)
    const verification = db.verifications.filter((v) => v.userId === u.id).sort((a, b) => b.submittedAt - a.submittedAt)[0]
    const sub = db.subscriptions.find((s) => s.userId === u.id && s.status !== 'cancelled')
    const moneyIn = txs.filter((t) => t.direction === 'in' && t.status === 'successful').reduce((a, t) => a + t.amount, 0)
    const moneyOut = txs.filter((t) => t.direction === 'out' && t.status === 'successful').reduce((a, t) => a + t.amount, 0)
    return { txs, orders, listings, verification, sub, moneyIn, moneyOut }
  }, [db, u])

  if (!u || !data) {
    return <Empty icon={WarningIcon} title="This user does not exist">They may have been removed. <Link className="text-brand font-semibold" to="/users">Back to users</Link></Empty>
  }
  const plan = db.plans.find((p) => p.key === u.plan)
  const limit = u.kyc === 'verified' ? db.settings.sendVerified : db.settings.sendUnverified

  const freeze = async () => {
    const r = await confirm({
      title: `Freeze ${u.name}’s account?`,
      message: 'They will not be able to sign in, pay or withdraw until you unfreeze it. Money in their wallet stays where it is.',
      confirmLabel: 'Freeze account',
      tone: 'danger',
      reason: { label: 'Reason', options: ['Suspected account takeover', 'Card chargeback', 'Suspected fraud', 'Requested by the user', 'Other'] },
    })
    if (!r) return
    dispatch({ t: 'user/freeze', id: u.id, reason: r.reason })
    toast('Account frozen')
  }
  const unfreeze = async () => {
    const r = await confirm({ title: `Unfreeze ${u.name}’s account?`, message: 'They can sign in and use their wallet again straight away.', confirmLabel: 'Unfreeze account', reason: { label: 'What changed?', placeholder: 'For example: confirmed identity on a call' } })
    if (!r) return
    dispatch({ t: 'user/unfreeze', id: u.id, reason: r.reason })
    toast('Account unfrozen')
  }

  const orderCols: Column<Order>[] = [
    {
      key: 'item', header: 'Order',
      cell: (o) => {
        const l = db.listings.find((x) => x.id === o.listingId)
        return (
          <span className="flex items-center gap-3 min-w-0">
            {l && <Thumb src={l.image} size={34} />}
            <span className="min-w-0"><span className="block font-semibold truncate max-w-[260px]">{l?.title}</span><Mono className="text-[12px] text-muted">{o.id}</Mono></span>
          </span>
        )
      },
    },
    { key: 'role', header: 'Role', cell: (o) => <span className="text-ink-2">{o.buyerId === u.id ? 'Buyer' : 'Seller'}</span> },
    { key: 'amount', header: 'Amount', align: 'right', cell: (o) => <span className="num font-semibold">{naira(o.amount + o.deliveryFee)}</span> },
    { key: 'stage', header: 'Status', cell: (o) => <Status kind="order" value={o.stage} /> },
    { key: 'date', header: 'Date', cell: (o) => <span className="text-ink-2">{fmtDate(o.createdAt)}</span> },
  ]
  const listingCols: Column<Listing>[] = [
    { key: 'l', header: 'Listing', cell: (l) => <span className="flex items-center gap-3 min-w-0"><Thumb src={l.image} size={34} /><span className="font-semibold truncate max-w-[300px]">{l.title}</span></span> },
    { key: 'price', header: 'Price', align: 'right', cell: (l) => <span className="num font-semibold">{naira(l.price)}{l.period ? <span className="text-muted font-medium">/{l.period === 'year' ? 'yr' : 'mo'}</span> : null}</span> },
    { key: 'views', header: 'Views', align: 'right', cell: (l) => <span className="num text-ink-2">{num(l.views)}</span> },
    { key: 's', header: 'Status', cell: (l) => <Status kind="listing" value={l.status} /> },
  ]

  return (
    <>
      <Link to="/users" className="inline-flex items-center gap-1 text-[13px] font-semibold text-muted hover:text-ink mb-4"><CaretLeftIcon size={14} weight="bold" /> Users</Link>
      <div className="flex flex-wrap items-start gap-5 mb-7">
        <Avatar name={u.name} src={u.avatar} size={64} verified={u.kyc === 'verified'} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2.5">
            <h1 className="h-title text-[26px] leading-tight">{u.name}</h1>
            <Status kind="user" value={u.status} />
            {u.risk !== 'low' && <Pill tone={u.risk === 'high' ? 'bad' : 'warn'} icon={WarningIcon}>{u.risk === 'high' ? 'High risk' : 'Watch'}</Pill>}
          </div>
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-[13px] text-muted mt-1.5">
            <span>@{u.username}</span><span>·</span><Mono copy>{u.id}</Mono><span>·</span><span>Joined {fmtDate(u.joinedAt)}</span><span>·</span><span>Last seen {timeAgo(u.lastActiveAt, now)}</span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button icon={ChatsCircleIcon} onClick={() => nav('/support')}>Message</Button>
          <Button
            icon={KeyIcon}
            onClick={async () => {
              const ok = await confirm({ title: 'Send a PIN reset link?', message: `We will email a link to ${u.email}. Their current PIN keeps working until they set a new one.`, confirmLabel: 'Send link' })
              if (ok) { dispatch({ t: 'user/resetPin', id: u.id }); toast('PIN reset link sent') }
            }}
          >
            Reset PIN
          </Button>
          {u.status === 'frozen' ? <Button icon={LockOpenIcon} variant="primary" onClick={unfreeze}>Unfreeze account</Button> : u.status === 'active' ? <Button icon={LockIcon} variant="danger-soft" onClick={freeze}>Freeze account</Button> : null}
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_340px] gap-6 items-start">
        <div className="min-w-0">
          <div className="grid grid-cols-3 gap-3 mb-6">
            <Fig label="Wallet balance" value={naira(u.balance)} />
            <Fig label="Money in, all time" value={naira(data.moneyIn)} />
            <Fig label="Money out, all time" value={naira(data.moneyOut)} />
          </div>
          <Tabs
            value={tab}
            onChange={setTab}
            items={[
              { value: 'activity', label: 'Transactions', count: data.txs.length },
              { value: 'orders', label: 'Orders', count: data.orders.length },
              { value: 'listings', label: 'Listings', count: data.listings.length },
              { value: 'notes', label: 'Notes', count: u.notes.length },
            ]}
          />
          {tab === 'activity' && <DataTable columns={txColumns} rows={data.txs} rowKey={(t) => t.id} onRowClick={setTx} pageSize={12} dense empty={<Empty icon={ReceiptIcon} title="No transactions yet" />} />}
          {tab === 'orders' && <DataTable columns={orderCols} rows={data.orders} rowKey={(o) => o.id} onRowClick={(o) => nav(`/orders?id=${o.id}`)} pageSize={12} dense empty={<Empty icon={PackageIcon} title="No orders yet" />} />}
          {tab === 'listings' && <DataTable columns={listingCols} rows={data.listings} rowKey={(l) => l.id} onRowClick={(l) => nav(`/listings?id=${l.id}`)} pageSize={12} dense empty={<Empty icon={StorefrontIcon} title="Not selling anything">This person has no listings.</Empty>} />}
          {tab === 'notes' && (
            <Card>
              <Textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Add a note for the team. The user never sees notes." rows={3} />
              <div className="flex justify-end mt-2">
                <Button variant="primary" size="sm" disabled={note.trim().length < 3} onClick={() => { dispatch({ t: 'user/note', id: u.id, text: note.trim() }); setNote(''); toast('Note added') }}>Add note</Button>
              </div>
              <ul className="mt-4 divide-y divide-line-2">
                {u.notes.length === 0 && <li className="py-6 text-center text-[13px] text-muted">No notes yet.</li>}
                {u.notes.map((n) => (
                  <li key={n.id} className="py-3 flex gap-3">
                    <NoteIcon size={18} className="text-muted mt-0.5 shrink-0" />
                    <div className="min-w-0">
                      <p className="text-[13.5px] leading-relaxed">{n.text}</p>
                      <p className="text-[12px] text-faint mt-1">{n.by} · {fmtDateTime(n.at)}</p>
                    </div>
                  </li>
                ))}
              </ul>
            </Card>
          )}
        </div>

        <div className="space-y-4">
          <Card title="Wallet">
            <KV rows={[
              ['Balance', naira(u.balance)],
              ['Held for open orders', naira(u.held)],
              ['CCT not yet converted', `${num(u.cct)} CCT`],
              ['Send limit', `${naira(limit)} per transfer`],
            ]} />
          </Card>
          <Card title="Identity">
            <KV rows={[
              ['ID check', <Status kind="kyc" value={u.kyc} />],
              ['Document', data.verification ? `${data.verification.idType} ${maskId(data.verification.idType, data.verification.idNumber)}` : '—'],
              ['Checked by', data.verification?.reviewedBy ?? '—'],
              ['Date of birth', u.dob],
            ]} />
            {data.verification?.status === 'pending' && <Link to={`/verifications?id=${data.verification.id}`} className="inline-block mt-3 text-[13px] font-semibold text-brand hover:underline">Review this ID now</Link>}
            {data.verification?.status === 'rejected' && <p className="mt-3 text-[12.5px] text-bad flex gap-1.5"><XCircleIcon size={15} className="mt-0.5 shrink-0" />{data.verification.rejectReason}</p>}
          </Card>
          <Card title="Contact">
            <KV rows={[['Email', u.email], ['Phone', u.phone], ['Location', `${u.city}, ${u.state}`]]} />
          </Card>
          <Card title="Security">
            <KV rows={[
              ['Two-step sign-in', u.twoStep ? 'On' : 'Off'],
              ['Fingerprint unlock', u.biometric ? 'On' : 'Off'],
              ['Last device', u.device],
            ]} />
          </Card>
          <Card title="Selling">
            <KV rows={[
              ['Seller plan', planName[u.plan]],
              ['Live listings', plan ? `${data.listings.filter((l) => l.status === 'live').length} of ${plan.listings}` : String(data.listings.length)],
              ['Plan renews', data.sub ? fmtDate(data.sub.renewsAt) : '—'],
            ]} />
          </Card>
          {u.status === 'active' && (
            <button
              type="button"
              className="w-full text-[13px] font-semibold text-bad hover:underline text-left px-1"
              onClick={async () => {
                const r = await confirm({ title: `Close ${u.name}’s account?`, message: u.balance > 0 ? `Their wallet still holds ${naira(u.balance)}. Close it only after they withdraw, or after finance agrees how to return it.` : 'They will be signed out and cannot sign in again. Their records are kept for as long as the law requires.', confirmLabel: 'Close account', tone: 'danger', reason: { label: 'Reason', options: ['Requested by the user', 'Fraud confirmed', 'Duplicate account', 'Other'] } })
                if (r) { dispatch({ t: 'user/close', id: u.id, reason: r.reason }); toast('Account closed') }
              }}
            >
              Close this account
            </button>
          )}
        </div>
      </div>
      <TxDrawer tx={tx} onClose={() => setTx(null)} />
    </>
  )
}

function Fig({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-line px-4 py-3">
      <div className="text-[12px] text-muted">{label}</div>
      <div className="text-[18px] font-bold tracking-[-0.02em] mt-0.5">{value}</div>
    </div>
  )
}
