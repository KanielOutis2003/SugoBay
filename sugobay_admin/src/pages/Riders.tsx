import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

interface Rider {
  id: string
  name: string
  phone: string
  is_active: boolean
  created_at: string
  location?: { is_online: boolean; lat: number; lng: number }
  totalJobs: number
  rating: number
}

export default function Riders() {
  const [riders, setRiders] = useState<Rider[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => { loadRiders() }, [])

  async function loadRiders() {
    setLoading(true)
    const { data: users } = await supabase.from('users').select('*').eq('role', 'rider').order('created_at', { ascending: false })

    const riderList: Rider[] = []
    for (const u of (users || [])) {
      const { data: loc } = await supabase.from('rider_locations').select('*').eq('rider_id', u.id).maybeSingle()
      const { count: foodCount } = await supabase.from('orders').select('id', { count: 'exact', head: true }).eq('rider_id', u.id).eq('status', 'delivered')
      const { count: pahapitCount } = await supabase.from('pahapit_requests').select('id', { count: 'exact', head: true }).eq('rider_id', u.id).eq('status', 'completed')
      const { data: ratings } = await supabase.from('ratings').select('rider_rating').not('rider_rating', 'is', null)
      const avgRating = ratings && ratings.length > 0 ? ratings.reduce((sum, r) => sum + (r.rider_rating || 0), 0) / ratings.length : 0

      riderList.push({
        id: u.id,
        name: u.name,
        phone: u.phone,
        is_active: u.is_active,
        created_at: u.created_at,
        location: loc || undefined,
        totalJobs: (foodCount || 0) + (pahapitCount || 0),
        rating: avgRating,
      })
    }
    setRiders(riderList)
    setLoading(false)
  }

  async function toggleActive(id: string, current: boolean) {
    await supabase.from('users').update({ is_active: !current }).eq('id', id)
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
        <button onClick={loadRiders} className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm">Refresh</button>
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
                <th className="text-left p-4">Status</th>
                <th className="text-left p-4">Level</th>
                <th className="text-left p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {riders.map(r => {
                const level = getStatusLevel(r.totalJobs)
                return (
                  <tr key={r.id} className="border-b border-[#2D2F34] hover:bg-white/5">
                    <td className="p-4 text-white">{r.name}</td>
                    <td className="p-4 text-gray-300">{r.phone}</td>
                    <td className="p-4">
                      <span className={`w-2.5 h-2.5 rounded-full inline-block ${r.location?.is_online ? 'bg-green-400' : 'bg-gray-600'}`} />
                    </td>
                    <td className="p-4 text-[#E9C46A]">{r.totalJobs}</td>
                    <td className="p-4 text-[#D4AF37]">{r.rating > 0 ? r.rating.toFixed(1) : 'N/A'}</td>
                    <td className="p-4">
                      <span className={`px-2 py-1 rounded-full text-xs ${r.is_active ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                        {r.is_active ? 'Active' : 'Suspended'}
                      </span>
                    </td>
                    <td className={`p-4 text-xs font-semibold ${level.color}`}>{level.label}</td>
                    <td className="p-4">
                      <button onClick={() => toggleActive(r.id, r.is_active)} className={`text-xs ${r.is_active ? 'text-red-400' : 'text-green-400'}`}>
                        {r.is_active ? 'Suspend' : 'Reactivate'}
                      </button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
