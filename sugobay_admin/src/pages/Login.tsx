import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const navigate = useNavigate()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)

    try {
      const { data, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (authError) throw authError

      // Check if user is admin
      const { data: profile, error: profileError } = await supabase
        .from('users')
        .select('role')
        .eq('id', data.user.id)
        .single()

      if (profileError) throw profileError

      if (profile.role !== 'admin') {
        await supabase.auth.signOut()
        throw new Error('Unauthorized: You are not an admin.')
      }

      navigate('/')
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#1A1C20] flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-[#23252A] rounded-xl shadow-xl border border-[#2D2F34] p-8">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] bg-clip-text text-transparent">
            SugoBay Admin
          </h1>
          <p className="text-gray-400 mt-2 text-sm">Please sign in to access the dashboard</p>
        </div>

        <form onSubmit={handleLogin} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Email Address
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-[#1A1C20] border border-[#2D2F34] rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-[#2A9D8F] transition-all"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full bg-[#1A1C20] border border-[#2D2F34] rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-[#2A9D8F] transition-all"
              required
            />
          </div>

          {error && (
            <div className="bg-red-500/10 border border-red-500/20 text-red-500 text-sm px-4 py-3 rounded-lg">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#2A9D8F] hover:bg-[#2A9D8F]/90 text-white font-medium py-2 rounded-lg transition-colors disabled:opacity-50"
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  )
}
