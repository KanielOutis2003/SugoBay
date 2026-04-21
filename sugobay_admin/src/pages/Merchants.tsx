import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { Merchant } from '../lib/supabase'

export default function Merchants() {
  const [merchants, setMerchants] = useState<Merchant[]>([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState<'approved' | 'pending'>('pending')

  useEffect(() => { loadMerchants() }, [tab])

  async function loadMerchants() {
    setLoading(true)
    const { data } = await supabase.from('merchants').select('*')
      .eq('is_approved', tab === 'approved')
      .order('created_at', { ascending: false })
    setMerchants(data || [])
    setLoading(false)
  }

  async function approve(id: string) {
    // Get the merchant's user_id to confirm their email
    const { data: merchant } = await supabase.from('merchants').select('user_id').eq('id', id).single()

    // Approve the merchant
    await supabase.from('merchants').update({ is_approved: true, is_active: true }).eq('id', id)

    // Confirm their email in auth.users so they can sign in
    if (merchant?.user_id) {
      await supabase.auth.admin.updateUserById(merchant.user_id, {
        email_confirm: true,
      })
    }

    loadMerchants()
  }

  async function reject(id: string) {
    if (!confirm('Reject this merchant?')) return
    await supabase.from('merchants').delete().eq('id', id)
    loadMerchants()
  }

  async function suspend(id: string, active: boolean) {
    await supabase.from('merchants').update({ is_active: !active }).eq('id', id)
    loadMerchants()
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-6">Merchants</h1>

      <div className="flex gap-3 mb-6">
        <button onClick={() => setTab('pending')} className={`px-4 py-2 rounded-lg text-sm ${tab === 'pending' ? 'bg-[#E76F51] text-white' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34]'}`}>
          Pending Approval
        </button>
        <button onClick={() => setTab('approved')} className={`px-4 py-2 rounded-lg text-sm ${tab === 'approved' ? 'bg-[#2A9D8F] text-white' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34]'}`}>
          Approved
        </button>
      </div>

      {loading ? <p className="text-gray-500">Loading...</p> : merchants.length === 0 ? (
        <p className="text-gray-500">No {tab} merchants</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {merchants.map(m => (
            <div key={m.id} className="bg-[#23252A] rounded-xl p-5 border border-[#2D2F34]">
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-white font-semibold">{m.shop_name}</h3>
                <span className={`text-xs px-2 py-0.5 rounded-full ${m.is_active ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                  {m.is_active ? 'Active' : 'Suspended'}
                </span>
              </div>
              <p className="text-gray-400 text-sm capitalize mb-1">{m.category}</p>
              <p className="text-gray-500 text-xs mb-2">{m.address}</p>
              <div className="flex items-center gap-4 text-xs text-gray-400 mb-4">
                <span>⭐ {m.rating.toFixed(1)}</span>
                <span>{m.total_orders} orders</span>
                <span>{m.is_open ? '🟢 Open' : '🔴 Closed'}</span>
              </div>
              <div className="flex gap-2">
                {tab === 'pending' ? (
                  <>
                    <button onClick={() => approve(m.id)} className="flex-1 py-2 bg-[#2A9D8F] text-white rounded-lg text-xs hover:bg-[#2A9D8F]/80">Approve</button>
                    <button onClick={() => reject(m.id)} className="flex-1 py-2 bg-red-500/20 text-red-400 rounded-lg text-xs hover:bg-red-500/30">Reject</button>
                  </>
                ) : (
                  <button onClick={() => suspend(m.id, m.is_active)} className={`flex-1 py-2 rounded-lg text-xs ${m.is_active ? 'bg-red-500/20 text-red-400' : 'bg-green-500/20 text-green-400'}`}>
                    {m.is_active ? 'Suspend' : 'Reactivate'}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
