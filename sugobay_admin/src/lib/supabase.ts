import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'YOUR_SUPABASE_URL'
const supabaseServiceKey = import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY || 'YOUR_SERVICE_ROLE_KEY'

// IMPORTANT: React admin uses SERVICE ROLE KEY only
export const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Helper types
export interface User {
  id: string
  name: string
  phone: string
  email: string | null
  role: 'customer' | 'rider' | 'merchant' | 'admin'
  avatar_url: string | null
  is_active: boolean
  created_at: string
}

export interface Merchant {
  id: string
  user_id: string
  shop_name: string
  description: string | null
  address: string
  lat: number
  lng: number
  category: string
  is_open: boolean
  is_active: boolean
  is_approved: boolean
  subscription_plan: string
  rating: number
  total_orders: number
  created_at: string
}

export interface Order {
  id: string
  customer_id: string
  merchant_id: string
  rider_id: string | null
  status: string
  total_amount: number
  delivery_fee: number
  commission_amount: number
  payment_method: string
  payment_status: string
  delivery_address: string
  notes: string | null
  created_at: string
  delivered_at: string | null
}

export interface PahapitRequest {
  id: string
  customer_id: string
  rider_id: string | null
  store_name: string
  store_category: string
  items_description: string
  budget_limit: number
  actual_amount_spent: number | null
  receipt_photo_url: string | null
  errand_fee: number
  delivery_fee: number
  total_amount: number | null
  status: string
  created_at: string
  completed_at: string | null
}

export interface Complaint {
  id: string
  order_id: string | null
  pahapit_id: string | null
  customer_id: string
  type: string
  description: string | null
  photo_url: string | null
  status: string
  resolution: string | null
  created_at: string
  resolved_at: string | null
}

export interface Announcement {
  id: string
  title: string
  message: string
  target_role: string
  sent_at: string
}

export interface AppSetting {
  key: string
  value: string
  updated_at: string
}
