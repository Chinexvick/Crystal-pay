import { useMemo, useState } from 'react'
import { BellRingingIcon, EnvelopeSimpleIcon, MegaphoneIcon, PaperPlaneTiltIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { useNow } from '../lib/queues'
import { T, fmtDateTime, num, pct } from '../lib/format'
import { Button, Card, Checkbox, Empty, Field, Input, PageHeader, Segmented, Select, Textarea } from '../components/ui'
import { DataTable, type Column } from '../components/Table'
import { Status } from '../components/status'
import { confirm, toast } from '../components/overlays'
import type { Announcement, Channel, User } from '../data/types'

export default function Announcements() {
  const db = useDb()
  const dispatch = useDispatch()
  const now = useNow()
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [aud, setAud] = useState('All users')
  const [channels, setChannels] = useState<Channel[]>(['push', 'in-app'])
  const [when, setWhen] = useState<'now' | 'later'>('now')
  const [at, setAt] = useState(() => new Date(now + 2 * T.HOUR - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16))

  const audiences = useMemo(() => {
    const live = db.users.filter((u) => u.status === 'active')
    const sellers = new Set(db.subscriptions.filter((s) => s.status === 'active').map((s) => s.userId))
    const renew = new Set(db.subscriptions.filter((s) => s.status === 'active' && s.renewsAt - now < 3 * T.DAY).map((s) => s.userId))
    const list: [string, (u: User) => boolean][] = [
      ['All users', () => true],
      ['People with a verified ID', (u) => u.kyc === 'verified'],
      ['Users without a verified ID', (u) => u.kyc !== 'verified'],
      ['Sellers with an active plan', (u) => sellers.has(u.id)],
      ['Sellers with a plan renewing in 3 days', (u) => renew.has(u.id)],
      ['People in Lagos', (u) => u.state === 'Lagos'],
      ['Inactive for 14 days', (u) => now - u.lastActiveAt > 14 * T.DAY],
    ]
    return list.map(([name, f]) => ({ name, count: live.filter(f).length }))
  }, [db, now])
  const reach = audiences.find((a) => a.name === aud)?.count ?? 0
  const valid = title.trim().length >= 3 && body.trim().length >= 10 && channels.length > 0 && reach > 0

  const send = async () => {
    const whenTs = when === 'now' ? 'now' : new Date(at).getTime()
    const ok = await confirm({ title: when === 'now' ? `Send to ${num(reach)} people now?` : `Schedule for ${fmtDateTime(whenTs as number)}?`, message: `${aud}, by ${channels.map((c) => (c === 'in-app' ? 'in-app message' : c)).join(' and ')}. A sent announcement cannot be called back.`, confirmLabel: when === 'now' ? 'Send now' : 'Schedule' })
    if (!ok) return
    dispatch({ t: 'announce/send', title: title.trim(), body: body.trim(), audience: aud, channels, when: whenTs, recipients: reach })
    toast(when === 'now' ? 'Announcement sent' : 'Announcement scheduled')
    setTitle('')
    setBody('')
  }

  const columns: Column<Announcement>[] = [
    { key: 't', header: 'Announcement', cell: (a) => <span className="min-w-0"><span className="block font-semibold truncate max-w-[320px]">{a.title}</span><span className="block text-[12px] text-muted truncate max-w-[320px]">{a.body}</span></span> },
    { key: 'aud', header: 'Audience', cell: (a) => <span className="text-ink-2">{a.audience}</span> },
    { key: 'ch', header: 'Channels', cell: (a) => <span className="text-ink-2">{a.channels.map((c) => (c === 'push' ? 'Push' : c === 'in-app' ? 'In-app' : 'Email')).join(', ')}</span> },
    { key: 's', header: 'Status', cell: (a) => <Status kind="announcement" value={a.status} /> },
    { key: 'when', header: 'When', cell: (a) => <span className="text-ink-2 whitespace-nowrap">{fmtDateTime(a.at)}</span> },
    { key: 'reach', header: 'Reach', align: 'right', cell: (a) => <span className="num">{num(a.recipients)}</span> },
    { key: 'open', header: 'Opened', align: 'right', cell: (a) => <span className="num text-ink-2">{a.status === 'sent' && a.recipients ? pct((a.opened / a.recipients) * 100, 0) : '—'}</span> },
  ]

  return (
    <>
      <PageHeader title="Announcements" description="Tell people about something new or something they need to do. Pick who gets it and how." />
      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_380px] gap-5 mb-8">
        <Card title="New announcement">
          <div className="space-y-4">
            <Field label="Title" hint={`${title.length}/50`}><Input maxLength={50} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Electricity tokens now arrive instantly" /></Field>
            <Field label="Message" hint={`${body.length}/160 · keep it to one clear action`}><Textarea maxLength={160} rows={3} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Buy a token and it shows on your screen in seconds. No more waiting for SMS." /></Field>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Field label="Who gets it" hint={`${num(reach)} people`}>
                <Select value={aud} onChange={(e) => setAud(e.target.value)}>{audiences.map((a) => <option key={a.name} value={a.name}>{a.name} ({num(a.count)})</option>)}</Select>
              </Field>
              <div>
                <span className="block text-[12.5px] font-semibold text-ink-2 mb-1.5">Send as</span>
                <div className="flex flex-wrap gap-4 h-9 items-center">
                  {(['push', 'in-app', 'email'] as Channel[]).map((c) => (
                    <label key={c} className="inline-flex items-center gap-2 text-[13.5px] cursor-pointer">
                      <Checkbox label={c} checked={channels.includes(c)} onChange={(v) => setChannels((x) => (v ? [...x, c] : x.filter((y) => y !== c)))} />
                      {c === 'push' ? 'Push' : c === 'in-app' ? 'In-app' : 'Email'}
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div className="flex flex-wrap items-end gap-3">
              <div>
                <span className="block text-[12.5px] font-semibold text-ink-2 mb-1.5">When</span>
                <Segmented label="When" value={when} onChange={setWhen} items={[{ value: 'now', label: 'Now' }, { value: 'later', label: 'Schedule' }]} />
              </div>
              {when === 'later' && <Input type="datetime-local" value={at} onChange={(e) => setAt(e.target.value)} className="w-auto" aria-label="Send at" />}
              <span className="flex-1" />
              <Button variant="primary" icon={PaperPlaneTiltIcon} disabled={!valid} onClick={send}>{when === 'now' ? 'Send announcement' : 'Schedule announcement'}</Button>
            </div>
          </div>
        </Card>
        <div className="space-y-4">
          <div className="rounded-[var(--radius-card)] p-5" style={{ background: 'linear-gradient(160deg,#2b0a85,#4511ba 60%,#6326e2)' }}>
            <div className="text-[11.5px] font-semibold text-white/70 mb-2 flex items-center gap-1.5"><BellRingingIcon size={14} /> Push notification</div>
            <div className="rounded-2xl bg-white/95 backdrop-blur px-3.5 py-3 shadow-[0_8px_24px_-8px_rgb(0_0_0/0.4)]">
              <div className="flex items-center gap-2 text-[11.5px] text-muted mb-1"><img src="/favicon.png" alt="" className="w-4 h-4 rounded" /> Crystal Pay · now</div>
              <div className="text-[13.5px] font-bold text-ink leading-snug">{title || 'Your title appears here'}</div>
              <div className="text-[13px] text-ink-2 leading-snug mt-0.5 line-clamp-3">{body || 'Your message appears here. Keep it short so it fits on the lock screen.'}</div>
            </div>
          </div>
          <div className="border border-line rounded-[var(--radius-card)] p-5">
            <div className="text-[11.5px] font-semibold text-muted mb-2 flex items-center gap-1.5"><EnvelopeSimpleIcon size={14} /> In the app’s notification list</div>
            <div className="flex gap-3">
              <span className="w-9 h-9 rounded-full bg-brand-tint text-brand inline-flex items-center justify-center shrink-0"><MegaphoneIcon size={18} weight="fill" /></span>
              <div className="min-w-0"><div className="text-[13.5px] font-bold leading-snug">{title || 'Your title'}</div><div className="text-[13px] text-muted leading-snug">{body || 'Your message'}</div></div>
            </div>
          </div>
        </div>
      </div>
      <h2 className="h-title text-[18px] mb-3">Sent and scheduled</h2>
      <DataTable columns={columns} rows={db.announcements} rowKey={(a) => a.id} empty={<Empty icon={MegaphoneIcon} title="Nothing sent yet" />} />
    </>
  )
}
