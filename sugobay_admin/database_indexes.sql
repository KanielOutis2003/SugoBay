-- ============================================================
-- SugoBay Database Indexes for Production Performance
-- Run these in the Supabase SQL Editor
-- ============================================================

-- Orders: frequently queried by status, merchant, customer, rider
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_merchant_id ON orders(merchant_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_rider_id ON orders(rider_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_merchant_status ON orders(merchant_id, status);

-- Pahapit Requests: similar access patterns
CREATE INDEX IF NOT EXISTS idx_pahapit_status ON pahapit_requests(status);
CREATE INDEX IF NOT EXISTS idx_pahapit_customer_id ON pahapit_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_pahapit_rider_id ON pahapit_requests(rider_id);
CREATE INDEX IF NOT EXISTS idx_pahapit_created_at ON pahapit_requests(created_at DESC);

-- Menu Items: queried by merchant + category
CREATE INDEX IF NOT EXISTS idx_menu_items_merchant_id ON menu_items(merchant_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_merchant_category ON menu_items(merchant_id, category);

-- Users: role lookups
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Merchants: approval and active filters
CREATE INDEX IF NOT EXISTS idx_merchants_approved_active ON merchants(is_approved, is_active);
CREATE INDEX IF NOT EXISTS idx_merchants_user_id ON merchants(user_id);

-- Rider Locations: online status
CREATE INDEX IF NOT EXISTS idx_rider_locations_rider_id ON rider_locations(rider_id);
CREATE INDEX IF NOT EXISTS idx_rider_locations_online ON rider_locations(is_online);

-- Ratings: per order and per customer
CREATE INDEX IF NOT EXISTS idx_ratings_order_id ON ratings(order_id);
CREATE INDEX IF NOT EXISTS idx_ratings_pahapit_id ON ratings(pahapit_id);
CREATE INDEX IF NOT EXISTS idx_ratings_customer_id ON ratings(customer_id);

-- Complaints: status filtering
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_customer_id ON complaints(customer_id);

-- Order Items: per order
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- Announcements: for mobile app queries
CREATE INDEX IF NOT EXISTS idx_announcements_target_role ON announcements(target_role);
CREATE INDEX IF NOT EXISTS idx_announcements_sent_at ON announcements(sent_at DESC);

-- Saved Addresses: per user
CREATE INDEX IF NOT EXISTS idx_saved_addresses_user_id ON saved_addresses(user_id);

-- ============================================================
-- Saved Addresses table (run if it doesn't exist yet)
-- ============================================================
CREATE TABLE IF NOT EXISTS saved_addresses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE saved_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own addresses"
  ON saved_addresses FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- FCM token column on users table (run if it doesn't exist yet)
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- ============================================================
-- Promo Codes table (run if it doesn't exist yet)
-- ============================================================
CREATE TABLE IF NOT EXISTS promo_codes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  description TEXT,
  discount_type TEXT NOT NULL DEFAULT 'fixed',
  discount_value NUMERIC NOT NULL DEFAULT 0,
  min_order_amount NUMERIC DEFAULT 0,
  max_uses INT DEFAULT NULL,
  current_uses INT DEFAULT 0,
  is_active BOOL DEFAULT true,
  expires_at TIMESTAMPTZ DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON promo_codes(code);
CREATE INDEX IF NOT EXISTS idx_promo_codes_active ON promo_codes(is_active);

ALTER TABLE promo_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active promos"
  ON promo_codes FOR SELECT
  USING (is_active = true);

-- Add promo_code column to orders if not exists
ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_code TEXT DEFAULT NULL;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0;

-- ============================================================
-- Rider Shifts table (for shift scheduling)
-- ============================================================
CREATE TABLE IF NOT EXISTS rider_shifts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  rider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day TEXT NOT NULL CHECK (day IN ('monday','tuesday','wednesday','thursday','friday','saturday','sunday')),
  shift TEXT NOT NULL CHECK (shift IN ('morning','lunch','afternoon','evening')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(rider_id, day, shift)
);

CREATE INDEX IF NOT EXISTS idx_rider_shifts_rider_id ON rider_shifts(rider_id);

ALTER TABLE rider_shifts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Riders can manage their own shifts"
  ON rider_shifts FOR ALL
  USING (auth.uid() = rider_id)
  WITH CHECK (auth.uid() = rider_id);

-- ============================================================
-- Subscription expires column on merchants (if not exists)
-- ============================================================
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ DEFAULT NULL;

-- ============================================================
-- Auto-rate function: automatically rates unrated orders after 24h
-- Run this as a Supabase pg_cron job or Edge Function
-- Schedule: every hour
-- ============================================================
CREATE OR REPLACE FUNCTION auto_rate_expired_orders()
RETURNS void AS $$
DECLARE
  auto_hours INT;
BEGIN
  -- Get configurable auto-rate hours from app_settings (default 24)
  SELECT COALESCE(value::int, 24) INTO auto_hours
  FROM app_settings WHERE key = 'auto_rate_hours';

  IF auto_hours IS NULL THEN auto_hours := 24; END IF;

  -- Auto-rate delivered food orders without ratings
  INSERT INTO ratings (order_id, customer_id, merchant_rating, rider_rating, comment)
  SELECT o.id, o.customer_id, 5, 5, 'Auto-rated (no rating submitted within time limit)'
  FROM orders o
  WHERE o.status = 'delivered'
    AND o.delivered_at < now() - (auto_hours || ' hours')::interval
    AND NOT EXISTS (SELECT 1 FROM ratings r WHERE r.order_id = o.id);

  -- Auto-rate completed pahapit jobs without ratings
  INSERT INTO ratings (pahapit_id, customer_id, rider_rating, comment)
  SELECT p.id, p.customer_id, 5, 'Auto-rated (no rating submitted within time limit)'
  FROM pahapit_requests p
  WHERE p.status = 'completed'
    AND p.completed_at < now() - (auto_hours || ' hours')::interval
    AND NOT EXISTS (SELECT 1 FROM ratings r WHERE r.pahapit_id = p.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- To schedule with pg_cron (run once in SQL editor):
-- SELECT cron.schedule('auto-rate-orders', '0 * * * *', 'SELECT auto_rate_expired_orders()');

-- ============================================================
-- Habal-Habal Rides table (motorcycle taxi)
-- ============================================================
CREATE TABLE IF NOT EXISTS habal_habal_rides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID NOT NULL REFERENCES auth.users(id),
  rider_id UUID REFERENCES auth.users(id),
  pickup_address TEXT NOT NULL,
  pickup_lat DOUBLE PRECISION NOT NULL,
  pickup_lng DOUBLE PRECISION NOT NULL,
  dropoff_address TEXT NOT NULL,
  dropoff_lat DOUBLE PRECISION NOT NULL,
  dropoff_lng DOUBLE PRECISION NOT NULL,
  distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  fare NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'searching' CHECK (status IN (
    'searching', 'accepted', 'arriving', 'in_transit', 'completed', 'cancelled'
  )),
  note TEXT,
  accepted_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancelled_by TEXT CHECK (cancelled_by IN ('customer', 'rider')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hh_rides_customer ON habal_habal_rides(customer_id);
CREATE INDEX IF NOT EXISTS idx_hh_rides_rider ON habal_habal_rides(rider_id);
CREATE INDEX IF NOT EXISTS idx_hh_rides_status ON habal_habal_rides(status);
CREATE INDEX IF NOT EXISTS idx_hh_rides_created ON habal_habal_rides(created_at DESC);

ALTER TABLE habal_habal_rides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can create and view their rides"
  ON habal_habal_rides FOR ALL
  USING (auth.uid() = customer_id OR auth.uid() = rider_id)
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Riders can view and accept available rides"
  ON habal_habal_rides FOR SELECT
  USING (status = 'searching' OR auth.uid() = rider_id);
