# SugoBay — Claude Code Master Prompt
# Paste this ENTIRE file at the start of every Claude Code session.
# Claude Code has no memory between sessions — always start with this.

---

You are helping me build **SugoBay** — a hyperlocal delivery and errand app
for Ubay, Bohol, Philippines. Read this entire spec before writing any code.
Follow it exactly. Ask nothing — just build.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
APP OVERVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

App Name:    SugoBay
Tagline:     "Sugo para sa tanan sa Ubay"
Target Area: Ubay, Bohol, Philippines (Pop. 82,179)
Type:        Hyperlocal delivery + errand app
Version:     2.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TECH STACK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mobile App:     Flutter (Dart) — Android first
Admin Panel:    React + Tailwind CSS
Database:       Supabase (PostgreSQL + Auth + Realtime)
Auth:           Supabase Auth — Phone OTP login
Maps:           Google Maps API
Notifications:  Firebase Cloud Messaging (FCM)
Payments:       COD (default) + GCash via Paymongo (Month 2)
State Mgmt:     Riverpod or GetX
Navigation:     GoRouter (role-based)
Hosting:        Netlify (admin panel only)
Storage:        Supabase Storage (photos, receipts, proofs)

CRITICAL KEY RULE:
- Flutter app    → uses Supabase ANON KEY only
- React admin    → uses Supabase SERVICE ROLE KEY only
- NEVER put service role key inside Flutter app

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TWO CORE FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FEATURE 1 — FOOD DELIVERY
- Customer browses food merchant menus
- Adds to cart, places order, pays, tracks rider live
- Standard delivery marketplace flow

FEATURE 2 — PAHAPIT / PAPALIT (Errand Service)
- Customer describes what to buy + sets budget limit
- Customer picks store type + pins location or types name
- Rider goes to store, buys item with own money
- Takes photo of receipt + items purchased
- Delivers to customer
- Customer pays: exact item cost + ₱50 errand fee + delivery fee
- Payment: COD ONLY for Pahapit (exact amount unknown until purchase)
- NO merchant partnership needed for Pahapit stores

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MERCHANT RULES — CRITICAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MERCHANTS ON PLATFORM = FOOD ONLY
Allowed food categories:
  restaurant, carenderia, fastfood,
  bbq, bakery, cafe, other_food

NOT merchants (served via Pahapit instead):
  - Pharmacies / Botika / Generics
  - Hardware stores
  - Grocery / supermarket / palengke
  - Sari-sari stores
  - Clothing / department stores

MERCHANT PRIORITY ORDER (sign up in this order):
  Round 1 (Week 1):  Carenderias, BBQ stalls, panaderya
  Round 2 (Week 2-3): Local restaurants, fast food
  Round 3 (Month 2+): Jollibee/McDonald's franchise owner
                      (approach local owner, not corporate)
                      (need volume data first)

MERCHANT REGISTRATION:
  - Merchant registers in app
  - is_approved = false by default
  - Admin approves from web panel → is_approved = true
  - Merchant manages own menu after approval

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USER ROLES — ONE APP, FOUR ROLES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ONE Flutter app — role detected on login → different dashboard

customer  → Home with tabs: Food | Pahapit | Habal-habal
rider     → Unified job queue (food orders + Pahapit errands)
merchant  → Food order management + menu
admin     → Redirect to React web panel URL

Role detection flow:
  Login with phone + OTP
  → Check role from users table
  → Route accordingly via GoRouter

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROJECT STRUCTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sugobay/
├── sugobay_app/              ← Flutter mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── supabase_client.dart
│   │   │   ├── router.dart
│   │   │   └── constants.dart
│   │   └── features/
│   │       ├── auth/
│   │       ├── customer/
│   │       │   ├── food/
│   │       │   └── pahapit/
│   │       ├── rider/
│   │       │   ├── food_orders/
│   │       │   └── pahapit_jobs/
│   │       └── merchant/
│   └── pubspec.yaml
│
└── sugobay_admin/            ← React web admin panel
    ├── src/
    │   ├── lib/supabase.js
    │   ├── pages/
    │   │   ├── Dashboard.jsx
    │   │   ├── FoodOrders.jsx
    │   │   ├── PahapitJobs.jsx
    │   │   ├── Merchants.jsx
    │   │   ├── Riders.jsx
    │   │   ├── Customers.jsx
    │   │   ├── Revenue.jsx
    │   │   ├── Complaints.jsx
    │   │   ├── Announcements.jsx
    │   │   └── Settings.jsx
    │   └── App.jsx
    └── package.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FLUTTER DEPENDENCIES (pubspec.yaml)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

