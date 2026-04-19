import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { User } from '../lib/supabase'

export default function Customers() {
  const [customers, setCustomers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')

  useEffect(() => { loadCustomers() }, [])

  async function loadCustomers() {
    setLoading(true)
    const { data } = await supabase.from('users').select('*').eq('role', 'customer').order('created_at', { ascending: false })
    setCustomers(data || [])
    setLoading(false)
  }

  async function toggleActive(id: string, current: boolean) {
    await supabase.from('users').update({ is_active: !current }).eq('id', id)
    loadCustomers()
  }

  const filtered = customers.filter(c =>
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.phone.includes(search)
  )

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">Customers</h1>
        <span className="text-gray-400 text-sm">{customers.length} total</span>
      </div>

      <input
        type="text" placeholder="Search by name or phone..."
        value={search} onChange={e => setSearch(e.target.value)}
        className="w-full mb-6 px-4 py-3 bg-[#23252A] border border-[#2D2F34] rounded-xl text-white text-sm placeholder:text-gray-500 focus:outline-none focus:border-[#2A9D8F]"
      />

      {loading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-[#23252A] rounded-xl border border-[#2D2F34] overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[#2D2F34] text-gray-400">
                <th className="text-left p-4">Name</th>
                <th className="text-left p-4">Phone</th>
                <th className="text-left p-4">Email</th>
                <th className="text-left p-4">Status</th>
                <th className="text-left p-4">Joined</th>
                <th className="text-left p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(c => (
                <tr key={c.id} className="border-b border-[#2D2F34] hover:bg-white/5">
                  <td className="p-4 text-white">{c.name}</td>
                  <td className="p-4 text-gray-300">{c.phone}</td>
                  <td className="p-4 text-gray-400">{c.email || '-'}</td>
                  <td className="p-4">
                    <span className={`px-2 py-1 rounded-full text-xs ${c.is_active ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                      {c.is_active ? 'Active' : 'Banned'}
                    </span>
                  </td>
                  <td className="p-4 text-gray-400">{new Date(c.created_at).toLocaleDateString()}</td>
                  <td className="p-4">
                    <button onClick={() => toggleActive(c.id, c.is_active)} className={`text-xs ${c.is_active ? 'text-red-400' : 'text-green-400'}`}>
                      {c.is_active ? 'Ban' : 'Unban'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
