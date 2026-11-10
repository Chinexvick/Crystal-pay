import { useState, type ButtonHTMLAttributes, type ReactNode, type InputHTMLAttributes, type SelectHTMLAttributes, type TextareaHTMLAttributes } from 'react'
import { CheckIcon, CopyIcon, MagnifyingGlassIcon, SealCheckIcon, type Icon } from '@phosphor-icons/react'
import { initials } from '../lib/format'

export const cx = (...c: (string | false | null | undefined)[]) => c.filter(Boolean).join(' ')

/* ───────────── buttons ───────────── */

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'danger-soft'
const variants: Record<Variant, string> = {
  primary: 'bg-brand text-white hover:bg-brand-deep shadow-[0_1px_0_rgb(255_255_255/0.15)_inset,0_1px_2px_rgb(69_16_179/0.3)]',
  secondary: 'bg-surface text-ink border border-line hover:bg-hover hover:border-[#dcd8e7] shadow-[0_1px_1px_rgb(21_16_46/0.04)]',
  ghost: 'text-ink-2 hover:bg-hover',
  danger: 'bg-bad-mark text-white hover:bg-bad',
  'danger-soft': 'bg-surface text-bad border border-line hover:bg-bad-tint hover:border-[#f3c9d0]',
}

export function Button({ variant = 'secondary', size = 'md', icon: I, iconRight: IR, className, children, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: 'sm' | 'md'; icon?: Icon; iconRight?: Icon }) {
  return (
    <button
      type="button"
      {...rest}
      className={cx(
        'inline-flex items-center justify-center gap-1.5 rounded-lg font-semibold whitespace-nowrap transition-colors disabled:opacity-45 disabled:pointer-events-none select-none',
        size === 'sm' ? 'h-8 px-2.5 text-[13px]' : 'h-9 px-3.5 text-[13.5px]',
        variants[variant],
        className,
      )}
    >
      {I && <I size={size === 'sm' ? 15 : 16} weight="bold" className="shrink-0" />}
      {children}
      {IR && <IR size={size === 'sm' ? 14 : 15} weight="bold" className="shrink-0" />}
    </button>
  )
}

