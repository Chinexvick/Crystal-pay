import { useState } from 'react'
import { ArrowDownIcon, ArrowUpIcon, ImageIcon, PauseIcon, PencilSimpleIcon, PlayIcon, PlusIcon, TrashIcon } from '@phosphor-icons/react'
import { useDb, useDispatch } from '../lib/store'
import { fmtDate, num, pct } from '../lib/format'
import { Button, Empty, Field, IconButton, Input, PageHeader, Select } from '../components/ui'
import { Status } from '../components/status'
import { Modal, confirm, toast } from '../components/overlays'
import type { Banner } from '../data/types'

const links = ['Shop', 'Shop · Houses', 'Shop · Land', 'Add money', 'Sell', 'Bills', 'Send money', 'Refer and earn', 'Security settings']
const images = [
  ['/img/illustrations/hero_market.webp', 'Market'],
  ['/img/illustrations/wallet_coins.webp', 'Wallet and coins'],
  ['/img/illustrations/property.webp', 'House'],
  ['/img/illustrations/shop_bags.webp', 'Shopping bags'],
  ['/img/illustrations/bills_phone.webp', 'Phone with bills'],
  ['/img/illustrations/shield.webp', 'Shield'],
] as const

/** A small copy of the app's home banner, so staff see what people will see. */
export function BannerPreview({ b, width = 300 }: { b: Pick<Banner, 'title' | 'subtitle' | 'cta' | 'image' | 'eyebrow'>; width?: number }) {
  const s = width / 340
  return (
    <div className="relative overflow-hidden text-white shrink-0" style={{ width, height: 150 * s, borderRadius: 22 * s, background: 'linear-gradient(120deg,#3d0ab2,#5b1adb 55%,#9466f2)' }}>
      <div className="absolute rounded-full" style={{ right: -40 * s, top: -30 * s, width: 190 * s, height: 190 * s, background: 'radial-gradient(circle,rgba(255,255,255,.22),rgba(255,255,255,0) 70%)' }} />
      <img src={b.image} alt="" className="absolute object-contain" style={{ right: 6 * s, top: 8 * s, bottom: 8 * s, height: 134 * s, width: 140 * s }} />
      <div className="absolute flex flex-col justify-center" style={{ left: 18 * s, top: 0, bottom: 0, width: 180 * s }}>
        {b.eyebrow && <span className="self-start rounded-full font-extrabold" style={{ background: '#8be3ae', color: '#0e3b22', fontSize: 10 * s, padding: `${3 * s}px ${9 * s}px`, marginBottom: 6 * s }}>{b.eyebrow}</span>}
        <div className="font-extrabold leading-[1.15]" style={{ fontSize: 17 * s, letterSpacing: '-0.02em' }}>{b.title || 'Banner title'}</div>
        <div className="opacity-85 leading-snug line-clamp-2" style={{ fontSize: 11 * s, marginTop: 4 * s }}>{b.subtitle}</div>
        <span className="self-start bg-white text-[#3d08a8] font-extrabold rounded-full" style={{ fontSize: 11 * s, padding: `${6 * s}px ${12 * s}px`, marginTop: 8 * s }}>{b.cta || 'Button'} →</span>
      </div>
    </div>
  )
}

