import { useMemo, useState, type ReactNode } from 'react'
import { ArrowRightIcon } from '@phosphor-icons/react'
import { useDb, useDispatch, settingLabels, settingValue } from '../lib/store'
import { fmtDateTime } from '../lib/format'
import { Button, Card, Field, Input, PageHeader, Segmented, Textarea } from '../components/ui'
import { Modal, toast } from '../components/overlays'
import type { Settings as S } from '../data/types'

type Draft = Record<keyof S, string>

const toDraft = (s: S): Draft => Object.fromEntries(Object.entries(s).map(([k, v]) => [k, String(v)])) as Draft

export default function Settings() {
  const db = useDb()
  const dispatch = useDispatch()
  const [draft, setDraft] = useState<Draft>(() => toDraft(db.settings))
  const [review, setReview] = useState(false)
  const [why, setWhy] = useState('')

  const patch = useMemo(() => {
    const p: Partial<S> = {}
    for (const k of Object.keys(db.settings) as (keyof S)[]) {
      const cur = db.settings[k]
      const raw = draft[k]
      const next = typeof cur === 'number' ? Number(raw) : raw
      if (typeof cur === 'number' && (raw.trim() === '' || Number.isNaN(next))) continue
      if (next !== cur) (p as Record<string, unknown>)[k] = next
    }
    return p
  }, [draft, db.settings])
  const changes = Object.keys(patch) as (keyof S)[]
  const set = (k: keyof S) => (v: string) => setDraft((d) => ({ ...d, [k]: v }))
  const errors: Partial<Record<keyof S, string>> = {}
  const n = (k: keyof S) => Number(draft[k])
  if (n('sendVerified') < n('sendUnverified')) errors.sendVerified = 'Should be higher than the unverified limit'
  if (n('fundMax') <= n('fundMin')) errors.fundMax = 'Must be more than the smallest funding'
  if (n('withdrawMax') <= n('withdrawMin')) errors.withdrawMax = 'Must be more than the smallest withdrawal'
  if (n('cctServicePct') > 10) errors.cctServicePct = 'That is unusually high; most swaps charge under 3%'
  if (n('cctConfirmations') < 3) errors.cctConfirmations = 'Use at least 3 confirmations to avoid reversed deposits'
  const hasErrors = Object.keys(errors).length > 0

  return (
    <>
      <PageHeader title="Rates and fees" description="What people pay and how much they can move. Changes apply to new transactions only, and each one is recorded with your name and reason." />
      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-5 items-start pb-24">
        <div className="space-y-5">
          <Card title="Crystal Cat token (CCT)" subtitle="Tokens are converted to Naira when a deposit is confirmed. People cannot sell or withdraw CCT.">
            <div className="mb-4">
              <span className="block text-[12.5px] font-semibold text-ink-2 mb-1.5">{settingLabels.cctMode}</span>
              <Segmented label={settingLabels.cctMode} value={draft.cctMode as S['cctMode']} onChange={set('cctMode')} items={[{ value: 'market', label: 'Follow the market' }, { value: 'fixed', label: 'Fixed rate' }]} />
            </div>
            <Grid>
              {draft.cctMode === 'fixed' ? (
                <Num k="cctRate" draft={draft} set={set} prefix="₦" hint="Naira paid for 1 CCT" step />
              ) : (
                <Field label="Market rate now" hint="Read from the price feed every minute"><Input value={`₦${db.settings.cctMarketRate.toFixed(2)}`} disabled /></Field>
              )}
              <Num k="cctServicePct" draft={draft} set={set} suffix="%" hint="Taken from the Naira value" step error={errors.cctServicePct} />
              <Num k="cctConfirmations" draft={draft} set={set} suffix="blocks" hint="More is safer, but slower" error={errors.cctConfirmations} />
              <Num k="cctQuoteMinutes" draft={draft} set={set} suffix="min" hint="How long a quoted rate holds" />
              <Num k="cctMinDeposit" draft={draft} set={set} suffix="CCT" hint="Smaller deposits wait for a decision" />
            </Grid>
          </Card>
          <Card title="Fees">
            <Grid>
              <Num k="withdrawalFee" draft={draft} set={set} prefix="₦" hint="Charged on every bank withdrawal" />
              <Num k="deliveryFee" draft={draft} set={set} prefix="₦" hint="Added once per seller in a cart" />
            </Grid>
          </Card>
          <Card title="Limits" subtitle="People with a verified ID get the higher send limit.">
            <Grid>
              <Num k="sendUnverified" draft={draft} set={set} prefix="₦" hint="Per transfer" />
              <Num k="sendVerified" draft={draft} set={set} prefix="₦" hint="Per transfer" error={errors.sendVerified} />
              <Num k="fundMin" draft={draft} set={set} prefix="₦" />
              <Num k="fundMax" draft={draft} set={set} prefix="₦" error={errors.fundMax} />
              <Num k="withdrawMin" draft={draft} set={set} prefix="₦" />
              <Num k="withdrawMax" draft={draft} set={set} prefix="₦" error={errors.withdrawMax} />
              <Num k="dailyOut" draft={draft} set={set} prefix="₦" hint="Withdrawals plus transfers, per person per day" />
            </Grid>
          </Card>
          <Card title="Referrals">
            <Grid>
              <Num k="referralReward" draft={draft} set={set} prefix="₦" hint="Paid to the person who invited" />
              <Num k="referralMinFunding" draft={draft} set={set} prefix="₦" hint="Reward is paid once the friend funds this much" />
            </Grid>
          </Card>
        </div>
        <Card title="Change history" pad={false} className="xl:sticky xl:top-0">
          <ul>
            {db.settingsHistory.map((h) => (
              <li key={h.id} className="px-5 py-3 border-t border-line-2">
                <div className="text-[13px] font-semibold">{h.field}</div>
                <div className="flex items-center gap-1.5 text-[13px] mt-0.5"><span className="text-muted line-through decoration-1">{h.from}</span><ArrowRightIcon size={12} className="text-faint" /><span className="font-semibold">{h.to}</span></div>
                <div className="text-[12px] text-faint mt-1">{h.by} · {fmtDateTime(h.at)}</div>
                {h.reason && <div className="text-[12.5px] text-ink-2 mt-0.5">“{h.reason}”</div>}
              </li>
            ))}
          </ul>
        </Card>
      </div>

      {changes.length > 0 && (
        <div className="fixed bottom-4 left-1/2 -translate-x-1/2 lg:left-[calc(50%+122px)] z-30 flex items-center gap-3 bg-ink text-white rounded-2xl pl-5 pr-2 h-14 shadow-[var(--shadow-pop)] animate-toast">
          <span className="text-[13.5px] font-semibold whitespace-nowrap">{changes.length} unsaved {changes.length === 1 ? 'change' : 'changes'}</span>
          <Button size="sm" variant="ghost" className="text-white/80 hover:bg-white/10 hover:text-white" onClick={() => setDraft(toDraft(db.settings))}>Discard</Button>
          <Button size="sm" variant="primary" disabled={hasErrors} onClick={() => setReview(true)}>Review and save</Button>
        </div>
      )}
      {review && (
        <Modal
          open
          onClose={() => setReview(false)}
          title="Save these changes?"
          footer={<><Button onClick={() => setReview(false)}>Cancel</Button><Button variant="primary" disabled={why.trim().length < 3} onClick={() => { dispatch({ t: 'settings/update', patch, reason: why.trim() }); setReview(false); setWhy(''); toast('Rates and fees saved') }}>Save changes</Button></>}
        >
          <ul className="border border-line rounded-xl divide-y divide-line-2 mb-4">
            {changes.map((k) => (
              <li key={k} className="px-4 py-2.5 text-[13px]">
                <div className="text-muted">{settingLabels[k]}</div>
                <div className="flex items-center gap-1.5 font-semibold"><span className="text-muted font-medium line-through decoration-1">{settingValue(k, db.settings[k])}</span><ArrowRightIcon size={12} className="text-faint" />{settingValue(k, patch[k] as S[keyof S])}</div>
              </li>
            ))}
          </ul>
          <Field label="Reason" hint="Saved to the change history and the audit log."><Textarea rows={2} value={why} onChange={(e) => setWhy(e.target.value)} placeholder="For example: payout partner raised its charge" autoFocus /></Field>
        </Modal>
      )}
    </>
  )
}

function Grid({ children }: { children: ReactNode }) {
  return <div className="grid grid-cols-1 md:grid-cols-2 gap-4">{children}</div>
}

function Num({ k, draft, set, prefix, suffix, hint, error, step }: { k: keyof S; draft: Draft; set: (k: keyof S) => (v: string) => void; prefix?: string; suffix?: string; hint?: string; error?: string; step?: boolean }) {
  return (
    <Field label={settingLabels[k]} hint={hint} error={error}>
      <Input inputMode={step ? 'decimal' : 'numeric'} prefix={prefix} suffix={suffix} value={draft[k]} onChange={(e) => set(k)(e.target.value.replace(step ? /[^\d.]/g : /\D/g, ''))} />
    </Field>
  )
}
