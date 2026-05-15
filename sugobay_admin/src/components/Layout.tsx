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
      <div className="p-6 border-b border-[#2D2F34]">
        <div className="flex items-center gap-3">
          <img src="/icon.png" alt="SugoBay" className="w-10 h-10 rounded-full" />
          <div>
            <h1 className="text-lg font-bold bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] bg-clip-text text-transparent">
              SugoBay Admin
            </h1>
            <p className="text-xs text-gray-500">Sugo para sa tanan sa Ubay</p>
          </div>
        </div>
      </div>
      <nav className="flex-1 overflow-y-auto py-4">
        {navItems.map(({ path, label, icon: Icon, badgeKey }) => {
          const count = badgeKey ? (badges[badgeKey] || 0) : 0
          return (
            <NavLink
              key={path}
              to={path}
              end={path === '/'}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-6 py-3 text-sm transition-colors ${
                  isActive
                    ? 'text-[#2A9D8F] bg-[#2A9D8F]/10 border-r-2 border-[#2A9D8F]'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`
              }
            >
              <Icon size={18} />
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
      <div className="p-4 border-t border-[#2D2F34]">
        <button
          onClick={signOut}
          className="flex items-center gap-2 text-gray-400 hover:text-red-400 text-sm transition-colors w-full mb-3"
        >
          <LogOut size={16} />
          Sign Out
        </button>
        <p className="text-xs text-gray-500">SugoBay v3.0.0</p>
      </div>
    </>
  )

  return (
    <div className="flex h-screen bg-[#1A1C20]">
      {/* Mobile top bar */}
      <div className="lg:hidden fixed top-0 left-0 right-0 z-40 bg-[#23252A] border-b border-[#2D2F34] flex items-center px-4 h-14">
        <button onClick={() => setSidebarOpen(true)} className="text-gray-400 hover:text-white p-1 relative">
          <Menu size={22} />
          {(badges.pendingMerchants > 0 || badges.openComplaints > 0) && (
            <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-red-500 rounded-full" />
          )}
        </button>
        <h1 className="ml-3 text-sm font-bold bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] bg-clip-text text-transparent">
          SugoBay Admin
        </h1>
      </div>

      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div className="lg:hidden fixed inset-0 z-50 flex">
          <div className="w-64 bg-[#23252A] flex flex-col shadow-2xl">
            <div className="flex justify-end p-3">
              <button onClick={() => setSidebarOpen(false)} className="text-gray-400 hover:text-white">
                <X size={20} />
              </button>
            </div>
            {sidebarContent}
          </div>
          <div className="flex-1 bg-black/50" onClick={() => setSidebarOpen(false)} />
        </div>
      )}

      {/* Desktop sidebar */}
      <aside className="hidden lg:flex w-64 bg-[#23252A] border-r border-[#2D2F34] flex-col flex-shrink-0">
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
