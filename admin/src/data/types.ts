export type KycStatus = 'unverified' | 'pending' | 'verified' | 'rejected'
export type UserStatus = 'active' | 'frozen' | 'closed'
export type PlanKey = 'none' | 'basic' | 'pro' | 'business'
export type IdType = 'NIN' | 'BVN' | 'Passport'

export interface Note {
  id: string
  at: number
  by: string
  text: string
}

export interface User {
  id: string
  name: string
  username: string
  email: string
  phone: string
  city: string
  state: string
  avatar?: string
  status: UserStatus
  kyc: KycStatus
  idType?: IdType
  balance: number
  held: number
  cct: number
  plan: PlanKey
  joinedAt: number
  lastActiveAt: number
  device: string
  twoStep: boolean
  biometric: boolean
  risk: 'low' | 'medium' | 'high'
  notes: Note[]
  referredBy?: string
  dob: string
}

export interface Verification {
  id: string
  userId: string
  idType: IdType
  idNumber: string
  submittedAt: number
  status: 'pending' | 'approved' | 'rejected'
  reviewedBy?: string
  reviewedAt?: number
  rejectReason?: string
  recordName: string
  recordDob: string
  nameMatch: 'match' | 'partial' | 'mismatch'
  dobMatch: boolean
  faceScore: number
  liveness: boolean
  signals: string[]
}

export type ListingStatus = 'live' | 'review' | 'removed' | 'sold'

export interface Listing {
  id: string
  title: string
  image: string
  category: string
  price: number
  period?: 'year' | 'month'
  sellerId: string
  status: ListingStatus
  createdAt: number
  views: number
  saves: number
  property: boolean
  location: string
  condition: string
  featured: boolean
  removedReason?: string
}

export type ReportReason =
  | 'Counterfeit or fake'
  | 'Scam or suspicious price'
  | 'Prohibited item'
  | 'Wrong category'
  | 'Misleading photos'
  | 'Duplicate listing'

export interface Report {
  id: string
  listingId: string
  reporterId: string
  reason: ReportReason
  note: string
  createdAt: number
  status: 'open' | 'removed' | 'dismissed'
  closedBy?: string
}

export type OrderStage = 'paid' | 'shipped' | 'delivered' | 'completed' | 'cancelled' | 'disputed'

export interface Order {
  id: string
  listingId: string
  buyerId: string
  sellerId: string
  amount: number
  deliveryFee: number
  serviceFeePct: number
  method: 'Delivery' | 'Pickup'
  stage: OrderStage
  createdAt: number
  shippedAt?: number
  deliveredAt?: number
  completedAt?: number
  address: string
}

export type DisputeStatus = 'open' | 'awaiting_seller' | 'refunded' | 'released' | 'split'

export interface TimelineItem {
  at: number
  text: string
  by?: string
}

export interface Dispute {
  id: string
  orderId: string
  reason: string
  statement: string
  sellerResponse?: string
  evidence: string[]
  status: DisputeStatus
  openedAt: number
  resolvedAt?: number
  resolution?: string
  refundAmount?: number
  timeline: TimelineItem[]
}

export type TxType =
  | 'funding_card'
  | 'funding_transfer'
  | 'funding_cct'
  | 'bill'
  | 'purchase'
  | 'sale_release'
  | 'withdrawal'
  | 'transfer_out'
  | 'transfer_in'
  | 'refund'
  | 'plan_fee'
  | 'referral'

export type TxStatus = 'successful' | 'pending' | 'failed' | 'reversed'

export interface Tx {
  id: string
  userId: string
  type: TxType
  direction: 'in' | 'out'
  amount: number
  fee: number
  status: TxStatus
  createdAt: number
  title: string
  channel: string
  meta: Record<string, string>
}

export type BillService = 'Airtime' | 'Data' | 'Electricity' | 'Cable TV' | 'Betting' | 'Internet' | 'Intl airtime'

