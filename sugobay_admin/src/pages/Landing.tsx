import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { LogIn, ShoppingBag, Truck, Bike, ArrowRight, MapPin, Star } from 'lucide-react'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

// Unsplash images (free to use under Unsplash License)
const HERO_BG = 'https://images.unsplash.com/photo-1526367790999-0150786686a2?w=1920&q=80&auto=format&fit=crop'
const IMG_FOOD = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80&auto=format&fit=crop'
const IMG_PAHAPIT = 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80&auto=format&fit=crop'
const IMG_HABAL = 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80&auto=format&fit=crop'

export default function Landing() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const heroTextRef = useRef<HTMLDivElement>(null)
  const loginCardRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const checkSession = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (session) {
        const { data: profile } = await supabase.from('users').select('role').eq('id', session.user.id).single()
        if (profile?.role === 'admin') navigate('/dashboard')
      }
    }
    checkSession()
  }, [navigate])

  useEffect(() => {
    const tl = gsap.timeline({ defaults: { ease: 'power3.out' } })

    tl.from('.hero-badge', { y: -24, opacity: 0, duration: 0.5, ease: 'back.out(1.7)' })
      .from('.hero-title span', { y: 48, opacity: 0, stagger: 0.12, duration: 0.7 }, '-=0.2')
      .from('.hero-sub', { y: 20, opacity: 0, duration: 0.6 }, '-=0.4')
      .from('.hero-chip', { y: 12, opacity: 0, stagger: 0.08, duration: 0.45 }, '-=0.3')
      .from(loginCardRef.current, { x: 60, opacity: 0, duration: 0.8, ease: 'power3.out' }, '-=0.6')

    gsap.from('.feature-card', {
      y: 56, opacity: 0, stagger: 0.15, duration: 0.7, ease: 'power2.out',
      scrollTrigger: { trigger: '.features-section', start: 'top 82%' },
    })

    gsap.from('.stat-item', {
      y: 32, opacity: 0, stagger: 0.12, duration: 0.6, ease: 'power2.out',
      scrollTrigger: { trigger: '.stats-section', start: 'top 85%' },
    })

    gsap.from('.cta-section', {
      y: 40, opacity: 0, duration: 0.8, ease: 'power2.out',
      scrollTrigger: { trigger: '.cta-section', start: 'top 85%' },
    })

    return () => { ScrollTrigger.getAll().forEach(t => t.kill()) }
  }, [])

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const { data, error: authError } = await supabase.auth.signInWithPassword({ email, password })
      if (authError) throw authError
      const { data: profile, error: profileError } = await supabase.from('users').select('role').eq('id', data.user.id).single()
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

  function handleButtonClick(e: React.MouseEvent<HTMLButtonElement>) {
    gsap.to(e.currentTarget, { scale: 0.95, duration: 0.08, yoyo: true, repeat: 1, ease: 'power2.inOut' })
  }

  return (
    <div className="min-h-screen overflow-x-hidden" style={{ background: '#0F1117' }}>

      {/* Hero Section */}
      <section className="relative min-h-screen flex flex-col">

        {/* Background Image */}
        <div className="absolute inset-0 overflow-hidden">
          <img
            src={HERO_BG}
            alt=""
            className="w-full h-full object-cover object-center opacity-20"
            style={{ filter: 'saturate(1.2)' }}
          />
          <div className="absolute inset-0" style={{
            background: 'linear-gradient(135deg, rgba(15,17,23,0.97) 0%, rgba(15,17,23,0.85) 50%, rgba(15,17,23,0.75) 100%)'
          }} />
          {/* Ambient glows */}
          <div className="absolute top-[-20%] right-[-10%] w-[60%] h-[60%] rounded-full opacity-20"
            style={{ background: 'radial-gradient(circle, rgba(42,157,143,0.4) 0%, transparent 70%)' }} />
          <div className="absolute bottom-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full opacity-15"
            style={{ background: 'radial-gradient(circle, rgba(231,111,81,0.4) 0%, transparent 70%)' }} />
        </div>

        {/* Header */}
        <header className="relative z-10 px-6 lg:px-12 py-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img src="/icon.png" alt="SugoBay" className="w-9 h-9 rounded-xl" onError={e => { (e.target as HTMLImageElement).style.display = 'none' }} />
            <div>
              <h1 className="text-xl font-bold gradient-text">SugoBay</h1>
              <p className="text-[10px] text-gray-500 -mt-0.5">Sugo para sa tanan sa Ubay</p>
            </div>
          </div>
          <nav className="hidden md:flex items-center gap-6">
            {['Features', 'About', 'Contact'].map(item => (
              <a key={item} href={`#${item.toLowerCase()}`}
                className="text-sm text-gray-400 hover:text-white transition-colors hover:text-[#2A9D8F]">
                {item}
              </a>
            ))}
          </nav>
        </header>

        {/* Hero Content */}
        <main className="relative z-10 flex-1 flex flex-col lg:flex-row items-center justify-center px-6 lg:px-12 py-12 gap-12 lg:gap-20 max-w-7xl mx-auto w-full">

          {/* Left: Text */}
          <div className="flex-1 max-w-2xl" ref={heroTextRef}>
            <div className="hero-badge inline-flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold mb-8"
              style={{
                background: 'rgba(42,157,143,0.12)',
                border: '1px solid rgba(42,157,143,0.3)',
                color: '#2A9D8F'
              }}>
              <MapPin size={12} />
              Now serving Ubay, Bohol
            </div>

            <div className="hero-title text-5xl lg:text-6xl xl:text-7xl font-bold text-white leading-tight mb-6">
              <span className="block">Your Local</span>
              <span className="block" style={{ background: 'linear-gradient(135deg, #2A9D8F, #E76F51)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
                Delivery Hub
              </span>
              <span className="block" style={{ fontSize: '0.7em', color: 'rgba(255,255,255,0.6)', fontWeight: 500 }}>for Ubay</span>
            </div>

            <p className="hero-sub text-gray-400 text-lg leading-relaxed mb-10 max-w-lg">
              Order food, send packages, and ride with trusted local riders — all in one seamless app built for your community.
            </p>

            <div className="flex flex-wrap gap-3 mb-12">
              {[
                { icon: ShoppingBag, label: 'Food Delivery', color: '#2A9D8F' },
                { icon: Truck, label: 'Pahapit Errands', color: '#E76F51' },
                { icon: Bike, label: 'Habal-Habal', color: '#E9C46A' },
              ].map(({ icon: Icon, label, color }) => (
                <div key={label} className="hero-chip flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium"
                  style={{ background: `${color}14`, border: `1px solid ${color}30`, color }}>
                  <Icon size={15} />
                  {label}
                </div>
              ))}
            </div>

            <div className="flex items-center gap-4">
              <button
                onClick={e => { handleButtonClick(e); document.getElementById('admin-form')?.scrollIntoView({ behavior: 'smooth' }) }}
                className="flex items-center gap-2 px-6 py-3.5 rounded-xl text-sm font-semibold text-white btn-press"
                style={{ background: 'linear-gradient(135deg, #2A9D8F, #238b7f)' }}>
                Admin Portal <ArrowRight size={16} />
              </button>
              <a href="#features" className="flex items-center gap-2 px-6 py-3.5 rounded-xl text-sm font-medium text-gray-400 hover:text-white transition-colors"
                style={{ border: '1px solid rgba(255,255,255,0.1)' }}>
                Learn More
              </a>
            </div>

            {/* Ratings */}
            <div className="mt-10 flex items-center gap-4">
              <div className="flex -space-x-2">
                {['#2A9D8F', '#E76F51', '#E9C46A', '#8B5CF6'].map((c, i) => (
                  <div key={i} className="w-8 h-8 rounded-full border-2 border-[#0F1117] flex items-center justify-center text-xs font-bold"
                    style={{ background: c }}>{['R', 'M', 'C', 'A'][i]}</div>
                ))}
              </div>
              <div>
                <div className="flex text-yellow-400 text-xs gap-0.5">
                  {[...Array(5)].map((_, i) => <Star key={i} size={12} fill="currentColor" />)}
                </div>
                <p className="text-xs text-gray-500 mt-0.5">Trusted by riders & merchants in Ubay</p>
              </div>
            </div>
          </div>

          {/* Right: Login Card */}
          <div className="w-full max-w-md" ref={loginCardRef} id="admin-form">
            <div className="rounded-2xl p-8"
              style={{
                background: 'rgba(255,255,255,0.04)',
                backdropFilter: 'blur(24px)',
                WebkitBackdropFilter: 'blur(24px)',
                border: '1px solid rgba(255,255,255,0.08)',
                boxShadow: '0 32px 80px rgba(0,0,0,0.4), 0 0 0 1px rgba(255,255,255,0.04)',
              }}>

              {/* Card Header */}
              <div className="text-center mb-8">
                <div className="w-14 h-14 rounded-2xl mx-auto mb-4 flex items-center justify-center"
                  style={{ background: 'linear-gradient(135deg, rgba(42,157,143,0.3), rgba(231,111,81,0.2))', border: '1px solid rgba(42,157,143,0.3)' }}>
                  <LogIn size={22} color="#2A9D8F" />
                </div>
                <h3 className="text-xl font-bold text-white mb-1">Admin Portal</h3>
                <p className="text-gray-500 text-sm">Sign in to manage SugoBay</p>
              </div>

              <form onSubmit={handleLogin} className="space-y-5">
                <div>
                  <label className="block text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">Email Address</label>
                  <input
                    type="email" value={email} onChange={e => setEmail(e.target.value)}
                    className="w-full rounded-xl px-4 py-3.5 text-white text-sm focus:outline-none transition-all"
                    style={{
                      background: 'rgba(255,255,255,0.05)',
                      border: '1px solid rgba(255,255,255,0.1)',
                      // @ts-ignore
                      '--tw-ring-color': '#2A9D8F',
                    }}
                    onFocus={e => e.target.style.borderColor = 'rgba(42,157,143,0.6)'}
                    onBlur={e => e.target.style.borderColor = 'rgba(255,255,255,0.1)'}
                    placeholder="admin@sugobay.shop" required
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">Password</label>
                  <input
                    type="password" value={password} onChange={e => setPassword(e.target.value)}
                    className="w-full rounded-xl px-4 py-3.5 text-white text-sm focus:outline-none transition-all"
                    style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)' }}
                    onFocus={e => e.target.style.borderColor = 'rgba(42,157,143,0.6)'}
                    onBlur={e => e.target.style.borderColor = 'rgba(255,255,255,0.1)'}
                    placeholder="Enter your password" required
                  />
                </div>

                {error && (
                  <div className="px-4 py-3 rounded-xl text-sm"
                    style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.25)', color: '#f87171' }}>
                    {error}
                  </div>
                )}

                <button
                  type="submit" disabled={loading}
                  onClick={!loading ? handleButtonClick : undefined}
                  className="w-full py-3.5 rounded-xl text-white font-semibold text-sm transition-all flex items-center justify-center gap-2 disabled:opacity-50 btn-press"
                  style={{ background: 'linear-gradient(135deg, #2A9D8F, #238b7f)', boxShadow: '0 8px 24px rgba(42,157,143,0.35)' }}>
                  {loading
                    ? <div className="animate-spin rounded-full h-5 w-5 border-2 border-white/30 border-t-white" />
                    : <><LogIn size={17} /> Sign In</>}
                </button>
              </form>

              <div className="mt-6 pt-6" style={{ borderTop: '1px solid rgba(255,255,255,0.07)' }}>
                <p className="text-center text-gray-500 text-xs mb-3">Download the mobile app</p>
                <div className="flex gap-3">
                  {['Google Play', 'App Store'].map(label => (
                    <button key={label}
                      onClick={handleButtonClick}
                      className="flex-1 py-2.5 rounded-xl text-xs text-gray-400 hover:text-white transition-all btn-press"
                      style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}>
                      {label}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </main>
      </section>

      {/* Stats Section */}
      <section className="stats-section relative z-10 py-16 px-6" style={{ borderTop: '1px solid rgba(255,255,255,0.06)' }}>
        <div className="max-w-5xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-8">
          {[
            { value: '500+', label: 'Active Riders', color: '#2A9D8F' },
            { value: '200+', label: 'Merchants', color: '#E76F51' },
            { value: '10k+', label: 'Customers', color: '#E9C46A' },
            { value: '4.9★', label: 'App Rating', color: '#8B5CF6' },
          ].map(({ value, label, color }) => (
            <div key={label} className="stat-item text-center">
              <p className="text-4xl font-bold mb-1" style={{ color }}>{value}</p>
              <p className="text-sm text-gray-500">{label}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="features-section relative z-10 py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <p className="text-xs font-semibold tracking-widest uppercase mb-3" style={{ color: '#2A9D8F' }}>What We Offer</p>
            <h3 className="text-4xl font-bold text-white">Platform Features</h3>
            <p className="text-gray-500 mt-4 max-w-md mx-auto text-sm leading-relaxed">
              Everything your community needs, delivered to your doorstep.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              {
                img: IMG_FOOD, icon: ShoppingBag, color: '#2A9D8F',
                title: 'Food Delivery', gradient: 'from-[#2A9D8F]/80',
                desc: 'Order from your favorite local restaurants and have freshly cooked meals delivered fast.',
              },
              {
                img: IMG_PAHAPIT, icon: Truck, color: '#E76F51',
                title: 'Pahapit Errands', gradient: 'from-[#E76F51]/80',
                desc: 'Need items bought from stores? Our riders handle your errands so you don\'t have to go out.',
              },
              {
                img: IMG_HABAL, icon: Bike, color: '#E9C46A',
                title: 'Habal-Habal', gradient: 'from-[#E9C46A]/80',
                desc: 'Book a ride with trusted local habal-habal riders for quick trips around Ubay.',
              },
            ].map(({ img, icon: Icon, color, title, desc, gradient }) => (
              <div key={title}
                className="feature-card group relative rounded-2xl overflow-hidden cursor-pointer"
                style={{ border: '1px solid rgba(255,255,255,0.07)' }}
                onMouseEnter={e => gsap.to(e.currentTarget, { y: -6, duration: 0.3, ease: 'power2.out' })}
                onMouseLeave={e => gsap.to(e.currentTarget, { y: 0, duration: 0.3, ease: 'power2.out' })}>

                {/* Image */}
                <div className="relative h-48 overflow-hidden">
                  <img src={img} alt={title}
                    className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                    style={{ filter: 'brightness(0.7) saturate(1.2)' }}
                  />
                  <div className={`absolute inset-0 bg-gradient-to-t ${gradient} to-transparent opacity-70`} />
                  <div className="absolute top-4 left-4 w-10 h-10 rounded-xl flex items-center justify-center"
                    style={{ background: `${color}30`, backdropFilter: 'blur(8px)', border: `1px solid ${color}50` }}>
                    <Icon size={18} color={color} />
                  </div>
                </div>

                {/* Content */}
                <div className="p-6" style={{ background: 'rgba(22,24,29,0.95)' }}>
                  <h4 className="text-white font-semibold text-lg mb-2">{title}</h4>
                  <p className="text-gray-500 text-sm leading-relaxed">{desc}</p>
                  <div className="mt-4 flex items-center gap-1 text-xs font-medium" style={{ color }}>
                    Learn more <ArrowRight size={13} />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="cta-section relative z-10 py-24 px-6">
        <div className="max-w-3xl mx-auto text-center">
          <div className="rounded-3xl p-12 relative overflow-hidden"
            style={{
              background: 'rgba(255,255,255,0.03)',
              border: '1px solid rgba(42,157,143,0.2)',
            }}>
            <div className="absolute inset-0 opacity-30" style={{
              background: 'radial-gradient(ellipse at center, rgba(42,157,143,0.2) 0%, transparent 70%)'
            }} />
            <div className="relative z-10">
              <h3 className="text-4xl font-bold text-white mb-4">Ready to Get Started?</h3>
              <p className="text-gray-400 mb-8 leading-relaxed">
                Join SugoBay as a rider or merchant and be part of Ubay's growing delivery community.
              </p>
              <div className="flex flex-wrap gap-4 justify-center">
                <button
                  onClick={handleButtonClick}
                  className="flex items-center gap-2 px-8 py-4 rounded-xl text-white font-semibold btn-press"
                  style={{ background: 'linear-gradient(135deg, #2A9D8F, #238b7f)', boxShadow: '0 8px 24px rgba(42,157,143,0.35)' }}>
                  <Bike size={18} /> Become a Rider
                </button>
                <button
                  onClick={handleButtonClick}
                  className="flex items-center gap-2 px-8 py-4 rounded-xl font-semibold btn-press"
                  style={{ background: 'rgba(231,111,81,0.15)', border: '1px solid rgba(231,111,81,0.3)', color: '#E76F51' }}>
                  <ShoppingBag size={18} /> Register as Merchant
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative z-10 px-6 py-10" style={{ borderTop: '1px solid rgba(255,255,255,0.06)' }}>
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
          <div>
            <h1 className="text-lg font-bold gradient-text">SugoBay</h1>
            <p className="text-xs text-gray-600 mt-1">© 2024 SugoBay. Sugo para sa tanan sa Ubay.</p>
          </div>
          <div className="flex items-center gap-6">
            {['Privacy Policy', 'Terms of Service', 'Support'].map(item => (
              <a key={item} href="#" className="text-gray-600 hover:text-gray-400 text-xs transition-colors">{item}</a>
            ))}
          </div>
        </div>
      </footer>
    </div>
  )
}
