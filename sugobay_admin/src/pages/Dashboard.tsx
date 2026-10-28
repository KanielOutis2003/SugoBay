import { useEffect, useState, useRef } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import { ShoppingBag, Truck, Store, Bike, Users, MapPin, RefreshCw } from 'lucide-react'
import { Map, AdvancedMarker } from '@vis.gl/react-google-maps'
import gsap from 'gsap'

interface Stats {
  totalOrders: number
  todayOrders: number
  totalPahapit: number
  todayPahapit: number
  totalMerchants: number
  pendingMerchants: number
  activeRiders: number
  totalRiders: number
  totalCustomers: number
  todayRevenue: number
}

interface OnlineRider {
  rider_id: string
  lat: number
  lng: number
  is_online: boolean
  updated_at: string
  name?: string
}

interface ActivityItem {
  id: string
  type: 'food' | 'pahapit'
  status: string
  amount: number
  customer_name: string
  created_at: string
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats>({
    totalOrders: 0, todayOrders: 0, totalPahapit: 0, todayPahapit: 0,
    totalMerchants: 0, pendingMerchants: 0, activeRiders: 0, totalRiders: 0,
    totalCustomers: 0, todayRevenue: 0,
  })
  const [recentOrders, setRecentOrders] = useState<any[]>([])
  const [recentPahapit, setRecentPahapit] = useState<any[]>([])
  const [onlineRiders, setOnlineRiders] = useState<OnlineRider[]>([])
  const [activity, setActivity] = useState<ActivityItem[]>([])
  const [loading, setLoading] = useState(true)
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const today = new Date().toISOString().slice(0, 10)

  useEffect(() => {
    loadStats()
    loadOnlineRiders()
    loadActivity()
    intervalRef.current = setInterval(loadOnlineRiders, 30000)
    return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
  }, [])

  async function loadStats() {
    setLoading(true)
    try {
      const [orders, todayOrd, pahapit, todayPah, merchants, pendingM, onlineRiderCount, totalRiderCount, customers, recent, recentPah, todayDelivered] = await Promise.all([
        supabaseAdmin.from('orders').select('id', { count: 'exact', head: true }),
        supabaseAdmin.from('orders').select('id', { count: 'exact', head: true }).gte('created_at', `${today}T00:00:00`),
        supabaseAdmin.from('pahapit_requests').select('id', { count: 'exact', head: true }),
        supabaseAdmin.from('pahapit_requests').select('id', { count: 'exact', head: true }).gte('created_at', `${today}T00:00:00`),
        supabaseAdmin.from('merchants').select('id', { count: 'exact', head: true }),
        supabaseAdmin.from('merchants').select('id', { count: 'exact', head: true }).eq('is_approved', false),
        supabaseAdmin.from('rider_locations').select('id', { count: 'exact', head: true }).eq('is_online', true),
        supabaseAdmin.from('users').select('id', { count: 'exact', head: true }).eq('role', 'rider'),
        supabaseAdmin.from('users').select('id', { count: 'exact', head: true }).eq('role', 'customer'),
        supabaseAdmin.from('orders').select('*').order('created_at', { ascending: false }).limit(5),
        supabaseAdmin.from('pahapit_requests').select('*').order('created_at', { ascending: false }).limit(5),
        supabaseAdmin.from('orders').select('total_amount, delivery_fee').gte('created_at', `${today}T00:00:00`).eq('status', 'delivered'),
      ])

      const revenue = (todayDelivered.data || []).reduce((sum: number, o: any) => sum + (o.total_amount || 0) + (o.delivery_fee || 0), 0)

      setStats({
        totalOrders: orders.count || 0,
        todayOrders: todayOrd.count || 0,
        totalPahapit: pahapit.count || 0,
        todayPahapit: todayPah.count || 0,
        totalMerchants: merchants.count || 0,
        pendingMerchants: pendingM.count || 0,
        activeRiders: onlineRiderCount.count || 0,
        totalRiders: totalRiderCount.count || 0,
        totalCustomers: customers.count || 0,
        todayRevenue: revenue,
      })
      setRecentOrders(recent.data || [])
      setRecentPahapit(recentPah.data || [])
    } catch (e) {
      console.error(e)
    }
    setLoading(false)
  }

  async function loadOnlineRiders() {
    try {
      const { data: locations } = await supabaseAdmin.from('rider_locations').select('*').eq('is_online', true)
      if (!locations || locations.length === 0) { setOnlineRiders([]); return }

      const riderIds = locations.map((l: any) => l.rider_id)
      const { data: users } = await supabaseAdmin.from('users').select('id, name').in('id', riderIds)
      const nameMap: Record<string, string> = {}
      for (const u of (users || [])) nameMap[u.id] = u.name

      setOnlineRiders(locations.map((l: any) => ({ ...l, name: nameMap[l.rider_id] || 'Unknown' })))
    } catch (e) { console.error(e) }
  }

