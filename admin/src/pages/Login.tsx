import { useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { EyeIcon, EyeSlashIcon, LockSimpleIcon } from '@phosphor-icons/react'
import { useStore } from '../lib/store'
import { DEMO_MODE } from '../lib/config'
import { Button, Field, Input } from '../components/ui'

export default function Login() {
  const login = useStore((s) => s.login)
  const nav = useNavigate()
  const loc = useLocation() as { state?: { from?: string } }
  const [email, setEmail] = useState('victory@crystalpay.app')
  const [password, setPassword] = useState('')
  const [show, setShow] = useState(false)
  const [tried, setTried] = useState(false)
  const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
  const passOk = password.length > 0

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    setTried(true)
    if (!DEMO_MODE || !emailOk || !passOk) return
    login(email)
    nav(loc.state?.from && loc.state.from !== '/login' ? loc.state.from : '/', { replace: true })
  }

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 py-10">
      <div className="w-full max-w-[400px]">
        <div className="flex items-center gap-2.5 mb-8 justify-center">
          <img src="/img/brand/logo_mark.webp" alt="" className="h-7 w-auto" />
          <span className="font-extrabold text-[18px] tracking-[-0.02em]">Crystal Pay</span>
          <span className="text-[13px] font-semibold text-muted">Admin</span>
        </div>
        <form onSubmit={submit} noValidate className="bg-surface border border-line rounded-2xl p-7 shadow-[0_1px_2px_rgb(21_16_46/0.04),0_16px_40px_-20px_rgb(21_16_46/0.18)]">
          <h1 className="h-title text-[22px]">Sign in</h1>
          <p className="text-[13.5px] text-muted mt-1 mb-6">Use your Crystal Pay staff email.</p>
          <div className="space-y-4">
            <Field label="Work email" error={tried && !emailOk ? 'Enter a valid email address' : undefined}>
              <Input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} />
            </Field>
            <Field label="Password" error={tried && !passOk ? 'Enter your password' : undefined}>
              <div className="relative">
                <Input type={show ? 'text' : 'password'} autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} autoFocus className="pr-10" />
                <button type="button" onClick={() => setShow((v) => !v)} aria-label={show ? 'Hide password' : 'Show password'} className="absolute right-1.5 top-1/2 -translate-y-1/2 w-7 h-7 rounded-md inline-flex items-center justify-center text-muted hover:text-ink hover:bg-hover">
                  {show ? <EyeSlashIcon size={16} /> : <EyeIcon size={16} />}
                </button>
              </div>
            </Field>
          </div>
          <Button type="submit" variant="primary" className="w-full mt-6 h-10" disabled={!DEMO_MODE}>
            Sign in
          </Button>
          <div className="mt-5 flex gap-2.5 rounded-xl bg-sunken border border-line-2 px-3.5 py-3 text-[12.5px] text-ink-2 leading-relaxed">
            <LockSimpleIcon size={16} className="text-muted mt-0.5 shrink-0" />
            {DEMO_MODE ? (
              <p>
                <span className="font-semibold text-ink">Preview build.</span> Any password works for now. Staff accounts, two-step sign-in and permissions arrive with the backend.
              </p>
            ) : (
              <p>
                <span className="font-semibold text-ink">Sign-in is not open yet.</span> Staff accounts are being set up.
              </p>
            )}
          </div>
        </form>
        <p className="text-center text-[12px] text-faint mt-6">For Crystal Pay staff only. Every action is recorded in the audit log.</p>
      </div>
    </div>
  )
}
