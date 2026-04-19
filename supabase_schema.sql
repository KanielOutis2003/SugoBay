-- =====================================================
-- SUGOBAY v3 — Complete Database Schema
-- Run this in Supabase SQL Editor in order
-- =====================================================

create extension if not exists "uuid-ossp";

-- USERS
create table public.users (
  id uuid references auth.users(id)
     on delete cascade primary key,
  name text not null,
  phone text,
  email text,
  auth_provider text check (auth_provider in (
    'email','google','facebook','phone'
  )),
  role text check (role in (
    'customer','rider','merchant','admin'
  )) default 'customer',
  avatar_url text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger users_updated_at
  before update on public.users
  for each row execute function update_updated_at();

-- AUTO-CREATE USER ON SIGNUP (all providers)
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (
    id, email, name, avatar_url, auth_provider
  ) values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      'New User'
    ),
    new.raw_user_meta_data->>'avatar_url',
    case
      when new.app_metadata->>'provider' = 'google'
        then 'google'
      when new.app_metadata->>'provider' = 'facebook'
        then 'facebook'
      when new.app_metadata->>'provider' = 'phone'
        then 'phone'
      else 'email'
    end
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- MERCHANTS (food only)
create table public.merchants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id)
           on delete cascade,
  shop_name text not null,
  description text,
  address text not null,
  lat float not null,
  lng float not null,
  category text check (category in (
    'restaurant','carenderia','fastfood',
    'bbq','bakery','cafe','other_food'
  )),
  cover_photo_url text,
  business_permit_url text,
  is_open boolean default false,
  is_active boolean default true,
  is_approved boolean default false,
  rejection_reason text,
  subscription_plan text check (
    subscription_plan in (
      'free','basic','standard','premium'
  )) default 'free',
  subscription_expires_at timestamptz,
  rating float default 0,
  total_orders int default 0,
  created_at timestamptz default now()
);

-- MENU ITEMS
create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid references public.merchants(id)
              on delete cascade,
  name text not null,
  description text,
  price numeric(10,2) not null,
  image_url text,
  category text,
  is_available boolean default true,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- ORDERS (food delivery)
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.users(id),
  merchant_id uuid references public.merchants(id),
  rider_id uuid references public.users(id),
  status text check (status in (
    'pending','accepted','preparing',
    'ready_for_pickup','picked_up',
    'delivered','cancelled'
  )) default 'pending',
  total_amount numeric(10,2) not null,
  delivery_fee numeric(10,2) not null,
  commission_amount numeric(10,2) not null,
  payment_method text check (
    payment_method in ('cod','gcash')),
  payment_status text default 'pending',
  delivery_address text not null,
  delivery_lat float,
  delivery_lng float,
  delivery_proof_photo_url text,
  cancellation_reason text,
  notes text,
  created_at timestamptz default now(),
  accepted_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz
);

-- ORDER ITEMS
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id)
           on delete cascade,
  menu_item_id uuid references public.menu_items(id),
  name text not null,
  quantity int not null,
  unit_price numeric(10,2) not null,
  subtotal numeric(10,2) not null
);

-- PAHAPIT / PAPALIT ERRAND REQUESTS
create table public.pahapit_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.users(id),
  rider_id uuid references public.users(id),
  store_name text not null,
  store_category text check (store_category in (
    'pharmacy','grocery','sari_sari',
    'hardware','clothing','other'
  )),
  store_lat float,
  store_lng float,
  items_description text not null,
  budget_limit numeric(10,2) not null,
  special_instructions text,
  item_photo_url text,
  actual_amount_spent numeric(10,2),
  receipt_photo_url text,
  errand_fee numeric(10,2) default 50,
  delivery_fee numeric(10,2) not null,
  total_amount numeric(10,2),
  status text check (status in (
    'pending','accepted','buying',
    'delivering','completed','cancelled'
  )) default 'pending',
  payment_method text default 'cod',
  cancellation_reason text,
  created_at timestamptz default now(),
  completed_at timestamptz
);

-- RIDER LOCATIONS (realtime)
create table public.rider_locations (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references public.users(id)
           on delete cascade unique,
  lat float not null,
  lng float not null,
  is_online boolean default false,
  updated_at timestamptz default now()
);

