import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import { exportToCsv } from '../lib/csvExport'
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

// Teal rider dot icon
const riderIcon = new L.DivIcon({
  html: '<div style="background:#2A9D8F;width:28px;height:28px;border-radius:50%;border:3px solid #fff;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 6px rgba(0,0,0,0.4)"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><path d="M12 2L19 21L12 17L5 21L12 2Z"/></svg></div>',
  className: '',
  iconSize: [28, 28],
  iconAnchor: [14, 14],
})

// Region definitions
const REGIONS: Record<string, { center: [number, number]; zoom: number; label: string }> = {
  ubay:  { center: [10.0581, 124.0474], zoom: 14, label: 'Ubay, Bohol' },
  bohol: { center: [9.8500,  124.1435], zoom: 11, label: 'Bohol' },
  cebu:  { center: [10.3157, 123.8854], zoom: 11, label: 'Cebu' },
}

function FlyTo({ center, zoom }: { center: [number, number]; zoom: number }) {
  const map = useMap()
  useEffect(() => { map.flyTo(center, zoom, { duration: 1.2 }) }, [center, zoom])
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
  if (count === 0) return { label: 'Clean', color: 'text-green-400', bgColor: 'bg-green-500/20' }
  if (count === 1) return { label: 'Warning', color: 'text-yellow-400', bgColor: 'bg-yellow-500/20' }
  if (count === 2) return { label: 'Meeting Required', color: 'text-orange-400', bgColor: 'bg-orange-500/20' }
  if (count === 3) return { label: 'Suspended', color: 'text-red-400', bgColor: 'bg-red-500/20' }
  return { label: 'Removed', color: 'text-red-500', bgColor: 'bg-red-600/20' }
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

    // Build lookup maps
    const locMap = new Map(locations.map(l => [l.rider_id, l]))
    const ratingMap = new Map<string, number[]>()
    for (const r of ratings) {
      const riderId = (r as any).orders?.rider_id || (r as any).pahapit_requests?.rider_id
      if (!riderId) continue
      if (!ratingMap.has(riderId)) ratingMap.set(riderId, [])
      ratingMap.get(riderId)!.push(r.rider_rating || 0)
    }

    // Count delivered orders and completed pahapits per rider
    const orderCountMap = new Map<string, number>()
    for (const o of allOrders) {
      if (o.status === 'delivered') {
        orderCountMap.set(o.rider_id, (orderCountMap.get(o.rider_id) || 0) + 1)
      }
    }
    const pahapitCountMap = new Map<string, number>()
    for (const p of allPahapits) {
      if (p.status === 'completed') {
        pahapitCountMap.set(p.rider_id, (pahapitCountMap.get(p.rider_id) || 0) + 1)
      }
    }

    // Map order_id -> rider_id and pahapit_id -> rider_id for complaint lookups
    const orderRiderMap = new Map<string, string>()
    for (const o of allOrders) {
      if (o.rider_id) orderRiderMap.set(o.id, o.rider_id)
    }
    const pahapitRiderMap = new Map<string, string>()
    for (const p of allPahapits) {
      if (p.rider_id) pahapitRiderMap.set(p.id, p.rider_id)
    }

    // Count complaints per rider
    const complaintCountMap = new Map<string, number>()
    for (const c of complaintsOrders) {
      const riderId = orderRiderMap.get(c.order_id)
      if (riderId) complaintCountMap.set(riderId, (complaintCountMap.get(riderId) || 0) + 1)
    }
    for (const c of complaintsPahapit) {
      const riderId = pahapitRiderMap.get(c.pahapit_id)
      if (riderId) complaintCountMap.set(riderId, (complaintCountMap.get(riderId) || 0) + 1)
    }

    const riderList: Rider[] = users.map(u => {
      const riderRatings = ratingMap.get(u.id) || []
      const avgRating = riderRatings.length > 0 ? riderRatings.reduce((a, b) => a + b, 0) / riderRatings.length : 0
      return {
        id: u.id,
        name: u.name,
        phone: u.phone,
        is_active: u.is_active,
        created_at: u.created_at,
        location: locMap.get(u.id) || undefined,
        totalJobs: (orderCountMap.get(u.id) || 0) + (pahapitCountMap.get(u.id) || 0),
        rating: avgRating,
        complaintCount: complaintCountMap.get(u.id) || 0,
      }
    })
    setRiders(riderList)
    setLoading(false)
  }

  async function toggleActive(id: string, current: boolean) {
    await supabaseAdmin.from('users').update({ is_active: !current }).eq('id', id)
    loadRiders()
  }

  async function openShiftModal(rider: Rider) {
    setShiftModalRider(rider)
    setShiftLoading(true)
    const { data } = await supabaseAdmin
      .from('rider_shifts')
      .select('day_of_week, shift, is_committed')
      .eq('rider_id', rider.id)
    setShiftData(data || [])
    setShiftLoading(false)
  }

  function isCommitted(day: string, shift: string): boolean {
    return shiftData.some(s => s.day_of_week === day && s.shift === shift && s.is_committed)
  }

  async function issueWarning(rider: Rider) {
    setIssuingWarning(true)
    const newCount = rider.complaintCount + 1
    const strikeInfo = getStrikeInfo(newCount)

    // If strike level >= 3, suspend the rider
    if (newCount >= 3) {
      await supabaseAdmin.from('users').update({ is_active: false }).eq('id', rider.id)
    }

    // Find an order belonging to this rider so the complaint links back to them
    const { data: anyOrder } = await supabaseAdmin
      .from('orders')
      .select('id')
      .eq('rider_id', rider.id)
      .limit(1)
      .single()

    // Find a pahapit belonging to this rider as fallback
    const { data: anyPahapit } = await supabaseAdmin
      .from('pahapit_requests')
      .select('id')
      .eq('rider_id', rider.id)
      .limit(1)
      .single()

    // Insert a complaint record as the warning, linked to an order or pahapit so it maps back to the rider
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

  function getStatusLevel(totalJobs: number) {
    if (totalJobs >= 500) return { label: 'Elite', color: 'text-purple-400' }
    if (totalJobs >= 200) return { label: 'Trusted', color: 'text-blue-400' }
    if (totalJobs >= 50) return { label: 'Regular', color: 'text-green-400' }
    return { label: 'Rookie', color: 'text-gray-400' }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Riders</h1>
        <div className="flex gap-2">
          <button onClick={() => exportToCsv('riders', riders.map(r => ({ ...r, location: r.location ? `${r.location.lat},${r.location.lng}` : '' })))} className="px-4 py-2 bg-[#23252A] text-gray-300 rounded-lg text-sm border border-[#2D2F34] hover:bg-[#2D2F34]">Export CSV</button>
          <button onClick={loadRiders} className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm">Refresh</button>
        </div>
      </div>

      {/* Live Rider Map */}
      <div className="bg-[#23252A] rounded-xl border border-[#2D2F34] mb-6 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-[#2D2F34]">
          <div className="flex items-center gap-2">
            <span className="text-white font-semibold text-sm">Live Rider Map</span>
            <span className="text-xs bg-green-500/20 text-green-400 px-2 py-0.5 rounded-full">
              {riders.filter(r => r.location?.is_online).length} online
            </span>
          </div>
          {/* Region filter */}
          <div className="flex gap-1">
            {(Object.keys(REGIONS) as Array<keyof typeof REGIONS>).map(key => (
              <button
                key={key}
                onClick={() => setMapRegion(key)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                  mapRegion === key
                    ? 'bg-[#2A9D8F] text-white'
                    : 'bg-[#1A1C20] text-gray-400 hover:text-white border border-[#2D2F34]'
                }`}
              >
                {REGIONS[key].label}
              </button>
            ))}
          </div>
        </div>
        <div style={{ height: 320 }}>
          <MapContainer
            center={REGIONS[mapRegion].center}
            zoom={REGIONS[mapRegion].zoom}
            style={{ height: '100%', width: '100%' }}
            zoomControl={true}
          >
            <TileLayer
              url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
              attribution='&copy; <a href="https://carto.com/">CARTO</a>'
            />
            <FlyTo center={REGIONS[mapRegion].center} zoom={REGIONS[mapRegion].zoom} />
            {riders
              .filter(r => r.location?.is_online && r.location.lat && r.location.lng)
              .map(r => (
                <Marker key={r.id} position={[r.location!.lat, r.location!.lng]} icon={riderIcon}>
                  <Popup>
                    <div style={{ fontFamily: 'sans-serif', minWidth: 120 }}>
                      <div style={{ fontWeight: 700, marginBottom: 4 }}>{r.name}</div>
                      <div style={{ color: '#2A9D8F', fontSize: 12 }}>● Online</div>
                      <div style={{ color: '#888', fontSize: 11, marginTop: 2 }}>{r.phone}</div>
                    </div>
                  </Popup>
                </Marker>
              ))}
          </MapContainer>
        </div>
        {riders.filter(r => r.location?.is_online).length === 0 && !loading && (
          <p className="text-gray-500 text-xs text-center py-2">No riders currently online</p>
        )}
      </div>

      {loading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-[#23252A] rounded-xl border border-[#2D2F34] overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[#2D2F34] text-gray-400">
                <th className="text-left p-4">Name</th>
                <th className="text-left p-4">Phone</th>
                <th className="text-left p-4">Online</th>
                <th className="text-left p-4">Jobs</th>
                <th className="text-left p-4">Rating</th>
                <th className="text-left p-4">Warnings</th>
                <th className="text-left p-4">Strike Level</th>
                <th className="text-left p-4">Status</th>
                <th className="text-left p-4">Level</th>
                <th className="text-left p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {riders.map(r => {
                const level = getStatusLevel(r.totalJobs)
                const strike = getStrikeInfo(r.complaintCount)
                return (
                  <tr key={r.id} className="border-b border-[#2D2F34] hover:bg-white/5">
                    <td className="p-4 text-white">{r.name}</td>
                    <td className="p-4 text-gray-300">{r.phone}</td>
                    <td className="p-4">
                      <span className={`w-2.5 h-2.5 rounded-full inline-block ${r.location?.is_online ? 'bg-green-400' : 'bg-gray-600'}`} />
                    </td>
                    <td className="p-4 text-[#E9C46A]">{r.totalJobs}</td>
                    <td className="p-4 text-[#D4AF37]">{r.rating > 0 ? r.rating.toFixed(1) : '0'}</td>
                    <td className="p-4 text-gray-300">{r.complaintCount}</td>
                    <td className="p-4">
                      <span className={`px-2 py-1 rounded-full text-xs ${strike.bgColor} ${strike.color}`}>
                        {strike.label}
                      </span>
                    </td>
                    <td className="p-4">
                      <span className={`px-2 py-1 rounded-full text-xs ${r.is_active ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                        {r.is_active ? 'Active' : 'Suspended'}
                      </span>
                    </td>
                    <td className={`p-4 text-xs font-semibold ${level.color}`}>{level.label}</td>
                    <td className="p-4">
                      <div className="flex gap-2 items-center">
                        <button onClick={() => openShiftModal(r)} className="text-xs text-blue-400 hover:text-blue-300">
                          View Shifts
                        </button>
                        <button onClick={() => { setWarningModal(r); setWarningNote('') }} className="text-xs text-yellow-400 hover:text-yellow-300">
                          Issue Warning
                        </button>
                        <button onClick={() => toggleActive(r.id, r.is_active)} className={`text-xs ${r.is_active ? 'text-red-400' : 'text-green-400'}`}>
                          {r.is_active ? 'Suspend' : 'Reactivate'}
                        </button>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Shift Modal */}
      {shiftModalRider && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShiftModalRider(null)}>
          <div className="bg-[#1A1C20] rounded-xl border border-[#2D2F34] p-6 w-full max-w-2xl mx-4" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-white">Shift Schedule - {shiftModalRider.name}</h2>
              <button onClick={() => setShiftModalRider(null)} className="text-gray-400 hover:text-white text-xl">&times;</button>
            </div>
            {shiftLoading ? (
              <p className="text-gray-500">Loading shifts...</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-[#2D2F34] text-gray-400">
                      <th className="text-left p-3">Day</th>
                      {SHIFTS.map(s => (
                        <th key={s} className="text-center p-3">{SHIFT_LABELS[s]}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {DAYS.map(day => (
                      <tr key={day} className="border-b border-[#2D2F34]">
                        <td className="p-3 text-white capitalize">{day}</td>
                        {SHIFTS.map(shift => {
                          const committed = isCommitted(day, shift)
                          return (
                            <td key={shift} className="p-3 text-center">
                              <span className={`inline-block w-6 h-6 rounded-md ${committed ? 'bg-[#2A9D8F]' : 'bg-[#2D2F34]'}`}>
                                {committed && (
                                  <svg className="w-6 h-6 text-white p-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                  </svg>
                                )}
                              </span>
                            </td>
                          )
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
                {shiftData.length === 0 && (
                  <p className="text-gray-500 text-center py-4">No shift commitments found for this rider.</p>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Warning Modal */}
      {warningModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setWarningModal(null)}>
          <div className="bg-[#1A1C20] rounded-xl border border-[#2D2F34] p-6 w-full max-w-md mx-4" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-white">Issue Warning - {warningModal.name}</h2>
              <button onClick={() => setWarningModal(null)} className="text-gray-400 hover:text-white text-xl">&times;</button>
            </div>

            <div className="mb-4 space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Current complaints:</span>
                <span className="text-white">{warningModal.complaintCount}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Current strike level:</span>
                <span className={getStrikeInfo(warningModal.complaintCount).color}>
                  {getStrikeInfo(warningModal.complaintCount).label}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">After this warning:</span>
                <span className={getStrikeInfo(warningModal.complaintCount + 1).color}>
                  {getStrikeInfo(warningModal.complaintCount + 1).label}
                </span>
              </div>
            </div>

            <div className="mb-2 text-xs text-gray-500">
              <p>Strike policy: 1st = Warning | 2nd = Mandatory meeting | 3rd = 1 week suspension | 4th = Permanent removal</p>
            </div>

            {warningModal.complaintCount + 1 >= 3 && (
              <div className="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 text-sm">
                This warning will automatically suspend the rider's account.
              </div>
            )}

            <textarea
              value={warningNote}
              onChange={e => setWarningNote(e.target.value)}
              placeholder="Describe the reason for this warning..."
              className="w-full p-3 bg-[#23252A] border border-[#2D2F34] rounded-lg text-white placeholder-gray-500 text-sm mb-4 resize-none"
              rows={3}
            />

            <div className="flex gap-2 justify-end">
              <button onClick={() => setWarningModal(null)} className="px-4 py-2 text-sm text-gray-400 hover:text-white">
                Cancel
              </button>
              <button
                onClick={() => issueWarning(warningModal)}
                disabled={issuingWarning || !warningNote.trim()}
                className="px-4 py-2 bg-yellow-600 text-white rounded-lg text-sm hover:bg-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {issuingWarning ? 'Issuing...' : 'Confirm Warning'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
