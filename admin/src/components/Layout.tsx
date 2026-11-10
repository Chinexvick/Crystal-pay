import { useEffect, useMemo, useRef, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { createPortal } from 'react-dom'
import {
  ArrowsLeftRightIcon, BankIcon, BellIcon, ChatsCircleIcon, ClockCounterClockwiseIcon, CoinsIcon, CrownIcon, FlagIcon, IdentificationCardIcon,
  ImageIcon, InfoIcon, ListIcon, MagnifyingGlassIcon, MegaphoneIcon, PackageIcon, ReceiptIcon, ScalesIcon, SignOutIcon, SlidersIcon,
  SquaresFourIcon, StorefrontIcon, UserGearIcon, UsersIcon, WarningCircleIcon, WarningIcon, ArrowCounterClockwiseIcon, XIcon, type Icon,
} from '@phosphor-icons/react'
import { useDb, useDispatch, useMe, useStore, roleNames } from '../lib/store'
import { useBadges, type Queue } from '../lib/queues'
import { naira, timeAgo } from '../lib/format'
import { Avatar, Kbd, cx } from './ui'
import { confirm, toast } from './overlays'

interface NavItem {
  to: string
  label: string
  icon: Icon
  badge?: keyof ReturnType<typeof useBadges>
}

const nav: { section?: string; items: NavItem[] }[] = [
  { items: [{ to: '/', label: 'Overview', icon: SquaresFourIcon }] },
  {
    section: 'Operations',
    items: [
      { to: '/users', label: 'Users', icon: UsersIcon },
      { to: '/verifications', label: 'Verifications', icon: IdentificationCardIcon, badge: 'kyc' },
      { to: '/disputes', label: 'Disputes', icon: ScalesIcon, badge: 'dispute' },
      { to: '/support', label: 'Support', icon: ChatsCircleIcon, badge: 'support' },
    ],
  },
  {
    section: 'Money',
    items: [
      { to: '/transactions', label: 'Transactions', icon: ArrowsLeftRightIcon },
      { to: '/bills', label: 'Bill payments', icon: ReceiptIcon, badge: 'bill' },
      { to: '/withdrawals', label: 'Withdrawals', icon: BankIcon, badge: 'withdrawal' },
      { to: '/cct', label: 'CCT deposits', icon: CoinsIcon, badge: 'cct' },
    ],
  },
  {
    section: 'Marketplace',
    items: [
      { to: '/listings', label: 'Listings', icon: StorefrontIcon, badge: 'listing' },
      { to: '/reports', label: 'Reports', icon: FlagIcon, badge: 'report' },
      { to: '/orders', label: 'Orders', icon: PackageIcon },
      { to: '/plans', label: 'Seller plans', icon: CrownIcon },
    ],
  },
  {
    section: 'App content',
    items: [
      { to: '/banners', label: 'Home banners', icon: ImageIcon },
      { to: '/announcements', label: 'Announcements', icon: MegaphoneIcon },
    ],
  },
  {
    section: 'Settings',
    items: [
      { to: '/settings', label: 'Rates and fees', icon: SlidersIcon },
      { to: '/staff', label: 'Staff and roles', icon: UserGearIcon },
      { to: '/audit', label: 'Audit log', icon: ClockCounterClockwiseIcon },
    ],
  },
]

export const allPages = nav.flatMap((g) => g.items)

function Badge({ q }: { q?: Queue }) {
  if (!q || q.count === 0) return null
  return (
    <span title={`${q.count} waiting${q.late ? `, ${q.late} late` : ''}`} className={cx('ml-auto num text-[11.5px] font-semibold min-w-5 h-5 px-1.5 rounded-full inline-flex items-center justify-center', q.late ? 'bg-bad-tint text-bad' : 'bg-[#e9e6f1] text-ink-2')}>
      {q.count}
    </span>
  )
}

function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  const badges = useBadges()
  return (
    <nav className="flex-1 overflow-y-auto px-3 pb-4" aria-label="Main">
      {nav.map((g, gi) => (
        <div key={gi} className={cx(gi > 0 && 'mt-3.5')}>
          {g.section && <div className="px-3 mb-1 text-[11.5px] font-semibold text-faint">{g.section}</div>}
          <ul className="space-y-px">
            {g.items.map((it) => (
              <li key={it.to}>
                <NavLink
                  to={it.to}
                  end={it.to === '/'}
                  onClick={onNavigate}
                  className={({ isActive }) =>
                    cx('flex items-center gap-2.5 h-8 px-3 rounded-lg text-[13.5px] font-semibold transition-colors', isActive ? 'bg-surface text-ink shadow-[0_1px_2px_rgb(21_16_46/0.08),0_0_0_1px_rgb(21_16_46/0.04)]' : 'text-ink-2 hover:bg-[#e9e6f1]/70 hover:text-ink')
                  }
                >
                  {({ isActive }) => (
                    <>
                      <it.icon size={18} weight={isActive ? 'fill' : 'regular'} className={isActive ? 'text-brand' : 'text-muted'} />
                      {it.label}
                      {it.badge && <Badge q={badges[it.badge]} />}
                    </>
                  )}
                </NavLink>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </nav>
  )
}

function Brand() {
  return (
    <div className="flex items-center gap-2.5 px-6 h-14 shrink-0">
      <img src="/img/brand/logo_mark.webp" alt="" className="h-[22px] w-auto" />
      <div className="leading-none">
        <span className="font-extrabold text-[15px] tracking-[-0.02em]">Crystal Pay</span>
        <span className="ml-1.5 text-[12px] font-semibold text-muted">Admin</span>
      </div>
    </div>
  )
}

function Me() {
  const me = useMe()
  const logout = useStore((s) => s.logout)
  const reset = useStore((s) => s.reset)
  const ops = useStore((s) => s.ops.length)
  const [open, setOpen] = useState(false)
  const nav = useNavigate()
  return (
    <div className="relative px-3 pb-3 pt-2 border-t border-[#e6e3ee]">
      <button type="button" onClick={() => setOpen((v) => !v)} className="w-full flex items-center gap-2.5 p-2 rounded-lg hover:bg-[#e9e6f1]/70 text-left" aria-expanded={open}>
        <Avatar name={me.name} src={me.avatar} size={30} />
        <span className="min-w-0 flex-1">
          <span className="block text-[13px] font-bold truncate">{me.name}</span>
          <span className="block text-[12px] text-muted truncate">{roleNames[me.role]}</span>
        </span>
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-20" onClick={() => setOpen(false)} />
          <div className="absolute bottom-full left-3 right-3 mb-1 z-30 bg-surface border border-line rounded-xl shadow-[var(--shadow-pop)] p-1.5 animate-pop">
            <div className="px-2.5 py-2 text-[12px] text-muted border-b border-line-2 mb-1 truncate">{me.email}</div>
            <button
              type="button"
              className="w-full flex items-center gap-2 px-2.5 h-9 rounded-lg text-[13px] font-semibold hover:bg-hover"
              onClick={async () => {
                setOpen(false)
                const ok = await confirm({ title: 'Reset demo data?', message: `This undoes the ${ops} ${ops === 1 ? 'change' : 'changes'} made in this browser and puts every queue back the way it started.`, confirmLabel: 'Reset demo data', tone: 'danger' })
                if (ok) {
                  reset()
                  toast('Demo data reset')
                }
              }}
            >
              <ArrowCounterClockwiseIcon size={16} /> Reset demo data
            </button>
            <button type="button" className="w-full flex items-center gap-2 px-2.5 h-9 rounded-lg text-[13px] font-semibold hover:bg-hover" onClick={() => { logout(); nav('/login') }}>
              <SignOutIcon size={16} /> Sign out
            </button>
          </div>
        </>
      )}
    </div>
  )
}

function Alerts() {
  const db = useDb()
  const dispatch = useDispatch()
  const [open, setOpen] = useState(false)
  const nav = useNavigate()
  const unread = db.alerts.filter((a) => !a.read).length
  return (
    <div className="relative">
      <button type="button" onClick={() => setOpen((v) => !v)} aria-label={`Alerts${unread ? `, ${unread} unread` : ''}`} className="relative w-9 h-9 rounded-lg inline-flex items-center justify-center text-ink-2 hover:bg-hover">
        <BellIcon size={19} />
        {unread > 0 && <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-bad-mark ring-2 ring-surface" />}
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-20" onClick={() => setOpen(false)} />
          <div className="absolute right-0 top-11 z-30 w-[380px] bg-surface border border-line rounded-xl shadow-[var(--shadow-pop)] animate-pop overflow-hidden">
            <div className="flex items-center justify-between px-4 h-11 border-b border-line">
              <span className="font-bold text-[13.5px]">Alerts</span>
              {unread > 0 && (
                <button type="button" className="text-[12.5px] font-semibold text-brand hover:underline" onClick={() => dispatch({ t: 'alerts/read' })}>
                  Mark all as read
                </button>
              )}
            </div>
            <ul className="max-h-[420px] overflow-y-auto">
              {db.alerts.map((a) => (
                <li key={a.id}>
                  <button type="button" onClick={() => { setOpen(false); nav(a.link) }} className="w-full text-left flex gap-3 px-4 py-3 hover:bg-hover border-b border-line-2 last:border-b-0">
                    <span className={cx('mt-0.5 shrink-0', a.level === 'critical' ? 'text-bad-mark' : a.level === 'warning' ? 'text-warn-mark' : 'text-info')}>
                      {a.level === 'critical' ? <WarningCircleIcon size={18} weight="fill" /> : a.level === 'warning' ? <WarningIcon size={18} weight="fill" /> : <InfoIcon size={18} weight="fill" />}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className={cx('block text-[13px] leading-snug', !a.read ? 'font-semibold text-ink' : 'text-ink-2')}>{a.text}</span>
                      <span className="block text-[12px] text-faint mt-0.5">{timeAgo(a.at)}</span>
                    </span>
                    {!a.read && <span className="mt-1.5 w-2 h-2 rounded-full bg-brand shrink-0" />}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </>
      )}
    </div>
  )
}

/* ───────────── command palette ───────────── */

interface Hit {
  group: string
  label: string
  sub?: string
  to: string
}

function Palette({ onClose }: { onClose: () => void }) {
  const db = useDb()
  const nav = useNavigate()
  const [q, setQ] = useState('')
  const [sel, setSel] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  useEffect(() => inputRef.current?.focus(), [])
  const hits = useMemo<Hit[]>(() => {
    const s = q.trim().toLowerCase()
    const pages: Hit[] = allPages.filter((p) => !s || p.label.toLowerCase().includes(s)).map((p) => ({ group: 'Pages', label: p.label, to: p.to }))
    if (!s) return pages.slice(0, 8)
    const digits = s.replace(/\D/g, '')
    const users = db.users
      .filter((u) => u.name.toLowerCase().includes(s) || u.username.includes(s.replace('@', '')) || u.email.includes(s) || (digits.length >= 4 && u.phone.replace(/\D/g, '').includes(digits)))
      .slice(0, 6)
      .map((u) => ({ group: 'Users', label: u.name, sub: `@${u.username} · ${u.phone}`, to: `/users/${u.id}` }))
    const up = s.toUpperCase()
    const orders = db.orders.filter((o) => o.id.includes(up)).slice(0, 4).map((o) => ({ group: 'Orders', label: o.id, sub: db.listings.find((l) => l.id === o.listingId)?.title, to: `/orders?id=${o.id}` }))
    const txs = s.length >= 4 ? db.txs.filter((t) => t.id.includes(up)).slice(0, 4).map((t) => ({ group: 'Transactions', label: t.id, sub: `${t.title} · ${naira(t.amount)}`, to: `/transactions?id=${t.id}` })) : []
    const wds = db.withdrawals.filter((w) => w.id.includes(up)).slice(0, 3).map((w) => ({ group: 'Withdrawals', label: w.id, sub: `${naira(w.amount)} · ${w.bankName}`, to: `/withdrawals?id=${w.id}` }))
    const listings = db.listings.filter((l) => l.title.toLowerCase().includes(s)).slice(0, 4).map((l) => ({ group: 'Listings', label: l.title, sub: naira(l.price), to: `/listings?id=${l.id}` }))
    return [...pages.slice(0, 4), ...users, ...orders, ...txs, ...wds, ...listings]
  }, [q, db])
  useEffect(() => setSel(0), [q])
  const go = (h?: Hit) => {
    if (!h) return
    onClose()
    nav(h.to)
  }
  let lastGroup = ''
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-[14vh] px-4">
      <div className="absolute inset-0 bg-[rgb(21_16_46/0.36)] animate-fade" onClick={onClose} />
      <div className="relative w-full max-w-[600px] bg-surface rounded-2xl shadow-[var(--shadow-pop)] overflow-hidden animate-pop" role="dialog" aria-label="Search">
        <div className="flex items-center gap-3 px-4 h-14 border-b border-line">
          <MagnifyingGlassIcon size={19} className="text-muted" />
          <input
            ref={inputRef}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'ArrowDown') { e.preventDefault(); setSel((v) => Math.min(hits.length - 1, v + 1)) }
              if (e.key === 'ArrowUp') { e.preventDefault(); setSel((v) => Math.max(0, v - 1)) }
              if (e.key === 'Enter') go(hits[sel])
              if (e.key === 'Escape') onClose()
            }}
            placeholder="Search people, phone numbers, orders, references…"
            className="flex-1 h-full bg-transparent outline-none text-[15px] placeholder:text-faint"
            aria-label="Search"
          />
          <Kbd>Esc</Kbd>
        </div>
        <ul className="max-h-[52vh] overflow-y-auto py-2">
          {hits.length === 0 && <li className="px-4 py-8 text-center text-[13px] text-muted">Nothing matches “{q}”.</li>}
          {hits.map((h, i) => {
            const header = h.group !== lastGroup ? h.group : null
            lastGroup = h.group
            return (
              <li key={`${h.group}-${h.to}-${i}`}>
                {header && <div className="px-4 pt-2 pb-1 text-[11.5px] font-semibold text-faint">{header}</div>}
                <button type="button" onMouseEnter={() => setSel(i)} onClick={() => go(h)} className={cx('w-full flex items-center gap-3 px-4 h-10 text-left', sel === i && 'bg-hover')}>
                  <span className="text-[13.5px] font-semibold truncate">{h.label}</span>
                  {h.sub && <span className="text-[12.5px] text-muted truncate">{h.sub}</span>}
                </button>
              </li>
            )
          })}
        </ul>
      </div>
    </div>,
    document.body,
  )
}

/* ───────────── shell ───────────── */

export function Layout() {
  const [palette, setPalette] = useState(false)
  const [menu, setMenu] = useState(false)
  const loc = useLocation()
  const mainRef = useRef<HTMLElement>(null)
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setPalette((v) => !v)
      }
    }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [])
  useEffect(() => {
    mainRef.current?.scrollTo({ top: 0 })
  }, [loc.pathname])

  return (
    <div className="h-screen flex">
      <aside className="hidden lg:flex w-[244px] shrink-0 flex-col">
        <Brand />
        <Sidebar />
        <Me />
      </aside>
      {menu && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-[rgb(21_16_46/0.36)]" onClick={() => setMenu(false)} />
          <aside className="absolute left-0 top-0 h-full w-[260px] bg-canvas flex flex-col animate-drawer">
            <div className="flex items-center justify-between pr-3">
              <Brand />
              <button type="button" aria-label="Close menu" onClick={() => setMenu(false)} className="w-9 h-9 rounded-lg inline-flex items-center justify-center hover:bg-[#e9e6f1]"><XIcon size={18} /></button>
            </div>
            <Sidebar onNavigate={() => setMenu(false)} />
            <Me />
          </aside>
        </div>
      )}
      <div className="flex-1 min-w-0 lg:py-2 lg:pr-2">
        <div className="h-full bg-surface lg:rounded-[14px] lg:border border-line flex flex-col overflow-hidden">
          <div className="flex items-center gap-3 h-14 px-4 lg:px-6 border-b border-line shrink-0">
            <button type="button" aria-label="Open menu" onClick={() => setMenu(true)} className="lg:hidden w-9 h-9 -ml-1 rounded-lg inline-flex items-center justify-center hover:bg-hover"><ListIcon size={20} /></button>
            <button type="button" onClick={() => setPalette(true)} className="flex items-center gap-2.5 h-9 w-full max-w-[420px] px-3 rounded-lg border border-line bg-sunken text-faint text-[13.5px] hover:border-[#d8d4e4] transition-colors">
              <MagnifyingGlassIcon size={16} className="text-muted" />
              <span className="flex-1 text-left truncate">Search people, orders, references…</span>
              <span className="hidden sm:flex items-center gap-1"><Kbd>Ctrl</Kbd><Kbd>K</Kbd></span>
            </button>
            <div className="flex-1" />
            <span className="hidden md:inline-flex items-center gap-1.5 h-7 px-2.5 rounded-full border border-dashed border-[#cfc8e3] text-[12px] font-semibold text-ink-2" title="Everything here is sample data until the backend is connected. Changes you make are saved in this browser only.">
              <span className="w-1.5 h-1.5 rounded-full bg-warn-mark" />
              Demo data
            </span>
            <Alerts />
          </div>
          <main ref={mainRef} className="flex-1 overflow-y-auto">
            <div className="px-5 lg:px-8 py-7 max-w-[1420px] mx-auto">
              <Outlet />
            </div>
          </main>
        </div>
      </div>
      {palette && <Palette onClose={() => setPalette(false)} />}
    </div>
  )
}
