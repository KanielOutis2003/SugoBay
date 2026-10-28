import { useState, useEffect } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import {
  LayoutDashboard, ShoppingBag, Truck, Store, Bike,
  Users, DollarSign, AlertCircle, Megaphone, Tag, Settings, LogOut, Menu, X
} from 'lucide-react'
import { useAuth } from '../lib/AuthContext'
import { supabaseAdmin } from '../lib/supabase'

const navItems = [
  { path: '/', label: 'Dashboard', icon: LayoutDashboard, badgeKey: null },
  { path: '/food-orders', label: 'Food Orders', icon: ShoppingBag, badgeKey: 'activeOrders' },
  { path: '/pahapit-jobs', label: 'Pahapit Jobs', icon: Truck, badgeKey: 'activePahapit' },
  { path: '/merchants', label: 'Merchants', icon: Store, badgeKey: 'pendingMerchants' },
  { path: '/riders', label: 'Riders', icon: Bike, badgeKey: null },
  { path: '/customers', label: 'Customers', icon: Users, badgeKey: null },
  { path: '/revenue', label: 'Revenue', icon: DollarSign, badgeKey: null },
  { path: '/complaints', label: 'Complaints', icon: AlertCircle, badgeKey: 'openComplaints' },
  { path: '/announcements', label: 'Announcements', icon: Megaphone, badgeKey: null },
  { path: '/promo-codes', label: 'Promo Codes', icon: Tag, badgeKey: null },
  { path: '/settings', label: 'Settings', icon: Settings, badgeKey: null },
]

export default function Layout() {
  const { signOut } = useAuth()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [badges, setBadges] = useState<Record<string, number>>({})

  useEffect(() => {
    loadBadges()
    const interval = setInterval(loadBadges, 30000)
    return () => clearInterval(interval)
  }, [])

  async function loadBadges() {
    try {
      const [activeOrders, activePahapit, pendingMerchants, openComplaints] = await Promise.all([
        supabaseAdmin.from('orders').select('id', { count: 'exact', head: true }).not('status', 'in', '(delivered,cancelled)'),
        supabaseAdmin.from('pahapit_requests').select('id', { count: 'exact', head: true }).not('status', 'in', '(completed,cancelled)'),
        supabaseAdmin.from('merchants').select('id', { count: 'exact', head: true }).eq('is_approved', false),
        supabaseAdmin.from('complaints').select('id', { count: 'exact', head: true }).eq('status', 'open'),
      ])
      setBadges({
        activeOrders: activeOrders.count || 0,
        activePahapit: activePahapit.count || 0,
        pendingMerchants: pendingMerchants.count || 0,
        openComplaints: openComplaints.count || 0,
      })
    } catch (_) {}
  }

  const sidebarContent = (
    <>
      <div className="p-5" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        <div className="flex items-center gap-3">
          <img src="/icon.png" alt="SugoBay" className="w-9 h-9 rounded-xl"
            onError={e => { (e.target as HTMLImageElement).style.display = 'none' }} />
          <div>
            <h1 className="text-base font-bold gradient-text">SugoBay Admin</h1>
            <p className="text-[10px] text-gray-600 mt-0.5">Sugo para sa tanan sa Ubay</p>
          </div>
        </div>
      </div>
      <nav className="flex-1 overflow-y-auto py-3 px-2">
        {navItems.map(({ path, label, icon: Icon, badgeKey }) => {
          const count = badgeKey ? (badges[badgeKey] || 0) : 0
          return (
            <NavLink
              key={path} to={path} end={path === '/'}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm transition-all mb-0.5 ${
                  isActive ? 'text-[#2A9D8F] font-semibold' : 'text-gray-500 hover:text-gray-300'
                }`
              }
              style={({ isActive }) => isActive
                ? { background: 'rgba(42,157,143,0.12)', border: '1px solid rgba(42,157,143,0.2)' }
                : { border: '1px solid transparent' }}
            >
              <Icon size={16} />
              <span className="flex-1">{label}</span>
              {count > 0 && (
                <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full min-w-[20px] text-center ${
                  badgeKey === 'openComplaints' ? 'bg-red-500 text-white' :
                  badgeKey === 'pendingMerchants' ? 'bg-[#E76F51] text-white' :
                  'bg-[#2A9D8F]/20 text-[#2A9D8F]'
                }`}>
                  {count}
                </span>
              )}
            </NavLink>
          )
        })}
      </nav>
      <div className="p-4" style={{ borderTop: '1px solid rgba(255,255,255,0.06)' }}>
        <button onClick={signOut}
          className="flex items-center gap-2 w-full px-4 py-2.5 rounded-xl text-sm text-gray-500 hover:text-red-400 transition-colors mb-2"
          style={{ border: '1px solid transparent' }}
          onMouseEnter={e => (e.currentTarget.style.background = 'rgba(239,68,68,0.07)')}
          onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}>
          <LogOut size={15} /> Sign Out
        </button>
        <p className="text-[10px] text-gray-700 px-4">SugoBay v3.0.0</p>
      </div>
    </>
  )

  return (
    <div className="flex h-screen" style={{ background: '#0F1117' }}>
      {/* Mobile top bar */}
      <div className="lg:hidden fixed top-0 left-0 right-0 z-40 flex items-center px-4 h-14"
        style={{ background: 'rgba(22,24,29,0.95)', backdropFilter: 'blur(20px)', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        <button onClick={() => setSidebarOpen(true)} className="text-gray-400 hover:text-white p-1 relative">
          <Menu size={22} />
          {(badges.pendingMerchants > 0 || badges.openComplaints > 0) && (
            <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-red-500 rounded-full" />
          )}
        </button>
        <h1 className="ml-3 text-sm font-bold gradient-text">SugoBay Admin</h1>
      </div>

      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div className="lg:hidden fixed inset-0 z-50 flex">
          <div className="w-64 flex flex-col shadow-2xl" style={{ background: '#16181D', borderRight: '1px solid rgba(255,255,255,0.07)' }}>
            <div className="flex justify-end p-3">
              <button onClick={() => setSidebarOpen(false)} className="text-gray-400 hover:text-white w-8 h-8 flex items-center justify-center rounded-lg"
                style={{ background: 'rgba(255,255,255,0.05)' }}>
                <X size={18} />
              </button>
            </div>
            {sidebarContent}
          </div>
          <div className="flex-1" style={{ background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)' }} onClick={() => setSidebarOpen(false)} />
        </div>
      )}

      {/* Desktop sidebar */}
      <aside className="hidden lg:flex w-64 flex-col flex-shrink-0" style={{ background: '#16181D', borderRight: '1px solid rgba(255,255,255,0.06)' }}>
        {sidebarContent}
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-y-auto pt-14 lg:pt-0">
        <div className="p-4 md:p-6 lg:p-8">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
