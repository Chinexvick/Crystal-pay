import { useEffect, useMemo } from 'react'
import { create } from 'zustand'
import { useDb } from './store'
import { T } from './format'

/* A shared clock so waiting times and "x ago" labels move on their own. */
const useClock = create<{ now: number }>(() => ({ now: Date.now() }))
let started = false
export function useNow() {
  useEffect(() => {
    if (started) return
    started = true
    setInterval(() => useClock.setState({ now: Date.now() }), 30_000)
  }, [])
  return useClock((s) => s.now)
}

/** How long each kind of work may wait before it is late. */
export const SLA = {
  kyc: 24 * T.HOUR,
  withdrawal: 2 * T.HOUR,
  dispute: 48 * T.HOUR,
  support: 1 * T.HOUR,
  bill: 1 * T.HOUR,
  report: 12 * T.HOUR,
  listing: 6 * T.HOUR,
  cct: 4 * T.HOUR,
}

export interface Queue {
  key: keyof typeof SLA
  label: string
  what: [string, string]
  count: number
  oldest?: number
  sla: number
  to: string
  late: number
}

export function useQueues(): Queue[] {
  const db = useDb()
  const now = useNow()
  return useMemo(() => {
    const q = (key: keyof typeof SLA, label: string, what: [string, string], to: string, times: number[]): Queue => ({
      key, label, what, to, count: times.length, oldest: times.length ? Math.min(...times) : undefined, sla: SLA[key], late: times.filter((t) => now - t > SLA[key]).length,
    })
    const openReportsByListing = new Map<string, number>()
    db.reports.filter((r) => r.status === 'open').forEach((r) => openReportsByListing.set(r.listingId, Math.min(openReportsByListing.get(r.listingId) ?? Infinity, r.createdAt)))
    return [
      q('withdrawal', 'Withdrawals', ['flagged payout to approve', 'flagged payouts to approve'], '/withdrawals', db.withdrawals.filter((w) => w.status === 'review').map((w) => w.requestedAt)),
      q('support', 'Support', ['person waiting for a reply', 'people waiting for a reply'], '/support', db.conversations.filter((c) => c.status === 'open').map((c) => c.waitingSince ?? c.updatedAt)),
      q('bill', 'Failed bills', ['payment to refund by hand', 'payments to refund by hand'], '/bills?tab=failed', db.bills.filter((b) => b.status === 'failed').map((b) => b.createdAt)),
      q('kyc', 'Verifications', ['ID to check', 'IDs to check'], '/verifications', db.verifications.filter((v) => v.status === 'pending').map((v) => v.submittedAt)),
      q('dispute', 'Disputes', ['order to decide', 'orders to decide'], '/disputes', db.disputes.filter((d) => d.status === 'open' || d.status === 'awaiting_seller').map((d) => d.openedAt)),
      q('report', 'Reported listings', ['listing to review', 'listings to review'], '/reports', [...openReportsByListing.values()]),
      q('listing', 'New listings', ['listing to check before it goes live', 'listings to check before they go live'], '/listings?tab=review', db.listings.filter((l) => l.status === 'review').map((l) => l.createdAt)),
      q('cct', 'CCT deposits', ['deposit that needs a decision', 'deposits that need a decision'], '/cct', db.cct.filter((d) => d.status === 'underpaid').map((d) => d.createdAt)),
    ]
  }, [db, now])
}

export function useBadges() {
  const queues = useQueues()
  return useMemo(() => Object.fromEntries(queues.map((q) => [q.key, q])) as Record<keyof typeof SLA, Queue>, [queues])
}
