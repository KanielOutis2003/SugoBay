import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import Layout from './components/Layout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import FoodOrders from './pages/FoodOrders'
import PahapitJobs from './pages/PahapitJobs'
import Merchants from './pages/Merchants'
import Riders from './pages/Riders'
import Customers from './pages/Customers'
import Revenue from './pages/Revenue'
import Complaints from './pages/Complaints'
import Announcements from './pages/Announcements'
import Settings from './pages/Settings'

export default function App() {
  const [session, setSession] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })

    return () => subscription.unsubscribe()
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen bg-[#1A1C20] flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-[#2A9D8F]"></div>
      </div>
    )
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={!session ? <Login /> : <Navigate to="/" />} />
        
        <Route element={session ? <Layout /> : <Navigate to="/login" />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/food-orders" element={<FoodOrders />} />
          <Route path="/pahapit-jobs" element={<PahapitJobs />} />
          <Route path="/merchants" element={<Merchants />} />
          <Route path="/riders" element={<Riders />} />
          <Route path="/customers" element={<Customers />} />
          <Route path="/revenue" element={<Revenue />} />
          <Route path="/complaints" element={<Complaints />} />
          <Route path="/announcements" element={<Announcements />} />
          <Route path="/settings" element={<Settings />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
