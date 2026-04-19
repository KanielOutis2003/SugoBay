import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { PahapitRequest } from '../lib/supabase'

export default function PahapitJobs() {
  const [jobs, setJobs] = useState<PahapitRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')
  const [selectedJob, setSelectedJob] = useState<PahapitRequest | null>(null)

  useEffect(() => { loadJobs() }, [filter])

  async function loadJobs() {
    setLoading(true)
    let query = supabase.from('pahapit_requests').select('*').order('created_at', { ascending: false }).limit(100)
    if (filter !== 'all') query = query.eq('status', filter)
    const { data } = await query
    setJobs(data || [])
    setLoading(false)
  }

  const statuses = ['all', 'pending', 'accepted', 'buying', 'delivering', 'completed', 'cancelled']

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Pahapit Jobs</h1>
        <button onClick={loadJobs} className="px-4 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm">Refresh</button>
      </div>

      <div className="flex gap-2 mb-6 flex-wrap">
        {statuses.map(s => (
          <button key={s} onClick={() => setFilter(s)}
            className={`px-3 py-1.5 rounded-lg text-xs capitalize ${filter === s ? 'bg-[#2A9D8F] text-white' : 'bg-[#23252A] text-gray-400 border border-[#2D2F34]'}`}>
            {s}
          </button>
        ))}
      </div>

      {loading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-[#23252A] rounded-xl border border-[#2D2F34] overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[#2D2F34] text-gray-400">
                <th className="text-left p-4">Store</th>
                <th className="text-left p-4">Category</th>
                <th className="text-left p-4">Items</th>
                <th className="text-left p-4">Budget</th>
                <th className="text-left p-4">Actual</th>
                <th className="text-left p-4">Status</th>
                <th className="text-left p-4">Receipt</th>
                <th className="text-left p-4">Created</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map(job => (
                <tr key={job.id} className="border-b border-[#2D2F34] hover:bg-white/5 cursor-pointer" onClick={() => setSelectedJob(job)}>
                  <td className="p-4 text-white">{job.store_name}</td>
                  <td className="p-4 text-gray-400 capitalize">{job.store_category}</td>
                  <td className="p-4 text-gray-300 max-w-[200px] truncate">{job.items_description}</td>
                  <td className="p-4 text-[#E9C46A]">₱{job.budget_limit.toFixed(2)}</td>
                  <td className="p-4 text-[#2A9D8F]">{job.actual_amount_spent ? `₱${job.actual_amount_spent.toFixed(2)}` : '-'}</td>
                  <td className="p-4">
                    <span className={`px-2 py-1 rounded-full text-xs ${
                      job.status === 'completed' ? 'bg-green-500/20 text-green-400' :
                      job.status === 'cancelled' ? 'bg-red-500/20 text-red-400' :
                      'bg-yellow-500/20 text-yellow-400'
                    }`}>{job.status}</span>
                  </td>
                  <td className="p-4">
                    {job.receipt_photo_url ? (
                      <a href={job.receipt_photo_url} target="_blank" rel="noreferrer" className="text-[#2A9D8F] text-xs hover:underline">View</a>
                    ) : '-'}
                  </td>
                  <td className="p-4 text-gray-400">{new Date(job.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Detail Modal */}
      {selectedJob && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setSelectedJob(null)}>
          <div className="bg-[#23252A] rounded-xl p-6 max-w-lg w-full mx-4 border border-[#2D2F34]" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-white mb-4">{selectedJob.store_name}</h2>
            <div className="space-y-3 text-sm">
              <p className="text-gray-400">Items: <span className="text-white">{selectedJob.items_description}</span></p>
              <p className="text-gray-400">Budget: <span className="text-[#E9C46A]">₱{selectedJob.budget_limit.toFixed(2)}</span></p>
              {selectedJob.actual_amount_spent && (
                <p className="text-gray-400">Actual: <span className="text-[#2A9D8F]">₱{selectedJob.actual_amount_spent.toFixed(2)}</span></p>
              )}
              <p className="text-gray-400">Errand Fee: <span className="text-white">₱{selectedJob.errand_fee.toFixed(2)}</span></p>
              <p className="text-gray-400">Delivery Fee: <span className="text-white">₱{selectedJob.delivery_fee.toFixed(2)}</span></p>
              {selectedJob.total_amount && (
                <p className="text-gray-400">Total: <span className="text-[#E9C46A] font-bold">₱{selectedJob.total_amount.toFixed(2)}</span></p>
              )}
              {selectedJob.receipt_photo_url && (
                <img src={selectedJob.receipt_photo_url} alt="Receipt" className="rounded-lg max-h-48 w-full object-cover" />
              )}
            </div>
            <button onClick={() => setSelectedJob(null)} className="mt-4 w-full py-2 bg-[#2D2F34] text-white rounded-lg text-sm">Close</button>
          </div>
        </div>
      )}
    </div>
  )
}
