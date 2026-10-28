import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import { exportToCsv } from '../lib/csvExport'
import { Map as GoogleMap, AdvancedMarker, useMap } from '@vis.gl/react-google-maps'
import { Bike, AlertTriangle, ShieldOff, ShieldCheck, RefreshCw, Download, X, Calendar, Star } from 'lucide-react'
import gsap from 'gsap'

const REGIONS: Record<string, { center: { lat: number; lng: number }; zoom: number; label: string }> = {
  ubay:  { center: { lat: 10.0581, lng: 124.0474 }, zoom: 14, label: 'Ubay, Bohol' },
  bohol: { center: { lat: 9.8500,  lng: 124.1435 }, zoom: 11, label: 'Bohol' },
  cebu:  { center: { lat: 10.3157, lng: 123.8854 }, zoom: 11, label: 'Cebu' },
}

function FlyTo({ center, zoom }: { center: { lat: number; lng: number }; zoom: number }) {
  const map = useMap()
  useEffect(() => { if (map) map.panTo(center) }, [map, center, zoom])
  return null
}

interface Rider {
  id: string
  name: string
  phone: string
  is_active: boolean
  created_at: string
  location?: { is_online: boolean; lat: number; lng: number }
  totalJobs: number
  rating: number
  complaintCount: number
}

interface ShiftData {
  day_of_week: string
  shift: string
  is_committed: boolean
}

const DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
const SHIFTS = ['morning', 'lunch', 'afternoon', 'evening']
const SHIFT_LABELS: Record<string, string> = { morning: 'Morning', lunch: 'Lunch', afternoon: 'Afternoon', evening: 'Evening' }

function getStrikeInfo(count: number) {
  if (count === 0) return { label: 'Clean',            color: '#4ade80', bg: 'rgba(74,222,128,0.12)'  }
  if (count === 1) return { label: 'Warning',          color: '#facc15', bg: 'rgba(250,204,21,0.12)'  }
  if (count === 2) return { label: 'Meeting Required', color: '#fb923c', bg: 'rgba(251,146,60,0.12)'  }
  if (count === 3) return { label: 'Suspended',        color: '#f87171', bg: 'rgba(248,113,113,0.12)' }
  return             { label: 'Removed',               color: '#ef4444', bg: 'rgba(239,68,68,0.15)'  }
}

function getLevelInfo(totalJobs: number) {
  if (totalJobs >= 500) return { label: 'Elite',   color: '#a78bfa', bg: 'rgba(167,139,250,0.12)' }
  if (totalJobs >= 200) return { label: 'Trusted', color: '#60a5fa', bg: 'rgba(96,165,250,0.12)'  }
  if (totalJobs >= 50)  return { label: 'Regular', color: '#4ade80', bg: 'rgba(74,222,128,0.12)'  }
  return                        { label: 'Rookie',  color: '#9CA3AF', bg: 'rgba(156,163,175,0.1)'  }
}

