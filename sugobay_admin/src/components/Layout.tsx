import { NavLink, Outlet } from 'react-router-dom'
import {
  LayoutDashboard, ShoppingBag, Truck, Store, Bike,
  Users, DollarSign, AlertCircle, Megaphone, Settings
} from 'lucide-react'

const navItems = [
  { path: '/', label: 'Dashboard', icon: LayoutDashboard },
  { path: '/food-orders', label: 'Food Orders', icon: ShoppingBag },
  { path: '/pahapit-jobs', label: 'Pahapit Jobs', icon: Truck },
  { path: '/merchants', label: 'Merchants', icon: Store },
  { path: '/riders', label: 'Riders', icon: Bike },
  { path: '/customers', label: 'Customers', icon: Users },
  { path: '/revenue', label: 'Revenue', icon: DollarSign },
  { path: '/complaints', label: 'Complaints', icon: AlertCircle },
  { path: '/announcements', label: 'Announcements', icon: Megaphone },
  { path: '/settings', label: 'Settings', icon: Settings },
]

export default function Layout() {
  return (
    <div className="flex h-screen bg-[#1A1C20]">
      {/* Sidebar */}
      <aside className="w-64 bg-[#23252A] border-r border-[#2D2F34] flex flex-col">
        <div className="p-6 border-b border-[#2D2F34]">
          <h1 className="text-xl font-bold bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] bg-clip-text text-transparent">
            SugoBay Admin
          </h1>
          <p className="text-xs text-gray-500 mt-1">Sugo para sa tanan sa Ubay</p>
        </div>
        <nav className="flex-1 overflow-y-auto py-4">
          {navItems.map(({ path, label, icon: Icon }) => (
            <NavLink
              key={path}
              to={path}
              end={path === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 px-6 py-3 text-sm transition-colors ${
                  isActive
                    ? 'text-[#2A9D8F] bg-[#2A9D8F]/10 border-r-2 border-[#2A9D8F]'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="p-4 border-t border-[#2D2F34] text-xs text-gray-500">
          SugoBay v2.0
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-y-auto">
        <div className="p-8">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