export function IconButton({ icon: I, label, className, size = 34, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { icon: Icon; label: string; size?: number }) {
  return (
    <button type="button" aria-label={label} title={label} {...rest} className={cx('inline-flex items-center justify-center rounded-lg text-ink-2 hover:bg-hover hover:text-ink transition-colors', className)} style={{ width: size, height: size }}>
      <I size={18} />
    </button>
  )
}

/* ───────────── pills ───────────── */

export type Tone = 'neutral' | 'brand' | 'ok' | 'warn' | 'bad' | 'info'
const tones: Record<Tone, string> = {
  neutral: 'bg-[#f1f0f5] text-ink-2',
  brand: 'bg-brand-tint text-brand-deep',
  ok: 'bg-ok-tint text-ok',
  warn: 'bg-warn-tint text-warn',
  bad: 'bg-bad-tint text-bad',
  info: 'bg-info-tint text-info',
}
const dots: Record<Tone, string> = { neutral: 'bg-faint', brand: 'bg-brand', ok: 'bg-ok-mark', warn: 'bg-warn-mark', bad: 'bg-bad-mark', info: 'bg-info' }

export function Pill({ tone = 'neutral', icon: I, dot, children, className }: { tone?: Tone; icon?: Icon; dot?: boolean; children: ReactNode; className?: string }) {
  return (
    <span className={cx('inline-flex items-center gap-1 h-[22px] px-2 rounded-full text-[12px] font-semibold whitespace-nowrap leading-none', tones[tone], className)}>
      {dot && <span className={cx('w-1.5 h-1.5 rounded-full', dots[tone])} />}
      {I && <I size={13} weight="bold" />}
      {children}
    </span>
  )
}

/* ───────────── layout pieces ───────────── */

export function Card({ title, subtitle, actions, children, className, pad = true, id }: { title?: ReactNode; subtitle?: ReactNode; actions?: ReactNode; children: ReactNode; className?: string; pad?: boolean; id?: string }) {
  return (
    <section id={id} className={cx('bg-surface border border-line rounded-[var(--radius-card)]', className)}>
      {(title || actions) && (
        <header className="flex items-start gap-3 px-5 pt-4 pb-3">
          <div className="min-w-0 flex-1">
            {title && <h2 className="text-[14.5px] font-bold tracking-[-0.01em]">{title}</h2>}
            {subtitle && <p className="text-[12.5px] text-muted mt-0.5">{subtitle}</p>}
          </div>
          {actions && <div className="flex items-center gap-2 shrink-0">{actions}</div>}
        </header>
      )}
      <div className={cx(pad && 'px-5 pb-5', pad && !(title || actions) && 'pt-5')}>{children}</div>
    </section>
  )
}

export function PageHeader({ title, description, actions, eyebrow }: { title: ReactNode; description?: ReactNode; actions?: ReactNode; eyebrow?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end gap-x-6 gap-y-3 mb-6">
      <div className="min-w-0 flex-1">
        {eyebrow && <div className="mb-1.5">{eyebrow}</div>}
        <h1 className="h-title text-[26px] leading-[1.15]">{title}</h1>
        {description && <p className="text-[13.5px] text-muted mt-1.5 max-w-[70ch]">{description}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  )
}

export function Tabs<T extends string>({ value, onChange, items }: { value: T; onChange: (v: T) => void; items: { value: T; label: string; count?: number; alert?: boolean }[] }) {
  return (
    <div role="tablist" className="flex items-center gap-1 border-b border-line mb-4 overflow-x-auto">
      {items.map((it) => {
        const on = it.value === value
        return (
          <button
            key={it.value}
            role="tab"
            aria-selected={on}
            type="button"
            onClick={() => onChange(it.value)}
            className={cx('relative flex items-center gap-1.5 h-10 px-3 text-[13.5px] font-semibold whitespace-nowrap transition-colors', on ? 'text-ink' : 'text-muted hover:text-ink')}
          >
            {it.label}
            {it.count !== undefined && (
              <span className={cx('num text-[11.5px] font-semibold px-1.5 h-[18px] rounded-full inline-flex items-center', it.alert && it.count > 0 ? 'bg-brand text-white' : on ? 'bg-ink text-white' : 'bg-[#efedf4] text-ink-2')}>{it.count}</span>
            )}
            {on && <span className="absolute left-2 right-2 -bottom-px h-[2px] rounded-full bg-ink" />}
          </button>
        )
      })}
    </div>
  )
}

export function Segmented<T extends string>({ value, onChange, items, label }: { value: T; onChange: (v: T) => void; items: { value: T; label: string }[]; label: string }) {
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex p-0.5 rounded-lg bg-[#efedf4] border border-line">
      {items.map((it) => (
        <button
          key={it.value}
          type="button"
          role="radio"
          aria-checked={it.value === value}
          onClick={() => onChange(it.value)}
          className={cx('h-7 px-2.5 rounded-md text-[12.5px] font-semibold transition-colors', it.value === value ? 'bg-surface text-ink shadow-[0_1px_2px_rgb(21_16_46/0.1)]' : 'text-muted hover:text-ink')}
        >
          {it.label}
        </button>
      ))}
    </div>
  )
}

/* ───────────── form controls ───────────── */

const fieldBase = 'rounded-lg border border-line bg-surface text-[13.5px] text-ink placeholder:text-faint transition-colors hover:border-[#d8d4e4] focus:outline-none focus:border-brand focus:ring-3 focus:ring-brand/12'

/** Fields fill their container unless the caller gives them a width. */
const widthOf = (c?: string) => (c && /(^|\s)w-/.test(c) ? '' : 'w-full')

export function Input({ className, prefix, suffix, ...rest }: InputHTMLAttributes<HTMLInputElement> & { prefix?: ReactNode; suffix?: ReactNode }) {
  if (!prefix && !suffix) return <input {...rest} className={cx(fieldBase, widthOf(className), 'h-9 px-3', className)} />
  return (
    <div className={cx('relative flex items-center', widthOf(className), className)}>
      {prefix && <span className="absolute left-3 text-muted text-[13.5px] pointer-events-none">{prefix}</span>}
      <input {...rest} className={cx(fieldBase, 'w-full h-9', prefix ? 'pl-8' : 'pl-3', suffix ? 'pr-14' : 'pr-3')} />
      {suffix && <span className="absolute right-3 text-muted text-[12.5px] pointer-events-none">{suffix}</span>}
    </div>
  )
}

export function Textarea({ className, ...rest }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea {...rest} className={cx(fieldBase, 'w-full px-3 py-2 resize-y min-h-[80px] leading-relaxed', className)} />
}

export function Select({ className, children, ...rest }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      {...rest}
      className={cx(fieldBase, widthOf(className), 'h-9 pl-3 pr-8 appearance-none bg-no-repeat cursor-pointer', className)}
      style={{ backgroundImage: "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 256 256'%3E%3Cpath fill='%236b6684' d='M213.66 101.66l-80 80a8 8 0 0 1-11.32 0l-80-80a8 8 0 0 1 11.32-11.32L128 164.69l74.34-74.35a8 8 0 0 1 11.32 11.32Z'/%3E%3C/svg%3E\")", backgroundPosition: 'right 10px center' }}
    >
      {children}
    </select>
  )
}

export function SearchInput({ value, onChange, placeholder, className }: { value: string; onChange: (v: string) => void; placeholder: string; className?: string }) {
  return (
    <div className={cx('relative', className)}>
      <MagnifyingGlassIcon size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none" />
      <input value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} aria-label={placeholder} className={cx(fieldBase, 'w-full h-9 pl-9 pr-3')} />
    </div>
  )
}