-- RIDER SHIFTS
create table public.rider_shifts (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references public.users(id)
           on delete cascade,
  day_of_week text check (day_of_week in (
    'monday','tuesday','wednesday','thursday',
    'friday','saturday','sunday'
  )),
  shift text check (shift in (
    'morning','lunch','afternoon','evening'
  )),
  is_committed boolean default true,
  created_at timestamptz default now(),
  unique(rider_id, day_of_week, shift)
);

-- RIDER DAILY PERFORMANCE
create table public.rider_daily_performance (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references public.users(id),
  date date not null,
  food_deliveries int default 0,
  pahapit_jobs int default 0,
  total_jobs int default 0,
  quota_met boolean default false,
  guarantee_earned numeric(10,2) default 0,
  delivery_bonus numeric(10,2) default 0,
  shift_violations int default 0,
  created_at timestamptz default now(),
  unique(rider_id, date)
);

-- RIDER MONTHLY SUMMARY
create table public.rider_monthly_summary (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references public.users(id),
  month int not null check (month between 1 and 12),
  year int not null,
  total_food_deliveries int default 0,
  total_pahapit_jobs int default 0,
  total_jobs int default 0,
  average_rating float default 0,
  total_ratings int default 0,
  rating_bonus numeric(10,2) default 0,
  milestone_bonus numeric(10,2) default 0,
  weekly_perfect_bonus numeric(10,2) default 0,
  total_earnings numeric(10,2) default 0,
  status text default 'bronze',
  unique(rider_id, month, year)
);

-- RATINGS
create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id),
  pahapit_id uuid references public.pahapit_requests(id),
  customer_id uuid references public.users(id),
  merchant_rating int check (merchant_rating between 1 and 5),
  rider_rating int check (rider_rating between 1 and 5),
  is_auto_rated boolean default false,
  comment text,
  created_at timestamptz default now()
);

-- COMPLAINTS
create table public.complaints (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id),
  pahapit_id uuid references public.pahapit_requests(id),
  customer_id uuid references public.users(id),
  type text not null check (type in (
    'wrong_order','missing_items',
    'order_never_arrived','cold_food',
    'rude_rider','overcharged','app_bug',
    'budget_exceeded','item_unavailable','other'
  )),
  description text,
  photo_url text,
  status text default 'open' check (
    status in ('open','in_review','resolved')),
  resolution text,
  refund_amount numeric(10,2) default 0,
  created_at timestamptz default now(),
  resolved_at timestamptz
);

-- SUBSCRIPTIONS
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid references public.merchants(id),
  plan text check (plan in (
    'free','basic','standard','premium')),
  amount_paid numeric(10,2),
  started_at timestamptz default now(),
  expires_at timestamptz,
  payment_method text,
  payment_reference text,
  status text default 'active' check (
    status in ('active','expired','cancelled'))
);

-- INCENTIVE FUND
create table public.incentive_fund (
  id uuid primary key default gen_random_uuid(),
  source_type text check (
    source_type in ('order','pahapit')),
  source_id uuid,
  amount_added numeric(10,2) default 5,
  created_at timestamptz default now()
);

-- ANNOUNCEMENTS
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  target_role text check (target_role in (
    'all','customer','rider','merchant')),
  is_sent boolean default false,
  sent_at timestamptz
);

-- APP SETTINGS
create table public.app_settings (
  key text primary key,
  value text not null,
  description text,
  updated_at timestamptz default now()
);

insert into public.app_settings (key, value, description) values
  ('base_delivery_fee','30','Base fee PHP'),
  ('commission_rate','0.10','Merchant commission %'),
  ('max_delivery_radius_km','15','Max distance km'),
  ('errand_fee','50','Pahapit flat fee PHP'),
  ('errand_fee_cut_percent','0.20','SugoBay errand cut'),
  ('free_delivery_promo','false','Toggle promo'),
  ('maintenance_mode','false','App maintenance'),
  ('incentive_per_order','5','Fund per order PHP'),
  ('auto_rate_hours','24','Auto 5-star after hrs'),
  ('otp_expiry_minutes','5','OTP expiry'),
  ('max_otp_attempts','3','Max wrong OTP tries');

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

alter table public.users enable row level security;
alter table public.merchants enable row level security;
alter table public.orders enable row level security;
alter table public.pahapit_requests enable row level security;
alter table public.menu_items enable row level security;
alter table public.ratings enable row level security;
alter table public.complaints enable row level security;
alter table public.rider_locations enable row level security;
alter table public.order_items enable row level security;
alter table public.rider_shifts enable row level security;
alter table public.rider_daily_performance enable row level security;
alter table public.rider_monthly_summary enable row level security;
alter table public.subscriptions enable row level security;
alter table public.incentive_fund enable row level security;
alter table public.announcements enable row level security;
alter table public.app_settings enable row level security;

