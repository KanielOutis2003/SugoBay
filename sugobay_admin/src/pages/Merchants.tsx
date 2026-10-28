import { useEffect, useState, useRef } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import type { Merchant } from '../lib/supabase'
import { Store, CheckCircle, Clock, RefreshCw, Star, ShoppingBag, TrendingUp, X } from 'lucide-react'
import gsap from 'gsap'

const PLAN_META: Record<string, { color: string; label: string; bg: string }> = {
  free:     { color: '#6B7280', label: 'Free',     bg: 'rgba(107,114,128,0.12)' },
  basic:    { color: '#3B82F6', label: 'Basic',    bg: 'rgba(59,130,246,0.12)' },
  standard: { color: '#2A9D8F', label: 'Standard', bg: 'rgba(42,157,143,0.12)' },
  premium:  { color: '#E9C46A', label: 'Premium',  bg: 'rgba(233,196,106,0.12)' },
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
  const cardsRef = useRef<HTMLDivElement>(null)

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

  useEffect(() => {
    if (!loading && merchants.length > 0) {
      gsap.from('.merchant-card', {
        y: 28, opacity: 0, stagger: 0.07, duration: 0.5, ease: 'power2.out',
        clearProps: 'all',
      })
    }
  }, [loading, merchants])

  async function approve(id: string, e: React.MouseEvent) {
    gsap.to(e.currentTarget, { scale: 0.93, duration: 0.1, yoyo: true, repeat: 1, ease: 'power2.inOut' })
    const { data: merchant } = await supabaseAdmin.from('merchants').select('user_id').eq('id', id).single()
    await supabaseAdmin.from('merchants').update({ is_approved: true, is_active: true }).eq('id', id)
    if (merchant?.user_id) {
      await supabaseAdmin.auth.admin.updateUserById(merchant.user_id, { email_confirm: true })
    }
    loadMerchants()
  }

  async function reject(id: string, e: React.MouseEvent) {
    gsap.to(e.currentTarget, { scale: 0.93, duration: 0.1, yoyo: true, repeat: 1 })
    if (!confirm('Reject and delete this merchant application?')) return
    await supabaseAdmin.from('merchants').delete().eq('id', id)
    loadMerchants()
  }

  async function suspend(id: string, active: boolean, e: React.MouseEvent) {
    gsap.to(e.currentTarget, { scale: 0.93, duration: 0.1, yoyo: true, repeat: 1 })
    await supabaseAdmin.from('merchants').update({ is_active: !active }).eq('id', id)
    loadMerchants()
  }

  function openSubModal(m: Merchant) {
    setSelectedMerchant(m)
    setSubPlan(m.subscription_plan || 'free')
    setSubExpiry(m.subscription_expires_at ? m.subscription_expires_at.slice(0, 10) : '')
    setShowSubModal(true)
    requestAnimationFrame(() => {
      gsap.from('.sub-modal', { y: 30, scale: 0.96, opacity: 0, duration: 0.35, ease: 'back.out(1.5)' })
    })
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

  const tabData = [
    { key: 'pending', label: 'Pending Review', icon: Clock, color: '#E76F51', count: pendingCount },
    { key: 'approved', label: 'Approved', icon: CheckCircle, color: '#2A9D8F', count: approvedCount },
  ] as const

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-white">Merchants</h1>
          <p className="text-sm text-gray-500 mt-1">Manage merchant applications and subscriptions</p>
        </div>
        <button
          onClick={() => loadMerchants()}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium text-white btn-press"
          style={{ background: 'rgba(42,157,143,0.15)', border: '1px solid rgba(42,157,143,0.3)', color: '#2A9D8F' }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          { label: 'Total Merchants', value: pendingCount + approvedCount, icon: Store, color: '#2A9D8F' },
          { label: 'Pending Review', value: pendingCount, icon: Clock, color: '#E76F51' },
          { label: 'Approved', value: approvedCount, icon: CheckCircle, color: '#22C55E' },
          { label: 'Active Today', value: approvedCount, icon: TrendingUp, color: '#E9C46A' },
        ].map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="premium-card p-4">
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center"
                style={{ background: `${color}18`, border: `1px solid ${color}30` }}>
                <Icon size={16} color={color} />
              </div>
            </div>
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-xs text-gray-500 mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Tab Buttons */}
      <div className="flex gap-3 mb-6">
        {tabData.map(({ key, label, icon: Icon, color, count }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className="px-5 py-2.5 rounded-xl text-sm font-semibold flex items-center gap-2 transition-all btn-press"
            style={tab === key
              ? { background: `${color}20`, border: `1px solid ${color}50`, color }
              : { background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.07)', color: '#9CA3AF' }}>
            <Icon size={15} />
            {label}
            {count > 0 && (
              <span className="px-2 py-0.5 rounded-full text-xs font-bold"
                style={{ background: tab === key ? `${color}30` : 'rgba(255,255,255,0.08)', color: tab === key ? color : '#6B7280' }}>
                {count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Content */}
      {loading ? (
        <div className="flex items-center justify-center py-24 text-gray-600 gap-3">
          <div className="animate-spin rounded-full h-6 w-6 border-2 border-[#2A9D8F]/30 border-t-[#2A9D8F]" />
          Loading merchants...
        </div>
      ) : merchants.length === 0 ? (
        <div className="premium-card p-16 text-center">
          <div className="w-16 h-16 rounded-2xl mx-auto mb-4 flex items-center justify-center"
            style={{ background: 'rgba(255,255,255,0.04)' }}>
            <Store size={28} className="text-gray-600" />
          </div>
          <p className="text-gray-400 text-lg font-semibold">
            {tab === 'pending' ? 'No pending applications' : 'No approved merchants yet'}
          </p>
          <p className="text-gray-600 text-sm mt-2">
            {tab === 'pending' ? 'All applications have been reviewed' : 'Approve merchants from Pending Review'}
          </p>
        </div>
      ) : (
        <div ref={cardsRef} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {merchants.map(m => {
            const plan = PLAN_META[m.subscription_plan] || PLAN_META.free
            return (
              <div key={m.id} className="merchant-card premium-card p-5 flex flex-col gap-4"
                style={{
                  borderColor: tab === 'pending' ? 'rgba(231,111,81,0.15)' : undefined,
                }}>

                {/* Top row */}
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl flex items-center justify-center text-base font-bold"
                      style={{ background: tab === 'pending' ? 'rgba(231,111,81,0.15)' : 'rgba(42,157,143,0.15)', color: tab === 'pending' ? '#E76F51' : '#2A9D8F' }}>
                      {m.shop_name?.[0]?.toUpperCase() || 'M'}
                    </div>
                    <div>
                      <h3 className="text-white font-semibold text-sm leading-tight">{m.shop_name}</h3>
                      <p className="text-xs text-gray-500 capitalize">{m.category}</p>
                    </div>
                  </div>
                  {tab === 'pending' ? (
                    <span className="flex items-center gap-1 text-[10px] px-2.5 py-1 rounded-full font-semibold"
                      style={{ background: 'rgba(231,111,81,0.12)', border: '1px solid rgba(231,111,81,0.25)', color: '#E76F51' }}>
                      <Clock size={9} /> Pending
                    </span>
                  ) : (
                    <span className={`flex items-center gap-1 text-[10px] px-2.5 py-1 rounded-full font-semibold ${m.is_active ? 'text-green-400' : 'text-red-400'}`}
                      style={{ background: m.is_active ? 'rgba(34,197,94,0.1)' : 'rgba(239,68,68,0.1)', border: `1px solid ${m.is_active ? 'rgba(34,197,94,0.25)' : 'rgba(239,68,68,0.25)'}` }}>
                      ● {m.is_active ? 'Active' : 'Suspended'}
                    </span>
                  )}
                </div>

                {/* Address */}
                <p className="text-xs text-gray-500 leading-relaxed">{m.address}</p>

                {/* Stats row — approved only */}
                {tab === 'approved' && (
                  <div className="flex items-center gap-4 py-3 rounded-xl"
                    style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.05)', padding: '10px 14px' }}>
                    <div className="flex items-center gap-1.5">
                      <Star size={12} color="#E9C46A" fill="#E9C46A" />
                      <span className="text-xs text-gray-300 font-medium">{m.rating > 0 ? m.rating.toFixed(1) : '0.0'}</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <ShoppingBag size={12} color="#2A9D8F" />
                      <span className="text-xs text-gray-400">{m.total_orders} orders</span>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <span className={`w-2 h-2 rounded-full ${m.is_open ? 'bg-green-400' : 'bg-gray-600'}`} />
                      <span className="text-xs text-gray-400">{m.is_open ? 'Open' : 'Closed'}</span>
                    </div>
                  </div>
                )}

                {/* Subscription — approved only */}
                {tab === 'approved' && (
                  <div className="flex items-center justify-between">
                    <span className="text-xs px-2.5 py-1.5 rounded-lg font-semibold capitalize"
                      style={{ background: plan.bg, color: plan.color }}>
                      {plan.label} Plan
                    </span>
                    {m.subscription_expires_at && (
                      <span className="text-[10px] text-gray-600">
                        exp. {new Date(m.subscription_expires_at).toLocaleDateString()}
                      </span>
                    )}
                  </div>
                )}

                {/* Applied date — pending only */}
                {tab === 'pending' && (
                  <p className="text-[10px] text-gray-600">
                    Applied {new Date(m.created_at).toLocaleDateString()} at {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                )}

                {/* Action buttons */}
                <div className="flex gap-2 mt-auto pt-2" style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                  {tab === 'pending' ? (
                    <>
                      <button
                        onClick={e => approve(m.id, e)}
                        className="flex-1 py-2.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 btn-press"
                        style={{ background: 'rgba(42,157,143,0.15)', border: '1px solid rgba(42,157,143,0.3)', color: '#2A9D8F' }}>
                        <CheckCircle size={13} /> Approve
                      </button>
                      <button
                        onClick={e => reject(m.id, e)}
                        className="flex-1 py-2.5 rounded-xl text-xs font-semibold btn-press"
                        style={{ background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)', color: '#f87171' }}>
                        Reject
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        onClick={e => suspend(m.id, m.is_active, e)}
                        className="flex-1 py-2.5 rounded-xl text-xs font-semibold btn-press"
                        style={m.is_active
                          ? { background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)', color: '#f87171' }
                          : { background: 'rgba(34,197,94,0.08)', border: '1px solid rgba(34,197,94,0.2)', color: '#4ade80' }}>
                        {m.is_active ? 'Suspend' : 'Reactivate'}
                      </button>
                      <button
                        onClick={() => openSubModal(m)}
                        className="flex-1 py-2.5 rounded-xl text-xs font-semibold btn-press"
                        style={{ background: 'rgba(233,196,106,0.1)', border: '1px solid rgba(233,196,106,0.25)', color: '#E9C46A' }}>
                        Subscription
                      </button>
                    </>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Subscription Modal */}
      {showSubModal && selectedMerchant && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{ background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(8px)' }}
          onClick={() => setShowSubModal(false)}>
          <div className="sub-modal w-full max-w-md rounded-2xl p-6"
            style={{
              background: '#16181D',
              border: '1px solid rgba(255,255,255,0.08)',
              boxShadow: '0 40px 120px rgba(0,0,0,0.6)',
            }}
            onClick={e => e.stopPropagation()}>

            <div className="flex items-center justify-between mb-6">
              <div>
                <h2 className="text-lg font-bold text-white">Manage Subscription</h2>
                <p className="text-sm text-gray-500 mt-0.5">{selectedMerchant.shop_name}</p>
              </div>
              <button onClick={() => setShowSubModal(false)}
                className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-500 hover:text-white btn-press"
                style={{ background: 'rgba(255,255,255,0.05)' }}>
                <X size={16} />
              </button>
            </div>

            <div className="space-y-5">
              {/* Current plan display */}
              <div className="p-4 rounded-xl" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.06)' }}>
                <p className="text-xs text-gray-500 mb-2">Current Plan</p>
                <span className="text-sm px-3 py-1.5 rounded-lg font-semibold capitalize"
                  style={{
                    background: (PLAN_META[selectedMerchant.subscription_plan] || PLAN_META.free).bg,
                    color: (PLAN_META[selectedMerchant.subscription_plan] || PLAN_META.free).color
                  }}>
                  {selectedMerchant.subscription_plan || 'free'}
                </span>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">New Plan</label>
                <select value={subPlan} onChange={e => setSubPlan(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl text-white text-sm focus:outline-none"
                  style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: 'white' }}>
                  {Object.entries(PLAN_META).map(([key, meta]) => (
                    <option key={key} value={key} style={{ background: '#1E2128' }}>{meta.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">Expiry Date</label>
                <input type="date" value={subExpiry} onChange={e => setSubExpiry(e.target.value)}
                  className="w-full px-4 py-3 rounded-xl text-white text-sm focus:outline-none"
                  style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', colorScheme: 'dark' }} />
              </div>

              <div className="flex gap-3 pt-2">
                <button onClick={() => setShowSubModal(false)}
                  className="flex-1 py-3 rounded-xl text-sm text-gray-400 hover:text-white btn-press"
                  style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}>
                  Cancel
                </button>
                <button onClick={saveSubscription} disabled={subSaving}
                  className="flex-1 py-3 rounded-xl text-sm font-bold btn-press disabled:opacity-50"
                  style={{ background: 'linear-gradient(135deg, #E9C46A, #d4a843)', color: '#0F1117' }}>
                  {subSaving ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