  async function loadActivity() {
    try {
      const { data: orders } = await supabaseAdmin.from('orders').select('id, status, total_amount, customer_id, created_at')
        .gte('created_at', `${today}T00:00:00`).order('created_at', { ascending: false }).limit(10)
      const { data: pahapits } = await supabaseAdmin.from('pahapit_requests').select('id, status, budget_limit, customer_id, created_at')
        .gte('created_at', `${today}T00:00:00`).order('created_at', { ascending: false }).limit(10)

      const customerIds = new Set<string>()
      for (const o of (orders || [])) customerIds.add(o.customer_id)
      for (const p of (pahapits || [])) customerIds.add(p.customer_id)

      const nameMap: Record<string, string> = {}
      if (customerIds.size > 0) {
        const { data: users } = await supabaseAdmin.from('users').select('id, name').in('id', Array.from(customerIds))
        for (const u of (users || [])) nameMap[u.id] = u.name
      }

      const items: ActivityItem[] = [
        ...(orders || []).map((o: any) => ({ id: o.id, type: 'food' as const, status: o.status, amount: o.total_amount || 0, customer_name: nameMap[o.customer_id] || 'Customer', created_at: o.created_at })),
        ...(pahapits || []).map((p: any) => ({ id: p.id, type: 'pahapit' as const, status: p.status, amount: p.budget_limit || 0, customer_name: nameMap[p.customer_id] || 'Customer', created_at: p.created_at })),
      ]
      items.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
      setActivity(items.slice(0, 10))
    } catch (e) { console.error(e) }
  }

  function refreshAll() {
    loadStats()
    loadOnlineRiders()
    loadActivity()
  }

  const statCards = [
    { label: "Today's Orders", value: stats.todayOrders, icon: ShoppingBag, color: '#E76F51' },
    { label: "Today's Pahapit", value: stats.todayPahapit, icon: Truck, color: '#2A9D8F' },
    { label: 'Total Riders', value: stats.totalRiders, icon: Bike, color: '#E9C46A', sub: `${stats.activeRiders} online` },
    { label: 'Total Merchants', value: stats.totalMerchants, icon: Store, color: '#D4AF37' },
    { label: 'Pending Approval', value: stats.pendingMerchants, icon: Store, color: '#E76F51' },
    { label: 'Total Customers', value: stats.totalCustomers, icon: Users, color: '#2A9D8F' },
    { label: "Today's Revenue", value: `₱${stats.todayRevenue.toFixed(0)}`, icon: ShoppingBag, color: '#E9C46A' },
  ]

  const statusColor = (s: string) =>
    s === 'delivered' || s === 'completed' ? 'bg-green-500/20 text-green-400' :
    s === 'cancelled' ? 'bg-red-500/20 text-red-400' :
    'bg-yellow-500/20 text-yellow-400'

