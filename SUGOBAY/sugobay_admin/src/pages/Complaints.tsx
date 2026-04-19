import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { Complaint } from '../lib/supabase'

export default function Complaints() {
  const [complaints, setComplaints] = useState<Complaint[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('open')

  useEffect(() => { loadComplaints() }, [filter])

  async function loadComplaints() {
    setLoading(true)
    let query = supabase.from('complaints').select('*').order('created_at', { ascending: false })
    if (filter !== 'all') query = query.eq('status', filter)
    const { data } = await query
    setComplaints(data || [])
    setLoading(false)
  }

  async function resolve(id: string) {
    const resolution = prompt('Enter resolution:')
    if (!resolution) return
    await supabase.from('complaints').update({
      status: 'resolved',
      resolution,
      resolved_at: new Date().toISOString(),
    }).eq('id', id)
    loadComplaints()
  }

  async function dismiss(id: string) {
    await supabase.from('complaints').update({
      status: 'dismissed',
      resolved_at: new Date().toISOString(),
    }).eq('id', id)
    loadComplaints()
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-6">Complaints</h1>

      <div className="flex gap-2 mb-6">
        {['all', 'open', 'resolved', 'dismissed'].map(s => (
          <button key={s} onClick={() => setFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs capitalize ${filter === s ? 'bg-[#E76F51] text-white' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34]'}`}>
            {s}
          </button>
        ))}
      </div>

      {loading ? <p className="text-gray-500">Loading...</p> : complaints.length === 0 ? (
        <p className="text-gray-500">No complaints found</p>
      ) : (
        <div className="space-y-4">
          {complaints.map(c => (
            <div key={c.id} className="bg-[#23252A] rounded-xl p-5 border border-[#2D2F34]">
              <div className="flex items-start justify-between mb-3">
                <div>
                  <span className="text-[#E76F51] text-xs font-semibold capitalize">{c.type}</span>
                  <p className="text-sm text-gray-300 mt-1">{c.description || 'No description'}</p>
                </div>
                <span className={`px-2 py-1 rounded-full text-xs ${
                  c.status === 'open' ? 'bg-red-500/20 text-red-400' :
                  c.status === 'resolved' ? 'bg-green-500/20 text-green-400' :
                  'bg-gray-500/20 text-gray-400'
                }`}>{c.status}</span>
              </div>
              <div className="flex items-center gap-4 text-xs text-gray-500 mb-3">
                {c.order_id && <span>Order: #{c.order_id.slice(-6)}</span>}
                {c.pahapit_id && <span>Pahapit: #{c.pahapit_id.slice(-6)}</span>}
                <span>{new Date(c.created_at).toLocaleString()}</span>
              </div>
              {c.photo_url && (
                <a href={c.photo_url} target="_blank" rel="noreferrer" className="text-xs text-[#2A9D8F] hover:underline block mb-3">View Photo</a>
              )}
              {c.resolution && (
                <p className="text-xs text-green-400 bg-green-500/10 p-2 rounded mb-3">Resolution: {c.resolution}</p>
              )}
              {c.status === 'open' && (
                <div className="flex gap-2">
                  <button onClick={() => resolve(c.id)} className="px-3 py-1.5 bg-[#2A9D8F] text-white rounded-lg text-xs">Resolve</button>
                  <button onClick={() => dismiss(c.id)} className="px-3 py-1.5 bg-[#2D2F34] text-gray-400 rounded-lg text-xs">Dismiss</button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
