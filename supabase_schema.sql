-- =====================================================
-- SUGOBAY - Complete Database Schema
-- Run this in Supabase SQL Editor
-- =====================================================

-- USERS (all roles)
create table if not exists users (
  id uuid references auth.users primary key,
  name text not null,
  phone text unique not null,
  email text,
  role text check (role in (
    'customer','rider','merchant','admin'
  )) default 'customer',
  avatar_url text,
  is_active boolean default true,
  created_at timestamp default now()
);

-- MERCHANTS (food only)
create table if not exists merchants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  shop_name text not null,
  description text,
  address text not null,
  lat float not null,
  lng float not null,
  category text check (category in (
    'restaurant','carenderia','fastfood',
    'bbq','bakery','cafe','other_food'
  )),
  is_open boolean default true,
  is_active boolean default true,
  is_approved boolean default false,
  subscription_plan text default 'free',
  subscription_expires_at timestamp,
  rating float default 0,
  total_orders int default 0,
  created_at timestamp default now()
);

-- MENU ITEMS
create table if not exists menu_items (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid references merchants(id),
  name text not null,
  description text,
  price numeric not null,
  image_url text,
  category text,
  is_available boolean default true,
  created_at timestamp default now()
);

-- FOOD ORDERS
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references users(id),
  merchant_id uuid references merchants(id),
  rider_id uuid references users(id),
  status text check (status in (
    'pending','accepted','preparing',
    'ready_for_pickup','picked_up',
    'delivered','cancelled'
  )) default 'pending',
  total_amount numeric not null,
  delivery_fee numeric not null,
  commission_amount numeric not null,
  payment_method text check (
    payment_method in ('cod','gcash')
  ),
  payment_status text default 'pending',
  delivery_address text not null,
  delivery_lat float,
  delivery_lng float,
  delivery_proof_photo_url text,
  notes text,
  created_at timestamp default now(),
  delivered_at timestamp
);

-- ORDER ITEMS
create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id),
  menu_item_id uuid references menu_items(id),
  name text not null,
  quantity int not null,
  price numeric not null
);

-- PAHAPIT / PAPALIT ERRAND REQUESTS
create table if not exists pahapit_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references users(id),
  rider_id uuid references users(id),
  store_name text not null,
  store_category text check (store_category in (
    'pharmacy','grocery','sari_sari',
    'hardware','clothing','other'
  )),
  store_lat float,
  store_lng float,
  items_description text not null,
  budget_limit numeric not null,
  special_instructions text,
  item_photo_url text,
  actual_amount_spent numeric,
  receipt_photo_url text,
  errand_fee numeric default 50,
  delivery_fee numeric not null,
  total_amount numeric,
  status text check (status in (
    'pending','accepted','buying',
    'delivering','completed','cancelled'
  )) default 'pending',
  payment_method text default 'cod',
  delivery_address text,
  delivery_lat float,
  delivery_lng float,
  delivery_proof_photo_url text,
  created_at timestamp default now(),
  completed_at timestamp
);

-- RIDER LOCATIONS (realtime)
create table if not exists rider_locations (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references users(id) unique,
  lat float not null,
  lng float not null,
  is_online boolean default false,
  updated_at timestamp default now()
);

-- RIDER SHIFTS
create table if not exists rider_shifts (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references users(id),
  day_of_week text check (day_of_week in (
    'monday','tuesday','wednesday',
    'thursday','friday','saturday','sunday'
  )),
  shift text check (shift in (
    'morning','lunch','afternoon','evening'
  )),
  is_committed boolean default true,
  created_at timestamp default now()
);

-- RIDER DAILY PERFORMANCE
create table if not exists rider_daily_performance (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references users(id),
  date date not null,
  food_deliveries int default 0,
  pahapit_jobs int default 0,
  total_jobs int default 0,
  quota_met boolean default false,
  guarantee_earned numeric default 0,
  delivery_bonus numeric default 0,
  shift_violations int default 0,
  created_at timestamp default now()
);

