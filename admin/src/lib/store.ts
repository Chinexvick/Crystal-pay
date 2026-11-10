import { create } from 'zustand'
import { makeSeed, type Db } from '../data/seed'
import type {
  Announcement, AuditEntry, Banner, Channel, Message, PlanConfig, RoleKey, Settings, SettingsChange, Staff, Tx,
} from '../data/types'
import { naira } from './format'

/* The admin runs on demo data until the backend exists. Every staff action is stored
   as a small operation and replayed over a fresh copy of the demo data on load, so
   changes survive a refresh while the demo itself never goes stale. */

const OPS_KEY = 'cp-admin-ops-v2'
const SESSION_KEY = 'cp-admin-session'
const DEMO_IP = '203.0.113.120'

export type Op =
  | { t: 'kyc/approve'; id: string }
  | { t: 'kyc/reject'; id: string; reason: string }
  | { t: 'user/freeze'; id: string; reason: string }
  | { t: 'user/unfreeze'; id: string; reason: string }
  | { t: 'user/note'; id: string; text: string }
  | { t: 'user/resetPin'; id: string }
  | { t: 'user/close'; id: string; reason: string }
  | { t: 'listing/approve'; id: string }
  | { t: 'listing/remove'; id: string; reason: string }
  | { t: 'listing/restore'; id: string }
  | { t: 'listing/feature'; id: string; on: boolean }
  | { t: 'report/dismiss'; id: string }
  | { t: 'order/release'; id: string }
  | { t: 'order/cancel'; id: string; reason: string }
  | { t: 'dispute/resolve'; id: string; outcome: 'refunded' | 'released' | 'split'; refund: number; note: string }
  | { t: 'dispute/ask'; id: string; who: 'seller' | 'buyer'; text: string }
  | { t: 'dispute/note'; id: string; text: string }
  | { t: 'bill/refund'; id: string }
  | { t: 'bill/requery'; id: string }
  | { t: 'provider/toggle'; key: string; enabled: boolean }
  | { t: 'wd/approve'; ids: string[] }
  | { t: 'wd/hold'; id: string; reason: string }
  | { t: 'wd/reject'; id: string; reason: string }
  | { t: 'cct/credit'; id: string; reason: string }
  | { t: 'cct/fail'; id: string; reason: string }
  | { t: 'plan/update'; plan: PlanConfig; reason: string }
  | { t: 'banner/save'; banner: Banner }
  | { t: 'banner/status'; id: string; status: Banner['status'] }
  | { t: 'banner/move'; id: string; dir: -1 | 1 }
  | { t: 'banner/delete'; id: string }
  | { t: 'announce/send'; title: string; body: string; audience: string; channels: Channel[]; when: 'now' | number; recipients: number }
  | { t: 'support/reply'; id: string; text: string; staffId: string }
  | { t: 'support/note'; id: string; text: string }
  | { t: 'support/assign'; id: string; staffId: string | null }
  | { t: 'support/status'; id: string; status: 'open' | 'pending' | 'solved' }
  | { t: 'settings/update'; patch: Partial<Settings>; reason: string }
  | { t: 'staff/invite'; name: string; email: string; role: RoleKey }
  | { t: 'staff/role'; id: string; role: RoleKey }
  | { t: 'staff/status'; id: string; status: Staff['status'] }
  | { t: 'alerts/read' }

export type StoredOp = Op & { at: number; by: string }

export interface Session {
  email: string
  name: string
  at: number
}

function load<T>(key: string, fallback: T): T {
  try {
    const v = localStorage.getItem(key)
    return v ? (JSON.parse(v) as T) : fallback
  } catch {
    return fallback
  }
}

function save(key: string, value: unknown) {
  try {
    if (value === null) localStorage.removeItem(key)
    else localStorage.setItem(key, JSON.stringify(value))
  } catch {
    /* storage can be unavailable (private mode); the session simply won't persist */
  }
}

function upd<T extends { id: string }>(arr: T[], id: string, patch: Partial<T> | ((x: T) => Partial<T>)): T[] {
  return arr.map((x) => (x.id === id ? { ...x, ...(typeof patch === 'function' ? patch(x) : patch) } : x))
}