export default function Banners() {
  const db = useDb()
  const dispatch = useDispatch()
  const [edit, setEdit] = useState<Banner | null>(null)
  const live = db.banners.filter((b) => b.status === 'live')

  const blank = (): Banner => ({ id: `BN-${Date.now().toString(36)}`, title: '', subtitle: '', cta: 'Learn more', image: images[0][0], link: links[0], status: 'draft', impressions: 0, taps: 0 })

  return (
    <>
      <PageHeader
        title="Home banners"
        description={`The carousel at the top of the app’s home screen. ${live.length} live banners rotate every 6 seconds, in this order.`}
        actions={<Button variant="primary" icon={PlusIcon} onClick={() => setEdit(blank())}>New banner</Button>}
      />
      {db.banners.length === 0 && <Empty icon={ImageIcon} title="No banners">The home screen shows no carousel until you add one.</Empty>}
      <ol className="space-y-3">
        {db.banners.map((b, i) => {
          const ctr = b.impressions ? (b.taps / b.impressions) * 100 : 0
          return (
            <li key={b.id} className="flex flex-wrap items-center gap-5 border border-line rounded-[var(--radius-card)] p-4">
              <div className="flex flex-col items-center gap-1 w-8">
                <IconButton icon={ArrowUpIcon} label="Move up" size={28} disabled={i === 0} onClick={() => dispatch({ t: 'banner/move', id: b.id, dir: -1 })} className="disabled:opacity-30" />
                <span className="text-[13px] font-bold num text-muted">{i + 1}</span>
                <IconButton icon={ArrowDownIcon} label="Move down" size={28} disabled={i === db.banners.length - 1} onClick={() => dispatch({ t: 'banner/move', id: b.id, dir: 1 })} className="disabled:opacity-30" />
              </div>
              <BannerPreview b={b} width={260} />
              <div className="min-w-[220px] flex-1">
                <div className="flex items-center gap-2 mb-1"><h2 className="font-bold text-[14.5px]">{b.title}</h2><Status kind="banner" value={b.status} /></div>
                <p className="text-[13px] text-muted">Opens {b.link}{b.status === 'scheduled' && b.startsAt ? ` · starts ${fmtDate(b.startsAt)}` : ''}{b.endsAt ? ` · ends ${fmtDate(b.endsAt)}` : ''}</p>
                <div className="flex gap-6 mt-3 text-[13px]">
                  <div><div className="text-[12px] text-muted">Seen</div><div className="font-bold num">{num(b.impressions)}</div></div>
                  <div><div className="text-[12px] text-muted">Tapped</div><div className="font-bold num">{num(b.taps)}</div></div>
                  <div><div className="text-[12px] text-muted">Tap rate</div><div className="font-bold num">{b.impressions ? pct(ctr) : '—'}</div></div>
                </div>
              </div>
              <div className="flex items-center gap-1.5">
                {b.status === 'live' ? (
                  <Button size="sm" icon={PauseIcon} onClick={() => { dispatch({ t: 'banner/status', id: b.id, status: 'paused' }); toast('Banner paused') }}>Pause</Button>
                ) : (
                  <Button size="sm" icon={PlayIcon} onClick={() => { dispatch({ t: 'banner/status', id: b.id, status: 'live' }); toast('Banner is live') }}>Publish</Button>
                )}
                <IconButton icon={PencilSimpleIcon} label="Edit banner" onClick={() => setEdit(b)} />
                <IconButton
                  icon={TrashIcon}
                  label="Delete banner"
                  onClick={async () => {
                    const ok = await confirm({ title: 'Delete this banner?', message: `“${b.title}” is removed from the app straight away.`, confirmLabel: 'Delete banner', tone: 'danger' })
                    if (ok) { dispatch({ t: 'banner/delete', id: b.id }); toast('Banner deleted') }
                  }}
                />
              </div>
            </li>
          )
        })}
      </ol>
      {edit && <EditBanner banner={edit} isNew={!db.banners.some((b) => b.id === edit.id)} onClose={() => setEdit(null)} />}
    </>
  )
}

function EditBanner({ banner, isNew, onClose }: { banner: Banner; isNew: boolean; onClose: () => void }) {
  const dispatch = useDispatch()
  const [b, setB] = useState<Banner>(banner)
  const set = <K extends keyof Banner>(k: K, v: Banner[K]) => setB((x) => ({ ...x, [k]: v }))
  const valid = b.title.trim().length >= 3 && b.cta.trim().length >= 2
  return (
    <Modal
      open
      onClose={onClose}
      width={720}
      title={isNew ? 'New banner' : 'Edit banner'}
      footer={<><Button onClick={onClose}>Cancel</Button><Button variant="primary" disabled={!valid} onClick={() => { dispatch({ t: 'banner/save', banner: { ...b, title: b.title.trim(), subtitle: b.subtitle.trim() } }); toast(isNew ? 'Banner created' : 'Banner saved'); onClose() }}>{isNew ? 'Create banner' : 'Save changes'}</Button></>}
    >
      <div className="grid grid-cols-1 md:grid-cols-[minmax(0,1fr)_300px] gap-5">
        <div className="space-y-3">
          <Field label="Title" hint={`${b.title.length}/40 · short and specific works best`}><Input maxLength={40} value={b.title} onChange={(e) => set('title', e.target.value)} placeholder="Pay bills in seconds" autoFocus /></Field>
          <Field label="Line under the title"><Input maxLength={80} value={b.subtitle} onChange={(e) => set('subtitle', e.target.value)} placeholder="Airtime, data, power and TV" /></Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Button text"><Input maxLength={16} value={b.cta} onChange={(e) => set('cta', e.target.value)} /></Field>
            <Field label="Tapping opens"><Select value={b.link} onChange={(e) => set('link', e.target.value)}>{links.map((l) => <option key={l}>{l}</option>)}</Select></Field>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Picture"><Select value={b.image} onChange={(e) => set('image', e.target.value)}>{images.map(([src, name]) => <option key={src} value={src}>{name}</option>)}</Select></Field>
            <Field label="Status"><Select value={b.status} onChange={(e) => set('status', e.target.value as Banner['status'])}><option value="draft">Draft</option><option value="live">Live</option><option value="paused">Paused</option></Select></Field>
          </div>
        </div>
        <div>
          <div className="text-[12.5px] font-semibold text-ink-2 mb-1.5">Preview</div>
          <BannerPreview b={b} width={300} />
          <p className="text-[12px] text-muted mt-2">Shown at this size on a typical phone.</p>
        </div>
      </div>
    </Modal>
  )
}
