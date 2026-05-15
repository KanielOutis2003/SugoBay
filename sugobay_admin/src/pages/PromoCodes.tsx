import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'

interface PromoCode {
  id: string
  code: string
  description: string | null
  discount_type: 'fixed' | 'percent'
  discount_value: number
  min_order_amount: number
  max_uses: number | null
  current_uses: number
  is_active: boolean
  expires_at: string | null
  created_at: string
}

export default function PromoCodes() {
  const [promos, setPromos] = useState<PromoCode[]>([])
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({
    code: '',
    description: '',
    discount_type: 'fixed' as 'fixed' | 'percent',
    discount_value: 0,
    min_order_amount: 0,
    max_uses: '',
    expires_at: '',
  })

  useEffect(() => { loadPromos() }, [])

  async function loadPromos() {
    setLoading(true)
    const { data } = await supabaseAdmin.from('promo_codes').select('*').order('created_at', { ascending: false })
    setPromos(data || [])
    setLoading(false)
  }

  async function createPromo() {
    if (!form.code.trim()) return
    await supabaseAdmin.from('promo_codes').insert({
      code: form.code.trim().toUpperCase(),
      description: form.description || null,
      discount_type: form.discount_type,
      discount_value: form.discount_value,
      min_order_amount: form.min_order_amount,
      max_uses: form.max_uses ? parseInt(form.max_uses) : null,
      expires_at: form.expires_at || null,
    })
    setForm({ code: '', description: '', discount_type: 'fixed', discount_value: 0, min_order_amount: 0, max_uses: '', expires_at: '' })
    setShowForm(false)
    loadPromos()
  }

  async function toggleActive(id: string, current: boolean) {
    await supabaseAdmin.from('promo_codes').update({ is_active: !current }).eq('id', id)
    loadPromos()
  }

  async function deletePromo(id: string) {
    await supabaseAdmin.from('promo_codes').delete().eq('id', id)
    loadPromos()
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Promo Codes</h1>
        <div className="flex gap-2">
          <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm">
            {showForm ? 'Cancel' : '+ New Promo'}
          </button>
          <button onClick={loadPromos} className="px-4 py-2 bg-[#23252A] text-gray-300 rounded-lg text-sm border border-[#2D2F34] hover:bg-[#2D2F34]">Refresh</button>
        </div>
      </div>

      {showForm && (
        <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34] mb-6">
          <h2 className="text-lg font-semibold text-white mb-4">Create Promo Code</h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-gray-400 mb-1">Code</label>
              <input value={form.code} onChange={e => setForm({ ...form, code: e.target.value })} placeholder="e.g. WELCOME50" className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm" />
            </div>
            <div>
              <label className="block text-xs text-gray-400 mb-1">Description</label>
              <input value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} placeholder="Optional description" className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm" />
            </div>
            <div>
              <label className="block text-xs text-gray-400 mb-1">Discount Type</label>
              <select value={form.discount_type} onChange={e => setForm({ ...form, discount_type: e.target.value as 'fixed' | 'percent' })} className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm">
                <option value="fixed">Fixed Amount</option>
                <option value="percent">Percentage</option>
              </select>
            </div>
            <div>
              <label className="block text-xs text-gray-400 mb-1">Discount Value</label>
              <input type="number" value={form.discount_value} onChange={e => setForm({ ...form, discount_value: parseFloat(e.target.value) || 0 })} className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm" />
            </div>
            <div>
              <label className="block text-xs text-gray-400 mb-1">Min Order Amount</label>
              <input type="number" value={form.min_order_amount} onChange={e => setForm({ ...form, min_order_amount: parseFloat(e.target.value) || 0 })} className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm" />
            </div>
            <div>
              <label className="block text-xs text-gray-400 mb-1">Max Uses (empty = unlimited)</label>
              <input type="number" value={form.max_uses} onChange={e => setForm({ ...form, max_uses: e.target.value })} placeholder="Unlimited" className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm" />
            </div>
            <div>
              <label className="block text-xs text-gray-400 mb-1">Expires At (optional)</label>
              <input type="datetime-local" value={form.expires_at} onChange={e => setForm({ ...form, expires_at: e.target.value })} className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm" />
            </div>
            <div className="flex items-end">
              <button onClick={createPromo} className="px-6 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm">Create</button>
            </div>
          </div>
        </div>
      )}

      {loading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-[#23252A] rounded-xl border border-[#2D2F34] overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[#2D2F34] text-gray-400">
                <th className="text-left p-4">Code</th>
                <th className="text-left p-4">Type</th>
                <th className="text-left p-4">Value</th>
                <th className="text-left p-4">Min Order</th>
                <th className="text-left p-4">Uses</th>
                <th className="text-left p-4">Status</th>
                <th className="text-left p-4">Expires</th>
                <th className="text-left p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {promos.map(p => (
                <tr key={p.id} className="border-b border-[#2D2F34] hover:bg-white/5">
                  <td className="p-4">
                    <span className="text-[#E9C46A] font-mono font-bold">{p.code}</span>
                    {p.description && <p className="text-xs text-gray-500 mt-1">{p.description}</p>}
                  </td>
                  <td className="p-4 text-gray-300">{p.discount_type === 'percent' ? 'Percentage' : 'Fixed'}</td>
                  <td className="p-4 text-white">{p.discount_type === 'percent' ? `${p.discount_value}%` : `₱${p.discount_value}`}</td>
                  <td className="p-4 text-gray-300">₱{p.min_order_amount}</td>
                  <td className="p-4 text-gray-300">{p.current_uses}/{p.max_uses ?? '∞'}</td>
                  <td className="p-4">
                    <span className={`px-2 py-1 rounded-full text-xs ${p.is_active ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                      {p.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="p-4 text-gray-400 text-xs">
                    {p.expires_at ? new Date(p.expires_at).toLocaleDateString() : 'Never'}
                  </td>
                  <td className="p-4">
                    <div className="flex gap-2">
                      <button onClick={() => toggleActive(p.id, p.is_active)} className={`text-xs ${p.is_active ? 'text-red-400' : 'text-green-400'}`}>
                        {p.is_active ? 'Disable' : 'Enable'}
                      </button>
                      <button onClick={() => deletePromo(p.id)} className="text-xs text-red-400">Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
              {promos.length === 0 && (
                <tr><td colSpan={8} className="p-8 text-center text-gray-500">No promo codes yet</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
