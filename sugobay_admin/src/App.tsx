import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { AuthProvider } from './lib/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
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
import PromoCodes from './pages/PromoCodes'
import EmailConfirmed from './pages/EmailConfirmed'

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public pages */}
          <Route path="/login" element={<Login />} />
          <Route path="/email-confirmed" element={<EmailConfirmed />} />

          {/* Protected admin pages */}
          <Route element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }>
            <Route path="/" element={<Dashboard />} />
            <Route path="/food-orders" element={<FoodOrders />} />
            <Route path="/pahapit-jobs" element={<PahapitJobs />} />
            <Route path="/merchants" element={<Merchants />} />
            <Route path="/riders" element={<Riders />} />
            <Route path="/customers" element={<Customers />} />
            <Route path="/revenue" element={<Revenue />} />
            <Route path="/complaints" element={<Complaints />} />
            <Route path="/announcements" element={<Announcements />} />
            <Route path="/promo-codes" element={<PromoCodes />} />
            <Route path="/settings" element={<Settings />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
