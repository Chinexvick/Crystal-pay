import { useState } from 'react'
import { CheckIcon, EyeIcon, ShieldCheckIcon, UserPlusIcon, WarningIcon } from '@phosphor-icons/react'
import { useDb, useDispatch, useMe, roleNames } from '../lib/store'
import { useNow } from '../lib/queues'
import { timeAgo } from '../lib/format'
import { Avatar, Button, Field, Input, PageHeader, Pill, Select, Tabs } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import { Modal, confirm, toast } from '../components/overlays'
import type { RoleKey, Staff as StaffT } from '../data/types'

const roleHelp: Record<RoleKey, string> = {
  super_admin: 'Everything, including staff, rates and fees',
  operations: 'Listings, orders, disputes, banners and announcements',
  compliance: 'ID checks, account freezes and reports',
  finance: 'Withdrawals, CCT deposits, refunds and fees',
  support: 'Support chats; can view users and transactions',
  viewer: 'Can look at everything, change nothing',
}

const areas = ['Users and accounts', 'Verifications', 'Listings and reports', 'Orders and disputes', 'Transactions and refunds', 'Withdrawals', 'CCT deposits', 'Rates and fees', 'Banners and announcements', 'Support chats', 'Staff and roles']
const roles: RoleKey[] = ['super_admin', 'operations', 'compliance', 'finance', 'support', 'viewer']
// M = manage, V = view, - = no access
const matrix: Record<RoleKey, string> = {
  super_admin: 'MMMMMMMMMMM',
  operations: 'VVMMVVVVMVV',
  compliance: 'MMMVVVVV-V-',
  finance: 'VVVVMMMMVV-',
  support: 'VVVVV---VM-',
  viewer: 'VVVVVVVVVV-',
}

