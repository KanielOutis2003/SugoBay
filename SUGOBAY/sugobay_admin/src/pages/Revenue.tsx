import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

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

export default function Revenue() {
  const [data, setData] = useState<RevenueData>({
    totalFoodCommission: 0, totalFoodDeliveryShare: 0,
    totalPahapitErrandShare: 0, totalPahapitDeliveryShare: 0,
    totalIncentiveFund: 0, totalRevenue: 0,
    orderCount: 0, pahapitCount: 0,
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => { loadRevenue() }, [])

  async function loadRevenue() {
    setLoading(true)
    try {
      const { data: orders } = await supabase.from('orders').select('total_amount, delivery_fee, commission_amount').eq('status', 'delivered')
      const { data: pahapits } = await supabase.from('pahapit_requests').select('errand_fee, delivery_fee').eq('status', 'completed')
      const { data: incentives } = await supabase.from('incentive_fund').select('amount_added')

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

  if (loading) return <div className="text-gray-500">Loading revenue data...</div>

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-8">Revenue</h1>

      {/* Total Revenue Card */}
      <div className="bg-gradient-to-r from-[#2A9D8F] to-[#E76F51] rounded-xl p-6 mb-8">
        <p className="text-white/70 text-sm">Total Platform Revenue</p>
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
