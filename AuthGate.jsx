import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

export default function AuthGate({ children }) {
  const [session, setSession] = useState(undefined)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [err, setErr] = useState('')

  useEffect(() => {
    if (!supabase) return
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => data.subscription.unsubscribe()
  }, [])

  if (!supabase) return children // demo mode (no .env yet)
  if (session === undefined) return null
  if (session)
    return (
      <>
        {children}
        <button
          onClick={() => supabase.auth.signOut()}
          className="fixed bottom-4 left-4 z-50 px-3 py-1.5 rounded-xl bg-white/90 border border-rose-200 text-xs font-semibold text-rose-700 shadow"
        >
          Sign out
        </button>
      </>
    )

  const signIn = async (e) => {
    e.preventDefault()
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setErr(error ? error.message : '')
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#FFF7F9] p-4">
      <form onSubmit={signIn} className="w-full max-w-sm bg-white rounded-3xl p-7 shadow-xl border border-rose-100 space-y-4">
        <h1 className="text-2xl font-bold text-[#3E0A22]">Teacher Login</h1>
        <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email"
          className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 outline-none focus:border-rose-400" />
        <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password"
          className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 outline-none focus:border-rose-400" />
        {err && <p className="text-xs text-rose-600">{err}</p>}
        <button className="w-full py-2.5 rounded-xl bg-rose-600 text-white font-bold hover:bg-rose-700">Sign in</button>
      </form>
    </div>
  )
}
