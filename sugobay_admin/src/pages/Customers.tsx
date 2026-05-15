import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import type { User } from '../lib/supabase'
import { exportToCsv } from '../lib/csvExport'

interface OrderHistoryItem {
  id: string
  type: 'food' | 'pahapit'
  status: string
  amount: number
  created_at: string
  detail: string
}

export default function Customers() {
  const [customers, setCustomers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [selectedCustomer, setSelectedCustomer] = useState<User | null>(null)
  const [orderHistory, setOrderHistory] = useState<OrderHistoryItem[]>([])
  const [historyLoading, setHistoryLoading] = useState(false)

  useEffect(() => { loadCustomers() }, [])

  async function loadCustomers() {
    setLoading(true)
    const { data } = await supabaseAdmin.from('users').select('*').eq('role', 'customer').order('created_at', { ascending: false })
    setCustomers(data || [])
    setLoading(false)
  }

  async function toggleActive(id: string, current: boolean) {
    await supabaseAdmin.from('users').update({ is_active: !current }).eq('id', id)
    loadCustomers()
  }

  async function viewHistory(customer: User) {
    setSelectedCustomer(customer)
    setHistoryLoading(true)

    const [{ data: orders }, { data: pahapits }] = await Promise.all([
      supabaseAdmin.from('orders').select('id, status, total_amount, created_at, delivery_address').eq('customer_id', customer.id).order('created_at', { ascending: false }).limit(20),
      supabaseAdmin.from('pahapit_requests').select('id, status, budget_limit, created_at, store_name').eq('customer_id', customer.id).order('created_at', { ascending: false }).limit(20),
    ])

    const items: OrderHistoryItem[] = [
      ...(orders || []).map((o: any) => ({ id: o.id, type: 'food' as const, status: o.status, amount: o.total_amount || 0, created_at: o.created_at, detail: o.delivery_address || '' })),
      ...(pahapits || []).map((p: any) => ({ id: p.id, type: 'pahapit' as const, status: p.status, amount: p.budget_limit || 0, created_at: p.created_at, detail: p.store_name || '' })),
    ]
    items.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    setOrderHistory(items)
    setHistoryLoading(false)
  }

  const filtered = customers.filter(c =>
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.phone.includes(search)
  )

  const statusColor = (s: string) =>
    s === 'delivered' || s === 'completed' ? 'bg-green-500/20 text-green-400' :
    s === 'cancelled' ? 'bg-red-500/20 text-red-400' :
    'bg-yellow-500/20 text-yellow-400'

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Customers</h1>
        <div className="flex items-center gap-2">
          <button onClick={() => exportToCsv('customers', customers)} className="px-4 py-2 bg-[#23252A] text-gray-300 rounded-lg text-sm border border-[#2D2F34] hover:bg-[#2D2F34]">Export CSV</button>
          <span className="text-gray-400 text-sm">{customers.length} total</span>
        </div>
      </div>

      <input
        type="text" placeholder="Search by name or phone..."
        value={search} onChange={e => setSearch(e.target.value)}
        className="w-full mb-6 px-4 py-3 bg-[#23252A] border border-[#2D2F34] rounded-xl text-white text-sm placeholder:text-gray-500 focus:outline-none focus:border-[#2A9D8F]"
      />

      {loading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-[#23252A] rounded-xl border border-[#2D2F34] overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[#2D2F34] text-gray-400">
                <th className="text-left p-4">Name</th>
                <th className="text-left p-4">Phone</th>
                <th className="text-left p-4">Email</th>
                <th className="text-left p-4">Status</th>
                <th className="text-left p-4">Joined</th>
                <th className="text-left p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(c => (
                <tr key={c.id} className="border-b border-[#2D2F34] hover:bg-white/5">
                  <td className="p-4 text-white">{c.name}</td>
                  <td className="p-4 text-gray-300">{c.phone}</td>
                  <td className="p-4 text-gray-400">{c.email || '-'}</td>
                  <td className="p-4">
                    <span className={`px-2 py-1 rounded-full text-xs ${c.is_active ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                      {c.is_active ? 'Active' : 'Banned'}
                    </span>
                  </td>
                  <td className="p-4 text-gray-400">{new Date(c.created_at).toLocaleDateString()}</td>
                  <td className="p-4 flex gap-2">
                    <button onClick={() => viewHistory(c)} className="text-xs text-[#2A9D8F] hover:underline">History</button>
                    <button onClick={() => toggleActive(c.id, c.is_active)} className={`text-xs ${c.is_active ? 'text-red-400' : 'text-green-400'}`}>
                      {c.is_active ? 'Ban' : 'Unban'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Order History Modal */}
      {selectedCustomer && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setSelectedCustomer(null)}>
          <div className="bg-[#23252A] rounded-xl p-6 max-w-lg w-full mx-4 border border-[#2D2F34] max-h-[80vh] flex flex-col" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-white mb-1">Order History</h2>
            <p className="text-sm text-gray-400 mb-4">{selectedCustomer.name} — {selectedCustomer.phone}</p>

            {historyLoading ? (
              <p className="text-gray-500 text-sm">Loading...</p>
            ) : orderHistory.length === 0 ? (
              <p className="text-gray-500 text-sm">No orders found</p>
            ) : (
              <div className="space-y-3 overflow-y-auto flex-1">
                {orderHistory.map(item => (
                  <div key={item.id} className="flex items-center justify-between py-2 border-b border-[#2D2F34] last:border-0">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className={`text-xs px-1.5 py-0.5 rounded ${item.type === 'food' ? 'bg-[#E76F51]/20 text-[#E76F51]' : 'bg-[#2A9D8F]/20 text-[#2A9D8F]'}`}>
                          {item.type === 'food' ? 'Food' : 'Pahapit'}
                        </span>
                        <span className={`text-xs px-1.5 py-0.5 rounded-full ${statusColor(item.status)}`}>{item.status}</span>
                      </div>
                      <p className="text-xs text-gray-500 mt-1 truncate max-w-[250px]">{item.detail}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm text-[#E9C46A]">₱{item.amount.toFixed(0)}</p>
                      <p className="text-xs text-gray-600">{new Date(item.created_at).toLocaleDateString()}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}

            <button onClick={() => setSelectedCustomer(null)} className="mt-4 w-full py-2 bg-[#2D2F34] text-white rounded-lg text-sm">Close</button>
          </div>
        </div>
      )}
    </div>
  )
}
