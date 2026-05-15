import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'

interface RevenueData {
  totalFoodCommission: number
  totalFoodDeliveryShare: number
  totalPahapitErrandShare: number
  totalPahapitDeliveryShare: number
  totalIncentiveFund: number
  totalRevenue: number
  orderCount: number
  pahapitCount: number
}

type DateRange = 'all' | 'today' | '7d' | '30d' | 'custom'

export default function Revenue() {
  const [data, setData] = useState<RevenueData>({
    totalFoodCommission: 0, totalFoodDeliveryShare: 0,
    totalPahapitErrandShare: 0, totalPahapitDeliveryShare: 0,
    totalIncentiveFund: 0, totalRevenue: 0,
    orderCount: 0, pahapitCount: 0,
  })
  const [loading, setLoading] = useState(true)
  const [range, setRange] = useState<DateRange>('all')
  const [customFrom, setCustomFrom] = useState('')
  const [customTo, setCustomTo] = useState('')

  useEffect(() => { loadRevenue() }, [range, customFrom, customTo])

  function getDateFilter(): { from: string; to: string } | null {
    const now = new Date()
    const todayStr = now.toISOString().slice(0, 10)
    switch (range) {
      case 'today':
        return { from: `${todayStr}T00:00:00`, to: `${todayStr}T23:59:59` }
      case '7d': {
        const d = new Date(now)
        d.setDate(d.getDate() - 7)
        return { from: `${d.toISOString().slice(0, 10)}T00:00:00`, to: `${todayStr}T23:59:59` }
      }
      case '30d': {
        const d = new Date(now)
        d.setDate(d.getDate() - 30)
        return { from: `${d.toISOString().slice(0, 10)}T00:00:00`, to: `${todayStr}T23:59:59` }
      }
      case 'custom':
        if (customFrom && customTo) return { from: `${customFrom}T00:00:00`, to: `${customTo}T23:59:59` }
        return null
      default:
        return null
    }
  }

  async function loadRevenue() {
    setLoading(true)
    try {
      const dateFilter = getDateFilter()

      let ordersQuery = supabaseAdmin.from('orders').select('total_amount, delivery_fee, commission_amount').eq('status', 'delivered')
      let pahapitQuery = supabaseAdmin.from('pahapit_requests').select('errand_fee, delivery_fee').eq('status', 'completed')

      if (dateFilter) {
        ordersQuery = ordersQuery.gte('delivered_at', dateFilter.from).lte('delivered_at', dateFilter.to)
        pahapitQuery = pahapitQuery.gte('completed_at', dateFilter.from).lte('completed_at', dateFilter.to)
      }

      const [{ data: orders }, { data: pahapits }, { data: incentives }] = await Promise.all([
        ordersQuery,
        pahapitQuery,
        supabaseAdmin.from('incentive_fund').select('amount_added'),
      ])

      let foodComm = 0, foodDelShare = 0, pahErrand = 0, pahDel = 0, incFund = 0

      for (const o of (orders || [])) {
        foodComm += o.commission_amount || 0
        foodDelShare += (o.delivery_fee || 0) * 0.25
      }
      for (const p of (pahapits || [])) {
        pahErrand += (p.errand_fee || 50) * 0.20
        pahDel += (p.delivery_fee || 0) * 0.25
      }
      for (const i of (incentives || [])) {
        incFund += i.amount_added || 0
      }

      setData({
        totalFoodCommission: foodComm,
        totalFoodDeliveryShare: foodDelShare,
        totalPahapitErrandShare: pahErrand,
        totalPahapitDeliveryShare: pahDel,
        totalIncentiveFund: incFund,
        totalRevenue: foodComm + foodDelShare + pahErrand + pahDel,
        orderCount: orders?.length || 0,
        pahapitCount: pahapits?.length || 0,
      })
    } catch (e) { console.error(e) }
    setLoading(false)
  }

  const cards = [
    { label: 'Food Commission (10%)', value: data.totalFoodCommission, color: '#E76F51' },
    { label: 'Food Delivery Share (25%)', value: data.totalFoodDeliveryShare, color: '#2A9D8F' },
    { label: 'Pahapit Errand Share (20%)', value: data.totalPahapitErrandShare, color: '#E9C46A' },
    { label: 'Pahapit Delivery Share (25%)', value: data.totalPahapitDeliveryShare, color: '#D4AF37' },
  ]

  const ranges: { key: DateRange; label: string }[] = [
    { key: 'all', label: 'All Time' },
    { key: 'today', label: 'Today' },
    { key: '7d', label: 'Last 7 Days' },
    { key: '30d', label: 'Last 30 Days' },
    { key: 'custom', label: 'Custom' },
  ]

  if (loading) return <div className="text-gray-500">Loading revenue data...</div>

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-6">Revenue</h1>

      {/* Date Range Filter */}
      <div className="flex flex-wrap items-center gap-2 mb-6">
        {ranges.map(r => (
          <button key={r.key} onClick={() => setRange(r.key)}
            className={`px-3 py-1.5 rounded-lg text-xs ${range === r.key ? 'bg-[#2A9D8F] text-white' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34]'}`}>
            {r.label}
          </button>
        ))}
        {range === 'custom' && (
          <div className="flex items-center gap-2 ml-2">
            <input type="date" value={customFrom} onChange={e => setCustomFrom(e.target.value)}
              className="px-2 py-1.5 bg-[#23252A] border border-[#2D2F34] rounded-lg text-white text-xs focus:outline-none focus:border-[#2A9D8F]" />
            <span className="text-gray-500 text-xs">to</span>
            <input type="date" value={customTo} onChange={e => setCustomTo(e.target.value)}
              className="px-2 py-1.5 bg-[#23252A] border border-[#2D2F34] rounded-lg text-white text-xs focus:outline-none focus:border-[#2A9D8F]" />
          </div>
        )}
      </div>

      {/* Total Revenue Card */}
      <div className="bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] rounded-xl p-6 mb-8">
        <p className="text-white/70 text-sm">{range === 'all' ? 'Total Platform Revenue' : `Revenue (${ranges.find(r => r.key === range)?.label})`}</p>
        <p className="text-4xl font-bold text-white mt-1">₱{data.totalRevenue.toFixed(2)}</p>
        <div className="flex gap-6 mt-4 text-sm text-white/70">
          <span>{data.orderCount} food orders</span>
          <span>{data.pahapitCount} pahapit jobs</span>
        </div>
      </div>

      {/* Breakdown Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {cards.map(({ label, value, color }) => (
          <div key={label} className="bg-[#23252A] rounded-xl p-5 border border-[#2D2F34]">
            <p className="text-xs text-gray-500 mb-2">{label}</p>
            <p className="text-2xl font-bold" style={{ color }}>₱{value.toFixed(2)}</p>
          </div>
        ))}
      </div>

      {/* Incentive Fund */}
      <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34]">
        <h2 className="text-lg font-semibold text-white mb-2">Incentive Fund</h2>
        <p className="text-gray-400 text-sm mb-4">₱5 auto-saved from each transaction for rider bonuses</p>
        <p className="text-3xl font-bold text-[#E9C46A]">₱{data.totalIncentiveFund.toFixed(2)}</p>
      </div>
    </div>
  )
}