let auditSeq = 0
function audit(db: Db, op: StoredOp, area: string, action: string, target: string, detail?: string): Db {
  const entry: AuditEntry = { id: `AU-${op.at.toString(36)}-${auditSeq++}`, at: op.at, by: op.by, area, action, target, detail, ip: DEMO_IP }
  return { ...db, audit: [entry, ...db.audit] }
}

function newTx(op: StoredOp, t: Omit<Tx, 'id' | 'createdAt'> & { id?: string }): Tx {
  return { id: t.id ?? `CPX-${op.at.toString(36).toUpperCase().slice(-8)}`, createdAt: op.at, ...t }
}

const userName = (db: Db, id: string) => db.users.find((u) => u.id === id)?.name ?? id

export const settingLabels: Record<keyof Settings, string> = {
  cctMode: 'CCT rate source',
  cctRate: 'CCT rate',
  cctMarketRate: 'CCT market rate',
  cctServicePct: 'CCT conversion fee',
  cctConfirmations: 'Confirmations before credit',
  cctQuoteMinutes: 'Rate lock time',
  cctMinDeposit: 'Smallest CCT deposit',
  withdrawalFee: 'Withdrawal fee',
  deliveryFee: 'Delivery fee per seller',
  sendUnverified: 'Send limit, unverified users',
  sendVerified: 'Send limit, verified users',
  fundMin: 'Smallest wallet funding',
  fundMax: 'Largest wallet funding',
  withdrawMin: 'Smallest withdrawal',
  withdrawMax: 'Largest withdrawal',
  dailyOut: 'Daily money-out limit',
  referralReward: 'Referral reward',
  referralMinFunding: 'Friend’s first funding needed',
}

export function settingValue(key: keyof Settings, v: Settings[keyof Settings]) {
  if (key === 'cctMode') return v === 'market' ? 'Follow the market' : 'Fixed rate'
  if (key === 'cctServicePct') return `${v}%`
  if (key === 'cctConfirmations') return `${v} blocks`
  if (key === 'cctQuoteMinutes') return `${v} minutes`
  if (key === 'cctMinDeposit') return `${v} CCT`
  if (key === 'cctRate' || key === 'cctMarketRate') return `₦${Number(v).toFixed(2)}`
  return naira(Number(v))
}

