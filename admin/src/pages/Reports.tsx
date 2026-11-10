import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { CheckIcon, FlagIcon, ProhibitIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { SLA, useNow } from '../lib/queues'
import { fmtDateTime, timeAgo } from '../lib/format'
import { Avatar, Button, Empty, PageHeader, Pill, Tabs, Thumb } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import { Wait } from '../components/Wait'
import { Drawer, confirm, toast } from '../components/overlays'
import { priceLabel, removeReasons } from './Listings'
import type { Listing, Report } from '../data/types'

interface Group {
  listing: Listing
  reports: Report[]
  oldest: number
  reason: string
}

export default function Reports() {
  const db = useDb()
  const now = useNow()
  const [tab, setTab] = useState<'open' | 'closed'>('open')
  const [openId, setOpenId] = useState<string | null>(null)

  const groups = useMemo(() => {
    const m = new Map<string, Report[]>()
    db.reports.filter((r) => r.status === 'open').forEach((r) => m.set(r.listingId, [...(m.get(r.listingId) ?? []), r]))
    return [...m.entries()].map(([id, reports]): Group => {
      const freq = new Map<string, number>()
      reports.forEach((r) => freq.set(r.reason, (freq.get(r.reason) ?? 0) + 1))
      return { listing: db.listings.find((l) => l.id === id)!, reports, oldest: Math.min(...reports.map((r) => r.createdAt)), reason: [...freq.entries()].sort((a, b) => b[1] - a[1])[0][0] }
    }).sort((a, b) => b.reports.length - a.reports.length || a.oldest - b.oldest)
  }, [db.reports, db.listings])
  const closed = db.reports.filter((r) => r.status !== 'open').sort((a, b) => b.createdAt - a.createdAt)
  const group = groups.find((g) => g.listing.id === openId) ?? null

  const columns: Column<Group>[] = [
    { key: 'l', header: 'Listing', cell: (g) => <span className="flex items-center gap-3 min-w-0"><Thumb src={g.listing.image} size={40} /><span className="min-w-0"><span className="block font-semibold truncate max-w-[300px]">{g.listing.title}</span><span className="block text-[12px] text-muted num">{priceLabel(g.listing)}</span></span></span> },
    { key: 'seller', header: 'Seller', cell: (g) => <span className="truncate">{db.users.find((u) => u.id === g.listing.sellerId)?.name}</span> },
    { key: 'n', header: 'Reports', align: 'center', cell: (g) => <Pill tone={g.reports.length > 1 ? 'bad' : 'warn'} icon={FlagIcon}>{g.reports.length}</Pill> },
    { key: 'why', header: 'Main reason', cell: (g) => <span className="text-ink-2">{g.reason}</span> },
    { key: 'wait', header: 'Waiting', cell: (g) => <Wait since={g.oldest} sla={SLA.report} width={44} /> },
  ]
  const closedCols: Column<Report>[] = [
    { key: 'l', header: 'Listing', cell: (r) => { const l = db.listings.find((x) => x.id === r.listingId)!; return <span className="flex items-center gap-3 min-w-0"><Thumb src={l.image} size={34} /><span className="font-semibold truncate max-w-[300px]">{l.title}</span></span> } },
    { key: 'why', header: 'Reason', cell: (r) => <span className="text-ink-2">{r.reason}</span> },
    { key: 'by', header: 'Reported by', cell: (r) => <span className="truncate">{db.users.find((u) => u.id === r.reporterId)?.name}</span> },
    { key: 's', header: 'Outcome', cell: (r) => <Status kind="report" value={r.status} /> },
    { key: 'closed', header: 'Handled by', cell: (r) => <span className="text-ink-2">{r.closedBy ?? '—'}</span> },
  ]

  return (
    <>
      <PageHeader title="Reports" description="Listings people flagged from the app. Several reports on one listing usually means a scam; act on those first." />
      <Tabs value={tab} onChange={setTab} items={[{ value: 'open', label: 'Open', count: groups.length, alert: true }, { value: 'closed', label: 'Closed', count: closed.length }]} />
      {tab === 'open' ? (
        <DataTable columns={columns} rows={groups} rowKey={(g) => g.listing.id} activeKey={openId} onRowClick={(g) => setOpenId(g.listing.id)} empty={<Empty icon={FlagIcon} title="No open reports">Reports appear here when someone taps “Report this listing”.</Empty>} />
      ) : (
        <DataTable columns={closedCols} rows={closed} rowKey={(r) => r.id} empty={<Empty icon={FlagIcon} title="Nothing closed yet" />} />
      )}
      {group && <GroupDrawer g={group} now={now} onClose={() => setOpenId(null)} />}
    </>
  )
}

function GroupDrawer({ g, now, onClose }: { g: Group; now: number; onClose: () => void }) {
  const db = useDb()
  const dispatch = useDispatch()
  const seller = db.users.find((u) => u.id === g.listing.sellerId)!
  const priorRemovals = db.listings.filter((l) => l.sellerId === seller.id && l.status === 'removed').length
  return (
    <Drawer
      open
      onClose={onClose}
      title={g.listing.title}
      subtitle={`${g.reports.length} open ${g.reports.length === 1 ? 'report' : 'reports'} · oldest ${timeAgo(g.oldest, now)}`}
      footer={
        <>
          <Button icon={CheckIcon} onClick={async () => {
            const ok = await confirm({ title: 'Dismiss these reports?', message: 'The listing stays live. The people who reported it are told it was checked.', confirmLabel: 'Dismiss reports' })
            if (!ok) return
            g.reports.forEach((r) => dispatch({ t: 'report/dismiss', id: r.id }))
            toast('Reports dismissed')
            onClose()
          }}>Keep listing, dismiss</Button>
          <span className="flex-1" />
          <Button variant="danger" icon={ProhibitIcon} onClick={async () => {
            const options = [g.reason, ...removeReasons.filter((x) => x !== g.reason)]
            const r = await confirm({ title: 'Remove this listing?', message: `${seller.name} is told why. All reports on it are closed.`, confirmLabel: 'Remove listing', tone: 'danger', reason: { label: 'Reason the seller will see', options } })
            if (!r) return
            dispatch({ t: 'listing/remove', id: g.listing.id, reason: r.reason })
            toast('Listing removed')
            onClose()
          }}>Remove listing</Button>
        </>
      }
    >
      <div className="flex gap-4 mb-5">
        <Thumb src={g.listing.image} size={96} />
        <div className="min-w-0">
          <div className="text-[20px] font-bold num tracking-[-0.02em]">{priceLabel(g.listing)}</div>
          <div className="text-[13px] text-muted mt-0.5">{g.listing.location}</div>
          <div className="mt-2 flex items-center gap-2 text-[13px]"><Avatar name={seller.name} src={seller.avatar} size={22} /><Link to={`/users/${seller.id}`} className="font-semibold hover:text-brand">{seller.name}</Link></div>
          <div className="text-[12.5px] text-muted mt-1">Joined {timeAgo(seller.joinedAt, now)} · {priorRemovals} removed listings before</div>
        </div>
      </div>
      <h3 className="text-[13px] font-bold mb-2">What people said</h3>
      <ul className="space-y-3">
        {g.reports.map((r) => {
          const u = db.users.find((x) => x.id === r.reporterId)!
          return (
            <li key={r.id} className="rounded-xl border border-line px-4 py-3">
              <div className="flex items-center gap-2 mb-1"><Avatar name={u.name} src={u.avatar} size={22} /><span className="text-[13px] font-semibold">{u.name}</span><span className="text-[12px] text-faint ml-auto">{fmtDateTime(r.createdAt)}</span></div>
              <div className="text-[13px] font-semibold">{r.reason}</div>
              <p className="text-[13px] text-ink-2 mt-0.5 leading-relaxed">{r.note}</p>
            </li>
          )
        })}
      </ul>
    </Drawer>
  )
}
