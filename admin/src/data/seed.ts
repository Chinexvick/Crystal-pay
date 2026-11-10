import type {
  Alert, Announcement, AuditEntry, Banner, Bill, BillService, CctDeposit, Conversation, Dispute, Listing,
  Order, PlanConfig, PlanKey, Provider, Report, Settings, SettingsChange, Staff, Subscription, Tx, User, Verification, Withdrawal,
} from './types'

/* Deterministic demo data. Times are relative to the moment the page loads, so the
   preview always looks current. Staff actions are replayed on top (see store.ts). */

export interface Db {
  users: User[]
  verifications: Verification[]
  listings: Listing[]
  reports: Report[]
  orders: Order[]
  disputes: Dispute[]
  txs: Tx[]
  providers: Provider[]
  bills: Bill[]
  withdrawals: Withdrawal[]
  cct: CctDeposit[]
  plans: PlanConfig[]
  subscriptions: Subscription[]
  banners: Banner[]
  announcements: Announcement[]
  conversations: Conversation[]
  staff: Staff[]
  audit: AuditEntry[]
  settings: Settings
  settingsHistory: SettingsChange[]
  alerts: Alert[]
  cctRates: { at: number; rate: number }[]
}

const MIN = 60_000
const HOUR = 60 * MIN
const DAY = 24 * HOUR

