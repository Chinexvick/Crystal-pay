import {
  ArrowCounterClockwiseIcon, CheckCircleIcon, ClockIcon, HourglassIcon, PauseIcon, ProhibitIcon, SealCheckIcon, SnowflakeIcon,
  WarningCircleIcon, XCircleIcon, type Icon,
} from '@phosphor-icons/react'
import { Pill, type Tone } from './ui'

type Def = [Tone, string, Icon?]

const maps: Record<string, Record<string, Def>> = {
  user: { active: ['ok', 'Active'], frozen: ['info', 'Frozen', SnowflakeIcon], closed: ['neutral', 'Closed'] },
  kyc: { verified: ['brand', 'Verified', SealCheckIcon], pending: ['warn', 'Pending', ClockIcon], unverified: ['neutral', 'Not verified'], rejected: ['bad', 'Rejected', XCircleIcon] },
  verification: { pending: ['warn', 'Waiting', ClockIcon], approved: ['ok', 'Approved', CheckCircleIcon], rejected: ['bad', 'Rejected', XCircleIcon] },
  listing: { live: ['ok', 'Live'], review: ['warn', 'Needs check', ClockIcon], removed: ['bad', 'Removed', ProhibitIcon], sold: ['neutral', 'Sold'] },
  report: { open: ['warn', 'Open'], removed: ['bad', 'Listing removed'], dismissed: ['neutral', 'Dismissed'] },
  order: { paid: ['info', 'Paid, held'], shipped: ['info', 'Shipped'], delivered: ['brand', 'Delivered'], completed: ['ok', 'Completed', CheckCircleIcon], cancelled: ['neutral', 'Cancelled'], disputed: ['bad', 'In dispute', WarningCircleIcon] },
  dispute: { open: ['bad', 'Open'], awaiting_seller: ['warn', 'Waiting on seller', HourglassIcon], refunded: ['neutral', 'Refunded buyer'], released: ['ok', 'Released to seller'], split: ['ok', 'Split'] },
  tx: { successful: ['ok', 'Successful'], pending: ['warn', 'Pending', ClockIcon], failed: ['bad', 'Failed', XCircleIcon], reversed: ['neutral', 'Reversed', ArrowCounterClockwiseIcon] },
  bill: { successful: ['ok', 'Delivered'], pending: ['warn', 'Waiting on provider', ClockIcon], failed: ['bad', 'Failed, not refunded', WarningCircleIcon], refunded: ['neutral', 'Refunded', ArrowCounterClockwiseIcon] },
  withdrawal: { review: ['warn', 'Needs review', ClockIcon], processing: ['info', 'Processing'], paid: ['ok', 'Paid'], failed: ['neutral', 'Returned to wallet', ArrowCounterClockwiseIcon], held: ['bad', 'On hold', PauseIcon] },
  cct: { confirming: ['info', 'Confirming'], converting: ['brand', 'Converting'], credited: ['ok', 'Credited'], underpaid: ['warn', 'Below minimum', WarningCircleIcon], failed: ['neutral', 'Not credited'] },
  sub: { active: ['ok', 'Active'], past_due: ['warn', 'Payment due', ClockIcon], cancelled: ['neutral', 'Cancelled'] },
  banner: { live: ['ok', 'Live'], scheduled: ['info', 'Scheduled', ClockIcon], paused: ['neutral', 'Paused', PauseIcon], draft: ['neutral', 'Draft'] },
  announcement: { sent: ['ok', 'Sent'], scheduled: ['info', 'Scheduled', ClockIcon], draft: ['neutral', 'Draft'] },
  support: { open: ['warn', 'Waiting on us'], pending: ['info', 'Waiting on user'], solved: ['neutral', 'Solved', CheckCircleIcon] },
  staff: { active: ['ok', 'Active'], invited: ['info', 'Invited'], disabled: ['neutral', 'Access off'] },
}

export function Status({ kind, value }: { kind: keyof typeof maps; value: string }) {
  const def = maps[kind]?.[value] ?? (['neutral', value] as Def)
  return (
    <Pill tone={def[0]} icon={def[2]} dot={!def[2]}>
      {def[1]}
    </Pill>
  )
}

export const statusLabel = (kind: keyof typeof maps, value: string) => maps[kind]?.[value]?.[1] ?? value
