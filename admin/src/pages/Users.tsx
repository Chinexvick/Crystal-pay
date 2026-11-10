import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { DownloadSimpleIcon, UsersIcon } from '@phosphor-icons/react'
import { useDb } from '../lib/store'
import { useNow } from '../lib/queues'
import { downloadCsv, fmtDate, naira, num, timeAgo } from '../lib/format'
import { Avatar, Button, Empty, PageHeader, SearchInput, Select } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import type { User } from '../data/types'

export const planName = { none: '—', basic: 'Basic', pro: 'Pro', business: 'Business' } as const

export default function Users() {
  const db = useDb()
  const now = useNow()
  const nav = useNavigate()
  const [q, setQ] = useState('')
  const [kyc, setKyc] = useState('all')
  const [status, setStatus] = useState('all')
  const [plan, setPlan] = useState('all')

  const rows = useMemo(() => {
    const s = q.trim().toLowerCase()
    const digits = s.replace(/\D/g, '')
    return db.users
      .filter((u) => {
        if (kyc !== 'all' && u.kyc !== kyc) return false
        if (status !== 'all' && u.status !== status) return false
        if (plan !== 'all' && u.plan !== plan) return false
        if (!s) return true
        return u.name.toLowerCase().includes(s) || u.username.includes(s.replace('@', '')) || u.email.includes(s) || u.id.toLowerCase().includes(s) || (digits.length >= 3 && u.phone.replace(/\D/g, '').includes(digits))
      })
      .sort((a, b) => b.joinedAt - a.joinedAt)
  }, [db.users, q, kyc, status, plan])

  const verified = db.users.filter((u) => u.kyc === 'verified').length
  const frozen = db.users.filter((u) => u.status === 'frozen').length

  const columns: Column<User>[] = [
    {
      key: 'person', header: 'Person',
      cell: (u) => (
        <span className="flex items-center gap-3 min-w-0">
          <Avatar name={u.name} src={u.avatar} size={32} verified={u.kyc === 'verified'} />
          <span className="min-w-0">
            <span className="block font-semibold truncate">{u.name}</span>
            <span className="block text-[12.5px] text-muted truncate">@{u.username}</span>
          </span>
        </span>
      ),
    },
    { key: 'phone', header: 'Phone', cell: (u) => <span className="num text-ink-2 whitespace-nowrap">{u.phone}</span> },
    { key: 'kyc', header: 'ID check', cell: (u) => <Status kind="kyc" value={u.kyc} /> },
    { key: 'wallet', header: 'Wallet', align: 'right', cell: (u) => <span className="num font-semibold">{naira(u.balance)}</span> },
    { key: 'plan', header: 'Seller plan', cell: (u) => <span className={u.plan === 'none' ? 'text-faint' : 'font-semibold'}>{planName[u.plan]}</span> },
    { key: 'joined', header: 'Joined', cell: (u) => <span className="text-ink-2 whitespace-nowrap">{fmtDate(u.joinedAt)}</span> },
    { key: 'active', header: 'Last seen', cell: (u) => <span className="text-ink-2 whitespace-nowrap">{timeAgo(u.lastActiveAt, now)}</span> },
    { key: 'status', header: 'Account', cell: (u) => <Status kind="user" value={u.status} /> },
  ]

  return (
    <>
      <PageHeader
        title="Users"
        description={`${num(db.users.length)} people · ${num(verified)} with a verified ID · ${frozen} frozen`}
        actions={
          <Button
            icon={DownloadSimpleIcon}
            onClick={() => downloadCsv('crystal-pay-users.csv', [['ID', 'Name', 'Username', 'Email', 'Phone', 'City', 'State', 'ID check', 'Wallet (NGN)', 'Seller plan', 'Joined', 'Account'], ...rows.map((u) => [u.id, u.name, u.username, u.email, u.phone, u.city, u.state, u.kyc, u.balance, u.plan, new Date(u.joinedAt).toISOString(), u.status])])}
          >
            Export CSV
          </Button>
        }
      />
      <div className="flex flex-wrap items-center gap-2.5 mb-4">
        <SearchInput value={q} onChange={setQ} placeholder="Name, @username, email or phone" className="w-full sm:w-[320px]" />
        <Select value={kyc} onChange={(e) => setKyc(e.target.value)} aria-label="ID check" className="w-auto">
          <option value="all">Any ID check</option>
          <option value="verified">Verified</option>
          <option value="pending">Pending</option>
          <option value="unverified">Not verified</option>
          <option value="rejected">Rejected</option>
        </Select>
        <Select value={status} onChange={(e) => setStatus(e.target.value)} aria-label="Account status" className="w-auto">
          <option value="all">Any account status</option>
          <option value="active">Active</option>
          <option value="frozen">Frozen</option>
          <option value="closed">Closed</option>
        </Select>
        <Select value={plan} onChange={(e) => setPlan(e.target.value)} aria-label="Seller plan" className="w-auto">
          <option value="all">Any seller plan</option>
          <option value="none">No plan</option>
          <option value="basic">Basic</option>
          <option value="pro">Pro</option>
          <option value="business">Business</option>
        </Select>
        <span className="text-[12.5px] text-muted ml-auto">{num(rows.length)} shown</span>
      </div>
      <DataTable columns={columns} rows={rows} rowKey={(u) => u.id} onRowClick={(u) => nav(`/users/${u.id}`)} empty={<Empty icon={UsersIcon} title="No one matches">Try a different name, phone number or filter.</Empty>} />
    </>
  )
}