export interface Provider {
  key: string
  name: string
  logo: string
  service: BillService
  rate24h: number
  rate1h: number
  avgMs: number
  enabled: boolean
  volume24h: number
}

export type BillStatus = 'successful' | 'pending' | 'failed' | 'refunded'

export interface Bill {
  id: string
  userId: string
  service: BillService
  providerKey: string
  recipient: string
  recipientName?: string
  plan?: string
  amount: number
  status: BillStatus
  providerRef: string
  token?: string
  units?: string
  failureReason?: string
  createdAt: number
}

export type WithdrawalStatus = 'review' | 'processing' | 'paid' | 'failed' | 'held'

export interface Withdrawal {
  id: string
  userId: string
  amount: number
  fee: number
  bankCode: string
  bankName: string
  accountNumber: string
  accountName: string
  nameMatch: boolean
  status: WithdrawalStatus
  flags: string[]
  requestedAt: number
  processedAt?: number
  processedBy?: string
  holdReason?: string
}

export type CctStatus = 'confirming' | 'converting' | 'credited' | 'underpaid' | 'failed'

export interface CctDeposit {
  id: string
  userId: string
  address: string
  txHash: string
  amount: number
  confirmations: number
  status: CctStatus
  rate: number
  fee: number
  naira: number
  createdAt: number
  block: number
}

export interface PlanConfig {
  key: Exclude<PlanKey, 'none'>
  name: string
  price: number
  listings: number
  feePct: number
  boosts: number
}

export interface Subscription {
  userId: string
  plan: Exclude<PlanKey, 'none'>
  status: 'active' | 'past_due' | 'cancelled'
  startedAt: number
  renewsAt: number
  listingsUsed: number
}

export interface Banner {
  id: string
  eyebrow?: string
  title: string
  subtitle: string
  cta: string
  image: string
  link: string
  status: 'live' | 'scheduled' | 'paused' | 'draft'
  startsAt?: number
  endsAt?: number
  impressions: number
  taps: number
}

export type Channel = 'push' | 'in-app' | 'email'

export interface Announcement {
  id: string
  title: string
  body: string
  audience: string
  channels: Channel[]
  status: 'sent' | 'scheduled' | 'draft'
  at: number
  recipients: number
  opened: number
  by: string
}

export interface Message {
  id: string
  from: 'user' | 'agent' | 'bot' | 'note'
  text: string
  at: number
  by?: string
}

export interface Conversation {
  id: string
  userId: string
  subject: string
  status: 'open' | 'pending' | 'solved'
  assignee?: string
  updatedAt: number
  waitingSince?: number
  tags: string[]
  ref?: string
  messages: Message[]
}

export type RoleKey = 'super_admin' | 'operations' | 'compliance' | 'finance' | 'support' | 'viewer'

export interface Staff {
  id: string
  name: string
  email: string
  role: RoleKey
  twoStep: boolean
  lastActiveAt: number
  status: 'active' | 'invited' | 'disabled'
  avatar?: string
}

export interface AuditEntry {
  id: string
  at: number
  by: string
  area: string
  action: string
  target: string
  detail?: string
  ip: string
}

export interface Settings {
  cctMode: 'market' | 'fixed'
  cctRate: number
  cctMarketRate: number
  cctServicePct: number
  cctConfirmations: number
  cctQuoteMinutes: number
  cctMinDeposit: number
  withdrawalFee: number
  deliveryFee: number
  sendUnverified: number
  sendVerified: number
  fundMin: number
  fundMax: number
  withdrawMin: number
  withdrawMax: number
  dailyOut: number
  referralReward: number
  referralMinFunding: number
}

export interface SettingsChange {
  id: string
  at: number
  by: string
  field: string
  from: string
  to: string
  reason: string
}

export interface Alert {
  id: string
  at: number
  level: 'info' | 'warning' | 'critical'
  text: string
  link: string
  read: boolean
}
