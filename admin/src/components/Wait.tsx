import { WarningCircleIcon } from '@phosphor-icons/react'
import { useNow } from '../lib/queues'
import { duration } from '../lib/format'
import { cx } from './ui'

/**
 * How long something has waited, against its target time.
 * The bar fills toward the target; purple while there is time, amber in the last
 * 40%, red once it is late. The label always carries the state too.
 */
export function Wait({ since, sla, width = 56, showTarget }: { since?: number; sla: number; width?: number; showTarget?: boolean }) {
  const now = useNow()
  if (!since) return <span className="text-faint text-[12.5px]">—</span>
  const elapsed = Math.max(0, now - since)
  const ratio = elapsed / sla
  const late = ratio >= 1
  const tone = late ? 'bad' : ratio >= 0.6 ? 'warn' : 'brand'
  const track = { brand: 'bg-brand-tint-2', warn: 'bg-[#fbe3bd]', bad: 'bg-[#f9cfd6]' }[tone]
  const fill = { brand: 'bg-brand', warn: 'bg-warn-mark', bad: 'bg-bad-mark' }[tone]
  const label = `Waiting ${duration(elapsed)}. Target ${duration(sla)}.${late ? ' Late.' : ''}`
  return (
    <span className="inline-flex items-center gap-2 whitespace-nowrap" title={label} aria-label={label}>
      <span className={cx('mono text-[12.5px] num', late ? 'text-bad font-medium' : 'text-ink-2')}>{duration(elapsed)}</span>
      <span className={cx('relative h-1 rounded-full overflow-hidden', track)} style={{ width }}>
        <span className={cx('absolute inset-y-0 left-0 rounded-full', fill)} style={{ width: `${Math.min(1, ratio) * 100}%` }} />
      </span>
      {late ? (
        <span className="inline-flex items-center gap-0.5 text-[12px] font-semibold text-bad">
          <WarningCircleIcon size={13} weight="fill" />
          Late
        </span>
      ) : (
        showTarget && <span className="text-[12px] text-faint">of {duration(sla)}</span>
      )}
    </span>
  )
}
