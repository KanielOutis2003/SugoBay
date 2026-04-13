import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { AppSetting } from '../lib/supabase'

export default function Settings() {
  const [settings, setSettings] = useState<AppSetting[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState<string | null>(null)
  const [editValues, setEditValues] = useState<Record<string, string>>({})

  useEffect(() => { loadSettings() }, [])

  async function loadSettings() {
    setLoading(true)
    const { data } = await supabase.from('app_settings').select('*').order('key')
    setSettings(data || [])
    const vals: Record<string, string> = {}
    for (const s of (data || [])) vals[s.key] = s.value
    setEditValues(vals)
    setLoading(false)
  }

  async function saveSetting(key: string) {
    setSaving(key)
    await supabase.from('app_settings').update({
      value: editValues[key],
      updated_at: new Date().toISOString(),
    }).eq('key', key)
    setSaving(null)
  }

  const labels: Record<string, { label: string; desc: string }> = {
    base_delivery_fee: { label: 'Base Delivery Fee', desc: 'Fee for first 2km (₱)' },
    commission_rate: { label: 'Commission Rate', desc: 'Food order commission (decimal)' },
    max_delivery_radius_km: { label: 'Max Delivery Radius', desc: 'Maximum delivery distance (km)' },
    errand_fee: { label: 'Errand Fee', desc: 'Pahapit errand fee (₱)' },
    errand_fee_cut_percent: { label: 'Errand Fee Cut', desc: 'SugoBay cut from errand fee (decimal)' },
    free_delivery_promo: { label: 'Free Delivery Promo', desc: 'Enable free delivery promotion' },
    maintenance_mode: { label: 'Maintenance Mode', desc: 'Put app in maintenance mode' },
    incentive_per_order: { label: 'Incentive Per Order', desc: 'Auto-save to incentive fund per order (₱)' },
    auto_rate_hours: { label: 'Auto-Rate Hours', desc: 'Hours before auto 5-star rating' },
  }

  if (loading) return <div className="text-gray-500">Loading settings...</div>

  return (
    <div>
      <h1 className="text-2xl font-bold text-white mb-8">Settings</h1>

      <div className="space-y-4">
        {settings.map(s => {
          const info = labels[s.key] || { label: s.key, desc: '' }
          const isBool = s.value === 'true' || s.value === 'false'

          return (
            <div key={s.key} className="bg-[#23252A] rounded-xl p-5 border border-[#2D2F34]">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <h3 className="text-white font-semibold text-sm">{info.label}</h3>
                  <p className="text-gray-500 text-xs mt-1">{info.desc}</p>
                  <p className="text-gray-600 text-xs mt-1">Key: {s.key}</p>
                </div>
                <div className="flex items-center gap-2">
                  {isBool ? (
                    <button
                      onClick={() => {
                        const newVal = editValues[s.key] === 'true' ? 'false' : 'true'
                        setEditValues({ ...editValues, [s.key]: newVal })
                      }}
                      className={`px-4 py-2 rounded-lg text-xs ${
                        editValues[s.key] === 'true' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                      }`}
                    >
                      {editValues[s.key] === 'true' ? 'Enabled' : 'Disabled'}
                    </button>
                  ) : (
                    <input
                      type="text"
                      value={editValues[s.key] || ''}
                      onChange={e => setEditValues({ ...editValues, [s.key]: e.target.value })}
                      className="w-32 px-3 py-2 bg-[#1A1C20] border border-[#2D2F34] rounded-lg text-white text-sm focus:outline-none focus:border-[#2A9D8F]"
                    />
                  )}
                  <button
                    onClick={() => saveSetting(s.key)}
                    disabled={saving === s.key}
                    className="px-3 py-2 bg-[#2A9D8F] text-white rounded-lg text-xs hover:bg-[#2A9D8F]/80 disabled:opacity-50"
                  >
                    {saving === s.key ? '...' : 'Save'}
                  </button>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
