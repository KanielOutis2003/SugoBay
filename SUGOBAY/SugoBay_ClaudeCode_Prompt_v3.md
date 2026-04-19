# SugoBay v3 — Claude Code Master Prompt
# Paste this ENTIRE file at the start of every Claude Code session.
# Claude Code has NO memory between sessions — always start with this.

---

You are building SugoBay v3 — a hyperlocal delivery and errand app
for Ubay, Bohol, Philippines. Read this entire spec before writing
any code. Follow it exactly. Ask nothing — just build.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
APP OVERVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

App Name:    SugoBay
Tagline:     "Sugo para sa tanan sa Ubay"
Target Area: Ubay, Bohol, Philippines
Platform:    Flutter (Android) + React (Web Admin)
Backend:     Supabase — ONE project for both
Version:     3.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AUTHENTICATION — MULTI-PROVIDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

4 login methods — user chooses any:
  1. Google OAuth (via Supabase + Google Cloud Console)
  2. Facebook OAuth (via Supabase + Meta Developers)
  3. Email + Password (via Supabase Auth)
  4. Phone OTP (via Supabase + Twilio SMS)

SAME login screen for ALL roles (customer/rider/merchant).
Role is detected AFTER login from the users table.

PHONE NUMBER is ALWAYS collected at profile setup
even if user logged in via Google or Facebook.
Reason: needed for delivery contact.

TRIGGER: handle_new_user() fires on auth.users INSERT
and auto-creates row in public.users with name and
avatar pulled from Google/Facebook metadata.

ADMIN role: set MANUALLY in Supabase SQL editor.
No one can self-register as admin through the app.

AUTH FLOW:
  Any login method
    ↓
  Supabase verifies identity
    ↓
  Check public.users table
    ↓
  No profile → /profile-setup
    ↓
  Has profile → check role
    ↓
  customer  → /customer/home
  rider     → /rider/dashboard
  merchant + is_approved=true  → /merchant/dashboard
  merchant + is_approved=false → /merchant/pending
  admin     → /admin/redirect (use web panel)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MAPS — OPENSTREETMAP (FREE — NO GOOGLE MAPS)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DO NOT use Google Maps API — it costs money.

Map display:
  Package: flutter_map + latlong2
  Tiles: https://tile.openstreetmap.org/{z}/{x}/{y}.png
  Cost: FREE forever, no API key