-- Users
create policy "users_own" on public.users
  for all using (auth.uid() = id);

-- Merchants
create policy "read_approved_merchants" on public.merchants
  for select using (is_approved = true and is_active = true);
create policy "owner_manages_merchant" on public.merchants
  for all using (user_id = auth.uid());

-- Menu Items
create policy "menu_read_all" on public.menu_items
  for select using (true);
create policy "menu_merchant_edit" on public.menu_items
  for all using (
    auth.uid() = (
      select user_id from public.merchants
      where id = merchant_id
    )
  );

-- Orders
create policy "orders_access" on public.orders
  for select using (
    auth.uid() = customer_id or
    auth.uid() = rider_id or
    auth.uid() = (
      select user_id from public.merchants
      where id = merchant_id
    )
  );
create policy "customer_creates_order" on public.orders
  for insert with check (auth.uid() = customer_id);
create policy "rider_updates_order" on public.orders
  for update using (auth.uid() = rider_id);
create policy "merchant_updates_order" on public.orders
  for update using (
    auth.uid() = (
      select user_id from public.merchants
      where id = merchant_id
    )
  );
create policy "rider_reads_available_orders" on public.orders
  for select using (rider_id is null or rider_id = auth.uid());

-- Order Items
create policy "read_own_order_items" on public.order_items
  for select using (
    order_id in (
      select id from public.orders
      where customer_id = auth.uid()
         or rider_id = auth.uid()
         or merchant_id in (select id from public.merchants where user_id = auth.uid())
    )
  );
create policy "customer_inserts_order_items" on public.order_items
  for insert with check (
    order_id in (select id from public.orders where customer_id = auth.uid())
  );

-- Pahapit Requests
create policy "customer_reads_own_pahapit" on public.pahapit_requests
  for select using (customer_id = auth.uid());
create policy "rider_reads_available_pahapit" on public.pahapit_requests
  for select using (rider_id is null or rider_id = auth.uid());
create policy "customer_creates_pahapit" on public.pahapit_requests
  for insert with check (customer_id = auth.uid());
create policy "rider_updates_pahapit" on public.pahapit_requests
  for update using (rider_id = auth.uid());

-- Rider Locations
create policy "rider_loc_read" on public.rider_locations
  for select using (true);
create policy "rider_loc_own" on public.rider_locations
  for all using (auth.uid() = rider_id);

-- Rider Shifts
create policy "rider_manages_shifts" on public.rider_shifts
  for all using (rider_id = auth.uid());

-- Rider Performance
create policy "rider_reads_performance" on public.rider_daily_performance
  for select using (rider_id = auth.uid());
create policy "rider_reads_monthly" on public.rider_monthly_summary
  for select using (rider_id = auth.uid());

-- Ratings
create policy "anyone_reads_ratings" on public.ratings
  for select using (true);
create policy "customer_creates_rating" on public.ratings
  for insert with check (customer_id = auth.uid());

-- Complaints
create policy "customer_creates_complaint" on public.complaints
  for insert with check (customer_id = auth.uid());
create policy "customer_reads_complaints" on public.complaints
  for select using (customer_id = auth.uid());

-- Announcements
create policy "everyone_reads_announcements" on public.announcements
  for select using (true);

-- App Settings
create policy "everyone_reads_settings" on public.app_settings
  for select using (true);

-- Incentive Fund
create policy "read_incentive_fund" on public.incentive_fund
  for select using (true);

-- Subscriptions
create policy "merchant_reads_subs" on public.subscriptions
  for select using (
    merchant_id in (select id from public.merchants where user_id = auth.uid())
  );

-- =====================================================
-- ENABLE REALTIME
-- =====================================================

alter publication supabase_realtime
  add table public.orders;
alter publication supabase_realtime
  add table public.pahapit_requests;
alter publication supabase_realtime
  add table public.rider_locations;
alter publication supabase_realtime
  add table public.complaints;
alter publication supabase_realtime
  add table public.announcements;

-- =====================================================
-- STORAGE BUCKETS
-- =====================================================
-- Create these in Supabase Dashboard > Storage:
-- 1. delivery-photos (public)
-- 2. menu-images (public)
-- 3. pahapit-photos (public)
-- 4. avatars (public)
