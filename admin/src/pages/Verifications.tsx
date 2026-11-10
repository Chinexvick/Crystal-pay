import { useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { CheckCircleIcon, UserIcon, WarningCircleIcon, WarningIcon, XCircleIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { SLA, useNow } from '../lib/queues'
import { fmtDateTime, maskId, timeAgo } from '../lib/format'
import { Avatar, Button, Empty, Kbd, PageHeader, Tabs, cx } from '../components/ui'
import { Meter } from '../components/Charts'
import { Status } from '../components/status'
import { Wait } from '../components/Wait'
import { confirm, toast } from '../components/overlays'
import type { Verification } from '../data/types'

const rejectReasons = ['Name does not match the ID record', 'Photo does not match the ID record', 'Selfie failed the liveness check', 'Document image is unreadable', 'ID is linked to another account', 'Other']

export default function Verifications() {
  const db = useDb()
  const dispatch = useDispatch()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const [tab, setTab] = useState<'pending' | 'approved' | 'rejected'>('pending')

  const lists = useMemo(() => {
    const pending = db.verifications.filter((v) => v.status === 'pending').sort((a, b) => a.submittedAt - b.submittedAt)
    const approved = db.verifications.filter((v) => v.status === 'approved').sort((a, b) => (b.reviewedAt ?? 0) - (a.reviewedAt ?? 0))
    const rejected = db.verifications.filter((v) => v.status === 'rejected').sort((a, b) => (b.reviewedAt ?? 0) - (a.reviewedAt ?? 0))
    return { pending, approved, rejected }
  }, [db.verifications])
  const list = lists[tab]
  const selId = params.get('id') ?? list[0]?.id
  const sel = db.verifications.find((v) => v.id === selId) ?? list[0]

  useEffect(() => {
    const v = db.verifications.find((x) => x.id === params.get('id'))
    if (v && v.status !== tab) setTab(v.status)
  }, [])

  const select = (v?: Verification) => setParams(v ? { id: v.id } : {}, { replace: true })
  const nextAfter = (v: Verification) => {
    const i = lists.pending.findIndex((x) => x.id === v.id)
    return lists.pending[i + 1] ?? lists.pending[i - 1]
  }

  const approve = (v: Verification) => {
    const next = nextAfter(v)
    dispatch({ t: 'kyc/approve', id: v.id })
    toast(`${db.users.find((u) => u.id === v.userId)?.name} is verified`)
    select(next)
  }
  const reject = async (v: Verification) => {
    const r = await confirm({ title: 'Reject this ID?', message: 'The user is told why and can submit a new ID straight away.', confirmLabel: 'Reject ID', tone: 'danger', reason: { label: 'Reason the user will see', options: rejectReasons } })
    if (!r) return
    const next = nextAfter(v)
    dispatch({ t: 'kyc/reject', id: v.id, reason: r.reason })
    toast('ID rejected')
    select(next)
  }

  useEffect(() => {
    if (!sel || sel.status !== 'pending') return
    const h = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement
      if (el.closest('input, textarea, select, [role="dialog"]')) return
      if (e.key === 'a' || e.key === 'A') approve(sel)
      if (e.key === 'r' || e.key === 'R') reject(sel)
    }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  })

  return (
    <>
      <PageHeader title="Verifications" description="Compare each person with their ID record before you approve. Approved people get the blue tick and the higher send limit." />
      <Tabs
        value={tab}
        onChange={(t) => { setTab(t); setParams({}, { replace: true }) }}
        items={[
          { value: 'pending', label: 'Waiting', count: lists.pending.length, alert: true },
          { value: 'approved', label: 'Approved', count: lists.approved.length },
          { value: 'rejected', label: 'Rejected', count: lists.rejected.length },
        ]}
      />
      {list.length === 0 ? (
        <div className="bg-surface border border-line rounded-[var(--radius-card)]"><Empty icon={CheckCircleIcon} title="No IDs waiting">New submissions appear here as soon as someone uploads their ID in the app.</Empty></div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-[340px_minmax(0,1fr)] gap-5 items-start">
          <ul className="bg-surface border border-line rounded-[var(--radius-card)] overflow-hidden max-h-[calc(100vh-250px)] overflow-y-auto">
            {list.slice(0, 80).map((v) => {
              const u = db.users.find((x) => x.id === v.userId)!
              const on = sel?.id === v.id
              return (
                <li key={v.id} className="border-b border-line-2 last:border-b-0">
                  <button type="button" onClick={() => select(v)} className={cx('w-full flex items-center gap-3 px-4 py-3 text-left transition-colors', on ? 'bg-brand-tint/70' : 'hover:bg-hover')}>
                    <Avatar name={u.name} src={u.avatar} size={36} />
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center gap-1.5">
                        <span className="font-semibold text-[13.5px] truncate">{u.name}</span>
                        {v.signals.length > 0 && <WarningIcon size={14} weight="fill" className="text-warn-mark shrink-0" aria-label="Needs a closer look" />}
                      </span>
                      <span className="block text-[12px] text-muted">{v.idType} · {tab === 'pending' ? `sent ${timeAgo(v.submittedAt, now)}` : `${v.reviewedBy} · ${timeAgo(v.reviewedAt ?? v.submittedAt, now)}`}</span>
                    </span>
                    {tab === 'pending' && <Wait since={v.submittedAt} sla={SLA.kyc} width={36} />}
                  </button>
                </li>
              )
            })}
          </ul>
          {sel && <Review key={sel.id} v={sel} onApprove={() => approve(sel)} onReject={() => reject(sel)} />}
        </div>
      )}
    </>
  )
}

function Review({ v, onApprove, onReject }: { v: Verification; onApprove: () => void; onReject: () => void }) {
  const db = useDb()
  const u = db.users.find((x) => x.id === v.userId)!
  const faceTone = v.faceScore >= 85 ? 'ok' : v.faceScore >= 70 ? 'warn' : 'bad'
  const nameRes = v.nameMatch === 'match' ? 'ok' : v.nameMatch === 'partial' ? 'warn' : 'bad'
  return (
    <section className="bg-surface border border-line rounded-[var(--radius-card)]">
      <header className="flex flex-wrap items-center gap-3 px-6 py-4 border-b border-line">
        <Avatar name={u.name} src={u.avatar} size={44} />
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2"><h2 className="h-title text-[18px]">{u.name}</h2><Status kind="verification" value={v.status} /></div>
          <div className="text-[12.5px] text-muted">@{u.username} · {u.phone} · sent {fmtDateTime(v.submittedAt)}</div>
        </div>
        <Link to={`/users/${u.id}`} className="text-[13px] font-semibold text-brand hover:underline">Open profile</Link>
      </header>

      <div className="p-6 space-y-6">
        <div className="grid grid-cols-[150px_150px] gap-4">
          <Photo label="Selfie taken in the app" src={u.avatar} name={u.name} />
          <Photo label={`Photo on the ${v.idType} record`} />
        </div>

        <div className="max-w-[316px]">
          <div className="flex items-center justify-between mb-1.5 text-[13px]">
            <span className="font-semibold">Face match</span>
            <span className="num font-bold">{v.faceScore}%</span>
          </div>
          <Meter value={v.faceScore / 100} tone={faceTone} />
          <p className="text-[12px] text-muted mt-1.5">85% or more is a strong match. Below 70%, reject unless you can confirm on a video call.</p>
        </div>

        <div>
          <h3 className="text-[13.5px] font-bold mb-2">Details against the ID record</h3>
          <div className="border border-line rounded-xl overflow-hidden">
            <table className="w-full text-[13px]">
              <thead>
                <tr className="bg-sunken text-[12px] text-muted"><th className="text-left font-semibold px-4 h-8"></th><th className="text-left font-semibold px-4">On Crystal Pay</th><th className="text-left font-semibold px-4">On the ID record</th><th className="px-4 w-28"></th></tr>
              </thead>
              <tbody>
                <Cmp field="Name" ours={u.name} theirs={v.recordName} res={nameRes} label={v.nameMatch === 'match' ? 'Match' : v.nameMatch === 'partial' ? 'Partly' : 'No match'} />
                <Cmp field="Date of birth" ours={u.dob} theirs={v.recordDob} res={v.dobMatch ? 'ok' : 'bad'} label={v.dobMatch ? 'Match' : 'No match'} />
                <Cmp field={v.idType} ours="—" theirs={maskId(v.idType, v.idNumber)} res="ok" label="Found" mono />
                <Cmp field="Liveness" ours="—" theirs={v.liveness ? 'Passed' : 'Failed'} res={v.liveness ? 'ok' : 'bad'} label={v.liveness ? 'Passed' : 'Failed'} />
              </tbody>
            </table>
          </div>
        </div>

        {v.signals.length > 0 && (
          <div className="rounded-xl bg-warn-tint/70 border border-[#f6dcb0] px-4 py-3">
            <div className="flex items-center gap-1.5 text-[13px] font-bold text-warn mb-1"><WarningIcon size={16} weight="fill" /> Look closer</div>
            <ul className="text-[13px] text-ink-2 list-disc pl-5 space-y-0.5">{v.signals.map((s) => <li key={s}>{s}</li>)}</ul>
          </div>
        )}
        {v.status === 'rejected' && <p className="text-[13px] text-bad flex gap-1.5"><XCircleIcon size={16} className="mt-0.5" /> Rejected by {v.reviewedBy}: {v.rejectReason}</p>}
        {v.status === 'approved' && <p className="text-[13px] text-ok flex gap-1.5"><CheckCircleIcon size={16} className="mt-0.5" /> Approved by {v.reviewedBy} on {fmtDateTime(v.reviewedAt ?? v.submittedAt)}</p>}
      </div>

      {v.status === 'pending' && (
        <footer className="flex flex-wrap items-center gap-2 px-6 py-4 border-t border-line bg-sunken rounded-b-[var(--radius-card)]">
          <span className="text-[12px] text-muted flex items-center gap-1.5 mr-auto"><Kbd>A</Kbd> approve <Kbd>R</Kbd> reject</span>
          <Button variant="danger-soft" icon={XCircleIcon} onClick={onReject}>Reject</Button>
          <Button variant="primary" icon={CheckCircleIcon} onClick={onApprove}>Approve ID</Button>
        </footer>
      )}
    </section>
  )
}

function Photo({ label, src, name }: { label: string; src?: string; name?: string }) {
  return (
    <figure>
      <div className="aspect-[4/5] rounded-xl overflow-hidden bg-[#f1eff6] border border-line-2 flex items-center justify-center">
        {src ? <img src={src} alt="" className="w-full h-full object-cover" /> : (
          <div className="text-center px-4">
            {name ? <Avatar name={name} size={72} /> : <UserIcon size={56} className="text-[#c9c3da] mx-auto" />}
            <p className="text-[11.5px] text-muted mt-2 leading-snug">{name ? 'No selfie image in demo data' : 'Shown once the ID provider is connected'}</p>
          </div>
        )}
      </div>
      <figcaption className="text-[12px] text-muted mt-1.5">{label}</figcaption>
    </figure>
  )
}

function Cmp({ field, ours, theirs, res, label, mono }: { field: string; ours: string; theirs: string; res: 'ok' | 'warn' | 'bad'; label: string; mono?: boolean }) {
  const I = res === 'ok' ? CheckCircleIcon : res === 'warn' ? WarningIcon : WarningCircleIcon
  return (
    <tr className="border-t border-line-2">
      <td className="px-4 h-10 text-muted whitespace-nowrap">{field}</td>
      <td className="px-4 font-semibold">{ours}</td>
      <td className={cx('px-4 font-semibold', mono && 'mono')}>{theirs}</td>
      <td className="px-4">
        <span className={cx('inline-flex items-center gap-1 text-[12.5px] font-semibold', res === 'ok' ? 'text-ok' : res === 'warn' ? 'text-warn' : 'text-bad')}>
          <I size={14} weight="fill" /> {label}
        </span>
      </td>
    </tr>
  )
}

