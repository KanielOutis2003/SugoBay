import { useEffect, useState } from 'react'
import { supabaseAdmin } from '../lib/supabase'
import type { PahapitRequest } from '../lib/supabase'

export default function PahapitJobs() {
  const [jobs, setJobs] = useState<PahapitRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')
  const [selectedJob, setSelectedJob] = useState<PahapitRequest | null>(null)
  const [showDisputeModal, setShowDisputeModal] = useState(false)
  const [disputeJob, setDisputeJob] = useState<PahapitRequest | null>(null)
  const [disputeResolution, setDisputeResolution] = useState('')
  const [disputeRefund, setDisputeRefund] = useState(false)
  const [disputeSaving, setDisputeSaving] = useState(false)

  useEffect(() => { loadJobs() }, [filter])

  async function loadJobs() {
    setLoading(true)
    let query = supabaseAdmin.from('pahapit_requests').select('*').order('created_at', { ascending: false }).limit(100)
    if (filter !== 'all') query = query.eq('status', filter)
    const { data } = await query
    setJobs(data || [])
    setLoading(false)
  }

  function openDispute(job: PahapitRequest) {
    setDisputeJob(job)
    setDisputeResolution('')
    setDisputeRefund(false)
    setShowDisputeModal(true)
  }

  async function resolveDispute() {
    if (!disputeJob || !disputeResolution.trim()) return
    setDisputeSaving(true)

    // Update pahapit status to disputed_resolved
    await supabaseAdmin.from('pahapit_requests').update({
      status: disputeRefund ? 'cancelled' : 'completed',
    }).eq('id', disputeJob.id)

    // Create a complaint record for the dispute resolution
    await supabaseAdmin.from('complaints').insert({
      pahapit_id: disputeJob.id,
      customer_id: disputeJob.customer_id,
      type: 'dispute_resolution',
      description: `Dispute on pahapit job. Budget: ₱${disputeJob.budget_limit}, Actual: ₱${disputeJob.actual_amount_spent || 0}`,
      status: 'resolved',
      resolution: disputeResolution,
      resolved_at: new Date().toISOString(),
    })

    setDisputeSaving(false)
    setShowDisputeModal(false)
    loadJobs()
  }

  async function cancelJob(id: string) {
    if (!confirm('Cancel this pahapit job?')) return
    await supabaseAdmin.from('pahapit_requests').update({ status: 'cancelled' }).eq('id', id)
    loadJobs()
  }

  const statuses = ['all', 'pending', 'accepted', 'buying', 'delivering', 'completed', 'cancelled']

  const hasOverspend = (job: PahapitRequest) =>
    job.actual_amount_spent != null && job.actual_amount_spent > job.budget_limit

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
                <th className="text-left p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map(job => (
                <tr key={job.id} className="border-b border-[#2D2F34] hover:bg-white/5">
                  <td className="p-4 text-white cursor-pointer" onClick={() => setSelectedJob(job)}>{job.store_name}</td>
                  <td className="p-4 text-gray-400 capitalize">{job.store_category}</td>
                  <td className="p-4 text-gray-300 max-w-[200px] truncate">{job.items_description}</td>
                  <td className="p-4 text-[#E9C46A]">₱{job.budget_limit.toFixed(2)}</td>
                  <td className={`p-4 ${hasOverspend(job) ? 'text-red-400 font-semibold' : 'text-[#2A9D8F]'}`}>
                    {job.actual_amount_spent ? `₱${job.actual_amount_spent.toFixed(2)}` : '-'}
                    {hasOverspend(job) && <span className="ml-1 text-xs">⚠️</span>}
                  </td>
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
                  <td className="p-4">
                    <div className="flex gap-2">
                      {(job.status === 'completed' || job.status === 'delivering') && hasOverspend(job) && (
                        <button onClick={() => openDispute(job)} className="text-xs text-[#E9C46A] hover:underline">Dispute</button>
                      )}
                      {job.status !== 'completed' && job.status !== 'cancelled' && (
                        <button onClick={() => cancelJob(job.id)} className="text-xs text-red-400 hover:underline">Cancel</button>
                      )}
                    </div>
                  </td>
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
              {selectedJob.actual_amount_spent != null && (
                <p className="text-gray-400">Actual: <span className={hasOverspend(selectedJob) ? 'text-red-400 font-semibold' : 'text-[#2A9D8F]'}>
                  ₱{selectedJob.actual_amount_spent.toFixed(2)}
                  {hasOverspend(selectedJob) && ` (over by ₱${(selectedJob.actual_amount_spent - selectedJob.budget_limit).toFixed(2)})`}
                </span></p>
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
            <div className="flex gap-2 mt-4">
              {hasOverspend(selectedJob) && selectedJob.status !== 'cancelled' && (
                <button onClick={() => { setSelectedJob(null); openDispute(selectedJob) }} className="flex-1 py-2 bg-[#E9C46A]/20 text-[#E9C46A] rounded-lg text-sm">
                  Open Dispute
                </button>
              )}
              <button onClick={() => setSelectedJob(null)} className="flex-1 py-2 bg-[#2D2F34] text-white rounded-lg text-sm">Close</button>
            </div>
          </div>
        </div>
      )}

      {/* Dispute Resolution Modal */}
      {showDisputeModal && disputeJob && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowDisputeModal(false)}>
          <div className="bg-[#23252A] rounded-xl p-6 max-w-md w-full mx-4 border border-[#2D2F34]" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-white mb-2">Resolve Dispute</h2>
            <p className="text-sm text-gray-400 mb-4">{disputeJob.store_name} — Budget: ₱{disputeJob.budget_limit.toFixed(2)}, Actual: ₱{disputeJob.actual_amount_spent?.toFixed(2)}</p>

            <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3 mb-4">
              <p className="text-xs text-red-400">Overspend: ₱{((disputeJob.actual_amount_spent || 0) - disputeJob.budget_limit).toFixed(2)}</p>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-sm text-gray-400 block mb-1">Resolution</label>
                <textarea value={disputeResolution} onChange={e => setDisputeResolution(e.target.value)}
                  rows={3} placeholder="Describe the resolution..."
                  className="w-full px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm focus:outline-none focus:border-[#2A9D8F] resize-none" />
              </div>
              <label className="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                <input type="checkbox" checked={disputeRefund} onChange={e => setDisputeRefund(e.target.checked)}
                  className="rounded border-[#2D2F34]" />
                Cancel job and issue refund
              </label>
              <div className="flex gap-2 pt-2">
                <button onClick={() => setShowDisputeModal(false)} className="flex-1 py-2 bg-[#2D2F34] text-white rounded-lg text-sm">Cancel</button>
                <button onClick={resolveDispute} disabled={disputeSaving || !disputeResolution.trim()}
                  className="flex-1 py-2 bg-[#E9C46A] text-black rounded-lg text-sm font-semibold hover:bg-[#E9C46A]/80 disabled:opacity-50">
                  {disputeSaving ? 'Saving...' : 'Resolve'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
