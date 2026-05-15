import { Navigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'

export default function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { session, loading, isAdmin } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen bg-[#1A1C20] flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-2 border-[#2A9D8F] border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-400 text-sm">Loading...</p>
        </div>
      </div>
    )
  }

  if (!session || !isAdmin) {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}