function mulberry32(seed: number) {
  return () => {
    seed |= 0
    seed = (seed + 0x6d2b79f5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export function makeSeed(now = Date.now()): Db {
  const r = mulberry32(20261110)
  const int = (a: number, b: number) => Math.floor(a + r() * (b - a + 1))
  const pick = <T,>(arr: readonly T[]): T => arr[Math.floor(r() * arr.length)]
  const chance = (p: number) => r() < p
  const round = (n: number, step: number) => Math.round(n / step) * step
  const hex = (len: number) => Array.from({ length: len }, () => '0123456789abcdef'[int(0, 15)]).join('')
  const digits = (len: number) => Array.from({ length: len }, () => String(int(0, 9))).join('')
  const ref = (prefix: string) => `${prefix}-${Array.from({ length: 8 }, () => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[int(0, 31)]).join('')}`
  const ago = (ms: number) => now - ms
  // cosmetic randomness that depends on the clock uses its own stream, so the main
  // sequence (and every id) stays identical between page loads
  const r2 = mulberry32(7)
  const todayStart = new Date(now).setHours(0, 0, 0, 0)
  const hourW = [0.15, 0.08, 0.05, 0.04, 0.05, 0.12, 0.35, 0.7, 1, 1.1, 1.15, 1.15, 1.2, 1.15, 1.1, 1.1, 1.15, 1.25, 1.35, 1.4, 1.35, 1.15, 0.8, 0.4]
  const hourTotal = hourW.reduce((a, b) => a + b, 0)
  const hourCdf = hourW.reduce<number[]>((acc, w) => [...acc, (acc[acc.length - 1] ?? 0) + w / hourTotal], [])
  const nowHour = (now - todayStart) / HOUR
  const elapsed = (hourCdf[Math.floor(nowHour) - 1] ?? 0) + (hourW[Math.floor(nowHour)] / hourTotal) * (nowHour % 1)
  // growth curve: activity on calendar day d (0 = today, 89 = 90 days ago)
  const dayWeight = (d: number) => {
    const growth = 0.35 + 0.65 * (1 - d / 90)
    const dow = new Date(todayStart - d * DAY + 12 * HOUR).getDay()
    const weekend = dow === 0 ? 0.72 : dow === 6 ? 0.86 : 1
    return growth * weekend * (d === 0 ? elapsed : 1)
  }
  const dayCdfs = new Map<number, number[]>()
  const spreadTs = (days: number) => {
    const x = r()
    const y = r()
    const z = r()
    let cdf = dayCdfs.get(days)
    if (!cdf) {
      const w = Array.from({ length: days }, (_, d) => dayWeight(d))
      const total = w.reduce((a, b) => a + b, 0)
      let acc = 0
      cdf = w.map((v) => (acc += v / total))
      dayCdfs.set(days, cdf)
    }
    let d = cdf.findIndex((c) => c >= x)
    if (d < 0) d = days - 1
    const target = y * (d === 0 ? elapsed : 1)
    let h = hourCdf.findIndex((c) => c >= target)
    if (h < 0) h = 23
    const t = todayStart - d * DAY + h * HOUR + z * HOUR
    return t > now - 2 * MIN ? now - (2 + z * 20) * MIN : t
  }

  /* ───────────── people ───────────── */
  const first = ['Adaeze', 'Babatunde', 'Chiamaka', 'Damilola', 'Ebuka', 'Folake', 'Gbenga', 'Habiba', 'Ifeanyi', 'Jumoke', 'Kelechi', 'Lanre', 'Musa', 'Nneka', 'Obinna', 'Precious', 'Rukayat', 'Segun', 'Temitope', 'Uchenna', 'Victoria', 'Wale', 'Yetunde', 'Zainab', 'Aisha', 'Bolaji', 'Chidi', 'Dayo', 'Efe', 'Funmi', 'Godwin', 'Ibrahim', 'Joy', 'Kunle', 'Lola', 'Mercy', 'Nkechi', 'Osas', 'Peace', 'Rotimi', 'Sade', 'Tunde', 'Uche', 'Yusuf', 'Hauwa', 'Emmanuel', 'Blessing', 'Samuel', 'Esther', 'Michael']
  const last = ['Okafor', 'Adeyemi', 'Bello', 'Eze', 'Nwosu', 'Balogun', 'Ibrahim', 'Okonkwo', 'Adebayo', 'Ogunleye', 'Mohammed', 'Uzor', 'Olatunji', 'Etim', 'Akpan', 'Danjuma', 'Nnaji', 'Obi', 'Lawal', 'Afolabi', 'Chukwu', 'Ige', 'Ojo', 'Umar', 'Okeke', 'Ekwueme', 'Abubakar', 'Salami', 'Fashola', 'Igwe']
  const places: [string, string][] = [['Lagos', 'Lagos'], ['Ikeja', 'Lagos'], ['Lekki', 'Lagos'], ['Yaba', 'Lagos'], ['Surulere', 'Lagos'], ['Abuja', 'FCT'], ['Port Harcourt', 'Rivers'], ['Ibadan', 'Oyo'], ['Enugu', 'Enugu'], ['Kano', 'Kano'], ['Benin City', 'Edo'], ['Kaduna', 'Kaduna'], ['Owerri', 'Imo'], ['Uyo', 'Akwa Ibom'], ['Abeokuta', 'Ogun'], ['Asaba', 'Delta'], ['Jos', 'Plateau']]
  const devices = ['Tecno Camon 20 · Android 13', 'Infinix Hot 30 · Android 13', 'Samsung Galaxy A14 · Android 14', 'itel P40 · Android 12', 'Redmi Note 12 · Android 13', 'Samsung Galaxy S21 · Android 14', 'Tecno Spark 10 · Android 13', 'Infinix Note 30 · Android 13', 'Pixel 6a · Android 15', 'Oppo A78 · Android 14', 'Samsung Galaxy A54 · Android 14']
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  const dobStr = () => `${int(1, 28)} ${pick(months)} ${int(1972, 2003)}`
  const phone = () => `0${pick(['803', '806', '813', '816', '703', '706', '810', '814', '903', '906', '805', '807', '815', '905', '802', '808', '701', '902', '809', '817', '818', '909', '908'])} ${digits(3)} ${digits(4)}`

  const users: User[] = []
  const named: Array<[string, string, string, string, string, PlanKey, User['kyc']]> = [
    ['Victory Bassey', 'victory', '/img/avatars/me.jpg', 'Lagos', 'Lagos', 'pro', 'verified'],
    ['Chijioke Obi', 'chijioke', '/img/avatars/chijioke.jpg', 'Ikeja', 'Lagos', 'basic', 'verified'],
    ['Chinelo Adeyemi', 'chinelo', '/img/avatars/chinelo.jpg', 'Abuja', 'FCT', 'pro', 'verified'],
    ['Amaka Eze', 'amaka', '/img/avatars/oluwatoyin.jpg', 'Lekki', 'Lagos', 'business', 'verified'],
    ['Emeka Nwosu', 'emeka', '/img/avatars/lender.jpg', 'Enugu', 'Enugu', 'pro', 'verified'],
    ['Tola Bakare', 'tola', '/img/avatars/tola.jpg', 'Ibadan', 'Oyo', 'basic', 'pending'],
    ['John Okafor', 'john', '/img/avatars/john.jpg', 'Port Harcourt', 'Rivers', 'basic', 'verified'],
    ['Tolu Adebayo', 'tolu', '/img/avatars/tolu.jpg', 'Yaba', 'Lagos', 'none', 'pending'],
    ['Ifeoma Nnaji', 'ifeoma', '/img/avatars/reviewer.jpg', 'Owerri', 'Imo', 'none', 'verified'],
  ]
  named.forEach(([name, username, avatar, city, state, plan, kyc], i) => {
    users.push({
      id: `U-${10001 + i}`, name, username, email: `${username}@${pick(['example.com', 'example.org', 'example.com', 'example.net'])}`,
      phone: phone(), city, state, avatar, status: 'active', kyc, idType: kyc === 'unverified' ? undefined : pick(['NIN', 'NIN', 'BVN', 'Passport'] as const),
      balance: 0, held: 0, cct: 0, plan, joinedAt: ago(int(70, 120) * DAY), lastActiveAt: ago(int(2, 300) * MIN), device: pick(devices),
      twoStep: true, biometric: chance(0.7), risk: 'low', notes: [], dob: dobStr(),
    })
  })
  users[0].email = 'victory@example.com'
  users[0].phone = '0803 000 0001'
  ;[48750, 23450, 186200, 412800, 97300, 4150, 31900, 12600, 58000].forEach((b, i) => { users[i].balance = b })
  const usedNames = new Set(users.map((u) => u.name))
  while (users.length < 220) {
    const fn = pick(first)
    const ln = pick(last)
    const name = `${fn} ${ln}`
    if (usedNames.has(name)) continue
    usedNames.add(name)
    const [city, state] = pick(places)
    const joinedDaysAgo = (() => {
      for (;;) {
        const d = r() * 120
        if (r() < 0.12 + 0.88 * (1 - d / 120) ** 1.6) return d
      }
    })()
    const kycRoll = r()
    const kyc: User['kyc'] = kycRoll < 0.62 ? 'verified' : kycRoll < 0.86 ? 'unverified' : kycRoll < 0.93 ? 'pending' : 'rejected'
    const username = `${fn.toLowerCase()}${pick(['', '_', '.'])}${pick([ln.toLowerCase(), String(int(1, 99)), ln.toLowerCase().slice(0, 3)])}`
    users.push({
      id: `U-${10001 + users.length}`, name, username,
      email: `${fn.toLowerCase()}.${ln.toLowerCase()}${chance(0.4) ? int(1, 99) : ''}@${pick(['example.com', 'example.com', 'example.com', 'example.org', 'example.net', 'example.org'])}`,
      phone: phone(), city, state, status: 'active', kyc, idType: kyc === 'unverified' ? undefined : pick(['NIN', 'NIN', 'NIN', 'BVN', 'Passport'] as const),
      balance: round(chance(0.15) ? r() * 4000 : chance(0.08) ? 150000 + r() * 650000 : r() * 120000, 50), held: 0, cct: 0,
      plan: 'none', joinedAt: ago(joinedDaysAgo * DAY), lastActiveAt: ago(Math.min(joinedDaysAgo * DAY, (chance(0.5) ? r() * 20 * HOUR : r() * 20 * DAY))),
      device: pick(devices), twoStep: chance(0.55), biometric: chance(0.6), risk: 'low', notes: [], dob: dobStr(),
    })
  }
  // a few more pending verifications so the queue is realistic
  const pendingNeeded = 14 - users.filter((u) => u.kyc === 'pending').length
  users.filter((u) => u.kyc === 'unverified' && u.joinedAt > ago(20 * DAY)).slice(0, Math.max(0, pendingNeeded)).forEach((u) => {
    u.kyc = 'pending'
    u.idType = pick(['NIN', 'NIN', 'BVN', 'Passport'] as const)
  })
  users.filter((u) => u.kyc === 'pending').slice(14).forEach((u) => {
    u.kyc = 'unverified'
    u.idType = undefined
  })
  // sellers on plans
  const generated = users.slice(9)
  generated.filter((u) => u.kyc === 'verified').slice(0, 31).forEach((u, i) => {
    u.plan = i < 20 ? 'basic' : i < 28 ? 'pro' : 'business'
  })
  // frozen / closed / risk
  const frozen = [generated[17], generated[64]]
  frozen[0].status = 'frozen'
  frozen[0].risk = 'high'
  frozen[0].notes.push({ id: 'n-f1', at: ago(2 * DAY), by: 'Ibrahim Musa', text: 'Froze after 5 wrong PIN attempts from a new device, then a password reset. Waiting for the user to confirm on a call.' })
  frozen[1].status = 'frozen'
  frozen[1].risk = 'high'
  frozen[1].notes.push({ id: 'n-f2', at: ago(5 * DAY), by: 'Ngozi Okonkwo', text: 'Card funding of ₦250,000 was charged back by the issuing bank. Wallet frozen until the dispute with the card issuer closes.' })
  generated[120].status = 'closed'
  generated.filter((u) => u.balance > 300000).forEach((u) => { u.risk = 'medium' })
  const byId = new Map(users.map((u) => [u.id, u]))
  const U = (i: number) => users[i].id
  const someUser = () => users[int(0, users.length - 1)]
  const activeUser = () => {
    for (;;) {
      const u = someUser()
      if (u.status !== 'closed') return u
    }
  }

  /* ───────────── verifications ───────────── */
  const verifications: Verification[] = []
  const staffNames = ['Ibrahim Musa', 'Kemi Adeleke', 'Victory Bassey']
  const upperName = (n: string, extra?: string) => {
    const [a, b] = n.split(' ')
    return `${b.toUpperCase()} ${a.toUpperCase()}${extra ? ' ' + extra : ''}`
  }
  const idNum = (t: User['idType']) => (t === 'Passport' ? `A${digits(8)}` : digits(11))
  let pendingIx = 0
  const pendingAges = [11.2 * HOUR, 48 * MIN, 22 * MIN, 1.4 * HOUR, 2.2 * HOUR, 3.1 * HOUR, 4.6 * HOUR, 5.2 * HOUR, 7.5 * HOUR, 9.8 * HOUR, 13 * HOUR, 16.5 * HOUR, 21 * HOUR, 31 * HOUR]
  users.forEach((u) => {
    if (u.kyc === 'unverified') return
    const t = u.idType ?? 'NIN'
    const base: Verification = {
      id: `KYC-${5001 + verifications.length}`, userId: u.id, idType: t, idNumber: idNum(t),
      submittedAt: u.joinedAt + int(10, 600) * MIN, status: 'approved', recordName: upperName(u.name, chance(0.4) ? pick(['GRACE', 'CHUKWUDI', 'OLUWASEUN', 'AMINU', 'NGOZI', 'TEMITOPE']) : undefined),
      recordDob: u.dob, nameMatch: 'match', dobMatch: true, faceScore: int(88, 99), liveness: true, signals: [],
    }
    if (u.kyc === 'pending') {
      base.status = 'pending'
      base.submittedAt = ago(pendingAges[pendingIx % pendingAges.length])
      pendingIx++
    } else if (u.kyc === 'rejected') {
      base.status = 'rejected'
      base.reviewedBy = pick(staffNames)
      base.reviewedAt = base.submittedAt + int(1, 12) * HOUR
      base.rejectReason = pick(['Photo does not match the ID record', 'Name does not match the ID record', 'Document image is unreadable'])
      base.faceScore = int(35, 70)
      base.nameMatch = chance(0.5) ? 'partial' : 'mismatch'
    } else {
      base.reviewedBy = pick(staffNames)
      base.reviewedAt = base.submittedAt + int(20, 900) * MIN
    }
    verifications.push(base)
  })
  // make a few pending ones need a closer look
  const pend = verifications.filter((v) => v.status === 'pending')
  const tolu = pend.find((v) => v.userId === 'U-10008')
  if (tolu) {
    tolu.recordName = 'ADEBAYO TOLULOPE MARIAM'
    tolu.nameMatch = 'partial'
    tolu.faceScore = 91
    tolu.signals = ['Account name uses a short form of the name on record']
  }
  if (pend[5]) {
    pend[5].nameMatch = 'mismatch'
    pend[5].recordName = 'OGUNDIPE KAYODE SAMUEL'
    pend[5].faceScore = 41
    pend[5].liveness = false
    pend[5].signals = ['ID number is already linked to another account (U-10142)', 'Selfie failed the liveness check']
    byId.get(pend[5].userId)!.risk = 'high'
  }
  if (pend[8]) {
    pend[8].dobMatch = false
    pend[8].recordDob = '14 Feb 1991'
    pend[8].faceScore = 86
    pend[8].signals = ['Date of birth on the account differs from the ID record']
  }
  if (pend[10]) pend[10].signals = ['Phone number was used on another account that was closed']

  /* ───────────── listings ───────────── */
  const sellerOf: Record<string, string> = { sEmeka: U(4), sChinelo: U(2), sJohn: U(6), sTola: U(5), sChijioke: U(1), sAmaka: U(3), me: U(0) }
  const base: Array<[string, string, number, string, string, string, string, boolean, ('year' | 'month')?]> = [
    ['re1', '4-bedroom duplex with BQ', 145000000, 'houses', 'house_1', 'Lekki, Lagos', 'sEmeka', true],
    ['re3', '3 bedroom apartment', 4500000, 'houses', 'apartment_1', 'Victoria Island, Lagos', 'sChinelo', true, 'year'],
    ['re4', '2 bedroom flat in a new block', 85000000, 'houses', 'building_1', 'Lekki, Lagos', 'sJohn', true],
    ['re5', '1 acre of farmland', 12000000, 'lands', 'farmland_1', 'Epe, Lagos', 'sEmeka', true],
    ['re2', '600 sqm residential land', 18000000, 'lands', 'land_1', 'Ajah, Lagos', 'sTola', true],
    ['l1', 'iPhone X 64GB, clean', 185000, 'phones', 'phone', 'Ikeja, Lagos', 'sChijioke', false],
    ['l2', 'DSLR camera with 18–55mm lens and bag', 320000, 'cameras', 'camera', 'Wuse, Abuja', 'sChinelo', false],
    ['l3', 'Portable Bluetooth boombox speaker', 120000, 'electronics', 'speaker', 'Lekki, Lagos', 'sAmaka', false],
    ['l4', 'Modern accent armchair, cream', 95000, 'furniture', 'chair', 'Victoria Island, Lagos', 'sAmaka', false],
    ['l5', 'Royal blue satin party dress (size 12)', 18500, 'fashion', 'dress', 'Independence Layout, Enugu', 'sEmeka', false],
    ['l6', '55-inch 4K smart TV with wall mount', 340000, 'electronics', 'tv_2', 'Yaba, Lagos', 'sChijioke', false],
    ['l7', '18-inch standing fan, 3 speeds', 28000, 'appliances', 'fan_2', 'Rumuola, Port Harcourt', 'sJohn', false],
    ['l8', 'Steam iron, non-stick soleplate', 14500, 'appliances', 'iron_2', 'Bodija, Ibadan', 'sTola', false],
    ['l9', 'Electric kettle 1.7L, stainless steel', 11000, 'kitchen', 'kettle_steel', 'Surulere, Lagos', 'sAmaka', false],
    ['l10', '25L digital microwave oven', 72000, 'kitchen', 'microwave_2', 'Garki, Abuja', 'sChinelo', false],
    ['l11', '2-slice stainless toaster', 12000, 'kitchen', 'toaster_2', 'Trans-Ekulu, Enugu', 'sEmeka', false],
    ['l12', 'Bagless vacuum cleaner 2000W', 58000, 'appliances', 'vacuum_2', 'Ajah, Lagos', 'sChijioke', false],
    ['l13', 'High-speed blender 1.5L', 26500, 'kitchen', 'blender_2', 'Obio-Akpor, Rivers', 'sJohn', false],
    ['l14', 'Event canopy tent 3×3 m (foldable)', 145000, 'events', 'tent', 'Ikorodu, Lagos', 'sAmaka', false],
    ['l15', 'Plush teddy bear with scarf (60 cm)', 7500, 'kids', 'teddy', 'Challenge, Ibadan', 'sTola', false],
    ['l16', 'Cordless electric kettle 1.8L', 9800, 'kitchen', 'kettle_2', 'Maryland, Lagos', 'sChijioke', false],
    ['m1', 'Cordless stick vacuum, rechargeable', 64000, 'appliances', 'vacuum', 'Yaba, Lagos', 'me', false],
    ['m2', 'Small desk fan, USB powered', 6500, 'appliances', 'fan', 'Yaba, Lagos', 'me', false],
  ]
  const planSellers = users.filter((u) => u.plan !== 'none' && u.id > 'U-10009' && u.status === 'active')
  const extra: Array<[string, number, string, string, string, boolean, ('year' | 'month')?]> = [
    ['iPhone 14 Pro Max 256GB, brand new sealed', 120000, 'phones', 'phone', 'Ikeja, Lagos', false],
    ['Canon EOS 2000D body only', 210000, 'cameras', 'camera', 'Wuse II, Abuja', false],
    ['32-inch LED TV, barely used', 85000, 'electronics', 'tv', 'Gwarinpa, Abuja', false],
    ['Rechargeable standing fan with remote', 41000, 'appliances', 'fan', 'Ogba, Lagos', false],
    ['Dry iron, 1200W', 9000, 'appliances', 'iron', 'Ojota, Lagos', false],
    ['Electric kettle 2L', 13500, 'kitchen', 'kettle', 'Aba Road, Port Harcourt', false],
    ['20L solo microwave', 61000, 'kitchen', 'microwave', 'Ring Road, Benin City', false],
    ['4-slice toaster with defrost', 23000, 'kitchen', 'toaster', 'Wuse, Abuja', false],
    ['Blender with dry mill', 31000, 'kitchen', 'blender', 'Sabon Gari, Kano', false],
    ['Self-contain apartment in Yaba', 900000, 'houses', 'apartment_1', 'Yaba, Lagos', true, 'year'],
    ['500 sqm plot with C of O, Ibeju-Lekki', 16500000, 'lands', 'land_1', 'Ibeju-Lekki, Lagos', true],
    ['Upright vacuum cleaner 1600W', 52000, 'appliances', 'vacuum', 'Bodija, Ibadan', false],
    ['Party canopy and 50 chairs for hire', 95000, 'events', 'tent', 'Owerri, Imo', false],
  ]
  const conditions = ['Brand new', 'Used, like new', 'Used, good', 'Used, fair']
  const listings: Listing[] = base.map(([id, title, price, category, img, location, seller, property, period]) => ({
    id: `L-${id.toUpperCase()}`, title, image: `/img/products/${img}.jpg`, category, price, period, sellerId: sellerOf[seller],
    status: 'live', createdAt: ago(int(2, 60) * DAY + int(0, 600) * MIN), views: int(40, 2400), saves: int(2, 160), property,
    location, condition: property ? '—' : pick(conditions), featured: false,
  }))
  extra.forEach(([title, price, category, img, location, property, period], i) => {
    listings.push({
      id: `L-X${String(i + 1).padStart(2, '0')}`, title, image: `/img/products/${img}.jpg`, category, price, period,
      sellerId: planSellers[i % planSellers.length].id, status: 'live', createdAt: ago(int(1, 40) * DAY + int(0, 600) * MIN),
      views: int(20, 1400), saves: int(0, 90), property, location, condition: property ? '—' : pick(conditions), featured: false,
    })
  })
  const L = (id: string) => listings.find((l) => l.id === id)!
  L('L-RE1').featured = true
  L('L-L6').featured = true
  // the scam-priced iPhone: under review after reports
  const scam = L('L-X01')
  scam.createdAt = ago(9 * HOUR)
  scam.views = 611
  // listings waiting for a check
  const review = [L('L-X10'), L('L-X11'), L('L-X13')]
  review[0].status = 'review'
  review[0].createdAt = ago(2.5 * HOUR)
  review[1].status = 'review'
  review[1].createdAt = ago(5 * HOUR)
  review[2].status = 'review'
  review[2].createdAt = ago(40 * MIN)
  L('L-X05').status = 'sold'
  L('L-L15').status = 'sold'
  L('L-X09').status = 'removed'
  L('L-X09').removedReason = 'Seller asked for it to be taken down'

  /* ───────────── reports ───────────── */
  const reports: Report[] = [
    { id: 'RP-2201', listingId: 'L-X01', reporterId: U(20), reason: 'Scam or suspicious price', note: 'A sealed 14 Pro Max for ₦120k is not real. Seller asked me to pay to his account directly.', createdAt: ago(7.6 * HOUR), status: 'open' },
    { id: 'RP-2202', listingId: 'L-X01', reporterId: U(41), reason: 'Scam or suspicious price', note: 'Price is too low. Looks like the usual scam.', createdAt: ago(5.1 * HOUR), status: 'open' },
    { id: 'RP-2203', listingId: 'L-X01', reporterId: U(77), reason: 'Misleading photos', note: 'The photo is a stock image, not the actual phone.', createdAt: ago(2.4 * HOUR), status: 'open' },
    { id: 'RP-2204', listingId: 'L-RE2', reporterId: U(33), reason: 'Duplicate listing', note: 'I have seen the same land with the same photos posted by a different agent on Facebook.', createdAt: ago(10.5 * HOUR), status: 'open' },
    { id: 'RP-2205', listingId: 'L-L5', reporterId: U(58), reason: 'Misleading photos', note: 'The dress in the photo is not the one I was shown on video call.', createdAt: ago(3.3 * HOUR), status: 'open' },
    { id: 'RP-2206', listingId: 'L-L14', reporterId: U(91), reason: 'Wrong category', note: 'Should be under rentals, not events.', createdAt: ago(3 * DAY), status: 'dismissed', closedBy: 'Kemi Adeleke' },
    { id: 'RP-2207', listingId: 'L-X09', reporterId: U(12), reason: 'Counterfeit or fake', note: 'Brand name on the blender is misspelt.', createdAt: ago(6 * DAY), status: 'removed', closedBy: 'Kemi Adeleke' },
  ]

  /* ───────────── plans ───────────── */
  const plans: PlanConfig[] = [
    { key: 'basic', name: 'Basic', price: 3000, listings: 5, feePct: 5, boosts: 0 },
    { key: 'pro', name: 'Pro', price: 7500, listings: 25, feePct: 3.5, boosts: 3 },
    { key: 'business', name: 'Business', price: 15000, listings: 100, feePct: 2, boosts: 10 },
  ]
  const feeFor = (sellerId: string) => plans.find((p) => p.key === byId.get(sellerId)!.plan)?.feePct ?? 5

  /* ───────────── orders & disputes ───────────── */
  const goods = listings.filter((l) => !l.property && l.id !== 'L-X01')
  const orders: Order[] = []
  const addresses = ['12 Admiralty Way, Lekki Phase 1, Lagos', '4 Aminu Kano Crescent, Wuse II, Abuja', '27 Ogui Road, Enugu', '9 Herbert Macaulay Way, Yaba, Lagos', '15 Rumuola Road, Port Harcourt', '3 Ring Road, Ibadan', '61 Allen Avenue, Ikeja, Lagos', '8 Wetheral Road, Owerri']
  for (let i = 0; i < 78; i++) {
    const l = pick(goods)
    let buyer = activeUser()
    while (buyer.id === l.sellerId) buyer = activeUser()
    const created = spreadTs(90)
    const method = chance(0.7) ? 'Delivery' : 'Pickup'
    const s1 = r()
    const s2 = r()
    const shipH = int(3, 30)
    const delH = int(30, 70)
    const doneH = int(72, 110)
    const addr = pick(addresses)
    const oid = `CP-${47000 + i * 7 + int(0, 6)}`
    const age = now - created
    let stage: Order['stage'] = 'completed'
    if (age < 1.5 * DAY) stage = s1 < 0.67 ? 'paid' : 'shipped'
    else if (age < 4 * DAY) stage = s1 < 0.34 ? 'shipped' : s1 < 0.67 ? 'delivered' : 'completed'
    else if (s2 < 0.05) stage = 'cancelled'
    orders.push({
      id: oid, listingId: l.id, buyerId: buyer.id, sellerId: l.sellerId, amount: l.price,
      deliveryFee: method === 'Delivery' ? 2500 : 0, serviceFeePct: feeFor(l.sellerId), method, stage, createdAt: created,
      shippedAt: stage !== 'paid' && stage !== 'cancelled' ? Math.min(created + shipH * HOUR, now - 40 * MIN) : undefined,
      deliveredAt: stage === 'delivered' || stage === 'completed' ? Math.min(created + delH * HOUR, now - 25 * MIN) : undefined,
      completedAt: stage === 'completed' ? Math.min(created + doneH * HOUR, now - 12 * MIN) : undefined,
      address: method === 'Delivery' ? addr : l.location,
    })
  }
  // the order from the app: Victory bought the canopy tent from Amaka
  orders.push({ id: 'CP-48213', listingId: 'L-L14', buyerId: U(0), sellerId: U(3), amount: 145000, deliveryFee: 3500, serviceFeePct: 2, method: 'Delivery', stage: 'shipped', createdAt: ago(44 * HOUR), shippedAt: ago(20 * HOUR), address: '12 Admiralty Way, Lekki Phase 1, Lagos' })
  const mkDisputeOrder = (listingId: string, buyer: string, daysAgo: number, stage: Order['stage']) => {
    const l = L(listingId)
    const o: Order = {
      id: `CP-${48700 + orders.length}`, listingId, buyerId: buyer, sellerId: l.sellerId, amount: l.price, deliveryFee: 2500, serviceFeePct: feeFor(l.sellerId),
      method: 'Delivery', stage, createdAt: ago(daysAgo * DAY), shippedAt: ago((daysAgo - 0.6) * DAY), deliveredAt: ago((daysAgo - 2.2) * DAY), address: pick(addresses),
      completedAt: stage === 'completed' ? ago((daysAgo - 4) * DAY) : undefined,
    }
    orders.push(o)
    return o
  }
  const o1 = mkDisputeOrder('L-L12', U(30), 7, 'disputed')
  const o2 = mkDisputeOrder('L-L6', U(47), 5, 'disputed')
  const o3 = mkDisputeOrder('L-L10', U(66), 4, 'disputed')
  const o4 = mkDisputeOrder('L-L16', U(83), 12, 'completed')
  const o5 = mkDisputeOrder('L-L3', U(102), 18, 'cancelled')
  o1.deliveredAt = undefined
  const disputes: Dispute[] = [
    {
      id: 'DSP-1041', orderId: o1.id, reason: 'Item not received', status: 'open', openedAt: ago(31 * HOUR),
      statement: 'Seller marked it as shipped 6 days ago. The dispatch rider never called me and the tracking number he gave me does not work.',
      sellerResponse: 'I gave it to the rider on Tuesday. I have the rider receipt and his phone number.',
      evidence: ['/img/products/vacuum_2.jpg'],
      timeline: [
        { at: o1.createdAt, text: 'Order paid · payment held in Crystal Protect' },
        { at: o1.shippedAt!, text: 'Seller marked the order as shipped' },
        { at: ago(31 * HOUR), text: 'Buyer opened a dispute: item not received' },
        { at: ago(26 * HOUR), text: 'Seller replied with a rider receipt' },
      ],
    },
    {
      id: 'DSP-1042', orderId: o2.id, reason: 'Not as described', status: 'open', openedAt: ago(18 * HOUR),
      statement: 'The TV has two vertical lines on the left side of the screen. The listing said there were no faults. I have a video.',
      sellerResponse: 'It was working perfectly when I packed it. The lines must have come from delivery.',
      evidence: ['/img/products/tv_2.jpg', '/img/products/tv.jpg'],
      timeline: [
        { at: o2.createdAt, text: 'Order paid · payment held in Crystal Protect' },
        { at: o2.shippedAt!, text: 'Seller marked the order as shipped' },
        { at: o2.deliveredAt!, text: 'Buyer confirmed delivery' },
        { at: ago(18 * HOUR), text: 'Buyer opened a dispute: not as described' },
        { at: ago(12 * HOUR), text: 'Seller replied' },
      ],
    },
    {
      id: 'DSP-1043', orderId: o3.id, reason: 'Arrived damaged', status: 'awaiting_seller', openedAt: ago(9 * HOUR),
      statement: 'The microwave door is dented and it does not close properly. Photos attached.',
      evidence: ['/img/products/microwave_2.jpg', '/img/products/microwave.jpg'],
      timeline: [
        { at: o3.createdAt, text: 'Order paid · payment held in Crystal Protect' },
        { at: o3.shippedAt!, text: 'Seller marked the order as shipped' },
        { at: ago(9 * HOUR), text: 'Buyer opened a dispute: arrived damaged' },
        { at: ago(6 * HOUR), text: 'Asked the seller to respond within 24 hours', by: 'Kemi Adeleke' },
      ],
    },
    {
      id: 'DSP-1038', orderId: o4.id, reason: 'Wrong item sent', status: 'split', openedAt: ago(10 * DAY), resolvedAt: ago(8 * DAY), refundAmount: 2000,
      resolution: 'Buyer received a 1.7L kettle instead of 1.8L and chose to keep it. Refunded ₦2,000; the rest was released to the seller.',
      statement: 'I ordered the 1.8L cordless kettle but got a 1.7L one.', sellerResponse: 'Sorry, we sold out of 1.8L. Happy to refund the difference.',
      evidence: ['/img/products/kettle_2.jpg'],
      timeline: [
        { at: o4.createdAt, text: 'Order paid · payment held in Crystal Protect' },
        { at: ago(10 * DAY), text: 'Buyer opened a dispute: wrong item sent' },
        { at: ago(8 * DAY), text: 'Resolved: ₦2,000 refunded to the buyer, rest released to the seller', by: 'Kemi Adeleke' },
      ],
    },
    {
      id: 'DSP-1036', orderId: o5.id, reason: 'Item not working', status: 'refunded', openedAt: ago(16 * DAY), resolvedAt: ago(14 * DAY), refundAmount: o5.amount + o5.deliveryFee,
      resolution: 'Speaker does not power on. Seller agreed to take it back. Full refund to the buyer.',
      statement: 'The speaker does not turn on even after charging all night.', sellerResponse: 'Send it back and I will refund.',
      evidence: ['/img/products/speaker.jpg'],
      timeline: [
        { at: o5.createdAt, text: 'Order paid · payment held in Crystal Protect' },
        { at: ago(16 * DAY), text: 'Buyer opened a dispute: item not working' },
        { at: ago(14 * DAY), text: 'Resolved: full refund to the buyer', by: 'Victory Bassey' },
      ],
    },
  ]

  /* ───────────── bill providers ───────────── */
  const prov = (key: string, name: string, service: BillService, rate24h: number, rate1h: number, avgMs: number, volume24h: number, logo = key): Provider => ({ key, name, service, rate24h, rate1h, avgMs, volume24h, enabled: true, logo: logo ? `/img/logos/${logo}.webp` : '' })
  const providers: Provider[] = [
    prov('mtn', 'MTN', 'Airtime', 99.4, 99.6, 1200, 412),
    prov('airtel', 'Airtel', 'Airtime', 98.9, 99.1, 1400, 268),
    prov('glo', 'Glo', 'Airtime', 96.2, 94.8, 2300, 131),
    prov('t2', 'T2 (9mobile)', 'Airtime', 97.5, 98.0, 1900, 38),
    prov('ikeja', 'Ikeja Electric', 'Electricity', 93.1, 81.4, 4800, 96),
    prov('eko', 'Eko Electricity', 'Electricity', 98.2, 98.9, 3100, 88),
    prov('abuja', 'Abuja Electricity', 'Electricity', 97.4, 97.0, 3500, 54),
    prov('ibedc', 'Ibadan Electricity', 'Electricity', 95.8, 96.6, 4200, 41),
    prov('phed', 'Port Harcourt Electricity', 'Electricity', 96.9, 97.2, 3900, 23),
    prov('enugu', 'Enugu Electricity', 'Electricity', 97.8, 98.1, 3300, 19),
    prov('kano', 'Kano Electricity', 'Electricity', 94.6, 95.3, 4400, 12),
    prov('kaduna', 'Kaduna Electric', 'Electricity', 95.1, 96.0, 4100, 9),
    prov('dstv', 'DStv', 'Cable TV', 99.1, 99.5, 2100, 74),
    prov('gotv', 'GOtv', 'Cable TV', 99.0, 99.2, 2000, 66),
    prov('startimes', 'StarTimes', 'Cable TV', 97.9, 97.5, 2600, 21),
    prov('bet9ja', 'Bet9ja', 'Betting', 98.7, 99.0, 1700, 58),
    prov('sporty', 'SportyBet', 'Betting', 99.2, 99.4, 1500, 49),
    prov('betking', 'BetKing', 'Betting', 98.1, 97.6, 1800, 22),
    prov('1xbet', '1xBet', 'Betting', 96.4, 97.1, 2400, 11),
    prov('spectranet', 'Spectranet', 'Internet', 97.0, 97.8, 2900, 8, ''),
    prov('smile', 'Smile', 'Internet', 95.5, 96.2, 3200, 5, ''),
  ]
  providers.find((p) => p.key === 'smile')!.enabled = false

  /* ───────────── bills ───────────── */
  const bills: Bill[] = []
  const svcPick = (): BillService => {
    const x = r()
    return x < 0.36 ? 'Airtime' : x < 0.66 ? 'Data' : x < 0.84 ? 'Electricity' : x < 0.93 ? 'Cable TV' : x < 0.985 ? 'Betting' : 'Internet'
  }
  const provFor = (s: BillService) => {
    const list = providers.filter((p) => p.service === (s === 'Data' ? 'Airtime' : s))
    const total = list.reduce((a, p) => a + p.volume24h, 0)
    let x = r() * total
    for (const p of list) {
      x -= p.volume24h
      if (x <= 0) return p
    }
    return list[0]
  }
  const dataPlans = [['1GB · 1 day', 350], ['1.5GB · 2 days', 600], ['2GB · 7 days', 1000], ['3GB · 30 days', 1500], ['5GB · 30 days', 2500], ['10GB · 30 days', 4000], ['20GB · 30 days', 6500], ['40GB · 30 days', 11000]] as const
  const tvPlans: Record<string, [string, number][]> = { dstv: [['Padi', 4400], ['Yanga', 6000], ['Confam', 11000], ['Compact', 19000], ['Compact Plus', 30000]], gotv: [['Smallie', 1900], ['Jinja', 3900], ['Jolli', 5800], ['Max', 8500], ['Supa', 11400]], startimes: [['Nova', 1900], ['Basic', 3700], ['Classic', 5500], ['Super', 9000]] }
  const failReasons: Record<BillService, string[]> = {
    Airtime: ['Network provider unavailable', 'Provider timed out'],
    Data: ['Network provider unavailable', 'Plan not available for this number', 'Provider timed out'],
    Electricity: ['Provider timed out', 'Meter number not found', 'Distribution company system is down'],
    'Cable TV': ['Smartcard number not found', 'Provider timed out'],
    Betting: ['Customer ID not found', 'Provider timed out'],
    Internet: ['Account not found', 'Provider timed out'],
    'Intl airtime': ['Provider timed out'],
  }
  const nBills = 3400
  for (let i = 0; i < nBills; i++) {
    const u = activeUser()
    const service = svcPick()
    const p = provFor(service)
    const created = spreadTs(90)
    let amount = 0
    let plan: string | undefined
    let recipient = u.phone
    let recipientName: string | undefined
    if (service === 'Airtime') amount = pick([100, 200, 200, 500, 500, 500, 1000, 1000, 1500, 2000, 3000, 5000])
    else if (service === 'Data') {
      const dp = pick(dataPlans)
      plan = dp[0]
      amount = dp[1]
    } else if (service === 'Electricity') {
      amount = pick([2000, 3000, 5000, 5000, 7500, 10000, 10000, 15000, 20000, 30000, 50000])
      recipient = digits(pick([11, 11, 13]))
      recipientName = u.name.toUpperCase()
      plan = chance(0.85) ? 'Prepaid' : 'Postpaid'
    } else if (service === 'Cable TV') {
      const tp = pick(tvPlans[p.key] ?? tvPlans.gotv)
      plan = tp[0]
      amount = tp[1]
      recipient = digits(10)
      recipientName = u.name.toUpperCase()
    } else if (service === 'Betting') {
      amount = pick([500, 1000, 1000, 2000, 5000, 10000, 20000])
      recipient = digits(8)
    } else {
      amount = pick([5000, 10000, 15000, 20000])
      recipient = digits(10)
      plan = pick(['10GB Monthly', '30GB Monthly', 'Unlimited Lite'])
    }
    const failP = p.rate24h < 95 ? 0.07 : 0.025
    let status: Bill['status'] = 'successful'
    let failureReason: string | undefined
    const roll = r()
    if (roll < failP) {
      status = 'refunded'
      failureReason = failReasons[service][Math.floor(r2() * failReasons[service].length)]
    }
    const b: Bill = {
      id: ref('CPB'), userId: u.id, service, providerKey: p.key, recipient, recipientName, plan, amount, status,
      providerRef: `${p.key.toUpperCase().slice(0, 3)}${digits(12)}`, failureReason, createdAt: created,
    }
    bills.push(b)
  }
  // the newest few: some still waiting on the provider, three failed with no automatic refund
  const tail = bills.slice(-7)
  tail.slice(0, 4).forEach((b, i) => {
    b.status = 'pending'
    b.failureReason = undefined
    b.createdAt = ago([3, 9, 16, 27][i] * MIN)
  })
  const manual = tail.slice(4)
  manual.forEach((b, i) => {
    b.status = 'failed'
    b.createdAt = ago([24, 38, 52][i] * MIN)
    b.failureReason = ['Provider said failed after we were charged', 'Distribution company system is down', 'Provider timed out with no final answer'][i]
    if (i === 0) {
      b.service = 'Airtime'
      b.providerKey = 'glo'
      b.amount = 2000
      b.plan = undefined
      b.recipient = users[1].phone
      b.userId = users[1].id
      b.recipientName = undefined
    }
    if (i === 1) {
      b.service = 'Electricity'
      b.providerKey = 'ikeja'
      b.amount = 10000
      b.recipient = '45031987266'
      b.recipientName = byId.get(b.userId)!.name.toUpperCase()
      b.plan = 'Prepaid'
    }
  })
  bills.forEach((b) => {
    if (b.service === 'Electricity' && b.plan === 'Prepaid' && b.status === 'successful') {
      b.token = Array.from({ length: 20 }, () => String(Math.floor(r2() * 10))).join('')
      b.units = `${(b.amount / (190 + Math.floor(r2() * 35))).toFixed(1)} kWh`
    }
  })
  bills.sort((a, b) => b.createdAt - a.createdAt)

  /* ───────────── CCT deposits & rate ───────────── */
  const cctRates: { at: number; rate: number }[] = []
  let rate = 11.2
  for (let d = 29; d >= 0; d--) {
    rate = Math.max(9.5, rate + (r() - 0.44) * 0.32)
    cctRates.push({ at: now - d * DAY, rate: Number(rate.toFixed(2)) })
  }
  cctRates[cctRates.length - 1].rate = 12.4
  const rateAt = (t: number) => cctRates[Math.min(29, Math.max(0, 29 - Math.floor((now - t) / DAY)))].rate
  const cct: CctDeposit[] = []
  for (let i = 0; i < 64; i++) {
    const u = users[int(0, 140)]
    if (u.status === 'closed') continue
    const created = spreadTs(30)
    const amount = round(pick([500, 1200, 2500, 4000, 8000, 15000, 30000]) * (0.8 + r() * 0.6), 10)
    const rt = rateAt(created)
    const gross = amount * rt
    const fee = Math.round(gross * 0.015)
    cct.push({
      id: `CCT-${7001 + i}`, userId: u.id, address: `0x${hex(40)}`, txHash: `0x${hex(64)}`, amount, confirmations: 12, status: 'credited', rate: rt, fee,
      naira: Math.round(gross - fee), createdAt: created, block: 69_400_000 + Math.floor((created - ago(30 * DAY)) / 750),
    })
  }
  const live = (i: number, status: CctDeposit['status'], conf: number, mins: number) => {
    const d = cct[cct.length - 1 - i]
    d.status = status
    d.confirmations = conf
    d.createdAt = ago(mins * MIN)
    d.rate = 12.4
    d.fee = Math.round(d.amount * 12.4 * 0.015)
    d.naira = Math.round(d.amount * 12.4 - d.fee)
    d.block = 69_400_000 + Math.floor((d.createdAt - ago(30 * DAY)) / 750)
  }
  live(4, 'credited', 12, 42)
  live(5, 'credited', 12, 188)
  live(0, 'confirming', 5, 3)
  live(1, 'confirming', 9, 11)
  live(2, 'converting', 12, 19)
  live(3, 'underpaid', 12, 95)
  const under = cct[cct.length - 4]
  under.amount = 4.5
  under.naira = 0
  under.fee = 0
  under.userId = users[40].id
  cct.sort((a, b) => b.createdAt - a.createdAt)

  /* ───────────── withdrawals ───────────── */
  const banks: [string, string][] = [['058', 'Guaranty Trust Bank'], ['044', 'Access Bank'], ['057', 'Zenith Bank'], ['033', 'United Bank for Africa'], ['011', 'First Bank of Nigeria'], ['999992', 'OPay'], ['50515', 'Moniepoint MFB'], ['50211', 'Kuda Microfinance Bank'], ['999991', 'PalmPay'], ['070', 'Fidelity Bank'], ['232', 'Sterling Bank'], ['214', 'First City Monument Bank'], ['035', 'Wema Bank'], ['221', 'Stanbic IBTC Bank'], ['032', 'Union Bank of Nigeria'], ['076', 'Polaris Bank']]
  const userBank = new Map<string, [string, string, string]>()
  const bankFor = (u: User) => {
    if (!userBank.has(u.id)) {
      const [code, name] = pick(banks)
      userBank.set(u.id, [code, name, digits(10)])
    }
    return userBank.get(u.id)!
  }
  const withdrawals: Withdrawal[] = []
  const verifiedUsers = users.filter((x) => x.kyc === 'verified' && x.status === 'active')
  for (let i = 0; i < 420; i++) {
    const u = verifiedUsers[int(0, verifiedUsers.length - 1)]
    const [code, bank, acct] = bankFor(u)
    const created = spreadTs(90)
    const amount = round(pick([5000, 10000, 20000, 35000, 50000, 80000, 120000, 200000, 350000]) * (0.7 + r() * 0.8), 100)
    const failed = chance(0.015)
    withdrawals.push({
      id: `WD-${29000 + i}`, userId: u.id, amount, fee: 50, bankCode: code, bankName: bank, accountNumber: acct, accountName: u.name.toUpperCase(),
      nameMatch: true, status: failed ? 'failed' : 'paid', flags: [], requestedAt: created, processedAt: created + int(1, 9) * MIN,
      holdReason: failed ? 'Bank rejected the transfer: beneficiary account is dormant' : undefined,
    })
  }
  const proc = withdrawals.slice(-4, -1)
  proc.forEach((w, i) => { w.status = 'processing'; w.requestedAt = ago([4, 13, 26][i] * MIN); w.processedAt = undefined; w.holdReason = undefined })
  const held = withdrawals[withdrawals.length - 1]
  held.status = 'held'
  held.holdReason = 'Waiting for the user to confirm the new device on a call'
  held.processedBy = 'Ngozi Okonkwo'
  held.requestedAt = ago(20 * HOUR)
  held.processedAt = undefined
  withdrawals.sort((a, b) => b.requestedAt - a.requestedAt)
  const flagged: Array<[number, number, string[], boolean?]> = [
    [20, 18 * MIN, ['New bank account (added 2 hours ago)', 'Above 3× this user’s usual amount']],
    [31, 46 * MIN, ['First withdrawal', 'Wallet was funded by card 40 minutes earlier']],
    [44, 1.2 * HOUR, ['Signed in from a new device today']],
    [57, 1.6 * HOUR, ['Name on bank account differs from the verified name'], false],
    [9, 54 * MIN, ['Tried to go above the daily limit twice today']],
    [83, 1.75 * HOUR, ['New bank account (added yesterday)']],
  ]
  flagged.forEach(([ui, age, flags, nameMatch], i) => {
    const u = verifiedUsers[ui % verifiedUsers.length]
    const [code, bank, acct] = bankFor(u)
    withdrawals.unshift({
      id: `WD-${30418 + i}`, userId: u.id, amount: [185000, 60000, 42500, 98000, 250000, 75000][i], fee: 50, bankCode: code, bankName: bank, accountNumber: acct,
      accountName: nameMatch === false ? 'BALOGUN ADEWALE T.' : u.name.toUpperCase(), nameMatch: nameMatch !== false, status: 'review', flags, requestedAt: ago(age),
    })
  })

  /* ───────────── ledger ───────────── */
  const txs: Tx[] = []
  const pushTx = (t: Omit<Tx, 'id'> & { id?: string }) => txs.push({ id: t.id ?? ref('CPX'), ...t })
  bills.forEach((b) => {
    const p = providers.find((x) => x.key === b.providerKey)!
    pushTx({ id: b.id, userId: b.userId, type: 'bill', direction: 'out', amount: b.amount, fee: 0, createdAt: b.createdAt, title: `${b.service} · ${p.name}`, channel: 'Bills partner',
      status: b.status === 'successful' ? 'successful' : b.status === 'pending' ? 'pending' : b.status === 'failed' ? 'failed' : 'reversed', meta: { Recipient: b.recipient, ...(b.plan ? { Plan: b.plan } : {}) } })
    if (b.status === 'refunded') pushTx({ userId: b.userId, type: 'refund', direction: 'in', amount: b.amount, fee: 0, createdAt: b.createdAt + int(1, 4) * MIN, title: `Refund · ${b.service}`, channel: 'Wallet', status: 'successful', meta: { 'Refund for': b.id, Reason: b.failureReason ?? '' } })
  })
  for (let i = 0; i < 1250; i++) {
    const u = activeUser()
    const card = chance(0.55)
    const created = spreadTs(90)
    const amount = round(pick([2000, 5000, 5000, 10000, 10000, 20000, 25000, 50000, 100000, 150000, 250000]) * (0.8 + r() * 0.5), 100)
    const failed = card && chance(0.04)
    pushTx({ userId: u.id, type: card ? 'funding_card' : 'funding_transfer', direction: 'in', amount, fee: card ? Math.min(2000, Math.round(amount * 0.014)) : 0, createdAt: created,
      title: card ? 'Wallet funding · card' : 'Wallet funding · bank transfer', channel: card ? 'Flutterwave card' : 'Flutterwave virtual account',
      status: failed ? 'failed' : 'successful', meta: card ? { Card: `${pick(['Visa', 'Mastercard', 'Verve'])} •••• ${digits(4)}` } : { 'Sender bank': pick(banks)[1], 'Sender name': u.name.toUpperCase() } })
  }
  cct.forEach((d) => pushTx({ id: d.id, userId: d.userId, type: 'funding_cct', direction: 'in', amount: d.naira, fee: d.fee, createdAt: d.createdAt, title: `CCT deposit · ${d.amount.toLocaleString('en-NG')} CCT`, channel: 'BNB Smart Chain',
    status: d.status === 'credited' ? 'successful' : d.status === 'failed' ? 'failed' : 'pending', meta: { 'Tx hash': d.txHash, Rate: `₦${d.rate.toFixed(2)} per CCT` } }))
  withdrawals.forEach((w) => pushTx({ id: w.id, userId: w.userId, type: 'withdrawal', direction: 'out', amount: w.amount, fee: w.fee, createdAt: w.requestedAt, title: `Withdrawal · ${w.bankName}`, channel: 'Flutterwave transfer',
    status: w.status === 'paid' ? 'successful' : w.status === 'failed' ? 'reversed' : 'pending', meta: { Account: `${w.accountNumber} · ${w.accountName}` } }))
  orders.forEach((o) => {
    const l = L(o.listingId)
    pushTx({ id: `${o.id}-P`, userId: o.buyerId, type: 'purchase', direction: 'out', amount: o.amount + o.deliveryFee, fee: 0, createdAt: o.createdAt, title: `Purchase · ${l.title}`, channel: 'Wallet · Crystal Protect',
      status: o.stage === 'cancelled' ? 'reversed' : 'successful', meta: { Order: o.id } })
    if (o.stage === 'completed') {
      const fee = Math.round((o.amount * o.serviceFeePct) / 100)
      pushTx({ id: `${o.id}-R`, userId: o.sellerId, type: 'sale_release', direction: 'in', amount: o.amount + o.deliveryFee - fee, fee, createdAt: o.completedAt ?? o.createdAt + 80 * HOUR, title: `Sale released · ${l.title}`, channel: 'Crystal Protect', status: 'successful', meta: { Order: o.id, 'Service fee': `${o.serviceFeePct}%` } })
    }
  })
  for (let i = 0; i < 520; i++) {
    const a = activeUser()
    let b = activeUser()
    while (b.id === a.id) b = activeUser()
    const created = spreadTs(90)
    const amount = round(pick([1000, 2000, 5000, 5000, 10000, 15000, 20000, 50000]) * (0.8 + r() * 0.6), 100)
    const id = ref('CPT')
    pushTx({ id, userId: a.id, type: 'transfer_out', direction: 'out', amount, fee: 0, createdAt: created, title: `Sent to ${b.name}`, channel: 'Wallet', status: 'successful', meta: { To: `${b.name} (@${b.username})` } })
    pushTx({ id: `${id}-IN`, userId: b.id, type: 'transfer_in', direction: 'in', amount, fee: 0, createdAt: created, title: `From ${a.name}`, channel: 'Wallet', status: 'successful', meta: { From: `${a.name} (@${a.username})` } })
  }
  const subscriptions: Subscription[] = []
  users.filter((u) => u.plan !== 'none').forEach((u) => {
    const p = plans.find((x) => x.key === u.plan)!
    const started = Math.min(u.joinedAt + int(1, 20) * DAY, ago(int(3, 25) * DAY))
    const pastDue = chance(0.08)
    subscriptions.push({ userId: u.id, plan: p.key, status: pastDue ? 'past_due' : 'active', startedAt: started, renewsAt: pastDue ? ago(int(1, 4) * DAY) : now + int(1, 29) * DAY,
      listingsUsed: Math.min(p.listings, listings.filter((l) => l.sellerId === u.id && l.status === 'live').length + int(0, Math.min(4, p.listings))) })
    for (let t = started; t < now; t += 30 * DAY) pushTx({ userId: u.id, type: 'plan_fee', direction: 'out', amount: p.price, fee: 0, createdAt: t, title: `${p.name} seller plan`, channel: 'Wallet', status: 'successful', meta: { Period: '30 days' } })
  })
  subscriptions.push({ userId: generated[150].id, plan: 'basic', status: 'cancelled', startedAt: ago(70 * DAY), renewsAt: ago(10 * DAY), listingsUsed: 0 })
  for (let i = 0; i < 64; i++) {
    const u = activeUser()
    pushTx({ userId: u.id, type: 'referral', direction: 'in', amount: 500, fee: 0, createdAt: spreadTs(90), title: 'Referral reward', channel: 'Wallet', status: 'successful', meta: { Friend: someUser().name } })
  }
  // a failed card funding and a pending transfer in the last hour so the ledger shows them
  txs.sort((a, b) => b.createdAt - a.createdAt)

  // held balances from orders still in Crystal Protect
  orders.forEach((o) => {
    if (o.stage === 'paid' || o.stage === 'shipped' || o.stage === 'delivered' || o.stage === 'disputed') byId.get(o.buyerId)!.held += o.amount + o.deliveryFee
  })
  users.forEach((u) => { if (chance(0.12)) u.cct = round(r() * 3000, 10) })
  frozen[1].balance = 251300

  /* ───────────── banners ───────────── */
  const banners: Banner[] = [
    { id: 'BN-1', eyebrow: 'New', title: 'Find. Buy. Own. All in one place', subtitle: 'Shop great items, get lands and houses, and pay your bills with ease.', cta: 'Explore now', image: '/img/illustrations/hero_market.webp', link: 'Shop', status: 'live', startsAt: ago(21 * DAY), impressions: 48210, taps: 3180 },
    { id: 'BN-2', title: 'Add money your way', subtitle: 'Fund your wallet by card, bank transfer or Crystal Cat token.', cta: 'Add money', image: '/img/illustrations/wallet_coins.webp', link: 'Add money', status: 'live', startsAt: ago(21 * DAY), impressions: 45122, taps: 2214 },
    { id: 'BN-3', title: 'Houses and land near you', subtitle: 'Browse verified sellers and agents, then talk to them directly.', cta: 'View property', image: '/img/illustrations/property.webp', link: 'Shop · Houses', status: 'live', startsAt: ago(14 * DAY), impressions: 39870, taps: 1906 },
    { id: 'BN-4', title: 'Turn items into cash', subtitle: 'Post in minutes and reach buyers across Nigeria.', cta: 'Start selling', image: '/img/illustrations/shop_bags.webp', link: 'Sell', status: 'live', startsAt: ago(14 * DAY), impressions: 37554, taps: 1422 },
    { id: 'BN-5', title: 'Never stress about bills again', subtitle: 'Airtime, data, power and TV in seconds.', cta: 'Pay bills', image: '/img/illustrations/bills_phone.webp', link: 'Bills', status: 'scheduled', startsAt: now + 2 * DAY, endsAt: now + 16 * DAY, impressions: 0, taps: 0 },
    { id: 'BN-6', title: 'Secure payments', subtitle: 'Every payment is PIN-protected and encrypted.', cta: 'Learn more', image: '/img/illustrations/shield.webp', link: 'Security settings', status: 'paused', startsAt: ago(40 * DAY), impressions: 21400, taps: 380 },
  ]

  /* ───────────── announcements ───────────── */
  const announcements: Announcement[] = [
    { id: 'AN-31', title: 'Send money to friends, free', body: 'You can now send money to any Crystal Pay user with their @username or phone number.', audience: 'All users', channels: ['push', 'in-app'], status: 'sent', at: ago(3 * DAY), recipients: 212, opened: 131, by: 'Victory Bassey' },
    { id: 'AN-30', title: 'Verify your ID to raise your limits', body: 'Verified users can send up to ₦500,000 and get the blue tick. It takes about 2 minutes.', audience: 'Users without a verified ID', channels: ['push', 'email'], status: 'sent', at: ago(9 * DAY), recipients: 74, opened: 39, by: 'Kemi Adeleke' },
    { id: 'AN-29', title: 'Planned maintenance tonight', body: 'Bill payments may be slow between 1:00 and 1:30 am while we upgrade our systems.', audience: 'All users', channels: ['in-app'], status: 'sent', at: ago(16 * DAY), recipients: 188, opened: 97, by: 'Seun Ogunleye' },
    { id: 'AN-32', title: 'Your plan renews soon', body: 'Keep your listings visible: top up your wallet before your seller plan renews.', audience: 'Sellers with a plan renewing in 3 days', channels: ['push'], status: 'scheduled', at: now + 14 * HOUR, recipients: 9, opened: 0, by: 'Kemi Adeleke' },
  ]

  /* ───────────── support ───────────── */
  const conv = (id: string, ui: number, subject: string, status: Conversation['status'], waitMin: number | null, tags: string[], msgs: Array<[Conversation['messages'][number]['from'], string, number, string?]>, refStr?: string, assignee?: string): Conversation => {
    const messages = msgs.map(([from, text, minsAgo, by], i) => ({ id: `${id}-${i}`, from, text, at: ago(minsAgo * MIN), by }))
    return { id, userId: users[ui].id, subject, status, assignee, updatedAt: messages[messages.length - 1].at, waitingSince: waitMin === null ? undefined : ago(waitMin * MIN), tags, ref: refStr, messages }
  }
  const failedBill = manual[0]
  const conversations: Conversation[] = [
    conv('SC-901', 1, 'Airtime not received', 'open', 112, ['Bills'], [
      ['user', `I bought ₦${failedBill.amount.toLocaleString('en-NG')} airtime and my wallet was debited but I did not get it.`, 118],
      ['bot', 'Sorry about that. If money left your wallet for a failed payment, it is returned automatically within 10 minutes. I have passed this to the team.', 118],
      ['user', 'It is more than one hour now. Ref ' + failedBill.id, 112],
    ], failedBill.id),
    conv('SC-902', 5, 'My verification is still pending', 'open', 26, ['Verification'], [
      ['user', 'I submitted my NIN since this morning. Why is it still pending? I want to withdraw.', 26],
    ], undefined),
    conv('SC-903', 3, 'When do I get paid for the tent?', 'pending', null, ['Marketplace'], [
      ['user', 'The buyer has received the canopy tent. When will the money enter my wallet?', 300],
      ['agent', 'Hi Amaka, the payment is released as soon as the buyer confirms, or automatically 72 hours after delivery. I will update you once it is out.', 286, 'Seun Ogunleye'],
    ], 'CP-48213', 'S-5'),
    conv('SC-904', 6, 'Withdrawal still processing', 'open', 38, ['Withdrawals'], [
      ['user', 'My withdrawal to GTBank is showing processing. Please check.', 38],
    ], undefined),
    conv('SC-905', 40, 'CCT deposit not showing', 'open', 41, ['CCT'], [
      ['user', 'I sent 4.5 CCT to my deposit address but my wallet was not credited.', 48],
      ['bot', 'Deposits are credited after 12 confirmations on BNB Smart Chain. Please share the transaction hash.', 48],
      ['user', under.txHash, 41],
    ], under.id),
    conv('SC-906', 23, 'Paid for wrong meter number', 'pending', null, ['Bills'], [
      ['user', 'I entered the wrong meter number for my electricity token. Can it be reversed?', 1440],
      ['agent', 'Tokens cannot be reversed once the distribution company issues them. I have asked Ikeja Electric to move it to your meter. It can take up to 3 working days.', 1400, 'Halima Bello'],
    ], undefined, 'S-6'),
    conv('SC-907', 26, 'Why is my account frozen?', 'open', 52, ['Account'], [
      ['user', 'I cannot log in. It says my account is frozen. I did not do anything wrong.', 52],
    ], undefined),
    conv('SC-908', 58, 'Seller is not answering', 'open', 15, ['Marketplace'], [
      ['user', 'I paid for a blender 2 days ago and the seller is not replying my chats.', 15],
    ], undefined),
    conv('SC-909', 77, 'How do I upgrade to Pro?', 'solved', null, ['Plans'], [
      ['user', 'How can I move from Basic to Pro?', 2900],
      ['agent', 'Go to More > Seller plans and tap Upgrade on Pro. It starts a fresh 30-day period.', 2890, 'Seun Ogunleye'],
      ['user', 'Done, thanks!', 2860],
    ], undefined, 'S-5'),
    conv('SC-910', 102, 'Refund for failed data', 'solved', null, ['Bills'], [
      ['user', 'My data purchase failed.', 5000],
      ['agent', 'The ₦1,500 was returned to your wallet automatically 2 minutes after it failed. You can see it in Transactions.', 4980, 'Halima Bello'],
    ], undefined, 'S-6'),
  ]

  /* ───────────── staff & audit ───────────── */
  const staff: Staff[] = [
    { id: 'S-1', name: 'Victory Bassey', email: 'victory@crystalpay.app', role: 'super_admin', twoStep: true, lastActiveAt: ago(1 * MIN), status: 'active', avatar: '/img/avatars/me.jpg' },
    { id: 'S-2', name: 'Kemi Adeleke', email: 'kemi@crystalpay.app', role: 'operations', twoStep: true, lastActiveAt: ago(12 * MIN), status: 'active' },
    { id: 'S-3', name: 'Ibrahim Musa', email: 'ibrahim@crystalpay.app', role: 'compliance', twoStep: true, lastActiveAt: ago(48 * MIN), status: 'active' },
    { id: 'S-4', name: 'Ngozi Okonkwo', email: 'ngozi@crystalpay.app', role: 'finance', twoStep: true, lastActiveAt: ago(3 * HOUR), status: 'active' },
    { id: 'S-5', name: 'Seun Ogunleye', email: 'seun@crystalpay.app', role: 'support', twoStep: false, lastActiveAt: ago(20 * MIN), status: 'active' },
    { id: 'S-6', name: 'Halima Bello', email: 'halima@crystalpay.app', role: 'support', twoStep: true, lastActiveAt: ago(2 * DAY), status: 'active' },
    { id: 'S-7', name: 'Daniel Etim', email: 'daniel@crystalpay.app', role: 'viewer', twoStep: false, lastActiveAt: ago(9 * DAY), status: 'invited' },
  ]
  const paidOne = withdrawals.find((w) => w.status === 'paid')!
  const ips = ['203.0.113.14', '198.51.100.88', '203.0.113.201', '192.0.2.7', '198.51.100.45']
  const audit: AuditEntry[] = []
  const auditSeed: Array<[number, string, string, string, string, string?]> = [
    [14, 'Ibrahim Musa', 'Verifications', 'Approved ID', users[44].name],
    [38, 'Kemi Adeleke', 'Listings', 'Approved listing', 'Rechargeable standing fan with remote'],
    [75, 'Ngozi Okonkwo', 'Withdrawals', 'Approved withdrawal', `${paidOne.id} · ₦${paidOne.amount.toLocaleString('en-NG')}`],
    [120, 'Seun Ogunleye', 'Support', 'Solved conversation', 'SC-899'],
    [190, 'Ibrahim Musa', 'Verifications', 'Rejected ID', users[61].name, 'Photo does not match the ID record'],
    [260, 'Kemi Adeleke', 'Disputes', 'Asked seller to respond', 'DSP-1043'],
    [410, 'Victory Bassey', 'Banners', 'Scheduled banner', 'Never stress about bills again'],
    [620, 'Ngozi Okonkwo', 'Withdrawals', 'Held withdrawal', held.id, held.holdReason],
    [900, 'Kemi Adeleke', 'Listings', 'Removed listing', 'Blender with dry mill', 'Counterfeit or fake'],
    [1300, 'Victory Bassey', 'Announcements', 'Sent announcement', 'Send money to friends, free'],
    [1800, 'Ibrahim Musa', 'Users', 'Froze account', frozen[0].name, 'Wrong PIN attempts from a new device'],
    [2600, 'Victory Bassey', 'Rates and fees', 'Changed delivery fee', '₦2,000 → ₦2,500', 'Riders raised prices'],
    [3500, 'Ngozi Okonkwo', 'Users', 'Froze account', frozen[1].name, 'Card chargeback'],
    [5200, 'Victory Bassey', 'Staff', 'Invited staff', 'Daniel Etim · Read-only'],
    [7100, 'Kemi Adeleke', 'Disputes', 'Resolved dispute', 'DSP-1038 · split', 'Refunded ₦2,000'],
    [9600, 'Victory Bassey', 'Disputes', 'Resolved dispute', 'DSP-1036 · refunded'],
  ]
  auditSeed.forEach(([m, by, area, action, target, detail], i) => audit.push({ id: `AU-${900 - i}`, at: ago(m * MIN), by, area, action, target, detail, ip: ips[i % ips.length] }))

  const settings: Settings = {
    cctMode: 'market', cctRate: 12.4, cctMarketRate: 12.4, cctServicePct: 1.5, cctConfirmations: 12, cctQuoteMinutes: 15, cctMinDeposit: 50,
    withdrawalFee: 50, deliveryFee: 2500, sendUnverified: 50000, sendVerified: 500000, fundMin: 100, fundMax: 5000000, withdrawMin: 100, withdrawMax: 2000000,
    dailyOut: 2000000, referralReward: 500, referralMinFunding: 1000,
  }
  const settingsHistory = [
    { id: 'SH-3', at: ago(2600 * MIN), by: 'Victory Bassey', field: 'Delivery fee per seller', from: '₦2,000', to: '₦2,500', reason: 'Riders raised prices' },
    { id: 'SH-2', at: ago(22 * DAY), by: 'Ngozi Okonkwo', field: 'Withdrawal fee', from: '₦25', to: '₦50', reason: 'Matches what the payout partner charges us' },
    { id: 'SH-1', at: ago(30 * DAY), by: 'Victory Bassey', field: 'Send limit, verified users', from: '₦200,000', to: '₦500,000', reason: 'Owner request' },
  ]

  const alerts: Alert[] = [
    { id: 'AL-1', at: ago(9 * MIN), level: 'warning', text: 'Ikeja Electric succeeded on 81% of payments in the last hour.', link: '/bills', read: false },
    { id: 'AL-2', at: ago(18 * MIN), level: 'warning', text: 'Withdrawal WD-30418 is waiting for review: new bank account added 2 hours ago.', link: '/withdrawals', read: false },
    { id: 'AL-3', at: ago(64 * MIN), level: 'critical', text: '2 ID checks have waited more than 24 hours.', link: '/verifications', read: false },
    { id: 'AL-4', at: ago(95 * MIN), level: 'info', text: `CCT deposit ${under.id} arrived below the minimum and needs a decision.`, link: '/cct', read: true },
    { id: 'AL-5', at: ago(5 * HOUR), level: 'info', text: 'Glo airtime recovered after 14 minutes of slow responses.', link: '/bills', read: true },
  ]

  return {
    users, verifications, listings, reports, orders, disputes, txs, providers, bills, withdrawals, cct, plans, subscriptions, banners, announcements,
    conversations, staff, audit, settings, settingsHistory, alerts, cctRates,
  }
}

export const listingReviewReason: Record<string, string> = {
  'L-X10': 'Property listing from a seller with no completed sales',
  'L-X11': 'Land listing: the title document needs a check',
  'L-X13': 'Seller created their account today',
}
