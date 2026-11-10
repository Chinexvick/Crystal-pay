import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { ChatsCircleIcon, CheckCircleIcon, LockSimpleIcon, PaperPlaneTiltIcon, RobotIcon } from '@phosphor-icons/react'
import { useDb, useDispatch, useMe } from '../lib/store'
import { SLA, useNow } from '../lib/queues'
import { fmtTime, naira, timeAgo } from '../lib/format'
import { Avatar, Button, Empty, KV, Select, Tabs, Textarea, cx } from '../components/ui'
import { Status } from '../components/status'
import { Wait } from '../components/Wait'
import { TxAmount } from '../components/tx'
import { toast } from '../components/overlays'
import type { Conversation } from '../data/types'

const quick = [
  'Thanks for reaching out. I’m checking this now and will update you shortly.',
  'Please share the transaction reference from Transactions so I can find it quickly.',
  'I have refunded the amount to your wallet. You should see it now.',
  'Your ID is in the review queue. Most checks finish within 24 hours.',
]

export default function Support() {
  const db = useDb()
  const now = useNow()
  const [params, setParams] = useSearchParams()
  const [tab, setTab] = useState<'open' | 'pending' | 'solved'>('open')
  const lists = useMemo(() => {
    const by = (s: Conversation['status']) => db.conversations.filter((c) => c.status === s)
    return {
      open: by('open').sort((a, b) => (a.waitingSince ?? a.updatedAt) - (b.waitingSince ?? b.updatedAt)),
      pending: by('pending').sort((a, b) => b.updatedAt - a.updatedAt),
      solved: by('solved').sort((a, b) => b.updatedAt - a.updatedAt),
    }
  }, [db.conversations])
  const list = lists[tab]
  const sel = db.conversations.find((c) => c.id === params.get('id')) ?? list[0]

  return (
    <>
      <div className="flex flex-wrap items-end gap-4 mb-5">
        <div className="flex-1">
          <h1 className="h-title text-[26px] leading-tight">Support</h1>
          <p className="text-[13.5px] text-muted mt-1.5">Chats from the Help screen in the app. Reply within an hour; the oldest wait is at the top.</p>
        </div>
      </div>
      <Tabs value={tab} onChange={(t) => { setTab(t); setParams({}, { replace: true }) }} items={[{ value: 'open', label: 'Waiting on us', count: lists.open.length, alert: true }, { value: 'pending', label: 'Waiting on user', count: lists.pending.length }, { value: 'solved', label: 'Solved', count: lists.solved.length }]} />
      {!sel ? (
        <div className="bg-surface border border-line rounded-[var(--radius-card)]"><Empty icon={ChatsCircleIcon} title="Inbox zero">Nobody is waiting for a reply.</Empty></div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-[290px_minmax(0,1fr)] xl:grid-cols-[280px_minmax(0,1fr)_270px] gap-4 items-start">
          <ul className="bg-surface border border-line rounded-[var(--radius-card)] overflow-hidden">
            {list.length === 0 && <li className="px-4 py-10 text-center text-[13px] text-muted">Nothing here.</li>}
            {list.map((c) => {
              const u = db.users.find((x) => x.id === c.userId)!
              const last = c.messages[c.messages.length - 1]
              const on = sel.id === c.id
              return (
                <li key={c.id} className="border-b border-line-2 last:border-b-0">
                  <button type="button" onClick={() => setParams({ id: c.id }, { replace: true })} className={cx('w-full flex gap-3 px-4 py-3 text-left transition-colors', on ? 'bg-brand-tint/70' : 'hover:bg-hover')}>
                    <Avatar name={u.name} src={u.avatar} size={34} />
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2"><span className="font-semibold text-[13.5px] truncate">{u.name}</span><span className="text-[11.5px] text-faint shrink-0">{timeAgo(c.updatedAt, now)}</span></span>
                      <span className="block text-[12.5px] font-semibold text-ink-2 truncate">{c.subject}</span>
                      <span className="block text-[12px] text-muted truncate">{last.from === 'agent' ? 'You: ' : ''}{last.text}</span>
                      {c.status === 'open' && <span className="block mt-1.5"><Wait since={c.waitingSince ?? c.updatedAt} sla={SLA.support} width={40} /></span>}
                    </span>
                  </button>
                </li>
              )
            })}
          </ul>
          <Thread key={sel.id} c={sel} />
          <Context c={sel} />
        </div>
      )}
    </>
  )
}