-- RIDER MONTHLY SUMMARY
create table if not exists rider_monthly_summary (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references users(id),
  month int not null,
  year int not null,
  total_food_deliveries int default 0,
  total_pahapit_jobs int default 0,
  total_jobs int default 0,
  average_rating float default 0,
  total_ratings int default 0,
  rating_bonus numeric default 0,
  milestone_bonus numeric default 0,
  weekly_perfect_bonus numeric default 0,
  total_earnings numeric default 0,
  status text default 'bronze'
);

-- RATINGS
create table if not exists ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id),
  pahapit_id uuid references pahapit_requests(id),
  customer_id uuid references users(id),
  merchant_rating int check (merchant_rating between 1 and 5),
  rider_rating int check (rider_rating between 1 and 5),
  is_auto_rated boolean default false,
  comment text,
  created_at timestamp default now()
);

-- COMPLAINTS
create table if not exists complaints (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id),
  pahapit_id uuid references pahapit_requests(id),
  customer_id uuid references users(id),
  type text not null,
  description text,
  photo_url text,
  status text default 'open',
  resolution text,
  created_at timestamp default now(),
  resolved_at timestamp
);

-- SUBSCRIPTIONS (food merchants only)
create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid references merchants(id),
  plan text check (plan in (
    'free','basic','standard','premium'
  )),
  amount_paid numeric,
  started_at timestamp default now(),
  expires_at timestamp,
  payment_method text,
  status text default 'active'
);

-- INCENTIVE FUND
create table if not exists incentive_fund (
  id uuid primary key default gen_random_uuid(),
  source_type text check (source_type in ('order','pahapit')),
  source_id uuid,
  amount_added numeric default 5,
  created_at timestamp default now()
);

-- ANNOUNCEMENTS
create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  target_role text check (target_role in (
    'all','customer','rider','merchant'
  )),
  sent_at timestamp default now()
);

-- APP SETTINGS
create table if not exists app_settings (
  key text primary key,
  value text not null,
  updated_at timestamp default now()
);

insert into app_settings (key, value) values
  ('base_delivery_fee', '30'),
  ('commission_rate', '0.10'),
  ('max_delivery_radius_km', '15'),
  ('errand_fee', '50'),
  ('errand_fee_cut_percent', '0.20'),
  ('free_delivery_promo', 'false'),
  ('maintenance_mode', 'false'),
  ('incentive_per_order', '5'),
  ('auto_rate_hours', '24')
on conflict (key) do nothing;

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

alter table users enable row level security;
alter table merchants enable row level security;
alter table menu_items enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table pahapit_requests enable row level security;
alter table rider_locations enable row level security;
alter table rider_shifts enable row level security;
alter table rider_daily_performance enable row level security;
alter table rider_monthly_summary enable row level security;
alter table ratings enable row level security;
alter table complaints enable row level security;
alter table subscriptions enable row level security;
alter table incentive_fund enable row level security;
alter table announcements enable row level security;
alter table app_settings enable row level security;

-- Users: can read own, insert own
create policy "Users read own" on users for select using (auth.uid() = id);
create policy "Users insert own" on users for insert with check (auth.uid() = id);
create policy "Users update own" on users for update using (auth.uid() = id);
create policy "Admins manage all users" on users for all using (
  (select role from users where id = auth.uid()) = 'admin'
);

-- Merchants: everyone reads approved, owner manages own
create policy "Read approved merchants" on merchants for select using (is_approved = true and is_active = true);
create policy "Owner reads own merchant" on merchants for select using (user_id = auth.uid());
create policy "Owner inserts merchant" on merchants for insert with check (user_id = auth.uid());
create policy "Owner updates merchant" on merchants for update using (user_id = auth.uid());
create policy "Admins manage all merchants" on merchants for all using (
  (select role from users where id = auth.uid()) = 'admin'
);

-- Menu Items: everyone reads available, merchant owner manages
create policy "Read available menu items" on menu_items for select using (is_available = true);
create policy "Merchant manages menu" on menu_items for all using (
  merchant_id in (select id from merchants where user_id = auth.uid())
);
create policy "Admins manage all menu items" on menu_items for all using (
  (select role from users where id = auth.uid()) = 'admin'
);