export function apply(db: Db, op: StoredOp): Db {
  switch (op.t) {
    case 'kyc/approve': {
      const v = db.verifications.find((x) => x.id === op.id)
      if (!v || v.status !== 'pending') return db
      db = { ...db, verifications: upd(db.verifications, op.id, { status: 'approved', reviewedBy: op.by, reviewedAt: op.at }), users: upd(db.users, v.userId, { kyc: 'verified', idType: v.idType }) }
      return audit(db, op, 'Verifications', 'Approved ID', userName(db, v.userId), `${v.idType} ${v.id}`)
    }
    case 'kyc/reject': {
      const v = db.verifications.find((x) => x.id === op.id)
      if (!v || v.status !== 'pending') return db
      db = { ...db, verifications: upd(db.verifications, op.id, { status: 'rejected', reviewedBy: op.by, reviewedAt: op.at, rejectReason: op.reason }), users: upd(db.users, v.userId, { kyc: 'rejected' }) }
      return audit(db, op, 'Verifications', 'Rejected ID', userName(db, v.userId), op.reason)
    }
    case 'user/freeze':
    case 'user/unfreeze':
    case 'user/close': {
      const u = db.users.find((x) => x.id === op.id)
      if (!u) return db
      const status = op.t === 'user/freeze' ? 'frozen' : op.t === 'user/close' ? 'closed' : 'active'
      const verb = op.t === 'user/freeze' ? 'Froze account' : op.t === 'user/close' ? 'Closed account' : 'Unfroze account'
      db = { ...db, users: upd(db.users, op.id, (x) => ({ status, notes: [{ id: `N-${op.at}`, at: op.at, by: op.by, text: `${verb}: ${op.reason}` }, ...x.notes] })) }
      return audit(db, op, 'Users', verb, u.name, op.reason)
    }
    case 'user/note': {
      const u = db.users.find((x) => x.id === op.id)
      if (!u) return db
      db = { ...db, users: upd(db.users, op.id, (x) => ({ notes: [{ id: `N-${op.at}`, at: op.at, by: op.by, text: op.text }, ...x.notes] })) }
      return audit(db, op, 'Users', 'Added note', u.name)
    }
    case 'user/resetPin': {
      const u = db.users.find((x) => x.id === op.id)
      if (!u) return db
      return audit(db, op, 'Users', 'Sent PIN reset link', u.name, u.email)
    }
    case 'listing/approve':
    case 'listing/restore': {
      const l = db.listings.find((x) => x.id === op.id)
      if (!l) return db
      db = { ...db, listings: upd(db.listings, op.id, { status: 'live', removedReason: undefined }) }
      return audit(db, op, 'Listings', op.t === 'listing/approve' ? 'Approved listing' : 'Restored listing', l.title)
    }
    case 'listing/remove': {
      const l = db.listings.find((x) => x.id === op.id)
      if (!l) return db
      db = {
        ...db,
        listings: upd(db.listings, op.id, { status: 'removed', removedReason: op.reason, featured: false }),
        reports: db.reports.map((r) => (r.listingId === op.id && r.status === 'open' ? { ...r, status: 'removed', closedBy: op.by } : r)),
      }
      return audit(db, op, 'Listings', 'Removed listing', l.title, op.reason)
    }
    case 'listing/feature': {
      const l = db.listings.find((x) => x.id === op.id)
      if (!l) return db
      db = { ...db, listings: upd(db.listings, op.id, { featured: op.on }) }
      return audit(db, op, 'Listings', op.on ? 'Featured listing' : 'Stopped featuring listing', l.title)
    }
    case 'report/dismiss': {
      const r = db.reports.find((x) => x.id === op.id)
      if (!r || r.status !== 'open') return db
      const l = db.listings.find((x) => x.id === r.listingId)
      db = { ...db, reports: upd(db.reports, op.id, { status: 'dismissed', closedBy: op.by }) }
      return audit(db, op, 'Reports', 'Dismissed report', `${r.id} · ${l?.title ?? r.listingId}`, r.reason)
    }
    case 'order/release': {
      const o = db.orders.find((x) => x.id === op.id)
      if (!o || !['paid', 'shipped', 'delivered'].includes(o.stage)) return db
      const fee = Math.round((o.amount * o.serviceFeePct) / 100)
      const l = db.listings.find((x) => x.id === o.listingId)
      db = {
        ...db,
        orders: upd(db.orders, o.id, { stage: 'completed', completedAt: op.at, deliveredAt: o.deliveredAt ?? op.at }),
        users: db.users.map((u) => (u.id === o.buyerId ? { ...u, held: Math.max(0, u.held - o.amount - o.deliveryFee) } : u)),
        txs: [newTx(op, { id: `${o.id}-R`, userId: o.sellerId, type: 'sale_release', direction: 'in', amount: o.amount + o.deliveryFee - fee, fee, status: 'successful', title: `Sale released · ${l?.title ?? ''}`, channel: 'Crystal Protect', meta: { Order: o.id, 'Released by': op.by } }), ...db.txs],
      }
      return audit(db, op, 'Orders', 'Released payment to seller', o.id, naira(o.amount + o.deliveryFee - fee))
    }
    case 'order/cancel': {
      const o = db.orders.find((x) => x.id === op.id)
      if (!o || !['paid', 'shipped', 'delivered'].includes(o.stage)) return db
      db = {
        ...db,
        orders: upd(db.orders, o.id, { stage: 'cancelled' }),
        users: db.users.map((u) => (u.id === o.buyerId ? { ...u, held: Math.max(0, u.held - o.amount - o.deliveryFee), balance: u.balance + o.amount + o.deliveryFee } : u)),
        txs: [newTx(op, { userId: o.buyerId, type: 'refund', direction: 'in', amount: o.amount + o.deliveryFee, fee: 0, status: 'successful', title: `Refund · order ${o.id}`, channel: 'Crystal Protect', meta: { Order: o.id, Reason: op.reason } }), ...db.txs],
      }
      return audit(db, op, 'Orders', 'Cancelled order and refunded buyer', o.id, op.reason)
    }
    case 'dispute/resolve': {
      const d = db.disputes.find((x) => x.id === op.id)
      if (!d || !(d.status === 'open' || d.status === 'awaiting_seller')) return db
      const o = db.orders.find((x) => x.id === d.orderId)
      if (!o) return db
      const total = o.amount + o.deliveryFee
      const refund = op.outcome === 'refunded' ? total : op.outcome === 'released' ? 0 : Math.min(total, Math.max(0, op.refund))
      const toSeller = total - refund
      const fee = toSeller > 0 ? Math.round((Math.max(0, toSeller - o.deliveryFee) * o.serviceFeePct) / 100) : 0
      const summary = op.outcome === 'refunded' ? `Full refund of ${naira(refund)} to the buyer` : op.outcome === 'released' ? `${naira(toSeller - fee)} released to the seller` : `${naira(refund)} refunded to the buyer, ${naira(toSeller - fee)} released to the seller`
      const newTxs: Tx[] = []
      if (refund > 0) newTxs.push(newTx(op, { id: `${d.id}-RF`, userId: o.buyerId, type: 'refund', direction: 'in', amount: refund, fee: 0, status: 'successful', title: `Dispute refund · ${o.id}`, channel: 'Crystal Protect', meta: { Dispute: d.id } }))
      if (toSeller > 0) newTxs.push(newTx(op, { id: `${d.id}-RL`, userId: o.sellerId, type: 'sale_release', direction: 'in', amount: toSeller - fee, fee, status: 'successful', title: `Sale released after dispute · ${o.id}`, channel: 'Crystal Protect', meta: { Dispute: d.id } }))
      db = {
        ...db,
        disputes: upd(db.disputes, d.id, (x) => ({ status: op.outcome, resolvedAt: op.at, refundAmount: refund, resolution: op.note || summary, timeline: [...x.timeline, { at: op.at, text: `Resolved: ${summary}`, by: op.by }] })),
        orders: upd(db.orders, o.id, { stage: op.outcome === 'refunded' ? 'cancelled' : 'completed', completedAt: op.at }),
        users: db.users.map((u) => (u.id === o.buyerId ? { ...u, held: Math.max(0, u.held - total), balance: u.balance + refund } : u)),
        txs: [...newTxs, ...db.txs],
      }
      return audit(db, op, 'Disputes', 'Resolved dispute', `${d.id} · ${o.id}`, summary)
    }
    case 'dispute/ask': {
      const d = db.disputes.find((x) => x.id === op.id)
      if (!d) return db
      db = { ...db, disputes: upd(db.disputes, d.id, (x) => ({ status: op.who === 'seller' && x.status === 'open' ? 'awaiting_seller' : x.status, timeline: [...x.timeline, { at: op.at, text: `Asked the ${op.who}: “${op.text}”`, by: op.by }] })) }
      return audit(db, op, 'Disputes', `Messaged the ${op.who}`, d.id)
    }
    case 'dispute/note': {
      const d = db.disputes.find((x) => x.id === op.id)
      if (!d) return db
      db = { ...db, disputes: upd(db.disputes, d.id, (x) => ({ timeline: [...x.timeline, { at: op.at, text: `Note: ${op.text}`, by: op.by }] })) }
      return audit(db, op, 'Disputes', 'Added note', d.id)
    }
    case 'bill/refund': {
      const b = db.bills.find((x) => x.id === op.id)
      if (!b || (b.status !== 'failed' && b.status !== 'pending')) return db
      db = {
        ...db,
        bills: upd(db.bills, b.id, { status: 'refunded', failureReason: b.failureReason ?? 'Refunded by staff' }),
        txs: [newTx(op, { id: `${b.id}-RF`, userId: b.userId, type: 'refund', direction: 'in', amount: b.amount, fee: 0, status: 'successful', title: `Refund · ${b.service}`, channel: 'Wallet', meta: { 'Refund for': b.id, 'Refunded by': op.by } }), ...upd(db.txs, b.id, { status: 'reversed' })],
        users: db.users.map((u) => (u.id === b.userId ? { ...u, balance: u.balance + b.amount } : u)),
      }
      return audit(db, op, 'Bill payments', 'Refunded failed bill', b.id, `${naira(b.amount)} to ${userName(db, b.userId)}`)
    }
    case 'bill/requery': {
      const b = db.bills.find((x) => x.id === op.id)
      if (!b) return db
      if (b.status === 'pending') {
        db = { ...db, bills: upd(db.bills, b.id, { status: 'successful' }), txs: upd(db.txs, b.id, { status: 'successful' }) }
        return audit(db, op, 'Bill payments', 'Checked with provider: delivered', b.id)
      }
      return audit(db, op, 'Bill payments', `Checked with provider: ${b.status}`, b.id)
    }
    case 'provider/toggle': {
      const p = db.providers.find((x) => x.key === op.key)
      if (!p) return db
      db = { ...db, providers: db.providers.map((x) => (x.key === op.key ? { ...x, enabled: op.enabled } : x)) }
      return audit(db, op, 'Bill payments', op.enabled ? 'Turned provider on' : 'Paused provider', p.name)
    }
    case 'wd/approve': {
      let next = db
      for (const id of op.ids) {
        const w = next.withdrawals.find((x) => x.id === id)
        if (!w || !(w.status === 'review' || w.status === 'held')) continue
        next = { ...next, withdrawals: upd(next.withdrawals, id, { status: 'paid', processedAt: op.at, processedBy: op.by, holdReason: undefined }), txs: upd(next.txs, id, { status: 'successful' }) }
        next = audit(next, op, 'Withdrawals', 'Approved withdrawal', `${id} · ${naira(w.amount)}`, `${w.bankName} ${w.accountNumber}`)
      }
      return next
    }
    case 'wd/hold': {
      const w = db.withdrawals.find((x) => x.id === op.id)
      if (!w || w.status !== 'review') return db
      db = { ...db, withdrawals: upd(db.withdrawals, op.id, { status: 'held', holdReason: op.reason, processedBy: op.by }) }
      return audit(db, op, 'Withdrawals', 'Held withdrawal', `${w.id} · ${naira(w.amount)}`, op.reason)
    }
    case 'wd/reject': {
      const w = db.withdrawals.find((x) => x.id === op.id)
      if (!w || !(w.status === 'review' || w.status === 'held')) return db
      db = {
        ...db,
        withdrawals: upd(db.withdrawals, op.id, { status: 'failed', holdReason: op.reason, processedAt: op.at, processedBy: op.by }),
        txs: upd(db.txs, w.id, { status: 'reversed' }),
        users: db.users.map((u) => (u.id === w.userId ? { ...u, balance: u.balance + w.amount + w.fee } : u)),
      }
      return audit(db, op, 'Withdrawals', 'Rejected withdrawal and returned money', `${w.id} · ${naira(w.amount)}`, op.reason)
    }
    case 'cct/credit': {
      const d = db.cct.find((x) => x.id === op.id)
      if (!d || d.status !== 'underpaid') return db
      const rate = db.settings.cctMode === 'market' ? db.settings.cctMarketRate : db.settings.cctRate
      const gross = d.amount * rate
      const fee = Math.round(gross * (db.settings.cctServicePct / 100))
      const naira_ = Math.round(gross - fee)
      db = { ...db, cct: upd(db.cct, d.id, { status: 'credited', rate, fee, naira: naira_ }), txs: upd(db.txs, d.id, { status: 'successful', amount: naira_, fee }) }
      return audit(db, op, 'CCT deposits', 'Credited deposit below minimum', d.id, op.reason)
    }
    case 'cct/fail': {
      const d = db.cct.find((x) => x.id === op.id)
      if (!d || d.status !== 'underpaid') return db
      db = { ...db, cct: upd(db.cct, d.id, { status: 'failed' }), txs: upd(db.txs, d.id, { status: 'failed' }) }
      return audit(db, op, 'CCT deposits', 'Marked deposit as not credited', d.id, op.reason)
    }
    case 'plan/update': {
      const prev = db.plans.find((p) => p.key === op.plan.key)
      if (!prev) return db
      const changes: string[] = []
      if (prev.price !== op.plan.price) changes.push(`price ${naira(prev.price)} → ${naira(op.plan.price)}`)
      if (prev.listings !== op.plan.listings) changes.push(`listings ${prev.listings} → ${op.plan.listings}`)
      if (prev.feePct !== op.plan.feePct) changes.push(`sale fee ${prev.feePct}% → ${op.plan.feePct}%`)
      if (prev.boosts !== op.plan.boosts) changes.push(`boosts ${prev.boosts} → ${op.plan.boosts}`)
      if (!changes.length) return db
      db = { ...db, plans: db.plans.map((p) => (p.key === op.plan.key ? op.plan : p)) }
      return audit(db, op, 'Seller plans', `Changed ${op.plan.name} plan`, changes.join(', '), op.reason)
    }
    case 'banner/save': {
      const exists = db.banners.some((b) => b.id === op.banner.id)
      db = { ...db, banners: exists ? db.banners.map((b) => (b.id === op.banner.id ? op.banner : b)) : [...db.banners, op.banner] }
      return audit(db, op, 'Banners', exists ? 'Edited banner' : 'Created banner', op.banner.title)
    }
    case 'banner/status': {
      const b = db.banners.find((x) => x.id === op.id)
      if (!b) return db
      db = { ...db, banners: upd(db.banners, op.id, { status: op.status, startsAt: op.status === 'live' ? b.startsAt ?? op.at : b.startsAt }) }
      return audit(db, op, 'Banners', op.status === 'live' ? 'Published banner' : op.status === 'paused' ? 'Paused banner' : 'Changed banner status', b.title)
    }
    case 'banner/move': {
      const i = db.banners.findIndex((b) => b.id === op.id)
      const j = i + op.dir
      if (i < 0 || j < 0 || j >= db.banners.length) return db
      const banners = [...db.banners]
      ;[banners[i], banners[j]] = [banners[j], banners[i]]
      db = { ...db, banners }
      return audit(db, op, 'Banners', 'Reordered banners', db.banners[j].title, `Now position ${j + 1}`)
    }
    case 'banner/delete': {
      const b = db.banners.find((x) => x.id === op.id)
      if (!b) return db
      db = { ...db, banners: db.banners.filter((x) => x.id !== op.id) }
      return audit(db, op, 'Banners', 'Deleted banner', b.title)
    }
    case 'announce/send': {
      const a: Announcement = {
        id: `AN-${op.at.toString(36).toUpperCase().slice(-5)}`, title: op.title, body: op.body, audience: op.audience, channels: op.channels,
        status: op.when === 'now' ? 'sent' : 'scheduled', at: op.when === 'now' ? op.at : op.when, recipients: op.recipients, opened: 0, by: op.by,
      }
      db = { ...db, announcements: [a, ...db.announcements] }
      return audit(db, op, 'Announcements', a.status === 'sent' ? 'Sent announcement' : 'Scheduled announcement', a.title, `${op.audience} · ${op.recipients} people`)
    }
    case 'support/reply':
    case 'support/note': {
      const c = db.conversations.find((x) => x.id === op.id)
      if (!c) return db
      const msg: Message = { id: `${c.id}-${op.at}`, from: op.t === 'support/reply' ? 'agent' : 'note', text: op.text, at: op.at, by: op.by }
      db = {
        ...db,
        conversations: upd(db.conversations, c.id, (x) => ({
          messages: [...x.messages, msg],
          updatedAt: op.at,
          ...(op.t === 'support/reply' ? { status: x.status === 'solved' ? 'solved' : 'pending', waitingSince: undefined, assignee: x.assignee ?? op.staffId } : {}),
        })),
      }
      return op.t === 'support/reply' ? audit(db, op, 'Support', 'Replied to user', `${c.id} · ${userName(db, c.userId)}`) : db
    }
    case 'support/assign': {
      const c = db.conversations.find((x) => x.id === op.id)
      if (!c) return db
      const s = db.staff.find((x) => x.id === op.staffId)
      db = { ...db, conversations: upd(db.conversations, c.id, { assignee: op.staffId ?? undefined }) }
      return audit(db, op, 'Support', op.staffId ? 'Assigned conversation' : 'Unassigned conversation', c.id, s?.name)
    }
    case 'support/status': {
      const c = db.conversations.find((x) => x.id === op.id)
      if (!c) return db
      db = { ...db, conversations: upd(db.conversations, c.id, { status: op.status, waitingSince: op.status === 'open' ? c.waitingSince ?? op.at : undefined, updatedAt: op.at }) }
      return audit(db, op, 'Support', op.status === 'solved' ? 'Solved conversation' : 'Reopened conversation', c.id)
    }
    case 'settings/update': {
      const changes: SettingsChange[] = []
      for (const k of Object.keys(op.patch) as (keyof Settings)[]) {
        const from = db.settings[k]
        const to = op.patch[k]
        if (to === undefined || from === to) continue
        changes.push({ id: `SH-${op.at}-${k}`, at: op.at, by: op.by, field: settingLabels[k], from: settingValue(k, from), to: settingValue(k, to as Settings[keyof Settings]), reason: op.reason })
      }
      if (!changes.length) return db
      db = { ...db, settings: { ...db.settings, ...op.patch }, settingsHistory: [...changes, ...db.settingsHistory] }
      for (const c of changes) db = audit(db, op, 'Rates and fees', `Changed ${c.field.toLowerCase()}`, `${c.from} → ${c.to}`, op.reason)
      return db
    }
    case 'staff/invite': {
      const s: Staff = { id: `S-${op.at.toString(36)}`, name: op.name, email: op.email, role: op.role, twoStep: false, lastActiveAt: op.at, status: 'invited' }
      db = { ...db, staff: [...db.staff, s] }
      return audit(db, op, 'Staff', 'Invited staff', `${op.name} · ${roleNames[op.role]}`, op.email)
    }
    case 'staff/role': {
      const s = db.staff.find((x) => x.id === op.id)
      if (!s) return db
      db = { ...db, staff: upd(db.staff, op.id, { role: op.role }) }
      return audit(db, op, 'Staff', 'Changed role', s.name, `${roleNames[s.role]} → ${roleNames[op.role]}`)
    }
    case 'staff/status': {
      const s = db.staff.find((x) => x.id === op.id)
      if (!s) return db
      db = { ...db, staff: upd(db.staff, op.id, { status: op.status }) }
      return audit(db, op, 'Staff', op.status === 'disabled' ? 'Turned off access' : 'Turned on access', s.name)
    }
    case 'alerts/read':
      return { ...db, alerts: db.alerts.map((a) => ({ ...a, read: true })) }
  }
}

