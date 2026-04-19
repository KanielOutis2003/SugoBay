import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { Order } from '../lib/supabase'

export default function FoodOrders() {
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')

  useEffect(() => { loadOrders() }, [filter])

  async function loadOrders() {
    setLoading(true)
    let query = supabase.from('orders').select('*').order('created_at', { ascending: false }).limit(100)
    if (filter !== 'all') query = query.eq('status', filter)
    const { data } = await query
    setOrders(data || [])
    setLoading(false)
  }

  async function updateStatus(id: string, status: string) {
    await supabase.from('orders').update({ status }).eq('id', id)
    loadOrders()
  }

  async function reassignRider(orderId: string) {
    const riderId = prompt('Enter new rider ID:')
    if (!riderId) return
    await supabase.from('orders').update({ rider_id: riderId }).eq('id', orderId)
    loadOrders()
  }

  const statuses = ['all', 'pending', 'accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'delivered', 'cancelled']

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Food Orders</h1>
        <button onClick={loadOrders} className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm">Refresh</button>
      </div>

      {/* Filters */}
      <div className="flex gap-2 mb-6 flex-wrap">
        {statuses.map(s => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs capitalize ${
              filter === s ? 'bg-[#2A9D8F] text-white' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34]'
            }`}
          >
            {s.replace('_', ' ')}
          </button>
        ))}
      </div>

      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : orders.length === 0 ? (
        <p className="text-gray-500">No orders found</p>
      ) : (
        <div className="bg-[#23252A] rounded-xl border border-[#2D2F34] overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[#2D2F34] text-gray-400">
                <th className="text-left p-4">Order ID</th>
                <th className="text-left p-4">Status</th>
                <th className="text-left p-4">Total</th>
                <th className="text-left p-4">Delivery Fee</th>
                <th className="text-left p-4">Payment</th>
                <th className="text-left p-4">Address</th>
                <th className="text-left p-4">Created</th>
                <th className="text-left p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {orders.map(order => (
                <tr key={order.id} className="border-b border-[#2D2F34] hover:bg-white/5">
                  <td className="p-4 text-[#2A9D8F] font-mono">#{order.id.slice(-6)}</td>
                  <td className="p-4">
                    <span className={`px-2 py-1 rounded-full text-xs ${
                      order.status === 'delivered' ? 'bg-green-500/20 text-green-400' :
                      order.status === 'cancelled' ? 'bg-red-500/20 text-red-400' :
                      'bg-yellow-500/20 text-yellow-400'
                    }`}>
                      {order.status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="p-4 text-[#E9C46A]">₱{order.total_amount.toFixed(2)}</td>
                  <td className="p-4 text-gray-300">₱{order.delivery_fee.toFixed(2)}</td>
                  <td className="p-4 text-gray-300 uppercase">{order.payment_method}</td>
                  <td className="p-4 text-gray-400 max-w-[200px] truncate">{order.delivery_address}</td>
                  <td className="p-4 text-gray-400">{new Date(order.created_at).toLocaleDateString()}</td>
                  <td className="p-4">
                    <div className="flex gap-2">
                      {order.status !== 'delivered' && order.status !== 'cancelled' && (
                        <button onClick={() => updateStatus(order.id, 'cancelled')} className="text-xs text-red-400 hover:text-red-300">Cancel</button>
                      )}
                      {order.rider_id && order.status !== 'delivered' && (
                        <button onClick={() => reassignRider(order.id)} className="text-xs text-[#2A9D8F] hover:text-[#2A9D8F]/80">Reassign</button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