dependencies:
  supabase_flutter: ^2.0.0
  go_router: ^13.0.0
  google_maps_flutter: ^2.5.0
  firebase_messaging: ^14.0.0
  geolocator: ^11.0.0
  image_picker: ^1.0.0
  cached_network_image: ^3.3.0
  flutter_riverpod: ^2.4.0
  intl: ^0.19.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUPABASE DATABASE SCHEMA — RUN IN SQL EDITOR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- USERS (all roles)
create table users (
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
create table merchants (
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
create table menu_items (
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
create table orders (
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
create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id),
  menu_item_id uuid references menu_items(id),
  name text not null,
  quantity int not null,
  price numeric not null
);

-- PAHAPIT / PAPALIT ERRAND REQUESTS
create table pahapit_requests (
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
  created_at timestamp default now(),
  completed_at timestamp
);

-- RIDER LOCATIONS (realtime)
create table rider_locations (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references users(id) unique,
  lat float not null,
  lng float not null,
  is_online boolean default false,
  updated_at timestamp default now()
);

-- RIDER SHIFTS
create table rider_shifts (
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
create table rider_daily_performance (
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
create table rider_monthly_summary (
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

-- RATINGS (food orders + pahapit)
create table ratings (
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
create table complaints (
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
create table subscriptions (
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
create table incentive_fund (
  id uuid primary key default gen_random_uuid(),
  source_type text check (source_type in ('order','pahapit')),
  source_id uuid,
  amount_added numeric default 5,
  created_at timestamp default now()
);

-- ANNOUNCEMENTS
create table announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  target_role text check (target_role in (
    'all','customer','rider','merchant'
  )),
  sent_at timestamp default now()
);

-- APP SETTINGS
create table app_settings (
  key text primary key,
  value text not null,
  updated_at timestamp default now()
);

insert into app_settings values
  ('base_delivery_fee', '30'),
  ('commission_rate', '0.10'),
  ('max_delivery_radius_km', '15'),
  ('errand_fee', '50'),
  ('errand_fee_cut_percent', '0.20'),
  ('free_delivery_promo', 'false'),
  ('maintenance_mode', 'false'),
  ('incentive_per_order', '5'),
  ('auto_rate_hours', '24');

-- ENABLE REALTIME ON THESE TABLES:
-- orders, pahapit_requests, rider_locations,
-- complaints, announcements

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DELIVERY FEE FORMULA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Applies to BOTH food orders and Pahapit errands.
Distance = actual road distance via Google Maps API.
Max radius = 15km.

double calculateDeliveryFee(double distanceKm) {
  double baseFee = 30.0;
  if (distanceKm <= 2) {
    return baseFee;
  } else if (distanceKm <= 5) {
    return baseFee + ((distanceKm - 2) * 5);
  } else if (distanceKm <= 10) {
    return baseFee + (3 * 5) + ((distanceKm - 5) * 7);
  } else {
    return baseFee + (3 * 5) + (5 * 7)
           + ((distanceKm - 10) * 10);
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REVENUE SPLIT PER TRANSACTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FOOD ORDER:
  Merchant gets:     order total - 10% commission
  Rider gets:        75% of delivery fee
  SugoBay keeps:     10% commission + 25% delivery fee
  Incentive fund:    ₱5 auto-saved from SugoBay share

PAHAPIT ERRAND:
  Rider gets:        item reimbursement + 80% of ₱50 errand fee (₱40)
  SugoBay keeps:     20% of errand fee (₱10) + 25% delivery fee
  Incentive fund:    ₱5 auto-saved from SugoBay share

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RIDER SYSTEM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SHIFTS:
  Morning:   6:00 AM – 12:00 PM
  Lunch:     11:00 AM – 2:00 PM
  Afternoon: 2:00 PM – 6:00 PM
  Evening:   5:00 PM – 9:00 PM

DAILY GUARANTEE (Month 1-3 only):
  Full time (3-4 shifts): ₱300/day
  Part time (2 shifts):   ₱150/day
  Sideline (1 shift):     ₱0 guarantee

QUOTA (food + pahapit combined):
  8+ jobs: ₱300  |  5-7: ₱200  |  3-4: ₱100  |  0-2: ₱0

STATUS LEVELS:
  Rookie (0-49 jobs):        standard pay
  Regular (50-199):          +₱5/job
  Trusted (200-499):         +₱10/job
  Elite (500+ + 4.7+ rating): +₱15/job

MONTHLY BONUSES:
  4.5-4.7 stars:  +₱500   |  4.8-5.0 stars: +₱1,000
  80 jobs:  +₱200  |  100 jobs: +₱500
  130 jobs: +₱800  |  150 jobs: +₱1,000
  Weekly perfect (zero complaints + quota): +₱150

AUTO-RATING:
  No customer rating after 24hrs → auto 5-star applied
  Minimum 15 ratings needed for monthly bonus eligibility
  Applies to both food orders and Pahapit jobs

STRIKE SYSTEM:
  1st complaint: Warning
  2nd: Mandatory meeting
  3rd: 1 week suspension
  4th: Permanent removal

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ORDER & PAHAPIT STATUS FLOWS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FOOD ORDER STATUS:
  pending → accepted → preparing →
  ready_for_pickup → picked_up → delivered

PAHAPIT STATUS:
  pending → accepted → buying →
  delivering → completed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ADMIN WEB PANEL PAGES (React)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Dashboard      - stats, live rider map, today's activity
2. Food Orders    - all orders, filter, cancel, reassign
3. Pahapit Jobs   - all errands, receipt photos, disputes
4. Merchants      - approve/reject, suspend, subscriptions
5. Riders         - status, ratings, shifts, warnings
6. Customers      - history, flag, ban no-shows
7. Revenue        - commission, errand, subscriptions, charts
8. Complaints     - food + pahapit complaints, refunds
9. Announcements  - push notifications by role
10. Settings      - fees, commission, promos, maintenance

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BRANDING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

App name:      SugoBay
Tagline:       "Sugo para sa tanan sa Ubay"
Font:          Bold, rounded, friendly
Logo:          Motorcycle + location pin icon 
Primary Background
#1A1C20 (Deep Charcoal/Navy)
Gradient Colors
Teal: #2A9D8F
Coral: #E76F51
Gold: #E9C46A
Accent Gold
#D4AF37 (Metallic highlight)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IMPORTANT DEVELOPER RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. COD is default payment — never force GCash
2. Pahapit = COD ONLY (amount unknown until purchase)
3. APK must be under 30MB — budget Android phones
4. Target Android API 26+ (Android 8.0)
5. Build offline tolerance — poor signal in outer barangays
6. Update rider GPS every 5 seconds (budget phone drift)
7. Flutter uses anon key — never service role key
8. React admin uses service role key only
9. is_approved = false by default for merchants
10. Auto-rate via Supabase Edge Function cron job
11. Photo proof required: delivery photo + Pahapit receipt
12. Rider job queue shows food orders AND Pahapit in one list
13. If Pahapit item cost exceeds budget — rider calls customer
14. Notifications in Bisaya/English mix
15. Add manual Refresh button as realtime fallback

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUILD ORDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1:  Create Supabase project 'sugobay'
Step 2:  Run all schema SQL above
Step 3:  Enable Realtime on: orders, pahapit_requests,
         rider_locations, complaints, announcements
Step 4:  Set up RLS policies per role
Step 5:  Enable Phone Auth + OTP in Supabase
Step 6:  flutter create sugobay_app
Step 7:  Add pubspec.yaml dependencies
Step 8:  Initialize Supabase + Firebase in main.dart
Step 9:  Auth flow: phone → OTP → role detect → route
Step 10: Customer: Food tab (browse, order, track)
Step 11: Customer: Pahapit tab (form, store picker, budget)
Step 12: Merchant: order management + menu CRUD
Step 13: Rider: unified job queue (food + pahapit)
Step 14: Rider: navigation + status updates + photo capture
Step 15: Delivery fee calculator (shared for food + pahapit)
Step 16: FCM push notifications
Step 17: Rating system + auto-rate Edge Function
Step 18: Rider shift scheduling
Step 19: npx create-react-app sugobay_admin
Step 20: React Supabase client (service role key)
Step 21: Build all 10 admin pages
Step 22: Realtime dashboard + live rider map
Step 23: End-to-end testing all roles
Step 24: Deploy admin → Netlify
Step 25: flutter build apk --release
Step 26: Publish to Google Play Console

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
START HERE — FIRST COMMAND
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Begin with Step 1:
"Set up the Supabase project and run
the complete schema SQL"

Then Step 6-9:
"Create the Flutter project with all
dependencies and build the auth flow"

One step at a time.