function Thread({ c }: { c: Conversation }) {
  const db = useDb()
  const dispatch = useDispatch()
  const me = useMe()
  const [text, setText] = useState('')
  const [mode, setMode] = useState<'reply' | 'note'>('reply')
  const end = useRef<HTMLDivElement>(null)
  const u = db.users.find((x) => x.id === c.userId)!
  useEffect(() => end.current?.scrollIntoView({ block: 'end' }), [c.messages.length])
  const send = () => {
    const t = text.trim()
    if (t.length < 2) return
    dispatch(mode === 'reply' ? { t: 'support/reply', id: c.id, text: t, staffId: me.id } : { t: 'support/note', id: c.id, text: t })
    setText('')
    toast(mode === 'reply' ? 'Reply sent' : 'Note added')
  }
  const agents = db.staff.filter((s) => s.status === 'active' && (s.role === 'support' || s.role === 'super_admin' || s.role === 'operations'))
  return (
    <section className="bg-surface border border-line rounded-[var(--radius-card)] flex flex-col min-h-[560px] max-h-[calc(100vh-230px)]">
      <header className="px-5 py-3.5 border-b border-line space-y-2">
        <div className="flex items-center gap-2">
          <h2 className="font-bold text-[15px] truncate">{c.subject}</h2>
          <Status kind="support" value={c.status} />
          <span className="flex-1" />
          {c.status !== 'solved' ? (
            <Button size="sm" icon={CheckCircleIcon} onClick={() => { dispatch({ t: 'support/status', id: c.id, status: 'solved' }); toast('Marked as solved') }}>Mark solved</Button>
          ) : (
            <Button size="sm" onClick={() => dispatch({ t: 'support/status', id: c.id, status: 'open' })}>Reopen</Button>
          )}
        </div>
        <div className="flex items-center gap-3">
          <div className="text-[12.5px] text-muted min-w-0 flex-1 truncate">{u.name} · {c.id}{c.ref ? ` · about ${c.ref}` : ''}</div>
          <Select aria-label="Assigned to" value={c.assignee ?? ''} onChange={(e) => dispatch({ t: 'support/assign', id: c.id, staffId: e.target.value || null })} className="w-[160px] h-8 text-[12.5px]">
            <option value="">Unassigned</option>
            {agents.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </Select>
        </div>
      </header>
      <div className="flex-1 overflow-y-auto px-5 py-5 space-y-4">
        {c.messages.map((m) => {
          const mine = m.from === 'agent'
          if (m.from === 'note') {
            return (
              <div key={m.id} className="mx-auto max-w-[85%] rounded-xl bg-warn-tint/70 border border-[#f6dcb0] px-3.5 py-2.5 text-[13px]">
                <div className="flex items-center gap-1 text-[11.5px] font-semibold text-warn mb-0.5"><LockSimpleIcon size={12} weight="bold" /> Private note · {m.by}</div>
                {m.text}
              </div>
            )
          }
          return (
            <div key={m.id} className={cx('flex gap-2.5', mine && 'flex-row-reverse')}>
              {m.from === 'user' ? <Avatar name={u.name} src={u.avatar} size={28} /> : m.from === 'bot' ? <span className="w-7 h-7 rounded-full bg-[#eceaf3] inline-flex items-center justify-center text-muted shrink-0"><RobotIcon size={16} /></span> : <Avatar name={m.by ?? 'Agent'} size={28} />}
              <div className={cx('max-w-[78%]', mine && 'text-right')}>
                <div className={cx('inline-block text-left rounded-2xl px-3.5 py-2.5 text-[13.5px] leading-relaxed', mine ? 'bg-brand text-white rounded-tr-md' : m.from === 'bot' ? 'bg-[#f3f2f7] text-ink-2 rounded-tl-md' : 'bg-[#f1eff6] rounded-tl-md')}>
                  {m.text}
                </div>
                <div className="text-[11.5px] text-faint mt-1">{m.from === 'bot' ? 'Automatic reply' : m.from === 'agent' ? m.by : u.name.split(' ')[0]} · {fmtTime(m.at)}</div>
              </div>
            </div>
          )
        })}
        <div ref={end} />
      </div>
      <div className="border-t border-line p-4">
        <div className="flex flex-wrap gap-1.5 mb-2.5">
          {quick.map((q) => <button key={q} type="button" onClick={() => setText(q)} className="h-7 px-2.5 rounded-full border border-line text-[12px] font-semibold text-ink-2 hover:bg-hover max-w-[260px] truncate">{q}</button>)}
        </div>
        <div className={cx('rounded-xl border transition-colors', mode === 'note' ? 'border-[#f0d39d] bg-warn-tint/40' : 'border-line')}>
          <Textarea value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => { if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') send() }} placeholder={mode === 'reply' ? `Reply to ${u.name.split(' ')[0]}…` : 'Private note, only staff can see it'} rows={3} className="border-0 bg-transparent focus:ring-0 shadow-none" />
          <div className="flex items-center gap-2 px-2.5 pb-2.5">
            <div className="inline-flex p-0.5 rounded-lg bg-[#efedf4]">
              {(['reply', 'note'] as const).map((m) => <button key={m} type="button" onClick={() => setMode(m)} className={cx('h-7 px-2.5 rounded-md text-[12.5px] font-semibold', mode === m ? 'bg-surface shadow-[0_1px_2px_rgb(21_16_46/0.1)]' : 'text-muted')}>{m === 'reply' ? 'Reply' : 'Private note'}</button>)}
            </div>
            <span className="text-[11.5px] text-faint ml-auto hidden sm:block">Ctrl + Enter to send</span>
            <Button size="sm" variant="primary" icon={PaperPlaneTiltIcon} disabled={text.trim().length < 2} onClick={send}>{mode === 'reply' ? 'Send reply' : 'Add note'}</Button>
          </div>
        </div>
      </div>
    </section>
  )
}

function Context({ c }: { c: Conversation }) {
  const db = useDb()
  const u = db.users.find((x) => x.id === c.userId)!
  const txs = db.txs.filter((t) => t.userId === u.id).slice(0, 5)
  const openOrders = db.orders.filter((o) => (o.buyerId === u.id || o.sellerId === u.id) && ['paid', 'shipped', 'delivered', 'disputed'].includes(o.stage))
  return (
    <aside className="hidden xl:block bg-surface border border-line rounded-[var(--radius-card)] p-5">
      <div className="flex items-center gap-3 mb-4">
        <Avatar name={u.name} src={u.avatar} size={44} verified={u.kyc === 'verified'} />
        <div className="min-w-0"><div className="font-bold truncate">{u.name}</div><div className="text-[12.5px] text-muted truncate">@{u.username}</div></div>
      </div>
      <KV rows={[['Account', <Status kind="user" value={u.status} />], ['ID check', <Status kind="kyc" value={u.kyc} />], ['Wallet', naira(u.balance)], ['Open orders', String(openOrders.length)]]} />
      <h3 className="text-[12.5px] font-bold text-muted mt-5 mb-2">Latest transactions</h3>
      <ul className="space-y-2.5">
        {txs.map((t) => (
          <li key={t.id} className="flex items-start justify-between gap-3 text-[12.5px]">
            <span className="min-w-0"><span className="block font-semibold truncate">{t.title}</span><span className="block text-faint">{timeAgo(t.createdAt)}{t.status !== 'successful' ? ` · ${t.status}` : ''}</span></span>
            <TxAmount t={t} size={12.5} />
          </li>
        ))}
      </ul>
      <Link to={`/users/${u.id}`} className="inline-block mt-5 text-[13px] font-semibold text-brand hover:underline">Open full profile</Link>
    </aside>
  )
}
