import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { ArrowCounterClockwiseIcon, CheckCircleIcon, FlagIcon, ProhibitIcon, StarIcon, StorefrontIcon, WarningIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { useNow } from '../lib/queues'
import { fmtDate, naira, num, timeAgo } from '../lib/format'
import { listingReviewReason } from '../data/seed'
import { Avatar, Button, Empty, KV, Mono, PageHeader, Pill, SearchInput, Select, Tabs, Thumb, Toggle } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import { Drawer, confirm, toast } from '../components/overlays'
import { planName } from './Users'
import type { Listing, ListingStatus } from '../data/types'

export const categoryName: Record<string, string> = {
  houses: 'Houses', lands: 'Land', phones: 'Phones', cameras: 'Cameras', electronics: 'Electronics', furniture: 'Furniture', fashion: 'Fashion',
  appliances: 'Appliances', kitchen: 'Kitchen', events: 'Events', kids: 'Kids',
}
export const removeReasons = ['Scam or suspicious price', 'Counterfeit or fake', 'Prohibited item', 'Misleading photos', 'Duplicate listing', 'Wrong category', 'Other']

export const priceLabel = (l: Listing) => `${naira(l.price)}${l.period ? (l.period === 'year' ? ' a year' : ' a month') : ''}`

export default function Listings() {
  const db = useDb()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const [tab, setTab] = useState<'all' | ListingStatus>((params.get('tab') as ListingStatus) ?? 'all')
  const [q, setQ] = useState('')
  const [cat, setCat] = useState('all')

  const reportCount = useMemo(() => {
    const m = new Map<string, number>()
    db.reports.filter((r) => r.status === 'open').forEach((r) => m.set(r.listingId, (m.get(r.listingId) ?? 0) + 1))
    return m
  }, [db.reports])
  const counts = useMemo(() => {
    const c: Record<string, number> = {}
    db.listings.forEach((l) => (c[l.status] = (c[l.status] ?? 0) + 1))
    return c
  }, [db.listings])
  const rows = useMemo(() => {
    const s = q.trim().toLowerCase()
    return db.listings
      .filter((l) => (tab === 'all' || l.status === tab) && (cat === 'all' || (cat === 'property' ? l.property : l.category === cat)) && (!s || l.title.toLowerCase().includes(s) || l.id.toLowerCase().includes(s)))
      .sort((a, b) => (a.status === 'review' ? -1 : 0) - (b.status === 'review' ? -1 : 0) || b.createdAt - a.createdAt)
  }, [db.listings, tab, cat, q])
  const open = db.listings.find((l) => l.id === params.get('id')) ?? null

  const columns: Column<Listing>[] = [
    { key: 'l', header: 'Listing', cell: (l) => <span className="flex items-center gap-3 min-w-0"><Thumb src={l.image} size={40} /><span className="min-w-0"><span className="flex items-center gap-1.5"><span className="font-semibold truncate max-w-[300px]">{l.title}</span>{l.featured && <StarIcon size={13} weight="fill" className="text-warn-mark shrink-0" aria-label="Featured" />}</span><Mono className="text-[12px] text-muted">{l.id}</Mono></span></span> },
    { key: 'seller', header: 'Seller', cell: (l) => { const u = db.users.find((x) => x.id === l.sellerId)!; return <span className="flex items-center gap-2 min-w-0"><Avatar name={u.name} src={u.avatar} size={24} /><span className="truncate">{u.name}</span></span> } },
    { key: 'cat', header: 'Category', cell: (l) => <span className="text-ink-2 whitespace-nowrap"><span className="block">{categoryName[l.category] ?? l.category}</span>{l.property && <span className="block text-[12px] text-faint">Contact only</span>}</span> },
    { key: 'price', header: 'Price', align: 'right', cell: (l) => <span className="num font-semibold whitespace-nowrap">{priceLabel(l)}</span> },
    { key: 'rep', header: 'Reports', align: 'center', cell: (l) => (reportCount.get(l.id) ? <Pill tone="bad" icon={FlagIcon}>{reportCount.get(l.id)}</Pill> : <span className="text-faint">—</span>) },
    { key: 'status', header: 'Status', cell: (l) => <Status kind="listing" value={l.status} /> },
    { key: 'when', header: 'Listed', cell: (l) => <span className="text-ink-2 whitespace-nowrap">{timeAgo(l.createdAt, now)}</span> },
  ]

  return (
    <>
      <PageHeader title="Listings" description="Everything for sale or rent. Houses and land are contact-only: buyers talk to the seller and pay outside the app." />
      <Tabs value={tab} onChange={(t) => { setTab(t); setParams(t === 'all' ? {} : { tab: t }, { replace: true }) }} items={[{ value: 'all', label: 'All', count: db.listings.length }, { value: 'review', label: 'Needs check', count: counts.review ?? 0, alert: true }, { value: 'live', label: 'Live', count: counts.live ?? 0 }, { value: 'sold', label: 'Sold', count: counts.sold ?? 0 }, { value: 'removed', label: 'Removed', count: counts.removed ?? 0 }]} />
      <div className="flex flex-wrap items-center gap-2.5 mb-4">
        <SearchInput value={q} onChange={setQ} placeholder="Title or listing ID" className="w-full sm:w-[300px]" />
        <Select value={cat} onChange={(e) => setCat(e.target.value)} aria-label="Category" className="w-auto">
          <option value="all">All categories</option>
          <option value="property">Houses and land</option>
          {Object.entries(categoryName).filter(([k]) => k !== 'houses' && k !== 'lands').map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </Select>
      </div>
      <DataTable columns={columns} rows={rows} rowKey={(l) => l.id} activeKey={open?.id} onRowClick={(l) => setParams({ ...(tab !== 'all' ? { tab } : {}), id: l.id }, { replace: true })} empty={<Empty icon={StorefrontIcon} title="No listings here" />} />
      <ListingDrawer l={open} onClose={() => setParams(tab !== 'all' ? { tab } : {}, { replace: true })} />
    </>
  )
}

export function ListingDrawer({ l, onClose }: { l: Listing | null; onClose: () => void }) {
  const db = useDb()
  const dispatch = useDispatch()
  if (!l) return null
  const u = db.users.find((x) => x.id === l.sellerId)!
  const reports = db.reports.filter((r) => r.listingId === l.id && r.status === 'open')
  const sold = db.orders.filter((o) => o.listingId === l.id && o.stage === 'completed').length
  const remove = async () => {
    const r = await confirm({ title: 'Remove this listing?', message: `It disappears from the app and ${u.name} is told why. Open reports on it are closed.`, confirmLabel: 'Remove listing', tone: 'danger', reason: { label: 'Reason the seller will see', options: removeReasons } })
    if (r) { dispatch({ t: 'listing/remove', id: l.id, reason: r.reason }); toast('Listing removed') }
  }
  return (
    <Drawer
      open
      onClose={onClose}
      title={l.title}
      subtitle={<Mono copy>{l.id}</Mono>}
      footer={
        <>
          {l.status !== 'removed' ? <Button variant="danger-soft" icon={ProhibitIcon} onClick={remove}>Remove listing</Button> : <Button icon={ArrowCounterClockwiseIcon} onClick={() => { dispatch({ t: 'listing/restore', id: l.id }); toast('Listing restored') }}>Restore listing</Button>}
          <span className="flex-1" />
          {l.status === 'review' && <Button variant="primary" icon={CheckCircleIcon} onClick={() => { dispatch({ t: 'listing/approve', id: l.id }); toast('Listing is live') }}>Approve and publish</Button>}
        </>
      }
    >
      <img src={l.image} alt="" className="w-full aspect-[16/10] object-cover rounded-xl border border-line-2 mb-4" />
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="text-[24px] font-bold tracking-[-0.02em] num">{priceLabel(l)}</div>
        <Status kind="listing" value={l.status} />
      </div>
      {l.status === 'review' && listingReviewReason[l.id] && <div className="flex gap-2 rounded-xl bg-warn-tint/70 border border-[#f6dcb0] px-4 py-3 mb-4 text-[13px] text-ink-2"><WarningIcon size={16} weight="fill" className="text-warn-mark shrink-0 mt-px" /><span><span className="font-semibold">Why it needs a check:</span> {listingReviewReason[l.id]}</span></div>}
      {l.removedReason && <div className="rounded-xl bg-bad-tint/60 px-4 py-3 mb-4 text-[13px] text-bad"><span className="font-semibold">Removed:</span> {l.removedReason}</div>}
      {reports.length > 0 && (
        <div className="rounded-xl border border-line mb-4">
          <div className="px-4 py-2.5 border-b border-line-2 text-[13px] font-bold flex items-center gap-1.5"><FlagIcon size={15} weight="fill" className="text-bad-mark" /> {reports.length} open {reports.length === 1 ? 'report' : 'reports'}</div>
          <ul className="divide-y divide-line-2">{reports.map((r) => <li key={r.id} className="px-4 py-2.5 text-[13px]"><span className="font-semibold">{r.reason}.</span> <span className="text-ink-2">{r.note}</span></li>)}</ul>
        </div>
      )}
      <KV rows={[
        ['Seller', <Link to={`/users/${u.id}`} className="text-brand hover:underline">{u.name}</Link>],
        ['Seller plan', planName[u.plan]],
        ['Category', `${categoryName[l.category] ?? l.category}${l.property ? ' · contact only' : ''}`],
        ['Condition', l.condition],
        ['Location', l.location],
        ['Listed', fmtDate(l.createdAt)],
        ['Views and saves', `${num(l.views)} views · ${num(l.saves)} saves`],
        ...(l.property ? [] : [['Sold through the app', String(sold)] as [string, string]]),
      ]} />
      {l.status === 'live' && (
        <div className="flex items-center justify-between gap-4 mt-5 rounded-xl border border-line px-4 py-3">
          <div><div className="text-[13.5px] font-semibold">Feature on the home screen</div><div className="text-[12.5px] text-muted">Shows in Popular Listings for everyone.</div></div>
          <Toggle label="Feature on the home screen" on={l.featured} onChange={(v) => { dispatch({ t: 'listing/feature', id: l.id, on: v }); toast(v ? 'Listing featured' : 'No longer featured') }} />
        </div>
      )}
    </Drawer>
  )
}
