-- ============================================================
-- SISTEM LELANG CUTI PERAWAT
-- Jalankan file ini di Supabase SQL Editor
-- ============================================================

-- 1. TABEL PERAWAT
create table perawat (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  no_hp text unique not null,
  email text unique,
  password_hash text not null,
  is_admin boolean default false,
  is_aktif boolean default true,
  kode_undangan text,
  created_at timestamptz default now()
);

-- 2. TABEL TIER BULANAN
-- Setiap baris = 1 perawat, 1 bulan, 1 tier
create table tier_bulanan (
  id uuid primary key default gen_random_uuid(),
  perawat_id uuid references perawat(id) on delete cascade,
  bulan date not null,           -- selalu tanggal 1, misal '2025-07-01'
  tier integer not null check (tier in (1, 2, 3)),
  created_at timestamptz default now(),
  unique (perawat_id, bulan)
);

-- 3. TABEL PENGAJUAN CUTI
create table pengajuan_cuti (
  id uuid primary key default gen_random_uuid(),
  perawat_id uuid references perawat(id) on delete cascade,
  bulan date not null,           -- bulan cuti yang diajukan
  tanggal_mulai date not null,
  tanggal_selesai date not null,
  jumlah_hari integer generated always as (tanggal_selesai - tanggal_mulai + 1) stored,
  tier_saat_pengajuan integer not null check (tier_saat_pengajuan in (1, 2, 3)),
  status text not null default 'aktif' check (status in ('aktif', 'dibatalkan_sistem', 'dibatalkan_perawat')),
  dibatalkan_karena text,        -- penjelasan jika dibatalkan sistem
  submitted_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 4. TABEL TANGGAL TERBLOKIR
create table tanggal_blokir (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null unique,
  alasan text not null,
  dibuat_oleh uuid references perawat(id),
  created_at timestamptz default now()
);

-- 5. TABEL PENGATURAN PERIODE
-- Kapan window pengajuan dibuka tiap bulan
create table pengaturan_periode (
  id uuid primary key default gen_random_uuid(),
  bulan date not null unique,        -- bulan yang dilelang (misal '2025-07-01')
  buka_tanggal date not null,        -- tanggal mulai bisa isi (misal 1 Juni)
  tenggat_tier1 date not null,       -- batas tier 1 (buka + 3 hari)
  tenggat_tier2 date not null,       -- batas tier 2 (setelah tier 1 selesai)
  slot_normal integer default 2,     -- slot normal per tanggal
  is_aktif boolean default true,
  created_at timestamptz default now()
);

-- 6. TABEL KODE UNDANGAN
create table kode_undangan (
  id uuid primary key default gen_random_uuid(),
  kode text unique not null,
  dibuat_oleh uuid references perawat(id),
  dipakai_oleh uuid references perawat(id),
  is_terpakai boolean default false,
  created_at timestamptz default now()
);

-- 7. TABEL LOG NOTIFIKASI (in-app)
create table notifikasi (
  id uuid primary key default gen_random_uuid(),
  perawat_id uuid references perawat(id) on delete cascade,
  judul text not null,
  pesan text not null,
  is_dibaca boolean default false,
  created_at timestamptz default now()
);

-- ============================================================
-- INDEXES untuk performa
-- ============================================================
create index idx_tier_bulanan_perawat on tier_bulanan(perawat_id);
create index idx_tier_bulanan_bulan on tier_bulanan(bulan);
create index idx_pengajuan_perawat on pengajuan_cuti(perawat_id);
create index idx_pengajuan_bulan on pengajuan_cuti(bulan);
create index idx_notifikasi_perawat on notifikasi(perawat_id);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
alter table perawat enable row level security;
alter table tier_bulanan enable row level security;
alter table pengajuan_cuti enable row level security;
alter table tanggal_blokir enable row level security;
alter table pengaturan_periode enable row level security;
alter table kode_undangan enable row level security;
alter table notifikasi enable row level security;

-- Semua bisa dibaca (untuk kalender bersama)
create policy "baca_publik_tier" on tier_bulanan for select using (true);
create policy "baca_publik_pengajuan" on pengajuan_cuti for select using (true);
create policy "baca_publik_blokir" on tanggal_blokir for select using (true);
create policy "baca_publik_periode" on pengaturan_periode for select using (true);
create policy "baca_publik_perawat" on perawat for select using (true);

-- Insert/update hanya via service role (kita pakai dari server/edge function)
create policy "service_insert_perawat" on perawat for insert with check (true);
create policy "service_update_perawat" on perawat for update using (true);
create policy "service_insert_tier" on tier_bulanan for insert with check (true);
create policy "service_update_tier" on tier_bulanan for update using (true);
create policy "service_insert_cuti" on pengajuan_cuti for insert with check (true);
create policy "service_update_cuti" on pengajuan_cuti for update using (true);
create policy "service_insert_blokir" on tanggal_blokir for insert with check (true);
create policy "service_delete_blokir" on tanggal_blokir for delete using (true);
create policy "service_insert_periode" on pengaturan_periode for insert with check (true);
create policy "service_update_periode" on pengaturan_periode for update using (true);
create policy "service_insert_kode" on kode_undangan for insert with check (true);
create policy "service_update_kode" on kode_undangan for update using (true);
create policy "service_insert_notif" on notifikasi for insert with check (true);
create policy "service_update_notif" on notifikasi for update using (true);
create policy "baca_kode" on kode_undangan for select using (true);
create policy "baca_notif" on notifikasi for select using (true);
