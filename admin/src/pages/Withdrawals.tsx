import { useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { BankIcon, CheckCircleIcon, PauseIcon, WarningCircleIcon, WarningIcon, XCircleIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { SLA, useNow } from '../lib/queues'
import { fmtDate, fmtDateTime, lastFour, naira, num, timeAgo } from '../lib/format'
import { Avatar, Button, Empty, KV, Logo, Mono, PageHeader, Pill, Tabs, cx } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import { Wait } from '../components/Wait'
import { TxAmount } from '../components/tx'
import { Drawer, confirm, toast } from '../components/overlays'
import type { Withdrawal, WithdrawalStatus } from '../data/types'

type TabKey = 'review' | 'held' | 'processing' | 'paid' | 'failed'

export default function Withdrawals() {
  const db = useDb()
  const dispatch = useDispatch()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const initial = db.withdrawals.find((w) => w.id === params.get('id'))?.status as TabKey | undefined
  const [tab, setTab] = useState<TabKey>(initial ?? 'review')
  const [picked, setPicked] = useState<Set<string>>(new Set())

  const counts = useMemo(() => {
    const c: Record<WithdrawalStatus, number> = { review: 0, held: 0, processing: 0, paid: 0, failed: 0 }
    db.withdrawals.forEach((w) => c[w.status]++)
    return c
  }, [db.withdrawals])
  const rows = useMemo(() => db.withdrawals.filter((w) => w.status === tab).sort((a, b) => (tab === 'review' || tab === 'held' ? a.requestedAt - b.requestedAt : b.requestedAt - a.requestedAt)), [db.withdrawals, tab])
  const reviewTotal = db.withdrawals.filter((w) => w.status === 'review').reduce((a, w) => a + w.amount, 0)
  const open = db.withdrawals.find((w) => w.id === params.get('id')) ?? null

  const approveMany = async (ids: string[]) => {
    const total = ids.reduce((a, id) => a + (db.withdrawals.find((w) => w.id === id)?.amount ?? 0), 0)
    const ok = await confirm({ title: ids.length === 1 ? `Pay out ${naira(total)}?` : `Approve ${ids.length} withdrawals?`, message: `${naira(total)} goes to the bank accounts shown. Transfers usually land within a few minutes.`, confirmLabel: ids.length === 1 ? 'Approve payout' : `Approve ${ids.length} payouts` })
    if (!ok) return
    dispatch({ t: 'wd/approve', ids })
    setPicked(new Set())
    toast(ids.length === 1 ? 'Payout approved' : `${ids.length} payouts approved`)
  }

  const columns: Column<Withdrawal>[] = [
    { key: 'id', header: 'Request', cell: (w) => <span><Mono className="block text-ink">{w.id}</Mono><span className="block text-[12px] text-muted">{timeAgo(w.requestedAt, now)}</span></span> },
    {
      key: 'who', header: 'Person',
      cell: (w) => {
        const u = db.users.find((x) => x.id === w.userId)!
        return <span className="flex items-center gap-2.5 min-w-0"><Avatar name={u.name} src={u.avatar} size={28} verified={u.kyc === 'verified'} /><span className="font-semibold truncate">{u.name}</span></span>
      },
    },
    { key: 'amt', header: 'Amount', align: 'right', cell: (w) => <span className="num font-bold">{naira(w.amount)}</span> },
    { key: 'bank', header: 'To', cell: (w) => <span className="flex items-center gap-2.5 min-w-0"><Logo src={`/img/banks/${w.bankCode}.webp`} name={w.bankName} size={26} rounded="rounded-full" /><span className="min-w-0"><span className="block font-semibold truncate max-w-[180px]">{w.bankName}</span><span className="block text-[12px] text-muted mono">{lastFour(w.accountNumber)}</span></span></span> },
    { key: 'name', header: 'Name check', cell: (w) => (w.nameMatch ? <Pill tone="ok" icon={CheckCircleIcon}>Matches</Pill> : <Pill tone="bad" icon={WarningCircleIcon}>Differs</Pill>) },
  ]
  if (tab === 'review' || tab === 'held') {
    columns.push({ key: 'flags', header: tab === 'held' ? 'Why held' : 'Why it stopped', cell: (w) => <span className="text-[12.5px] text-ink-2 line-clamp-2 max-w-[260px]">{tab === 'held' ? w.holdReason : w.flags.join(' · ')}</span> })
    columns.push({ key: 'wait', header: 'Waiting', cell: (w) => <Wait since={w.requestedAt} sla={SLA.withdrawal} width={44} /> })
  } else {
    columns.push({ key: 'status', header: 'Status', cell: (w) => <Status kind="withdrawal" value={w.status} /> })
    columns.push({ key: 'when', header: 'Requested', cell: (w) => <span className="text-ink-2 whitespace-nowrap">{fmtDateTime(w.requestedAt)}</span> })
  }

  return (
    <>
      <PageHeader title="Withdrawals" description="Payouts to people’s own verified bank accounts. Most go out on their own; the ones that trip a risk rule wait here for a person." />
      <Tabs
        value={tab}
        onChange={(t) => { setTab(t); setPicked(new Set()) }}
        items={[
          { value: 'review', label: 'Needs review', count: counts.review, alert: true },
          { value: 'held', label: 'On hold', count: counts.held },
          { value: 'processing', label: 'Processing', count: counts.processing },
          { value: 'paid', label: 'Paid', count: counts.paid },
          { value: 'failed', label: 'Returned', count: counts.failed },
        ]}
      />
      {tab === 'review' && rows.length > 0 && (
        <div className="flex flex-wrap items-center gap-3 mb-3 text-[13px]">
          <span className="text-ink-2"><span className="font-bold num">{naira(reviewTotal)}</span> waiting across {rows.length} requests. Target: decide within 2 hours.</span>
          <span className="flex-1" />
          {picked.size > 0 && <Button variant="primary" size="sm" icon={CheckCircleIcon} onClick={() => approveMany([...picked])}>Approve {picked.size} selected</Button>}
        </div>
      )}
      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(w) => w.id}
        activeKey={open?.id}
        onRowClick={(w) => setParams({ id: w.id }, { replace: true })}
        selectable={tab === 'review' ? () => true : undefined}
        selected={picked}
        onSelect={setPicked}
        empty={<Empty icon={BankIcon} title={tab === 'review' ? 'Nothing to review' : 'Nothing here'}>{tab === 'review' ? 'Flagged withdrawals show up here the moment they are requested.' : 'No withdrawals in this state.'}</Empty>}
      />
      <WithdrawalDrawer w={open} onClose={() => setParams({}, { replace: true })} onApprove={(id) => approveMany([id])} />
    </>
  )
}

function WithdrawalDrawer({ w, onClose, onApprove }: { w: Withdrawal | null; onClose: () => void; onApprove: (id: string) => void }) {
  const db = useDb()
  const dispatch = useDispatch()
  if (!w) return null
  const u = db.users.find((x) => x.id === w.userId)!
  const history = db.withdrawals.filter((x) => x.userId === u.id && x.id !== w.id && x.status === 'paid')
  const usual = history.length ? Math.round(history.reduce((a, x) => a + x.amount, 0) / history.length) : 0
  const txs = db.txs.filter((t) => t.userId === u.id).slice(0, 6)
  const canAct = w.status === 'review' || w.status === 'held'
  return (
    <Drawer
      open
      onClose={onClose}
      width={560}
      title={`${naira(w.amount)} to ${w.bankName}`}
      subtitle={<span className="flex items-center gap-2"><Mono copy>{w.id}</Mono><span>· requested {fmtDateTime(w.requestedAt)}</span></span>}
      footer={canAct ? (
        <>
          <Button
            variant="danger-soft"
            icon={XCircleIcon}
            onClick={async () => {
              const r = await confirm({ title: 'Reject and return the money?', message: `${naira(w.amount + w.fee)} goes back to ${u.name}’s wallet, including the ₦${w.fee} fee.`, confirmLabel: 'Reject withdrawal', tone: 'danger', reason: { label: 'Reason the user will see', options: ['Bank account name does not match', 'Could not confirm it was you', 'Suspected fraud', 'Other'] } })
              if (r) { dispatch({ t: 'wd/reject', id: w.id, reason: r.reason }); toast('Withdrawal rejected and money returned') }
            }}
          >
            Reject
          </Button>
          {w.status === 'review' && (
            <Button
              icon={PauseIcon}
              onClick={async () => {
                const r = await confirm({ title: 'Put this withdrawal on hold?', message: 'The money stays reserved. Nothing is sent until someone approves or rejects it.', confirmLabel: 'Hold withdrawal', reason: { label: 'What are you waiting for?', placeholder: 'For example: calling the user to confirm the new device' } })
                if (r) { dispatch({ t: 'wd/hold', id: w.id, reason: r.reason }); toast('Withdrawal on hold') }
              }}
            >
              Hold
            </Button>
          )}
          <span className="flex-1" />
          <Button variant="primary" icon={CheckCircleIcon} onClick={() => onApprove(w.id)}>Approve payout</Button>
        </>
      ) : undefined}
    >
      <div className="flex items-center justify-between mb-5"><Status kind="withdrawal" value={w.status} />{w.processedBy && <span className="text-[12.5px] text-muted">by {w.processedBy}</span>}</div>
      {w.flags.length > 0 && (
        <div className="rounded-xl bg-warn-tint/70 border border-[#f6dcb0] px-4 py-3 mb-5">
          <div className="flex items-center gap-1.5 text-[13px] font-bold text-warn mb-1"><WarningIcon size={16} weight="fill" /> Stopped for review</div>
          <ul className="text-[13px] text-ink-2 list-disc pl-5 space-y-0.5">{w.flags.map((f) => <li key={f}>{f}</li>)}</ul>
        </div>
      )}
      {w.holdReason && <div className="rounded-xl bg-[#f1f0f5] px-4 py-3 mb-5 text-[13px] text-ink-2"><span className="font-semibold">{w.status === 'failed' ? 'Returned:' : 'On hold:'}</span> {w.holdReason}</div>}
      <h3 className="text-[13px] font-bold mb-1">Bank account</h3>
      <KV rows={[
        ['Bank', <span className="inline-flex items-center gap-2"><Logo src={`/img/banks/${w.bankCode}.webp`} name={w.bankName} size={20} rounded="rounded-full" />{w.bankName}</span>],
        ['Account number', <Mono copy>{w.accountNumber}</Mono>],
        ['Name from the bank', <span className={cx(!w.nameMatch && 'text-bad')}>{w.accountName}</span>],
        ['Verified name on Crystal Pay', u.name.toUpperCase()],
      ]} />
      <h3 className="text-[13px] font-bold mt-6 mb-1">Person</h3>
      <KV rows={[
        ['Name', <Link to={`/users/${u.id}`} className="text-brand hover:underline">{u.name}</Link>],
        ['ID check', <Status kind="kyc" value={u.kyc} />],
        ['Member since', fmtDate(u.joinedAt)],
        ['Paid withdrawals before', `${num(history.length)}${usual ? ` · usually ${naira(usual)}` : ''}`],
        ['Wallet after this', naira(u.balance)],
        ['Device', u.device],
      ]} />
      <h3 className="text-[13px] font-bold mt-6 mb-2">Latest activity</h3>
      <ul className="space-y-2.5">
        {txs.map((t) => (
          <li key={t.id} className="flex items-start justify-between gap-3 text-[13px]">
            <span className="min-w-0"><span className="block font-semibold truncate">{t.title}</span><span className="block text-[12px] text-faint">{fmtDateTime(t.createdAt)}</span></span>
            <TxAmount t={t} size={13} />
          </li>
        ))}
      </ul>
    </Drawer>
  )
}