export function Field({ label, hint, children, error }: { label: string; hint?: ReactNode; children: ReactNode; error?: string }) {
  return (
    <label className="block">
      <span className="block text-[12.5px] font-semibold text-ink-2 mb-1.5">{label}</span>
      {children}
      {error ? <span className="block text-[12px] text-bad mt-1">{error}</span> : hint ? <span className="block text-[12px] text-muted mt-1">{hint}</span> : null}
    </label>
  )
}

export function Toggle({ on, onChange, label, disabled }: { on: boolean; onChange: (v: boolean) => void; label: string; disabled?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!on)}
      className={cx('relative inline-flex h-[22px] w-[38px] shrink-0 rounded-full transition-colors disabled:opacity-50', on ? 'bg-brand' : 'bg-[#d9d5e4]')}
    >
      <span className={cx('absolute top-[3px] h-4 w-4 rounded-full bg-white shadow-[0_1px_2px_rgb(0_0_0/0.25)] transition-transform', on ? 'translate-x-[19px]' : 'translate-x-[3px]')} />
    </button>
  )
}

export function Checkbox({ checked, onChange, label, indeterminate }: { checked: boolean; onChange: (v: boolean) => void; label: string; indeterminate?: boolean }) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={indeterminate ? 'mixed' : checked}
      aria-label={label}
      onClick={(e) => {
        e.stopPropagation()
        onChange(!checked)
      }}
      className={cx('w-[18px] h-[18px] rounded-[5px] border inline-flex items-center justify-center transition-colors', checked || indeterminate ? 'bg-brand border-brand text-white' : 'bg-surface border-[#cdc8da] hover:border-brand')}
    >
      {checked && <CheckIcon size={12} weight="bold" />}
      {!checked && indeterminate && <span className="w-2 h-[2px] bg-white rounded" />}
    </button>
  )
}

/* ───────────── identity ───────────── */

const avatarTints = ['#efe8fd', '#e7f3ee', '#fdeee4', '#e8eefb', '#fbeaf1', '#eef0e2']
const avatarInks = ['#4510b3', '#1c6b45', '#9a4a14', '#2f4fa8', '#9b2c5c', '#5a5f1f']

