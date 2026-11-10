import { useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { create } from 'zustand'
import { CheckCircleIcon, WarningCircleIcon, XIcon } from '@phosphor-icons/react'
import { Button, Field, Select, Textarea, cx } from './ui'

function useEscape(open: boolean, onClose: () => void) {
  useEffect(() => {
    if (!open) return
    const h = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [open, onClose])
}

/* ───────────── drawer ───────────── */

export function Drawer({ open, onClose, title, subtitle, headerExtra, children, footer, width = 540 }: { open: boolean; onClose: () => void; title: ReactNode; subtitle?: ReactNode; headerExtra?: ReactNode; children: ReactNode; footer?: ReactNode; width?: number }) {
  useEscape(open, onClose)
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (open) ref.current?.focus()
  }, [open])
  if (!open) return null
  return createPortal(
    <div className="fixed inset-0 z-40">
      <div className="absolute inset-0 bg-[rgb(21_16_46/0.28)] animate-fade" onClick={onClose} />
      <div ref={ref} tabIndex={-1} role="dialog" aria-modal="true" className="absolute right-0 top-0 h-full bg-surface flex flex-col shadow-[var(--shadow-drawer)] animate-drawer outline-none max-w-[100vw]" style={{ width }}>
        <header className="flex items-start gap-3 px-6 pt-5 pb-4 border-b border-line">
          <div className="min-w-0 flex-1">
            <h2 className="h-title text-[18px] leading-tight">{title}</h2>
            {subtitle && <div className="text-[13px] text-muted mt-1">{subtitle}</div>}
          </div>
          {headerExtra}
          <button type="button" onClick={onClose} aria-label="Close" className="w-8 h-8 -mr-2 rounded-lg inline-flex items-center justify-center text-muted hover:bg-hover hover:text-ink">
            <XIcon size={18} />
          </button>
        </header>
        <div className="flex-1 overflow-y-auto px-6 py-5">{children}</div>
        {footer && <footer className="px-6 py-4 border-t border-line flex items-center gap-2 bg-sunken">{footer}</footer>}
      </div>
    </div>,
    document.body,
  )
}

/* ───────────── dialog ───────────── */

export function Modal({ open, onClose, title, children, footer, width = 460 }: { open: boolean; onClose: () => void; title: ReactNode; children: ReactNode; footer?: ReactNode; width?: number }) {
  useEscape(open, onClose)
  if (!open) return null
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-[12vh] px-4">
      <div className="absolute inset-0 bg-[rgb(21_16_46/0.36)] animate-fade" onClick={onClose} />
      <div role="dialog" aria-modal="true" className="relative bg-surface rounded-2xl shadow-[var(--shadow-pop)] w-full animate-pop" style={{ maxWidth: width }}>
        <div className="px-6 pt-5">
          <h2 className="h-title text-[17px]">{title}</h2>
        </div>
        <div className="px-6 pt-3 pb-5">{children}</div>
        {footer && <div className="px-6 py-4 border-t border-line flex justify-end gap-2 bg-sunken rounded-b-2xl">{footer}</div>}
      </div>
    </div>,
    document.body,
  )
}

interface ConfirmOptions {
  title: string
  message?: ReactNode
  confirmLabel: string
  tone?: 'primary' | 'danger'
  reason?: { label: string; options?: string[]; placeholder?: string; optional?: boolean }
}

interface ConfirmState {
  opts: ConfirmOptions | null
  resolve: ((v: { reason: string } | null) => void) | null
}

const useConfirmStore = create<ConfirmState>(() => ({ opts: null, resolve: null }))

/** Ask for confirmation (and a reason, when the action needs one for the audit log). */
export function confirm(opts: ConfirmOptions) {
  return new Promise<{ reason: string } | null>((resolve) => useConfirmStore.setState({ opts, resolve }))
}

export function ConfirmHost() {
  const { opts, resolve } = useConfirmStore()
  const [choice, setChoice] = useState('')
  const [text, setText] = useState('')
  useEffect(() => {
    setChoice(opts?.reason?.options?.[0] ?? '')
    setText('')
  }, [opts])
  if (!opts || !resolve) return null
  const close = (v: { reason: string } | null) => {
    resolve(v)
    useConfirmStore.setState({ opts: null, resolve: null })
  }
  const isOther = choice === 'Other'
  const reason = opts.reason ? (opts.reason.options && !isOther ? [choice, text.trim()].filter(Boolean).join(' · ') : text.trim()) : ''
  const valid = !opts.reason || opts.reason.optional || reason.length >= 3
  return (
    <Modal
      open
      onClose={() => close(null)}
      title={opts.title}
      footer={
        <>
          <Button onClick={() => close(null)}>Cancel</Button>
          <Button variant={opts.tone === 'danger' ? 'danger' : 'primary'} disabled={!valid} onClick={() => close({ reason })}>
            {opts.confirmLabel}
          </Button>
        </>
      }
    >
      {opts.message && <div className="text-[13.5px] text-ink-2 leading-relaxed">{opts.message}</div>}
      {opts.reason && (
        <div className="mt-4 space-y-3">
          {opts.reason.options && (
            <Field label={opts.reason.label}>
              <Select value={choice} onChange={(e) => setChoice(e.target.value)}>
                {opts.reason.options.map((o) => (
                  <option key={o}>{o}</option>
                ))}
              </Select>
            </Field>
          )}
          <Field label={opts.reason.options ? (isOther ? 'Describe the reason' : 'Add detail (optional)') : opts.reason.label} hint="Saved to the audit log with your name.">
            <Textarea value={text} onChange={(e) => setText(e.target.value)} placeholder={opts.reason.placeholder} rows={3} autoFocus />
          </Field>
        </div>
      )}
    </Modal>
  )
}

/* ───────────── toasts ───────────── */

interface ToastItem {
  id: number
  text: string
  tone: 'ok' | 'bad'
}

const useToasts = create<{ items: ToastItem[] }>(() => ({ items: [] }))
let toastId = 0

export function toast(text: string, tone: 'ok' | 'bad' = 'ok') {
  const id = ++toastId
  useToasts.setState((s) => ({ items: [...s.items, { id, text, tone }] }))
  setTimeout(() => useToasts.setState((s) => ({ items: s.items.filter((t) => t.id !== id) })), 3600)
}

export function ToastHost() {
  const items = useToasts((s) => s.items)
  return createPortal(
    <div className="fixed bottom-5 left-1/2 -translate-x-1/2 z-[60] flex flex-col items-center gap-2 pointer-events-none" aria-live="polite">
      {items.map((t) => (
        <div key={t.id} className={cx('pointer-events-auto flex items-center gap-2 pl-3 pr-4 h-10 rounded-xl text-[13.5px] font-semibold text-white shadow-[var(--shadow-pop)] animate-toast', 'bg-ink')}>
          {t.tone === 'ok' ? <CheckCircleIcon size={18} weight="fill" className="text-[#7ee2a8]" /> : <WarningCircleIcon size={18} weight="fill" className="text-[#ff9aa8]" />}
          {t.text}
        </div>
      ))}
    </div>,
    document.body,
  )
}
