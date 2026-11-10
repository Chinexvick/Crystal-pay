import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import {
  ArrowCounterClockwiseIcon, ArrowDownLeftIcon, BankIcon, CoinsIcon, CreditCardIcon, CrownIcon, GiftIcon, PaperPlaneTiltIcon,
  ReceiptIcon, ShoppingBagIcon, StorefrontIcon, ArrowUpRightIcon, type Icon,
} from '@phosphor-icons/react'
import type { Tx, TxType } from '../data/types'
import { useDb } from '../lib/store'
import { fmtDateTime, naira } from '../lib/format'
import { Avatar, KV, Mono, cx } from './ui'
import { Status } from './status'
import { Drawer } from './overlays'
import type { Column } from './Table'

export const txTypes: Record<TxType, { label: string; icon: Icon }> = {
  funding_card: { label: 'Card funding', icon: CreditCardIcon },
  funding_transfer: { label: 'Bank transfer in', icon: BankIcon },
  funding_cct: { label: 'CCT deposit', icon: CoinsIcon },
  bill: { label: 'Bill payment', icon: ReceiptIcon },
  purchase: { label: 'Marketplace purchase', icon: ShoppingBagIcon },
  sale_release: { label: 'Sale payout', icon: StorefrontIcon },
  withdrawal: { label: 'Withdrawal', icon: ArrowUpRightIcon },
  transfer_out: { label: 'Sent money', icon: PaperPlaneTiltIcon },
  transfer_in: { label: 'Received money', icon: ArrowDownLeftIcon },
  refund: { label: 'Refund', icon: ArrowCounterClockwiseIcon },
  plan_fee: { label: 'Seller plan', icon: CrownIcon },
  referral: { label: 'Referral reward', icon: GiftIcon },
}

export function TxAmount({ t, size = 13.5 }: { t: Tx; size?: number }) {
  const dead = t.status === 'failed' || t.status === 'reversed'
  return (
    <span className={cx('num font-semibold whitespace-nowrap', dead && 'text-faint line-through decoration-1')} style={{ fontSize: size }}>
      {naira(t.direction === 'in' ? t.amount : -t.amount, { sign: true })}
    </span>
  )
}

export function TxType({ t }: { t: Tx }) {
  const def = txTypes[t.type]
  return (
    <span className="flex items-center gap-2.5 min-w-0">
      <span className="w-7 h-7 rounded-lg bg-[#f1eff6] text-ink-2 inline-flex items-center justify-center shrink-0">
        <def.icon size={15} />
      </span>
      <span className="min-w-0">
        <span className="block font-semibold truncate max-w-[280px]">{t.title}</span>
        <span className="block text-[12px] text-muted">{def.label}</span>
      </span>
    </span>
  )
}

export function useTxColumns(opts: { showUser?: boolean; showRef?: boolean } = {}): Column<Tx>[] {
  const db = useDb()
  const cols: Column<Tx>[] = [
    { key: 'what', header: 'Transaction', cell: (t) => <TxType t={t} /> },
  ]
  if (opts.showUser !== false) {
    cols.push({
      key: 'user', header: 'User',
      cell: (t) => {
        const u = db.users.find((x) => x.id === t.userId)
        return u ? (
          <span className="flex items-center gap-2 min-w-0">
            <Avatar name={u.name} src={u.avatar} size={24} />
            <span className="truncate">{u.name}</span>
          </span>
        ) : (
          t.userId
        )
      },
    })
  }
  if (opts.showRef !== false) cols.push({ key: 'ref', header: 'Reference', cell: (t) => <Mono className="text-ink-2">{t.id}</Mono> })
  cols.push(
    { key: 'amount', header: 'Amount', align: 'right', cell: (t) => <TxAmount t={t} /> },
    { key: 'status', header: 'Status', cell: (t) => <Status kind="tx" value={t.status} /> },
    { key: 'when', header: 'Date', cell: (t) => <span className="text-ink-2 whitespace-nowrap">{fmtDateTime(t.createdAt)}</span> },
  )
  return cols
}

export function TxDrawer({ tx, onClose }: { tx: Tx | null; onClose: () => void }) {
  const db = useDb()
  if (!tx) return null
  const u = db.users.find((x) => x.id === tx.userId)
  const net = tx.direction === 'in' ? tx.amount : tx.amount + tx.fee
  const bill = tx.type === 'bill' ? db.bills.find((b) => b.id === tx.id) : undefined
  const wd = tx.type === 'withdrawal' ? db.withdrawals.find((w) => w.id === tx.id) : undefined
  const order = tx.meta.Order
  return (
    <Drawer open onClose={onClose} title={tx.title} subtitle={<Mono copy>{tx.id}</Mono>}>
      <div className="flex items-end justify-between gap-4 mb-5">
        <div>
          <div className="text-[12.5px] text-muted mb-1">{txTypes[tx.type].label}</div>
          <TxAmount t={tx} size={28} />
        </div>
        <Status kind="tx" value={tx.status} />
      </div>
      <KV
        rows={[
          ['User', u ? <Link to={`/users/${u.id}`} className="text-brand hover:underline">{u.name}</Link> : tx.userId],
          ['Date', fmtDateTime(tx.createdAt)],
          ['Channel', tx.channel],
          ...(tx.fee ? ([['Fee', naira(tx.fee)], [tx.direction === 'in' ? 'Credited to wallet' : 'Total taken from wallet', naira(net)]] as [string, string][]) : []),
          ...Object.entries(tx.meta).map(([k, v]) => [k, k === 'Tx hash' ? <Mono copy={v}>{v.slice(0, 10) + '…' + v.slice(-6)}</Mono> : v] as [string, ReactNode]),
        ]}
      />
      <div className="mt-6 flex flex-wrap gap-2">
        {bill && <Link to={`/bills?id=${bill.id}`} className="text-[13px] font-semibold text-brand hover:underline">Open bill payment</Link>}
        {wd && <Link to={`/withdrawals?id=${wd.id}`} className="text-[13px] font-semibold text-brand hover:underline">Open withdrawal</Link>}
        {order && <Link to={`/orders?id=${order}`} className="text-[13px] font-semibold text-brand hover:underline">Open order {order}</Link>}
      </div>
    </Drawer>
  )
}