Distance calculation:
  API: OSRM (https://router.project-osrm.org)
  Endpoint: /route/v1/driving/{lng1},{lat1};{lng2},{lat2}
  Cost: FREE, no API key needed
  Returns actual road distance in meters

Rider navigation:
  Deep link to Waze → fallback Google Maps → fallback OSM
  Cost: FREE (opens external app)
  waze://?ll={lat},{lng}&navigate=yes
  https://www.google.com/maps/dir/?api=1&destination={lat},{lng}

Admin panel map:
  Leaflet.js + OpenStreetMap tiles
  Cost: FREE

Geocoding:
  Nominatim API (https://nominatim.openstreetmap.org)
  Cost: FREE, no API key

Center map on Ubay: LatLng(10.0570, 124.4703)
Max delivery radius: 15km

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TECH STACK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mobile App:       Flutter (Dart) — Android first
Admin Panel:      React + Tailwind CSS
Database:         Supabase (PostgreSQL + Realtime + Auth)
Maps:             OpenStreetMap + flutter_map (FREE)
Distance:         OSRM API (FREE)
Notifications:    Firebase Cloud Messaging (FCM)
Payments:         COD default + GCash via Paymongo (Month 2)
State Mgmt:       Riverpod
Navigation:       GoRouter
Hosting:          Netlify (admin panel)
Storage:          Supabase Storage

KEYS:
  Flutter app    → Supabase ANON KEY only
  React admin    → Supabase SERVICE ROLE KEY only
  NEVER mix these

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FLUTTER DEPENDENCIES (pubspec.yaml)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

dependencies:
  supabase_flutter: ^2.0.0
  google_sign_in: ^6.1.0
  flutter_facebook_auth: ^6.0.0
  go_router: ^13.0.0
  flutter_map: ^6.0.0
  latlong2: ^0.9.0
  url_launcher: ^6.2.0
  firebase_messaging: ^14.0.0
  geolocator: ^11.0.0
  image_picker: ^1.0.0
  cached_network_image: ^3.3.0
  flutter_riverpod: ^2.4.0
  http: ^1.1.0
  intl: ^0.19.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USER ROLES — ONE APP, ROLE-BASED DASHBOARDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ONE Flutter app on Play Store.
Role detected on login → different dashboard shown.

customer  → Tabs: Food | Pahapit | Habal-habal
rider     → Unified job queue (food orders + Pahapit)
merchant  → Food orders + menu management
admin     → Redirect to React web panel URL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TWO CORE FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FEATURE 1 — FOOD DELIVERY
- Customer browses food merchant menu
- Adds to cart, places order
- Rider picks up and delivers
- Customer tracks live on OpenStreetMap
- Rating after delivery (auto 5-star after 24hrs)

FEATURE 2 — PAHAPIT / PAPALIT (Errand)
- Customer types what to buy + sets budget limit
- Customer picks store type + pins on OSM map
- Rider goes to store, buys with own money
- Rider takes photo of receipt + items
- Delivers to customer
- Customer pays: exact receipt amount + ₱50 errand fee + delivery fee
- Payment: COD ONLY (amount unknown until purchase)
- Receipt photo REQUIRED before completing job
- Budget limit REQUIRED (protects rider)
- No merchant partnership needed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MERCHANT RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ONLY FOOD merchants on the platform.
Allowed categories:
  restaurant, carenderia, fastfood,
  bbq, bakery, cafe, other_food

NOT merchants (use Pahapit instead):
  pharmacy, hardware, grocery,
  sari-sari, clothing

Registration:
  Merchant registers in app
  is_approved = false by default
  Admin approves via web panel → is_approved = true
  Merchant notified via FCM when approved

Merchant manages own menu after approval.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COMPLETE SUPABASE SCHEMA SQL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Run in Supabase SQL Editor in order

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

-- RLS POLICIES
alter table public.users enable row level security;
alter table public.merchants enable row level security;
alter table public.orders enable row level security;
alter table public.pahapit_requests enable row level security;
alter table public.menu_items enable row level security;
alter table public.ratings enable row level security;
alter table public.complaints enable row level security;
alter table public.rider_locations enable row level security;

create policy "users_own" on public.users
  for all using (auth.uid() = id);

create policy "orders_access" on public.orders
  for select using (
    auth.uid() = customer_id or
    auth.uid() = rider_id or
    auth.uid() = (
      select user_id from public.merchants
      where id = merchant_id
    )
  );

create policy "menu_read_all" on public.menu_items
  for select using (true);

create policy "menu_merchant_edit" on public.menu_items
  for all using (
    auth.uid() = (
      select user_id from public.merchants
      where id = merchant_id
    )
  );

create policy "rider_loc_read" on public.rider_locations
  for select using (true);

create policy "rider_loc_own" on public.rider_locations
  for all using (auth.uid() = rider_id);

-- ENABLE REALTIME
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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DELIVERY FEE FORMULA (food + pahapit)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

double calculateDeliveryFee(double distanceKm) {
  double baseFee = 30.0;
  if (distanceKm <= 2) return baseFee;
  else if (distanceKm <= 5)
    return baseFee + ((distanceKm - 2) * 5);
  else if (distanceKm <= 10)
    return baseFee + (3*5) + ((distanceKm-5)*7);
  else
    return baseFee + (3*5) + (5*7)
           + ((distanceKm-10)*10);
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REVENUE SPLIT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FOOD ORDER:
  Merchant:  order total - 10% commission
  Rider:     75% of delivery fee
  SugoBay:   10% commission + 25% delivery fee
  Fund:      ₱5 saved from SugoBay share

PAHAPIT:
  Rider:     item reimbursement + ₱40 (80% of ₱50)
  SugoBay:   ₱10 (20% of errand) + 25% delivery fee
  Fund:      ₱5 saved from SugoBay share

SUBSCRIPTIONS (Month 4+):
  Basic:    ₱299/month
  Standard: ₱599/month
  Premium:  ₱999/month

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RIDER SYSTEM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SHIFTS: Morning 6AM-12PM, Lunch 11AM-2PM,
        Afternoon 2PM-6PM, Evening 5PM-9PM

GUARANTEE (Month 1-3):
  Full time (3-4 shifts): ₱300/day
  Part time (2 shifts):   ₱150/day
  Sideline (1 shift):     ₱0

QUOTA (food + pahapit combined):
  8+ jobs: ₱300 | 5-7: ₱200 | 3-4: ₱100 | 0-2: ₱0

MONTHLY BONUSES:
  4.5-4.7 stars: +₱500 | 4.8-5.0: +₱1,000
  80 jobs: +₱200 | 100: +₱500 | 130: +₱800 | 150: +₱1,000
  Weekly perfect (zero complaints + quota): +₱150/week

AUTO-RATING: No rating after 24hrs → auto 5 stars
STATUS: Rookie(0-49) → Regular(50-199) →
        Trusted(200-499) → Elite(500+, 4.7+)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IMPORTANT RULES FOR DEVELOPERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1.  COD is default — never force GCash
2.  Pahapit = COD ONLY
3.  APK under 30MB — budget phones in Ubay
4.  Target Android API 26+
5.  Offline tolerance — cache state, show last updated
6.  GPS update every 5 seconds
7.  Flutter = anon key ONLY
8.  React admin = service role key ONLY
9.  is_approved = false for all new merchants
10. Admin role = set manually in Supabase only
11. handle_new_user trigger creates user profile auto
12. Auto-rate via Supabase Edge Function cron
13. Delivery photo required for food orders
14. Receipt + item photo required for Pahapit
15. Rider queue shows food AND Pahapit in one list
16. Pahapit: if cost > budget → rider calls customer
17. Notifications in Bisaya/English mix
18. Add manual Refresh button as realtime fallback
19. NO Google Maps — use OpenStreetMap only
20. NO paid APIs of any kind at launch

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUILD ORDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1.  Create Supabase project 'sugobay'
2.  Run all schema SQL above
3.  Enable Realtime on required tables
4.  Enable Auth: Email, Google, Facebook, Phone
5.  Create handle_new_user trigger
6.  Set up Google OAuth (Google Cloud Console)
7.  Set up Facebook OAuth (Meta Developers)
8.  flutter create sugobay_app
9.  Add pubspec.yaml dependencies
10. Initialize Supabase + Firebase in main.dart
11. Build auth screens (login, email, phone, profile setup)
12. Build GoRouter with role guards
13. Customer: Food tab (browse, cart, order, track)
14. Customer: Pahapit tab (form, store picker, budget)
15. Merchant: registration + pending screen
16. Merchant: orders + menu management
17. Rider: unified job queue (food + pahapit)
18. Rider: OSM map + navigation deep link
19. Rider: photo capture (delivery + receipt)
20. Delivery fee calculator
21. FCM push notifications
22. Rating + auto-rate Edge Function
23. Rider shift scheduling
24. React admin: all 10 pages
25. React admin: live map (Leaflet.js + OSM)
26. End-to-end test all roles
27. Deploy admin → Netlify
28. flutter build apk --release
29. Google Play Console submission

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
START HERE — FIRST COMMAND TO CLAUDE CODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"Set up the Supabase project, run the complete
schema SQL, enable realtime, set up RLS policies,
and create the handle_new_user trigger."

Then:

"Create the Flutter project with all dependencies
and build all 4 auth screens: login screen with
Google/Facebook/Email/Phone options, email screen,
phone OTP screen, and profile setup screen."

One step at a time. Test before moving forward.