-- Orders: customer reads own, merchant reads own, rider reads assigned
create policy "Customer reads own orders" on orders for select using (customer_id = auth.uid());
create policy "Merchant reads own orders" on orders for select using (
  merchant_id in (select id from merchants where user_id = auth.uid())
);
create policy "Rider reads available orders" on orders for select using (
  rider_id is null or rider_id = auth.uid()
);
create policy "Customer creates order" on orders for insert with check (customer_id = auth.uid());
create policy "Rider updates order" on orders for update using (rider_id = auth.uid());
create policy "Merchant updates order" on orders for update using (
  merchant_id in (select id from merchants where user_id = auth.uid())
);
create policy "Admins manage all orders" on orders for all using (
  (select role from users where id = auth.uid()) = 'admin'
);

-- Order Items
create policy "Read own order items" on order_items for select using (
  order_id in (select id from orders where customer_id = auth.uid() or rider_id = auth.uid() or merchant_id in (select id from merchants where user_id = auth.uid()))
);
create policy "Customer inserts order items" on order_items for insert with check (
  order_id in (select id from orders where customer_id = auth.uid())
);
create policy "Admins manage all order items" on order_items for all using (
  (select role from users where id = auth.uid()) = 'admin'
);

-- Pahapit Requests
create policy "Customer reads own pahapit" on pahapit_requests for select using (customer_id = auth.uid());
create policy "Rider reads available pahapit" on pahapit_requests for select using (
  rider_id is null or rider_id = auth.uid()
);
create policy "Customer creates pahapit" on pahapit_requests for insert with check (customer_id = auth.uid());
create policy "Rider updates pahapit" on pahapit_requests for update using (rider_id = auth.uid());
create policy "Admins manage all pahapit" on pahapit_requests for all using (
  (select role from users where id = auth.uid()) = 'admin'
);

-- Rider Locations
create policy "Rider manages own location" on rider_locations for all using (rider_id = auth.uid());
create policy "Everyone reads rider locations" on rider_locations for select using (true);

-- Rider Shifts
create policy "Rider manages own shifts" on rider_shifts for all using (rider_id = auth.uid());

-- Rider Performance
create policy "Rider reads own performance" on rider_daily_performance for select using (rider_id = auth.uid());
create policy "Rider reads own monthly" on rider_monthly_summary for select using (rider_id = auth.uid());

-- Ratings
create policy "Anyone reads ratings" on ratings for select using (true);
create policy "Customer creates rating" on ratings for insert with check (customer_id = auth.uid());

-- Complaints
create policy "Customer creates complaint" on complaints for insert with check (customer_id = auth.uid());
create policy "Customer reads own complaints" on complaints for select using (customer_id = auth.uid());

-- Announcements: everyone reads
create policy "Everyone reads announcements" on announcements for select using (true);

-- App Settings: everyone reads
create policy "Everyone reads settings" on app_settings for select using (true);

-- Incentive Fund: read only
create policy "Read incentive fund" on incentive_fund for select using (true);

-- Subscriptions
create policy "Merchant reads own subs" on subscriptions for select using (
  merchant_id in (select id from merchants where user_id = auth.uid())
);

-- =====================================================
-- ENABLE REALTIME
-- =====================================================
-- Run these in Supabase Dashboard > Database > Replication
-- Or use the SQL:

alter publication supabase_realtime add table orders;
alter publication supabase_realtime add table pahapit_requests;
alter publication supabase_realtime add table rider_locations;
alter publication supabase_realtime add table complaints;
alter publication supabase_realtime add table announcements;

-- =====================================================
-- STORAGE BUCKETS
-- =====================================================
-- Create these in Supabase Dashboard > Storage:
-- 1. delivery-photos (public)
-- 2. menu-images (public)
-- 3. pahapit-photos (public)
-- 4. avatars (public)

-- =====================================================
-- AUTH TRIGGERS
-- =====================================================

-- Function to handle new user creation in the public.users table
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, name, phone, role, email)
  values (
    new.id,
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'role', 'customer'),
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to run the function after a user is created in auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