export default function Riders() {
  const [riders, setRiders] = useState<Rider[]>([])
  const [loading, setLoading] = useState(true)
  const [mapRegion, setMapRegion] = useState<keyof typeof REGIONS>('ubay')
  const [shiftModalRider, setShiftModalRider] = useState<Rider | null>(null)
  const [shiftData, setShiftData] = useState<ShiftData[]>([])
  const [shiftLoading, setShiftLoading] = useState(false)
  const [warningModal, setWarningModal] = useState<Rider | null>(null)
  const [warningNote, setWarningNote] = useState('')
  const [issuingWarning, setIssuingWarning] = useState(false)

  useEffect(() => { loadRiders() }, [])

  useEffect(() => {
    if (!loading && riders.length > 0) {
      gsap.from('.rider-row', { x: -16, opacity: 0, stagger: 0.03, duration: 0.4, ease: 'power2.out', clearProps: 'all' })
    }
  }, [loading, riders])

  async function loadRiders() {
    setLoading(true)
    const [usersRes, locationsRes, ratingsRes, ordersRes, pahapitRes, complaintsOrdersRes, complaintsPahapitRes] = await Promise.all([
      supabaseAdmin.from('users').select('*').eq('role', 'rider').order('created_at', { ascending: false }),
      supabaseAdmin.from('rider_locations').select('*'),
      supabaseAdmin.from('ratings').select('rider_rating, order_id, pahapit_id, orders(rider_id), pahapit_requests(rider_id)').not('rider_rating', 'is', null),
      supabaseAdmin.from('orders').select('id, rider_id, status'),
      supabaseAdmin.from('pahapit_requests').select('id, rider_id, status'),
      supabaseAdmin.from('complaints').select('order_id').not('order_id', 'is', null),
      supabaseAdmin.from('complaints').select('pahapit_id').not('pahapit_id', 'is', null),
    ])

    const users = usersRes.data || []
    const locations = locationsRes.data || []
    const ratings = ratingsRes.data || []
    const allOrders = ordersRes.data || []
    const allPahapits = pahapitRes.data || []
    const complaintsOrders = complaintsOrdersRes.data || []
    const complaintsPahapit = complaintsPahapitRes.data || []

    const locMap: globalThis.Map<string, any> = new globalThis.Map(locations.map((l: any) => [l.rider_id, l]))
    const ratingMap: globalThis.Map<string, number[]> = new globalThis.Map()
    for (const r of ratings) {
      const riderId = (r as any).orders?.rider_id || (r as any).pahapit_requests?.rider_id
      if (!riderId) continue
      if (!ratingMap.has(riderId)) ratingMap.set(riderId, [])
      ratingMap.get(riderId)!.push(r.rider_rating || 0)
    }

    const orderCountMap: globalThis.Map<string, number> = new globalThis.Map()
    for (const o of allOrders) {
      if (o.status === 'delivered') orderCountMap.set(o.rider_id, (orderCountMap.get(o.rider_id) || 0) + 1)
    }
    const pahapitCountMap: globalThis.Map<string, number> = new globalThis.Map()
    for (const p of allPahapits) {
      if (p.status === 'completed') pahapitCountMap.set(p.rider_id, (pahapitCountMap.get(p.rider_id) || 0) + 1)
    }

    const orderRiderMap: globalThis.Map<string, string> = new globalThis.Map()
    for (const o of allOrders) { if (o.rider_id) orderRiderMap.set(o.id, o.rider_id) }
    const pahapitRiderMap: globalThis.Map<string, string> = new globalThis.Map()
    for (const p of allPahapits) { if (p.rider_id) pahapitRiderMap.set(p.id, p.rider_id) }

    const complaintCountMap: globalThis.Map<string, number> = new globalThis.Map()
    for (const c of complaintsOrders) {
      const riderId = orderRiderMap.get(c.order_id)
      if (riderId) complaintCountMap.set(riderId, (complaintCountMap.get(riderId) || 0) + 1)
    }
    for (const c of complaintsPahapit) {
      const riderId = pahapitRiderMap.get(c.pahapit_id)
      if (riderId) complaintCountMap.set(riderId, (complaintCountMap.get(riderId) || 0) + 1)
    }

    setRiders(users.map((u: any) => {
      const riderRatings: number[] = ratingMap.get(u.id) || []
      return {
        id: u.id, name: u.name, phone: u.phone, is_active: u.is_active, created_at: u.created_at,
        location: locMap.get(u.id) || undefined,
        totalJobs: (orderCountMap.get(u.id) || 0) + (pahapitCountMap.get(u.id) || 0),
        rating: riderRatings.length > 0 ? riderRatings.reduce((a: number, b: number) => a + b, 0) / riderRatings.length : 0,
        complaintCount: complaintCountMap.get(u.id) || 0,
      }
    }))
    setLoading(false)
  }

  async function toggleActive(id: string, current: boolean) {
    await supabaseAdmin.from('users').update({ is_active: !current }).eq('id', id)
    loadRiders()
  }

  async function openShiftModal(rider: Rider) {
    setShiftModalRider(rider)
    setShiftLoading(true)
    const { data } = await supabaseAdmin.from('rider_shifts').select('day_of_week, shift, is_committed').eq('rider_id', rider.id)
    setShiftData(data || [])
    setShiftLoading(false)
    requestAnimationFrame(() => {
      gsap.from('.shift-modal', { y: 32, scale: 0.96, opacity: 0, duration: 0.35, ease: 'back.out(1.4)' })
    })
  }

  function isCommitted(day: string, shift: string): boolean {
    return shiftData.some(s => s.day_of_week === day && s.shift === shift && s.is_committed)
  }

  async function issueWarning(rider: Rider) {
    setIssuingWarning(true)
    const newCount = rider.complaintCount + 1
    const strikeInfo = getStrikeInfo(newCount)

    if (newCount >= 3) {
      await supabaseAdmin.from('users').update({ is_active: false }).eq('id', rider.id)
    }

    const { data: anyOrder } = await supabaseAdmin.from('orders').select('id').eq('rider_id', rider.id).limit(1).single()
    const { data: anyPahapit } = await supabaseAdmin.from('pahapit_requests').select('id').eq('rider_id', rider.id).limit(1).single()

    await supabaseAdmin.from('complaints').insert({
      customer_id: rider.id,
      order_id: anyOrder?.id || null,
      pahapit_id: !anyOrder ? (anyPahapit?.id || null) : null,
      type: 'rider_warning',
      description: `[ADMIN WARNING - Strike ${newCount}: ${strikeInfo.label}] ${warningNote}`,
      status: 'resolved',
    })

    setIssuingWarning(false)
    setWarningModal(null)
    setWarningNote('')
    loadRiders()
  }

  const onlineCount = riders.filter(r => r.location?.is_online).length

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-white">Riders</h1>
          <p className="text-sm text-gray-500 mt-1">
            {riders.length} registered &bull;{' '}
            <span className="text-green-400">{onlineCount} online now</span>
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => exportToCsv('riders', riders.map(r => ({ ...r, location: r.location ? `${r.location.lat},${r.location.lng}` : '' })))}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium btn-press"
            style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', color: '#9CA3AF' }}>
            <Download size={14} /> Export CSV
          </button>
          <button onClick={loadRiders}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium btn-press"
            style={{ background: 'rgba(42,157,143,0.15)', border: '1px solid rgba(42,157,143,0.3)', color: '#2A9D8F' }}>
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {[
          { label: 'Total Riders', value: riders.length, color: '#2A9D8F', icon: Bike },
          { label: 'Online Now', value: onlineCount, color: '#4ade80', icon: ShieldCheck },
          { label: 'Active Riders', value: riders.filter(r => r.is_active).length, color: '#E9C46A', icon: Star },
          { label: 'Suspended', value: riders.filter(r => !r.is_active).length, color: '#f87171', icon: ShieldOff },
        ].map(({ label, value, color, icon: Icon }) => (
          <div key={label} className="premium-card p-4">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center mb-3"
              style={{ background: `${color}15`, border: `1px solid ${color}25` }}>
              <Icon size={16} color={color} />
            </div>
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-xs text-gray-500 mt-1">{label}</p>
          </div>
        ))}
      </div>

      {/* Live Rider Map */}
      <div className="premium-card overflow-hidden mb-6">
        <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
          <div className="flex items-center gap-3">
            <span className="text-sm font-semibold text-white">Live Rider Map</span>
            <span className="text-xs px-2.5 py-1 rounded-full font-semibold"
              style={{ background: 'rgba(74,222,128,0.12)', color: '#4ade80', border: '1px solid rgba(74,222,128,0.25)' }}>
              {onlineCount} online
            </span>
          </div>
          <div className="flex gap-1.5">
            {(Object.keys(REGIONS) as Array<keyof typeof REGIONS>).map(key => (
              <button key={key} onClick={() => setMapRegion(key)}
                className="px-3 py-1.5 rounded-lg text-xs font-semibold transition-all btn-press"
                style={mapRegion === key
                  ? { background: 'rgba(42,157,143,0.2)', border: '1px solid rgba(42,157,143,0.4)', color: '#2A9D8F' }
                  : { background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)', color: '#6B7280' }}>
                {REGIONS[key].label}
              </button>
            ))}
          </div>
        </div>
        <div style={{ height: 300 }}>
          <GoogleMap
            defaultCenter={REGIONS[mapRegion].center}
            defaultZoom={REGIONS[mapRegion].zoom}
            style={{ width: '100%', height: '100%' }}
            mapId="sugobay-riders"
            disableDefaultUI={true}
            gestureHandling="greedy">
            <FlyTo center={REGIONS[mapRegion].center} zoom={REGIONS[mapRegion].zoom} />

            {riders.filter(r => r.location?.is_online && r.location.lat && r.location.lng).map(r => (
              <AdvancedMarker key={r.id} position={{ lat: r.location!.lat, lng: r.location!.lng }} title={`${r.name} • ${r.phone}`}>
                <div style={{
                  background: '#2A9D8F', width: 28, height: 28, borderRadius: '50%',
                  border: '2px solid #fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: '0 2px 8px rgba(42,157,143,0.5)',
                }}>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5">
                    <path d="M12 2L19 21L12 17L5 21L12 2Z" />
                  </svg>
                </div>
              </AdvancedMarker>
            ))}
          </GoogleMap>
        </div>
        {!onlineCount && !loading && (
          <p className="text-xs text-gray-600 text-center py-2">No riders currently online</p>
        )}
      </div>

      {/* Riders Table */}
      {loading ? (
        <div className="flex items-center justify-center py-16 gap-3 text-gray-600">
          <div className="animate-spin rounded-full h-6 w-6 border-2 border-[#2A9D8F]/30 border-t-[#2A9D8F]" />
          Loading riders...
        </div>
      ) : (
        <div className="premium-card overflow-hidden">
          <div className="px-5 py-4" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
            <h2 className="text-sm font-semibold text-white">All Riders</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                  {['Rider', 'Phone', 'Status', 'Jobs', 'Rating', 'Strike Level', 'Rider Level', 'Actions'].map(h => (
                    <th key={h} className="text-left px-5 py-3.5 text-xs font-semibold uppercase tracking-wider text-gray-600">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {riders.map(r => {
                  const level = getLevelInfo(r.totalJobs)
                  const strike = getStrikeInfo(r.complaintCount)
                  return (
                    <tr key={r.id} className="rider-row group"
                      style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}
                      onMouseEnter={e => gsap.to(e.currentTarget, { backgroundColor: 'rgba(255,255,255,0.025)', duration: 0.15 })}
                      onMouseLeave={e => gsap.to(e.currentTarget, { backgroundColor: 'transparent', duration: 0.15 })}>

                      {/* Rider name + online indicator */}
                      <td className="px-5 py-4">
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <div className="w-8 h-8 rounded-xl flex items-center justify-center text-xs font-bold"
                              style={{ background: 'rgba(42,157,143,0.15)', color: '#2A9D8F' }}>
                              {r.name?.[0]?.toUpperCase() || 'R'}
                            </div>
                            {r.location?.is_online && (
                              <span className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full bg-green-400 border-2"
                                style={{ borderColor: '#16181D' }} />
                            )}
                          </div>
                          <span className="text-white font-medium">{r.name}</span>
                        </div>
                      </td>

                      <td className="px-5 py-4 text-gray-400">{r.phone}</td>

                      {/* Online/offline */}
                      <td className="px-5 py-4">
                        <span className="text-xs px-2.5 py-1 rounded-lg font-semibold"
                          style={r.is_active
                            ? { background: 'rgba(74,222,128,0.1)', color: '#4ade80' }
                            : { background: 'rgba(248,113,113,0.1)', color: '#f87171' }}>
                          {r.is_active ? 'Active' : 'Suspended'}
                        </span>
                      </td>

                      <td className="px-5 py-4">
                        <span className="font-semibold" style={{ color: '#E9C46A' }}>{r.totalJobs}</span>
                      </td>

                      <td className="px-5 py-4">
                        <div className="flex items-center gap-1">
                          <Star size={12} color="#E9C46A" fill="#E9C46A" />
                          <span className="text-gray-300">{r.rating > 0 ? r.rating.toFixed(1) : '0.0'}</span>
                        </div>
                      </td>

                      <td className="px-5 py-4">
                        <span className="text-xs px-2.5 py-1 rounded-lg font-semibold"
                          style={{ background: strike.bg, color: strike.color }}>
                          {strike.label}
                        </span>
                      </td>

                      <td className="px-5 py-4">
                        <span className="text-xs px-2.5 py-1 rounded-lg font-semibold"
                          style={{ background: level.bg, color: level.color }}>
                          {level.label}
                        </span>
                      </td>

                      <td className="px-5 py-4">
                        <div className="flex items-center gap-2">
                          <button onClick={() => openShiftModal(r)}
                            className="text-xs px-3 py-1.5 rounded-lg font-medium btn-press transition-all"
                            style={{ background: 'rgba(96,165,250,0.1)', color: '#60a5fa' }}>
                            <Calendar size={11} className="inline mr-1" />Shifts
                          </button>
                          <button onClick={() => { setWarningModal(r); setWarningNote('') }}
                            className="text-xs px-3 py-1.5 rounded-lg font-medium btn-press"
                            style={{ background: 'rgba(250,204,21,0.1)', color: '#facc15' }}>
                            <AlertTriangle size={11} className="inline mr-1" />Warn
                          </button>
                          <button onClick={() => toggleActive(r.id, r.is_active)}
                            className="text-xs px-3 py-1.5 rounded-lg font-medium btn-press"
                            style={r.is_active
                              ? { background: 'rgba(248,113,113,0.1)', color: '#f87171' }
                              : { background: 'rgba(74,222,128,0.1)', color: '#4ade80' }}>
                            {r.is_active ? 'Suspend' : 'Restore'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Shift Modal */}
      {shiftModalRider && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{ background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(8px)' }}
          onClick={() => setShiftModalRider(null)}>
          <div className="shift-modal w-full max-w-2xl rounded-2xl"
            style={{ background: '#16181D', border: '1px solid rgba(255,255,255,0.08)', boxShadow: '0 40px 120px rgba(0,0,0,0.6)' }}
            onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 py-5"
              style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
              <div>
                <h2 className="text-base font-bold text-white">Shift Schedule</h2>
                <p className="text-sm text-gray-500 mt-0.5">{shiftModalRider.name}</p>
              </div>
              <button onClick={() => setShiftModalRider(null)}
                className="w-8 h-8 rounded-lg flex items-center justify-center btn-press"
                style={{ background: 'rgba(255,255,255,0.05)', color: '#9CA3AF' }}>
                <X size={16} />
              </button>
            </div>
            <div className="p-6">
              {shiftLoading ? (
                <div className="flex items-center justify-center py-8 gap-3 text-gray-600">
                  <div className="animate-spin rounded-full h-5 w-5 border-2 border-[#2A9D8F]/30 border-t-[#2A9D8F]" />
                  Loading shifts...
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
                        <th className="text-left py-3 pr-4 text-xs font-semibold uppercase tracking-wider text-gray-600">Day</th>
                        {SHIFTS.map(s => (
                          <th key={s} className="text-center py-3 px-2 text-xs font-semibold uppercase tracking-wider text-gray-600">
                            {SHIFT_LABELS[s]}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {DAYS.map(day => (
                        <tr key={day} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
                          <td className="py-3 pr-4 text-white capitalize text-sm font-medium">{day}</td>
                          {SHIFTS.map(shift => {
                            const committed = isCommitted(day, shift)
                            return (
                              <td key={shift} className="py-3 px-2 text-center">
                                <div className="w-7 h-7 rounded-lg mx-auto flex items-center justify-center"
                                  style={{ background: committed ? 'rgba(42,157,143,0.2)' : 'rgba(255,255,255,0.04)', border: `1px solid ${committed ? 'rgba(42,157,143,0.4)' : 'rgba(255,255,255,0.07)'}` }}>
                                  {committed && (
                                    <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="#2A9D8F" strokeWidth="2.5">
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                                    </svg>
                                  )}
                                </div>
                              </td>
                            )
                          })}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {shiftData.length === 0 && (
                    <p className="text-gray-600 text-center py-6 text-sm">No shift commitments found.</p>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Warning Modal */}
      {warningModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{ background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(8px)' }}
          onClick={() => setWarningModal(null)}>
          <div className="w-full max-w-md rounded-2xl"
            style={{ background: '#16181D', border: '1px solid rgba(255,255,255,0.08)', boxShadow: '0 40px 120px rgba(0,0,0,0.6)' }}
            onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 py-5"
              style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl flex items-center justify-center"
                  style={{ background: 'rgba(250,204,21,0.12)', border: '1px solid rgba(250,204,21,0.25)' }}>
                  <AlertTriangle size={16} color="#facc15" />
                </div>
                <div>
                  <h2 className="text-sm font-bold text-white">Issue Warning</h2>
                  <p className="text-xs text-gray-500">{warningModal.name}</p>
                </div>
              </div>
              <button onClick={() => setWarningModal(null)}
                className="w-8 h-8 rounded-lg flex items-center justify-center btn-press"
                style={{ background: 'rgba(255,255,255,0.05)', color: '#9CA3AF' }}>
                <X size={16} />
              </button>
            </div>

            <div className="p-6 space-y-5">
              {/* Strike info */}
              <div className="space-y-2 p-4 rounded-xl" style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.06)' }}>
                {[
                  { label: 'Current complaints', value: warningModal.complaintCount, color: 'white' },
                  { label: 'Current strike', value: getStrikeInfo(warningModal.complaintCount).label, color: getStrikeInfo(warningModal.complaintCount).color },
                  { label: 'After this warning', value: getStrikeInfo(warningModal.complaintCount + 1).label, color: getStrikeInfo(warningModal.complaintCount + 1).color },
                ].map(({ label, value, color }) => (
                  <div key={label} className="flex justify-between text-sm">
                    <span className="text-gray-500">{label}</span>
                    <span style={{ color }}>{value}</span>
                  </div>
                ))}
              </div>

              <p className="text-[10px] text-gray-600 leading-relaxed">
                Strike policy: 1st = Warning | 2nd = Mandatory meeting | 3rd = 1-week suspension | 4th = Permanent removal
              </p>

              {warningModal.complaintCount + 1 >= 3 && (
                <div className="px-4 py-3 rounded-xl text-sm"
                  style={{ background: 'rgba(248,113,113,0.08)', border: '1px solid rgba(248,113,113,0.25)', color: '#f87171' }}>
                  This warning will automatically suspend the rider.
                </div>
              )}

              <textarea
                value={warningNote} onChange={e => setWarningNote(e.target.value)}
                placeholder="Describe the reason for this warning..."
                rows={3} className="w-full text-sm text-white placeholder-gray-600 focus:outline-none resize-none"
                style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', padding: '12px 16px', borderRadius: 12 }} />

              <div className="flex gap-3">
                <button onClick={() => setWarningModal(null)}
                  className="flex-1 py-3 rounded-xl text-sm text-gray-500 hover:text-white btn-press"
                  style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}>
                  Cancel
                </button>
                <button
                  onClick={() => issueWarning(warningModal)}
                  disabled={issuingWarning || !warningNote.trim()}
                  className="flex-1 py-3 rounded-xl text-sm font-bold text-black btn-press disabled:opacity-50"
                  style={{ background: 'linear-gradient(135deg, #facc15, #eab308)' }}>
                  {issuingWarning ? 'Issuing...' : 'Confirm Warning'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
