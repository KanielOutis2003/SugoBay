import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import type { Complaint } from '../lib/supabase'

function ResolveModal({ isOpen, onClose, onSubmit }: {
  isOpen: boolean; onClose: () => void; onSubmit: (resolution: string) => void;
}) {
  const [value, setValue] = useState('')
  if (!isOpen) return null
  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={onClose}>
      <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34] w-full max-w-md mx-4" onClick={e => e.stopPropagation()}>
        <h3 className="text-lg font-semibold text-white mb-4">Resolve Complaint</h3>
        <textarea
          value={value} onChange={e => setValue(e.target.value)} placeholder="Enter resolution details..." autoFocus rows={3}
          className="w-full px-4 py-3 bg-[#1A1C20] text-white rounded-lg border border-[#2D2F34] focus:border-[#2A9D8F] outline-none mb-4 resize-none"
        />
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="px-4 py-2 text-gray-400 hover:text-white text-sm">Cancel</button>
          <button onClick={() => { if (value.trim()) { onSubmit(value.trim()); setValue(''); onClose(); } }}
            className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm hover:bg-[#2A9D8F]/80">Resolve</button>
        </div>
      </div>
    </div>
  )
}

export default function Complaints() {
  const [complaints, setComplaints] = useState<Complaint[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('open')
  const [resolveModal, setResolveModal] = useState<{ isOpen: boolean; complaintId: string }>({ isOpen: false, complaintId: '' })

  useEffect(() => { loadComplaints() }, [filter])

  async function loadComplaints() {
    setLoading(true)
    let query = supabaseAdmin.from('complaints').select('*').order('created_at', { ascending: false })
    if (filter !== 'all') query = query.eq('status', filter)
    const { data } = await query
    setComplaints(data || [])
    setLoading(false)
  }

  async function resolve(resolution: string) {
    await supabaseAdmin.from('complaints').update({
      status: 'resolved',
      resolution,
      resolved_at: new Date().toISOString(),
    }).eq('id', resolveModal.complaintId)
    loadComplaints()
  }

  async function dismiss(id: string) {
    await supabaseAdmin.from('complaints').update({
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
                  <button onClick={() => setResolveModal({ isOpen: true, complaintId: c.id })} className="px-3 py-1.5 bg-[#2A9D8F] text-white rounded-lg text-xs">Resolve</button>
                  <button onClick={() => dismiss(c.id)} className="px-3 py-1.5 bg-[#2D2F34] text-gray-400 rounded-lg text-xs">Dismiss</button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
      <ResolveModal
        isOpen={resolveModal.isOpen}
        onClose={() => setResolveModal({ isOpen: false, complaintId: '' })}
        onSubmit={resolve}
      />
    </div>
  )
}