  const statCardsRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!loading) {
      gsap.from('.dash-stat-card', { y: 24, opacity: 0, stagger: 0.06, duration: 0.5, ease: 'power2.out', clearProps: 'all' })
      gsap.from('.dash-activity-item', { x: -16, opacity: 0, stagger: 0.04, duration: 0.4, ease: 'power2.out', delay: 0.3, clearProps: 'all' })
    }
  }, [loading])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 gap-3 text-gray-600">
        <div className="animate-spin rounded-full h-6 w-6 border-2 border-[#2A9D8F]/30 border-t-[#2A9D8F]" />
        Loading dashboard...
      </div>
    )
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-white">Dashboard</h1>
          <p className="text-sm text-gray-500 mt-1">Real-time overview of SugoBay operations</p>
        </div>
        <button
          onClick={refreshAll}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium btn-press"
          style={{ background: 'rgba(42,157,143,0.15)', border: '1px solid rgba(42,157,143,0.3)', color: '#2A9D8F' }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {/* Stat Cards */}
      <div ref={statCardsRef} className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4 mb-8">
        {statCards.map(({ label, value, icon: Icon, color, sub }: any) => (
          <div key={label} className="dash-stat-card premium-card p-4">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center mb-3"
              style={{ background: `${color}18`, border: `1px solid ${color}30` }}>
              <Icon size={16} color={color} />
            </div>
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-xs text-gray-500 mt-1 leading-tight">{label}</p>
            {sub && <p className="text-[10px] text-green-400 mt-1 font-medium">{sub}</p>}
          </div>
        ))}
      </div>

      {/* Live Rider Map */}
      <div className="premium-card p-6 mb-8">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-white flex items-center gap-2">
            <MapPin size={18} className="text-green-400" /> Live Rider Map
            <span className="text-xs bg-green-500/20 text-green-400 px-2 py-0.5 rounded-full ml-2">{onlineRiders.length} online</span>
          </h2>
        </div>
        <div className="rounded-lg overflow-hidden" style={{ height: 350 }}>
          <Map
            defaultCenter={onlineRiders.length > 0 ? { lat: onlineRiders[0].lat, lng: onlineRiders[0].lng } : { lat: 10.0581, lng: 124.0474 }}
            defaultZoom={14}
            style={{ width: '100%', height: '100%' }}
            mapId="sugobay-dashboard"
            disableDefaultUI={true}
            gestureHandling="greedy"
          >
            {onlineRiders.map(r => (
              <AdvancedMarker key={r.rider_id} position={{ lat: r.lat, lng: r.lng }} title={r.name}>
                <div style={{
                  background: '#2A9D8F', width: 28, height: 28, borderRadius: '50%',
                  border: '3px solid #fff', display: 'flex', alignItems: 'center',
                  justifyContent: 'center', boxShadow: '0 2px 6px rgba(0,0,0,0.4)',
                  cursor: 'pointer',
                }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5">
                    <path d="M12 2L19 21L12 17L5 21L12 2Z" />
                  </svg>
                </div>
              </AdvancedMarker>
            ))}
          </Map>
        </div>
        {onlineRiders.length === 0 && (
          <p className="text-gray-500 text-sm text-center mt-3">No riders online — map centered on Ubay</p>
        )}
      </div>

      {/* Activity Timeline */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">

        {/* Today's Activity Timeline */}
        <div className="premium-card p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Today's Activity</h2>
          {activity.length === 0 ? (
            <p className="text-gray-500 text-sm">No activity today</p>
          ) : (
            <div className="space-y-3 max-h-64 overflow-y-auto">
              {activity.map(a => (
                <div key={a.id} className="dash-activity-item flex items-center justify-between py-2 border-b border-[#2D2F34] last:border-0">
                  <div className="flex items-center gap-3">
                    <div className={`w-2 h-2 rounded-full ${a.type === 'food' ? 'bg-[#E76F51]' : 'bg-[#2A9D8F]'}`} />
                    <div>
                      <div className="flex items-center gap-2">
                        <span className={`text-xs px-1.5 py-0.5 rounded ${a.type === 'food' ? 'bg-[#E76F51]/20 text-[#E76F51]' : 'bg-[#2A9D8F]/20 text-[#2A9D8F]'}`}>
                          {a.type === 'food' ? 'Food' : 'Pahapit'}
                        </span>
                        <span className={`text-xs px-1.5 py-0.5 rounded-full ${statusColor(a.status)}`}>{a.status}</span>
                      </div>
                      <p className="text-xs text-gray-500 mt-1">{a.customer_name}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-[#E9C46A]">₱{a.amount.toFixed(0)}</p>
                    <p className="text-xs text-gray-600">{new Date(a.created_at).toLocaleTimeString()}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Food Orders */}
        <div className="premium-card p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Recent Food Orders</h2>
          {recentOrders.length === 0 ? (
            <p className="text-gray-500 text-sm">No orders yet</p>
          ) : (
            <div className="space-y-3">
              {recentOrders.map((order) => (
                <div key={order.id} className="dash-activity-item flex items-center justify-between py-2 border-b border-[#2D2F34] last:border-0">
                  <div>
                    <p className="text-sm text-white">#{order.id.slice(-6)}</p>
                    <p className="text-xs text-gray-500">{new Date(order.created_at).toLocaleString()}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-[#E9C46A]">₱{order.total_amount?.toFixed(2)}</p>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${statusColor(order.status)}`}>
                      {order.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent Pahapit */}
        <div className="premium-card p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Recent Pahapit Jobs</h2>
          {recentPahapit.length === 0 ? (
            <p className="text-gray-500 text-sm">No pahapit jobs yet</p>
          ) : (
            <div className="space-y-3">
              {recentPahapit.map((job) => (
                <div key={job.id} className="dash-activity-item flex items-center justify-between py-2 border-b border-[#2D2F34] last:border-0">
                  <div>
                    <p className="text-sm text-white">{job.store_name}</p>
                    <p className="text-xs text-gray-500 truncate max-w-[200px]">{job.items_description}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-[#E9C46A]">₱{job.budget_limit?.toFixed(2)}</p>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${statusColor(job.status)}`}>
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
