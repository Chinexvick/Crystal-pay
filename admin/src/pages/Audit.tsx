import { useMemo, useState } from 'react'
import { ClockCounterClockwiseIcon, DownloadSimpleIcon } from '@phosphor-icons/react'
import { useDb } from '../lib/store'
import { downloadCsv, fmtDateTime, num } from '../lib/format'
import { Avatar, Button, Empty, Mono, PageHeader, SearchInput, Select } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import type { AuditEntry } from '../data/types'

export default function Audit() {
  const db = useDb()
  const [q, setQ] = useState('')
  const [who, setWho] = useState('all')
  const [area, setArea] = useState('all')
  const people = [...new Set(db.audit.map((a) => a.by))].sort()
  const areas = [...new Set(db.audit.map((a) => a.area))].sort()
  const rows = useMemo(() => {
    const s = q.trim().toLowerCase()
    return db.audit.filter((a) => (who === 'all' || a.by === who) && (area === 'all' || a.area === area) && (!s || `${a.action} ${a.target} ${a.detail ?? ''}`.toLowerCase().includes(s)))
  }, [db.audit, q, who, area])

  const columns: Column<AuditEntry>[] = [
    { key: 'when', header: 'When', width: '170px', cell: (a) => <span className="text-ink-2 whitespace-nowrap">{fmtDateTime(a.at)}</span> },
    { key: 'who', header: 'Staff', cell: (a) => { const s = db.staff.find((x) => x.name === a.by); return <span className="flex items-center gap-2 min-w-0"><Avatar name={a.by} src={s?.avatar} size={24} /><span className="truncate font-semibold">{a.by}</span></span> } },
    { key: 'area', header: 'Area', cell: (a) => <span className="text-ink-2 whitespace-nowrap">{a.area}</span> },
    { key: 'what', header: 'Action', cell: (a) => <span className="min-w-0"><span className="block font-semibold">{a.action}</span><span className="block text-[12.5px] text-ink-2 truncate max-w-[380px]">{a.target}</span></span> },
    { key: 'detail', header: 'Details', cell: (a) => <span className="text-[12.5px] text-muted line-clamp-2 max-w-[280px]">{a.detail ?? '—'}</span> },
    { key: 'ip', header: 'IP address', cell: (a) => <Mono className="text-muted">{a.ip}</Mono> },
  ]

  return (
    <>
      <PageHeader
        title="Audit log"
        description="Every change made in this admin: who made it, when, and from where. Entries cannot be edited or deleted."
        actions={<Button icon={DownloadSimpleIcon} onClick={() => downloadCsv('crystal-pay-audit-log.csv', [['Time', 'Staff', 'Area', 'Action', 'Target', 'Details', 'IP'], ...rows.map((a) => [new Date(a.at).toISOString(), a.by, a.area, a.action, a.target, a.detail ?? '', a.ip])])}>Export CSV</Button>}
      />
      <div className="flex flex-wrap items-center gap-2.5 mb-4">
        <SearchInput value={q} onChange={setQ} placeholder="Search actions, names, references" className="w-full sm:w-[300px]" />
        <Select value={who} onChange={(e) => setWho(e.target.value)} aria-label="Staff" className="w-auto"><option value="all">All staff</option>{people.map((p) => <option key={p}>{p}</option>)}</Select>
        <Select value={area} onChange={(e) => setArea(e.target.value)} aria-label="Area" className="w-auto"><option value="all">All areas</option>{areas.map((p) => <option key={p}>{p}</option>)}</Select>
        <span className="text-[12.5px] text-muted ml-auto">{num(rows.length)} entries</span>
      </div>
      <DataTable columns={columns} rows={rows} rowKey={(a) => a.id} empty={<Empty icon={ClockCounterClockwiseIcon} title="No entries match" />} />
    </>
  )
}
