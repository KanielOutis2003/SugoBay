import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { Announcement } from '../lib/supabase'

export default function Announcements() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([])
  const [loading, setLoading] = useState(true)
  const [title, setTitle] = useState('')
  const [message, setMessage] = useState('')
  const [targetRole, setTargetRole] = useState('all')
  const [sending, setSending] = useState(false)

  useEffect(() => { loadAnnouncements() }, [])

  async function loadAnnouncements() {
    setLoading(true)
    const { data } = await supabase.from('announcements').select('*').order('sent_at', { ascending: false }).limit(50)
    setAnnouncements(data || [])
    setLoading(false)
  }

  async function send() {
    if (!title.trim() || !message.trim()) return alert('Title and message required')
    setSending(true)
    await supabase.from('announcements').insert({
      title: title.trim(),
      message: message.trim(),
      target_role: targetRole,
    })
    setTitle('')
    setMessage('')
    setTargetRole('all')
    setSending(false)
    loadAnnouncements()
  }

  async function deleteAnnouncement(id: string) {
    if (!confirm('Delete this announcement?')) return
    await supabase.from('announcements').delete().eq('id', id)
    loadAnnouncements()
  }

  const roleColors: Record<string, string> = {
    all: 'bg-[#2A9D8F]/20 text-[#2A9D8F]',
    customer: 'bg-blue-500/20 text-blue-400',
    rider: 'bg-[#E9C46A]/20 text-[#E9C46A]',
    merchant: 'bg-[#E76F51]/20 text-[#E76F51]',
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-6">Announcements</h1>

      {/* Create Announcement */}
      <div className="bg-[#23252A] rounded-xl p-6 border border-[#2D2F34] mb-8">
        <h2 className="text-lg font-semibold text-white mb-4">Send New Announcement</h2>
        <input
          type="text" placeholder="Title" value={title} onChange={e => setTitle(e.target.value)}
          className="w-full mb-3 px-4 py-3 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm placeholder:text-gray-500 focus:outline-none focus:border-[#2A9D8F]"
        />
        <textarea
          placeholder="Message" value={message} onChange={e => setMessage(e.target.value)} rows={3}
          className="w-full mb-3 px-4 py-3 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm placeholder:text-gray-500 focus:outline-none focus:border-[#2A9D8F] resize-none"
        />
        <div className="flex items-center gap-3 mb-4">
          <span className="text-sm text-gray-400">Target:</span>
          {['all', 'customer', 'rider', 'merchant'].map(r => (
            <button key={r} onClick={() => setTargetRole(r)}
              className={`px-3 py-1 rounded-lg text-xs capitalize ${targetRole === r ? 'bg-[#2A9D8F] text-white' : 'bg-[#1A1C20] text-gray-400 border border-[#2D2F34]'}`}>
              {r}
            </button>
          ))}
        </div>
        <button onClick={send} disabled={sending} className="px-6 py-2 bg-[#2A9D8F] text-white rounded-lg text-sm hover:bg-[#2A9D8F]/80 disabled:opacity-50">
          {sending ? 'Sending...' : 'Send Announcement'}
        </button>
      </div>

      {/* History */}
      <h2 className="text-lg font-semibold text-white mb-4">History</h2>
      {loading ? <p className="text-gray-500">Loading...</p> : announcements.length === 0 ? (
        <p className="text-gray-500">No announcements sent yet</p>
      ) : (
        <div className="space-y-3">
          {announcements.map(a => (
            <div key={a.id} className="bg-[#23252A] rounded-xl p-4 border border-[#2D2F34] flex items-start justify-between">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="text-white font-semibold text-sm">{a.title}</h3>
                  <span className={`px-2 py-0.5 rounded-full text-xs ${roleColors[a.target_role] || roleColors.all}`}>
                    {a.target_role}
                  </span>
                </div>
                <p className="text-gray-400 text-sm">{a.message}</p>
                <p className="text-gray-600 text-xs mt-1">{new Date(a.sent_at).toLocaleString()}</p>
              </div>
              <button onClick={() => deleteAnnouncement(a.id)} className="text-gray-600 hover:text-red-400 text-xs">Delete</button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
