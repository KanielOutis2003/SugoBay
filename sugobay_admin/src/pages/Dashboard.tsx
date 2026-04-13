import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { ShoppingBag, Truck, Store, Bike, Users } from 'lucide-react'

interface Stats {
  totalOrders: number
  todayOrders: number
  totalPahapit: number
  todayPahapit: number
  totalMerchants: number
  pendingMerchants: number
  activeRiders: number
  totalCustomers: number
  todayRevenue: number
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats>({
    totalOrders: 0, todayOrders: 0, totalPahapit: 0, todayPahapit: 0,
    totalMerchants: 0, pendingMerchants: 0, activeRiders: 0,
    totalCustomers: 0, todayRevenue: 0,
  })
  const [recentOrders, setRecentOrders] = useState<any[]>([])
  const [recentPahapit, setRecentPahapit] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  const today = new Date().toISOString().slice(0, 10)

  useEffect(() => {
    loadStats()
  }, [])

  async function loadStats() {
    setLoading(true)
    try {
      const [orders, todayOrd, pahapit, todayPah, merchants, pendingM, riders, customers, recent, recentPah] = await Promise.all([
        supabase.from('orders').select('id', { count: 'exact', head: true }),
        supabase.from('orders').select('id', { count: 'exact', head: true }).gte('created_at', `${today}T00:00:00`),
        supabase.from('pahapit_requests').select('id', { count: 'exact', head: true }),
        supabase.from('pahapit_requests').select('id', { count: 'exact', head: true }).gte('created_at', `${today}T00:00:00`),
        supabase.from('merchants').select('id', { count: 'exact', head: true }).eq('is_approved', true),
        supabase.from('merchants').select('id', { count: 'exact', head: true }).eq('is_approved', false),
        supabase.from('rider_locations').select('id', { count: 'exact', head: true }).eq('is_online', true),
        supabase.from('users').select('id', { count: 'exact', head: true }).eq('role', 'customer'),
        supabase.from('orders').select('*').order('created_at', { ascending: false }).limit(5),
        supabase.from('pahapit_requests').select('*').order('created_at', { ascending: false }).limit(5),
      ])

      setStats({
        totalOrders: orders.count || 0,
        todayOrders: todayOrd.count || 0,
        totalPahapit: pahapit.count || 0,
        todayPahapit: todayPah.count || 0,
        totalMerchants: merchants.count || 0,
        pendingMerchants: pendingM.count || 0,
        activeRiders: riders.count || 0,
        totalCustomers: customers.count || 0,
        todayRevenue: 0,
      })
      setRecentOrders(recent.data || [])
      setRecentPahapit(recentPah.data || [])
    } catch (e) {
      console.error(e)
    }
    setLoading(false)
  }

  const statCards = [
    { label: "Today's Orders", value: stats.todayOrders, icon: ShoppingBag, color: '#E76F51' },
    { label: "Today's Pahapit", value: stats.todayPahapit, icon: Truck, color: '#2A9D8F' },
    { label: 'Active Riders', value: stats.activeRiders, icon: Bike, color: '#E9C46A' },
    { label: 'Total Merchants', value: stats.totalMerchants, icon: Store, color: '#D4AF37' },
    { label: 'Pending Approval', value: stats.pendingMerchants, icon: Store, color: '#E76F51' },
    { label: 'Total Customers', value: stats.totalCustomers, icon: Users, color: '#2A9D8F' },
  ]

  if (loading) {
    return <div className="flex items-center justify-center h-64 text-gray-400">Loading dashboard...</div>
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-2xl font-bold text-white">Dashboard</h1>
        <button onClick={loadStats} className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm hover:bg-[#2A9D8F]/80">
          Refresh
        </button>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
        {statCards.map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="bg-[#23252A] rounded-xl p-4 border border-[#2D2F34]">
            <Icon size={20} color={color} className="mb-2" />
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-xs text-gray-500 mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Food Orders */}
        <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34]">
          <h2 className="text-lg font-semibold text-white mb-4">Recent Food Orders</h2>
          {recentOrders.length === 0 ? (
            <p className="text-gray-500 text-sm">No orders yet</p>
          ) : (
            <div className="space-y-3">
              {recentOrders.map((order) => (
                <div key={order.id} className="flex items-center justify-between py-2 border-b border-[#2D2F34] last:border-0">
                  <div>
                    <p className="text-sm text-white">#{order.id.slice(-6)}</p>
                    <p className="text-xs text-gray-500">{new Date(order.created_at).toLocaleString()}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-[#E9C46A]">₱{order.total_amount?.toFixed(2)}</p>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${
                      order.status === 'delivered' ? 'bg-green-500/20 text-green-400' :
                      order.status === 'cancelled' ? 'bg-red-500/20 text-red-400' :
                      'bg-yellow-500/20 text-yellow-400'
                    }`}>
                      {order.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent Pahapit */}
        <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34]">
          <h2 className="text-lg font-semibold text-white mb-4">Recent Pahapit Jobs</h2>
          {recentPahapit.length === 0 ? (
            <p className="text-gray-500 text-sm">No pahapit jobs yet</p>
          ) : (
            <div className="space-y-3">
              {recentPahapit.map((job) => (
                <div key={job.id} className="flex items-center justify-between py-2 border-b border-[#2D2F34] last:border-0">
                  <div>
                    <p className="text-sm text-white">{job.store_name}</p>
                    <p className="text-xs text-gray-500 truncate max-w-[200px]">{job.items_description}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-[#E9C46A]">₱{job.budget_limit?.toFixed(2)}</p>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${
                      job.status === 'completed' ? 'bg-green-500/20 text-green-400' :
                      job.status === 'cancelled' ? 'bg-red-500/20 text-red-400' :
                      'bg-yellow-500/20 text-yellow-400'
                    }`}>
                      {job.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