export const roleNames: Record<RoleKey, string> = {
  super_admin: 'Super admin',
  operations: 'Operations',
  compliance: 'Compliance',
  finance: 'Finance',
  support: 'Support',
  viewer: 'Read-only',
}

function build(ops: StoredOp[]) {
  let db = makeSeed()
  for (const op of ops) {
    try {
      db = apply(db, op)
    } catch {
      /* an op from an older demo version: skip it */
    }
  }
  return db
}

interface State {
  db: Db
  ops: StoredOp[]
  session: Session | null
  dispatch: (op: Op) => void
  login: (email: string) => void
  logout: () => void
  reset: () => void
}

const initialOps = load<StoredOp[]>(OPS_KEY, [])

export const useStore = create<State>((set, get) => ({
  db: build(initialOps),
  ops: initialOps,
  session: load<Session | null>(SESSION_KEY, null),
  dispatch: (op) => {
    const s = get()
    const stored = { ...op, at: Date.now(), by: s.session?.name ?? 'Admin' } as StoredOp
    const db = apply(s.db, stored)
    const ops = op.t === 'alerts/read' ? s.ops : [...s.ops, stored]
    save(OPS_KEY, ops)
    set({ db, ops })
  },
  login: (email) => {
    const e = email.trim().toLowerCase()
    const staff = get().db.staff.find((x) => x.email === e)
    const local = e.split('@')[0].replace(/[._-]+/g, ' ').trim()
    const name = staff?.name ?? (local ? local.replace(/\b\w/g, (c) => c.toUpperCase()) : 'Admin')
    const session = { email: e, name, at: Date.now() }
    save(SESSION_KEY, session)
    set({ session })
  },
  logout: () => {
    save(SESSION_KEY, null)
    set({ session: null })
  },
  reset: () => {
    save(OPS_KEY, [])
    set({ db: build([]), ops: [] })
  },
}))

export const useDb = () => useStore((s) => s.db)
export const useDispatch = () => useStore((s) => s.dispatch)

/** The signed-in staff member (a stand-in record when the email is not on the staff list). */
export function useMe(): Staff {
  const session = useStore((s) => s.session)
  const staff = useStore((s) => s.db.staff)
  const found = staff.find((x) => x.email === session?.email)
  if (found) return found
  return { id: 'S-ME', name: session?.name ?? 'Admin', email: session?.email ?? '', role: 'super_admin', twoStep: false, lastActiveAt: Date.now(), status: 'active' }
}