export function Avatar({ name, src, size = 32, verified }: { name: string; src?: string; size?: number; verified?: boolean }) {
  const i = [...name].reduce((a, c) => a + c.charCodeAt(0), 0) % avatarTints.length
  return (
    <span className="relative inline-flex shrink-0" style={{ width: size, height: size }}>
      {src ? (
        <img src={src} alt="" className="w-full h-full rounded-full object-cover bg-line-2" />
      ) : (
        <span className="w-full h-full rounded-full inline-flex items-center justify-center font-bold" style={{ background: avatarTints[i], color: avatarInks[i], fontSize: Math.max(10, size * 0.36) }}>
          {initials(name)}
        </span>
      )}
      {verified && (
        <span className="absolute -right-0.5 -bottom-0.5 rounded-full bg-surface p-[1px]" title="ID verified">
          <SealCheckIcon size={Math.max(12, size * 0.4)} weight="fill" className="text-brand" />
        </span>
      )}
    </span>
  )
}

export function Logo({ src, name, size = 28, rounded = 'rounded-md' }: { src?: string; name: string; size?: number; rounded?: string }) {
  const [broken, setBroken] = useState(false)
  if (!src || broken) {
    return (
      <span className={cx('inline-flex items-center justify-center bg-[#efedf4] text-ink-2 font-bold shrink-0', rounded)} style={{ width: size, height: size, fontSize: size * 0.36 }}>
        {initials(name)}
      </span>
    )
  }
  return <img src={src} alt="" onError={() => setBroken(true)} className={cx('object-contain bg-surface border border-line-2 shrink-0', rounded)} style={{ width: size, height: size }} />
}

export function Thumb({ src, size = 40, className }: { src: string; size?: number; className?: string }) {
  return <img src={src} alt="" loading="lazy" className={cx('rounded-lg object-cover bg-line-2 shrink-0 border border-line-2', className)} style={{ width: size, height: size }} />
}

/* ───────────── text bits ───────────── */

export function Mono({ children, copy, className }: { children: string; copy?: boolean | string; className?: string }) {
  return (
    <span className={cx('inline-flex items-center gap-1 min-w-0', className)}>
      <span className="mono truncate">{children}</span>
      {copy && <CopyButton value={typeof copy === 'string' ? copy : children} />}
    </span>
  )
}

export function CopyButton({ value }: { value: string }) {
  const [done, setDone] = useState(false)
  return (
    <button
      type="button"
      aria-label="Copy"
      title="Copy"
      onClick={(e) => {
        e.stopPropagation()
        navigator.clipboard?.writeText(value).catch(() => undefined)
        setDone(true)
        setTimeout(() => setDone(false), 1200)
      }}
      className="inline-flex items-center justify-center w-6 h-6 rounded-md text-faint hover:text-ink hover:bg-hover shrink-0"
    >
      {done ? <CheckIcon size={13} weight="bold" className="text-ok-mark" /> : <CopyIcon size={13} />}
    </button>
  )
}

export function KV({ rows, cols = 1 }: { rows: [ReactNode, ReactNode][]; cols?: 1 | 2 }) {
  return (
    <dl className={cx('grid gap-x-6', cols === 2 ? 'grid-cols-2' : 'grid-cols-1')}>
      {rows.map(([k, v], i) => (
        <div key={i} className="flex items-baseline justify-between gap-4 py-2 border-b border-line-2 last:border-b-0 min-w-0">
          <dt className="text-[13px] text-muted shrink-0">{k}</dt>
          <dd className="text-[13px] font-semibold text-right min-w-0 truncate">{v}</dd>
        </div>
      ))}
    </dl>
  )
}

export function Empty({ icon: I, title, children }: { icon: Icon; title: string; children?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center text-center py-14 px-6">
      <span className="w-11 h-11 rounded-full bg-[#f1eff6] inline-flex items-center justify-center text-muted mb-3">
        <I size={22} />
      </span>
      <p className="font-bold text-[14.5px]">{title}</p>
      {children && <p className="text-[13px] text-muted mt-1 max-w-[46ch]">{children}</p>}
    </div>
  )
}

export function Kbd({ children }: { children: ReactNode }) {
  return <kbd className="inline-flex items-center h-5 px-1.5 rounded-[5px] border border-line bg-surface text-[11px] font-semibold text-muted mono">{children}</kbd>
}

export function SectionLabel({ children }: { children: ReactNode }) {
  return <h3 className="text-[12px] font-bold uppercase tracking-[0.06em] text-faint mb-2">{children}</h3>
}
