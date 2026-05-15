import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import type { Merchant } from '../lib/supabase'
import { Store, CheckCircle, Clock, RefreshCw } from 'lucide-react'

const planColors: Record<string, string> = {
  free: '#6B7280',
  basic: '#3B82F6',
  standard: '#2A9D8F',
  premium: '#D4AF37',
}

export default function Merchants() {
  const [merchants, setMerchants] = useState<Merchant[]>([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState<'approved' | 'pending'>('pending')
  const [pendingCount, setPendingCount] = useState(0)
  const [approvedCount, setApprovedCount] = useState(0)
  const [showSubModal, setShowSubModal] = useState(false)
  const [selectedMerchant, setSelectedMerchant] = useState<Merchant | null>(null)
  const [subPlan, setSubPlan] = useState('free')
  const [subExpiry, setSubExpiry] = useState('')
  const [subSaving, setSubSaving] = useState(false)

  useEffect(() => { loadMerchants() }, [tab])

  async function loadMerchants() {
    setLoading(true)
    const [{ data }, { count: pCount }, { count: aCount }] = await Promise.all([
      supabaseAdmin.from('merchants').select('*')
        .eq('is_approved', tab === 'approved')
        .order('created_at', { ascending: false }),
      supabaseAdmin.from('merchants').select('id', { count: 'exact', head: true }).eq('is_approved', false),
      supabaseAdmin.from('merchants').select('id', { count: 'exact', head: true }).eq('is_approved', true),
    ])
    setMerchants(data || [])
    setPendingCount(pCount || 0)
    setApprovedCount(aCount || 0)
    setLoading(false)
  }

  async function approve(id: string) {
    const { data: merchant } = await supabaseAdmin.from('merchants').select('user_id').eq('id', id).single()
    await supabaseAdmin.from('merchants').update({ is_approved: true, is_active: true }).eq('id', id)
    if (merchant?.user_id) {
      await supabaseAdmin.auth.admin.updateUserById(merchant.user_id, { email_confirm: true })
    }
    loadMerchants()
  }

  async function reject(id: string) {
    if (!confirm('Reject and delete this merchant application?')) return
    await supabaseAdmin.from('merchants').delete().eq('id', id)
    loadMerchants()
  }

  async function suspend(id: string, active: boolean) {
    await supabaseAdmin.from('merchants').update({ is_active: !active }).eq('id', id)
    loadMerchants()
  }

  function openSubModal(m: Merchant) {
    setSelectedMerchant(m)
    setSubPlan(m.subscription_plan || 'free')
    setSubExpiry(m.subscription_expires_at ? m.subscription_expires_at.slice(0, 10) : '')
    setShowSubModal(true)
  }

  async function saveSubscription() {
    if (!selectedMerchant) return
    setSubSaving(true)
    await supabaseAdmin.from('merchants').update({
      subscription_plan: subPlan,
      subscription_expires_at: subExpiry || null,
    }).eq('id', selectedMerchant.id)
    setSubSaving(false)
    setShowSubModal(false)
    loadMerchants()
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Merchants</h1>
        <button onClick={loadMerchants} className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm hover:bg-[#2A9D8F]/80 flex items-center gap-2">
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {/* Tab buttons with counts */}
      <div className="flex gap-3 mb-6">
        <button onClick={() => setTab('pending')} className={`px-5 py-2.5 rounded-lg text-sm font-medium flex items-center gap-2 transition-all ${tab === 'pending' ? 'bg-[#E76F51] text-white shadow-lg shadow-[#E76F51]/20' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34] hover:border-[#E76F51]/40'}`}>
          <Clock size={16} />
          Pending Review
          {pendingCount > 0 && (
            <span className={`ml-1 px-2 py-0.5 rounded-full text-xs font-bold ${tab === 'pending' ? 'bg-white/20' : 'bg-[#E76F51] text-white'}`}>
              {pendingCount}
            </span>
          )}
        </button>
        <button onClick={() => setTab('approved')} className={`px-5 py-2.5 rounded-lg text-sm font-medium flex items-center gap-2 transition-all ${tab === 'approved' ? 'bg-[#2A9D8F] text-white shadow-lg shadow-[#2A9D8F]/20' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34] hover:border-[#2A9D8F]/40'}`}>
          <CheckCircle size={16} />
          Approved
          <span className={`ml-1 px-2 py-0.5 rounded-full text-xs ${tab === 'approved' ? 'bg-white/20' : 'bg-[#2D2F34] text-gray-400'}`}>
            {approvedCount}
          </span>
        </button>
      </div>

      {loading ? <p className="text-gray-500">Loading...</p> : merchants.length === 0 ? (
        <div className="bg-[#23252A] rounded-xl p-12 border border-[#2D2F34] text-center">
          <Store size={48} className="mx-auto mb-4 text-gray-600" />
          <p className="text-gray-400 text-lg font-medium">
            {tab === 'pending' ? 'No pending applications' : 'No approved merchants yet'}
          </p>
          <p className="text-gray-600 text-sm mt-1">
            {tab === 'pending' ? 'All merchant applications have been reviewed' : 'Approve merchants from the Pending Review tab'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {merchants.map(m => (
            <div key={m.id} className={`bg-[#23252A] rounded-xl p-5 border transition-all ${tab === 'pending' ? 'border-[#E76F51]/30 hover:border-[#E76F51]/60' : 'border-[#2D2F34] hover:border-[#2A9D8F]/40'}`}>
              {/* Header */}
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-white font-semibold text-base">{m.shop_name}</h3>
                {tab === 'pending' ? (
                  <span className="text-xs px-2.5 py-1 rounded-full bg-[#E76F51]/15 text-[#E76F51] font-medium flex items-center gap-1">
                    <Clock size={10} /> Awaiting Review
                  </span>
                ) : (
                  <span className={`text-xs px-2.5 py-1 rounded-full font-medium ${m.is_active ? 'bg-green-500/15 text-green-400' : 'bg-red-500/15 text-red-400'}`}>
                    {m.is_active ? '● Active' : '● Suspended'}
                  </span>
                )}
              </div>

              {/* Details */}
              <div className="space-y-1.5 mb-3">
                <p className="text-gray-300 text-sm capitalize flex items-center gap-2">
                  <span className="text-gray-500">Category:</span> {m.category}
                </p>
                <p className="text-gray-400 text-xs">{m.address}</p>
              </div>

              {/* Stats - only for approved */}
              {tab === 'approved' && (
                <div className="flex items-center gap-4 text-xs text-gray-400 mb-3 py-2 border-t border-b border-[#2D2F34]">
                  <span className="text-[#D4AF37]">⭐ {m.rating > 0 ? m.rating.toFixed(1) : '0'}</span>
                  <span>{m.total_orders} orders</span>
                  <span>{m.is_open ? '🟢 Open' : '🔴 Closed'}</span>
                </div>
              )}

              {/* Subscription badge - only for approved */}
              {tab === 'approved' && (
                <div className="flex items-center gap-2 mb-4">
                  <span className="text-xs px-2.5 py-1 rounded-full font-medium capitalize" style={{ backgroundColor: `${planColors[m.subscription_plan] || planColors.free}20`, color: planColors[m.subscription_plan] || planColors.free }}>
                    {m.subscription_plan || 'free'} plan
                  </span>
                  {m.subscription_expires_at && (
                    <span className="text-xs text-gray-500">exp. {new Date(m.subscription_expires_at).toLocaleDateString()}</span>
                  )}
                </div>
              )}

              {/* Submitted date - for pending */}
              {tab === 'pending' && (
                <p className="text-xs text-gray-500 mb-4">
                  Applied {new Date(m.created_at).toLocaleDateString()} at {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </p>
              )}

              {/* Actions */}
              <div className="flex gap-2">
                {tab === 'pending' ? (
                  <>
                    <button onClick={() => approve(m.id)} className="flex-1 py-2.5 bg-[#2A9D8F] text-white rounded-lg text-xs font-medium hover:bg-[#2A9D8F]/80 transition-colors flex items-center justify-center gap-1">
                      <CheckCircle size={14} /> Approve
                    </button>
                    <button onClick={() => reject(m.id)} className="flex-1 py-2.5 bg-red-500/15 text-red-400 rounded-lg text-xs font-medium hover:bg-red-500/25 transition-colors">
                      Reject
                    </button>
                  </>
                ) : (
                  <>
                    <button onClick={() => suspend(m.id, m.is_active)} className={`flex-1 py-2.5 rounded-lg text-xs font-medium transition-colors ${m.is_active ? 'bg-red-500/15 text-red-400 hover:bg-red-500/25' : 'bg-green-500/15 text-green-400 hover:bg-green-500/25'}`}>
                      {m.is_active ? 'Suspend' : 'Reactivate'}
                    </button>
                    <button onClick={() => openSubModal(m)} className="flex-1 py-2.5 bg-[#D4AF37]/15 text-[#D4AF37] rounded-lg text-xs font-medium hover:bg-[#D4AF37]/25 transition-colors">
                      Subscription
                    </button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Subscription Modal */}
      {showSubModal && selectedMerchant && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowSubModal(false)}>
          <div className="bg-[#23252A] rounded-xl p-6 max-w-md w-full mx-4 border border-[#2D2F34]" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-white mb-4">Manage Subscription — {selectedMerchant.shop_name}</h2>
            <div className="space-y-4">
              <div>
                <label className="text-sm text-gray-400 block mb-1">Current Plan</label>
                <span className="text-sm px-3 py-1 rounded-full capitalize" style={{ backgroundColor: `${planColors[selectedMerchant.subscription_plan] || planColors.free}20`, color: planColors[selectedMerchant.subscription_plan] || planColors.free }}>
                  {selectedMerchant.subscription_plan || 'free'}
                </span>
              </div>
              <div>
                <label className="text-sm text-gray-400 block mb-1">New Plan</label>
                <select value={subPlan} onChange={e => setSubPlan(e.target.value)}
                  className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm focus:outline-none focus:border-[#2A9D8F]">
                  <option value="free">Free</option>
                  <option value="basic">Basic</option>
                  <option value="standard">Standard</option>
                  <option value="premium">Premium</option>
                </select>
              </div>
              <div>
                <label className="text-sm text-gray-400 block mb-1">Expiry Date</label>
                <input type="date" value={subExpiry} onChange={e => setSubExpiry(e.target.value)}
                  className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm focus:outline-none focus:border-[#2A9D8F]" />
              </div>
              <div className="flex gap-2 pt-2">
                <button onClick={() => setShowSubModal(false)} className="flex-1 py-2 bg-[#2D2F34] text-white rounded-lg text-sm">Cancel</button>
                <button onClick={saveSubscription} disabled={subSaving} className="flex-1 py-2 bg-[#D4AF37] text-black rounded-lg text-sm font-semibold hover:bg-[#D4AF37]/80 disabled:opacity-50">
                  {subSaving ? 'Saving...' : 'Save'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
