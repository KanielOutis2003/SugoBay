import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { LogIn, ShoppingBag, Truck, Store, Bike, Users } from 'lucide-react'

export default function Landing() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const checkSession = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (session) {
        const { data: profile } = await supabase
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .single()
        if (profile?.role === 'admin') {
          navigate('/dashboard')
        }
      }
    }
    checkSession()
  }, [navigate])

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

      navigate('/dashboard')
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#1A1C20]">
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute -top-[40%] -right-[20%] w-[80%] h-[80%] rounded-full bg-[#2A9D8F]/10 blur-[120px]" />
        <div className="absolute -bottom-[20%] -left-[20%] w-[60%] h-[60%] rounded-full bg-[#E76F51]/10 blur-[120px]" />
      </div>

      <header className="relative z-10 p-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] bg-clip-text text-transparent">
            SugoBay
          </h1>
          <p className="text-xs text-gray-500">Sugo para sa tanan sa Ubay</p>
        </div>
        <nav className="flex items-center gap-4">
          <a href="#features" className="text-gray-400 hover:text-white text-sm transition-colors">Features</a>
          <a href="#about" className="text-gray-400 hover:text-white text-sm transition-colors">About</a>
          <a href="#contact" className="text-gray-400 hover:text-white text-sm transition-colors">Contact</a>
        </nav>
      </header>

      <main className="relative z-10 flex flex-col lg:flex-row items-center justify-center min-h-[calc(100vh-100px)] px-6 gap-16">
        <div className="flex-1 max-w-xl">
          <h2 className="text-5xl lg:text-6xl font-bold text-white mb-6 leading-tight">
            The Ultimate <br />
            <span className="bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] bg-clip-text text-transparent">
              Delivery Platform
            </span>
          </h2>
          <p className="text-gray-400 text-lg mb-8 leading-relaxed">
            Connect riders, merchants, and customers in one seamless ecosystem. 
            Order food, send parcels, or become a rider - all in one app.
          </p>
          <div className="flex flex-wrap gap-4 mb-12">
            <div className="flex items-center gap-2 text-gray-400">
              <Store size={18} className="text-[#2A9D8F]" />
              <span className="text-sm">For Merchants</span>
            </div>
            <div className="flex items-center gap-2 text-gray-400">
              <Bike size={18} className="text-[#E76F51]" />
              <span className="text-sm">For Riders</span>
            </div>
            <div className="flex items-center gap-2 text-gray-400">
              <Users size={18} className="text-[#D4AF37]" />
              <span className="text-sm">For Customers</span>
            </div>
          </div>
        </div>

        <div className="w-full max-w-md">
          <div className="bg-[#23252A] rounded-2xl shadow-2xl border border-[#2D2F34] p-8">
            <div className="text-center mb-8">
              <h3 className="text-xl font-bold text-white mb-2">Admin Portal</h3>
              <p className="text-gray-500 text-sm">Sign in to manage SugoBay</p>
            </div>

            <form onSubmit={handleLogin} className="space-y-5">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Email Address
                </label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full bg-[#1A1C20] border border-[#2D2F34] rounded-lg px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-[#2A9D8F] transition-all"
                  placeholder="admin@sugobay.shop"
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
                  className="w-full bg-[#1A1C20] border border-[#2D2F34] rounded-lg px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-[#2A9D8F] transition-all"
                  placeholder="Enter your password"
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
                className="w-full bg-[#2A9D8F] hover:bg-[#2A9D8F]/90 text-white font-semibold py-3 rounded-lg transition-all flex items-center justify-center gap-2 disabled:opacity-50"
              >
                {loading ? (
                  <div className="animate-spin rounded-full h-5 w-5 border-2 border-white/30 border-t-white" />
                ) : (
                  <>
                    <LogIn size={18} />
                    Sign In
                  </>
                )}
              </button>
            </form>

            <div className="mt-6 pt-6 border-t border-[#2D2F34]">
              <p className="text-center text-gray-500 text-xs mb-4">Download the mobile app</p>
              <div className="flex gap-3">
                <button className="flex-1 bg-[#1A1C20] hover:bg-[#2D2F34] text-gray-400 hover:text-white py-2.5 rounded-lg text-sm transition-all">
                  Google Play
                </button>
                <button className="flex-1 bg-[#1A1C20] hover:bg-[#2D2F34] text-gray-400 hover:text-white py-2.5 rounded-lg text-sm transition-all">
                  App Store
                </button>
              </div>
            </div>
          </div>
        </div>
      </main>

      <section id="features" className="relative z-10 py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <h3 className="text-3xl font-bold text-white text-center mb-16">Platform Features</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34] hover:border-[#2A9D8F]/50 transition-all">
              <div className="w-12 h-12 bg-[#2A9D8F]/20 rounded-lg flex items-center justify-center mb-4">
                <ShoppingBag className="text-[#2A9D8F]" size={24} />
              </div>
              <h4 className="text-white font-semibold mb-2">Food Delivery</h4>
              <p className="text-gray-500 text-sm">Order from your favorite local restaurants and have food delivered to your doorstep.</p>
            </div>
            <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34] hover:border-[#E76F51]/50 transition-all">
              <div className="w-12 h-12 bg-[#E76F51]/20 rounded-lg flex items-center justify-center mb-4">
                <Truck className="text-[#E76F51]" size={24} />
              </div>
              <h4 className="text-white font-semibold mb-2">Pahapit Errands</h4>
              <p className="text-gray-500 text-sm">Need something bought? Connect with riders who can purchase and deliver items for you.</p>
            </div>
            <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34] hover:border-[#D4AF37]/50 transition-all">
              <div className="w-12 h-12 bg-[#D4AF37]/20 rounded-lg flex items-center justify-center mb-4">
                <Bike className="text-[#D4AF37]" size={24} />
              </div>
              <h4 className="text-white font-semibold mb-2">Rider Earnings</h4>
              <p className="text-gray-500 text-sm">Become a rider, set your own schedule, and earn by delivering food and errands.</p>
            </div>
          </div>
        </div>
      </section>

      <footer className="relative z-10 border-t border-[#2D2F34] py-8 px-6">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-gray-500 text-sm">© 2024 SugoBay. Sugo para sa tanan sa Ubay.</p>
          <div className="flex items-center gap-6">
            <a href="#" className="text-gray-500 hover:text-white text-sm transition-colors">Privacy Policy</a>
            <a href="#" className="text-gray-500 hover:text-white text-sm transition-colors">Terms of Service</a>
            <a href="#" className="text-gray-500 hover:text-white text-sm transition-colors">Support</a>
          </div>
        </div>
      </footer>
    </div>
  )
}
