import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { ArrowsLeftRightIcon, DownloadSimpleIcon } from '@phosphor-icons/react'
import { useDb } from '../lib/store'
import { useNow } from '../lib/queues'
import { T, downloadCsv, naira, num } from '../lib/format'
import { Button, Empty, PageHeader, SearchInput, Segmented, Select } from '../components/ui'
import { DataTable } from '../components/Table'
import { TxDrawer, txTypes, useTxColumns } from '../components/tx'
import type { TxType } from '../data/types'

export default function Transactions() {
  const db = useDb()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const [q, setQ] = useState('')
  const [type, setType] = useState<'all' | TxType>('all')
  const [status, setStatus] = useState('all')
  const [range, setRange] = useState<'1' | '7' | '30' | '90'>('7')
  const columns = useTxColumns()

  const rows = useMemo(() => {
    const start = range === '1' ? new Date(now).setHours(0, 0, 0, 0) : now - Number(range) * T.DAY
    const s = q.trim().toLowerCase()
    const users = s ? new Set(db.users.filter((u) => u.name.toLowerCase().includes(s) || u.username.includes(s.replace('@', ''))).map((u) => u.id)) : null
    return db.txs.filter((t) => {
      if (t.createdAt < start) return false
      if (type !== 'all' && t.type !== type) return false
      if (status !== 'all' && t.status !== status) return false
      if (s && !(t.id.toLowerCase().includes(s) || users!.has(t.userId) || t.title.toLowerCase().includes(s))) return false
      return true
    })
  }, [db, q, type, status, range, now])

  const sum = useMemo(() => {
    let inn = 0
    let out = 0
    let fees = 0
    for (const t of rows) {
      if (t.status !== 'successful') continue
      if (t.direction === 'in') inn += t.amount
      else out += t.amount
      fees += t.fee
    }
    return { inn, out, fees }
  }, [rows])

  const open = db.txs.find((t) => t.id === params.get('id')) ?? null

  return (
    <>
      <PageHeader
        title="Transactions"
        description="Every movement of money in and out of Crystal Pay wallets. Open one to see its full record."
        actions={<Button icon={DownloadSimpleIcon} onClick={() => downloadCsv('crystal-pay-transactions.csv', [['Reference', 'User ID', 'Type', 'Direction', 'Amount (NGN)', 'Fee (NGN)', 'Status', 'Channel', 'Date'], ...rows.map((t) => [t.id, t.userId, txTypes[t.type].label, t.direction, t.amount, t.fee, t.status, t.channel, new Date(t.createdAt).toISOString()])])}>Export CSV</Button>}
      />
      <div className="flex flex-wrap items-center gap-2.5 mb-4">
        <Segmented label="Date range" value={range} onChange={setRange} items={[{ value: '1', label: 'Today' }, { value: '7', label: '7 days' }, { value: '30', label: '30 days' }, { value: '90', label: '90 days' }]} />
        <SearchInput value={q} onChange={setQ} placeholder="Reference or name" className="w-full sm:w-[260px]" />
        <Select value={type} onChange={(e) => setType(e.target.value as 'all' | TxType)} aria-label="Type" className="w-auto">
          <option value="all">All types</option>
          {Object.entries(txTypes).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
        </Select>
        <Select value={status} onChange={(e) => setStatus(e.target.value)} aria-label="Status" className="w-auto">
          <option value="all">Any status</option>
          <option value="successful">Successful</option>
          <option value="pending">Pending</option>
          <option value="failed">Failed</option>
          <option value="reversed">Reversed</option>
        </Select>
      </div>
      <div className="grid grid-cols-2 lg:grid-cols-4 border border-line rounded-[var(--radius-card)] mb-4 divide-x divide-line overflow-hidden">
        <Fig label="Transactions" value={num(rows.length)} />
        <Fig label="Money in" value={naira(sum.inn)} />
        <Fig label="Money out" value={naira(sum.out)} />
        <Fig label="Fees charged" value={naira(sum.fees)} />
      </div>
      <DataTable columns={columns} rows={rows} rowKey={(t) => t.id} activeKey={open?.id} onRowClick={(t) => setParams({ id: t.id }, { replace: true })} empty={<Empty icon={ArrowsLeftRightIcon} title="No transactions match">Try a longer date range or clear the filters.</Empty>} />
      <TxDrawer tx={open} onClose={() => setParams({}, { replace: true })} />
    </>
  )
}

function Fig({ label, value }: { label: string; value: string }) {
  return (
    <div className="px-5 py-3.5 bg-surface">
      <div className="text-[12px] text-muted">{label}</div>
      <div className="text-[17px] font-bold num tracking-[-0.01em] mt-0.5">{value}</div>
    </div>
  )
}