export default function Staff() {
  const db = useDb()
  const dispatch = useDispatch()
  const me = useMe()
  const now = useNow()
  const [tab, setTab] = useState<'people' | 'roles'>('people')
  const [invite, setInvite] = useState(false)

  const columns: Column<StaffT>[] = [
    { key: 'who', header: 'Person', cell: (s) => <span className="flex items-center gap-3 min-w-0"><Avatar name={s.name} src={s.avatar} size={32} /><span className="min-w-0"><span className="block font-semibold truncate">{s.name}{s.id === me.id && <span className="text-muted font-medium"> (you)</span>}</span><span className="block text-[12.5px] text-muted truncate">{s.email}</span></span></span> },
    {
      key: 'role', header: 'Role',
      cell: (s) => s.id === me.id ? <span className="font-semibold">{roleNames[s.role]}</span> : (
        <Select aria-label={`Role for ${s.name}`} value={s.role} onClick={(e) => e.stopPropagation()} onChange={async (e) => {
          const role = e.target.value as RoleKey
          const ok = await confirm({ title: `Make ${s.name} ${roleNames[role]}?`, message: roleHelp[role] + '.', confirmLabel: 'Change role' })
          if (ok) { dispatch({ t: 'staff/role', id: s.id, role }); toast('Role changed') }
        }} className="w-auto h-8 text-[12.5px]">
          {roles.map((r) => <option key={r} value={r}>{roleNames[r]}</option>)}
        </Select>
      ),
    },
    { key: '2fa', header: 'Two-step sign-in', cell: (s) => (s.twoStep ? <Pill tone="ok" icon={ShieldCheckIcon}>On</Pill> : <Pill tone="warn" icon={WarningIcon}>Off</Pill>) },
    { key: 'last', header: 'Last active', cell: (s) => <span className="text-ink-2">{s.status === 'invited' ? 'Not joined yet' : timeAgo(s.lastActiveAt, now)}</span> },
    { key: 'status', header: 'Access', cell: (s) => <Status kind="staff" value={s.status} /> },
    {
      key: 'act', header: '', align: 'right',
      cell: (s) => s.id === me.id ? null : s.status === 'disabled' ? (
        <Button size="sm" onClick={() => { dispatch({ t: 'staff/status', id: s.id, status: 'active' }); toast('Access turned on') }}>Turn on access</Button>
      ) : (
        <Button size="sm" variant="danger-soft" onClick={async () => {
          const invited = s.status === 'invited'
          const ok = await confirm({ title: invited ? `Cancel ${s.name}’s invite?` : `Turn off ${s.name}’s access?`, message: invited ? 'The link in their email stops working. You can invite them again later.' : 'They are signed out everywhere straight away. Their past actions stay in the audit log.', confirmLabel: invited ? 'Cancel invite' : 'Turn off access', tone: 'danger' })
          if (ok) { dispatch({ t: 'staff/status', id: s.id, status: 'disabled' }); toast(invited ? 'Invite cancelled' : 'Access turned off') }
        }}>{s.status === 'invited' ? 'Cancel invite' : 'Turn off access'}</Button>
      ),
    },
  ]

  return (
    <>
      <PageHeader title="Staff and roles" description="Who can sign in to this admin and what they can change. Give each person the smallest role that lets them do their job." actions={<Button variant="primary" icon={UserPlusIcon} onClick={() => setInvite(true)}>Invite staff</Button>} />
      <Tabs value={tab} onChange={setTab} items={[{ value: 'people', label: 'People', count: db.staff.length }, { value: 'roles', label: 'What each role can do' }]} />
      {tab === 'people' ? (
        <DataTable columns={columns} rows={db.staff} rowKey={(s) => s.id} />
      ) : (
        <div className="border border-line rounded-[var(--radius-card)] overflow-x-auto">
          <table className="w-full text-[13px]">
            <thead>
              <tr className="bg-sunken border-b border-line">
                <th className="text-left font-semibold text-muted text-[12px] px-5 h-10">Area</th>
                {roles.map((r) => <th key={r} className="font-semibold text-[12.5px] px-3 text-center whitespace-nowrap">{roleNames[r]}</th>)}
              </tr>
            </thead>
            <tbody>
              {areas.map((a, i) => (
                <tr key={a} className="border-b border-line-2 last:border-b-0">
                  <td className="px-5 h-11 font-semibold">{a}</td>
                  {roles.map((r) => {
                    const c = matrix[r][i]
                    return (
                      <td key={r} className="text-center">
                        {c === 'M' ? <span className="inline-flex items-center gap-1 text-[12px] font-semibold text-brand"><CheckIcon size={14} weight="bold" />Change</span> : c === 'V' ? <span className="inline-flex items-center gap-1 text-[12px] text-muted"><EyeIcon size={14} />View</span> : <span className="text-faint">—</span>}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
          <p className="px-5 py-3.5 text-[12.5px] text-muted border-t border-line bg-sunken">Once the backend is connected, any single payout, refund or balance change above ₦500,000 will need a second person to approve it.</p>
        </div>
      )}
      {invite && <Invite onClose={() => setInvite(false)} />}
    </>
  )
}

function Invite({ onClose }: { onClose: () => void }) {
  const dispatch = useDispatch()
  const db = useDb()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<RoleKey>('support')
  const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
  const taken = db.staff.some((s) => s.email === email.trim().toLowerCase())
  const valid = name.trim().length >= 3 && emailOk && !taken
  return (
    <Modal open onClose={onClose} title="Invite staff" footer={<><Button onClick={onClose}>Cancel</Button><Button variant="primary" disabled={!valid} onClick={() => { dispatch({ t: 'staff/invite', name: name.trim(), email: email.trim().toLowerCase(), role }); toast(`Invite sent to ${email.trim()}`); onClose() }}>Send invite</Button></>}>
      <div className="space-y-3">
        <Field label="Full name"><Input value={name} onChange={(e) => setName(e.target.value)} autoFocus /></Field>
        <Field label="Work email" error={taken ? 'This person is already on the staff list' : undefined}><Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@crystalpay.app" /></Field>
        <Field label="Role" hint={roleHelp[role]}><Select value={role} onChange={(e) => setRole(e.target.value as RoleKey)}>{roles.map((r) => <option key={r} value={r}>{roleNames[r]}</option>)}</Select></Field>
      </div>
      <p className="text-[12.5px] text-muted mt-4">They set their password and two-step sign-in from the email. The invite expires in 48 hours.</p>
    </Modal>
  )
}
