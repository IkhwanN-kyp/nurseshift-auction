# Panduan Deploy — Sistem Lelang Cuti Perawat

## Urutan Langkah
1. Setup Supabase (database)
2. Edit konfigurasi di index.html
3. Upload ke GitHub
4. Deploy di Vercel

---

## LANGKAH 1 — Setup Supabase

### 1a. Jalankan skema database
1. Buka https://supabase.com → masuk ke project Anda
2. Klik menu **SQL Editor** (ikon database di sidebar kiri)
3. Klik **New Query**
4. Copy-paste seluruh isi file `sql/01_schema.sql` → klik **Run**
5. Buat query baru lagi → copy-paste isi file `sql/02_functions.sql` → klik **Run**

### 1b. Ambil URL dan Anon Key
1. Di Supabase, klik ikon **Settings** (roda gigi) di sidebar
2. Pilih **API**
3. Copy nilai **Project URL** (format: https://xxxx.supabase.co)
4. Copy nilai **anon public** key (string panjang)

### 1c. Buat akun admin pertama
Di SQL Editor, jalankan query ini (ganti sesuai data Anda):

```sql
INSERT INTO perawat (nama, no_hp, password_hash, is_admin, is_aktif)
VALUES (
  'Nama Admin',
  '08123456789',
  'h_' || abs(hashtext('passwordanda') % 2147483647)::text || length('passwordanda')::text,
  true,
  true
);
```

> **Catatan**: Karena kita pakai hash sederhana di frontend, jalankan ini di browser console dulu untuk dapat hash yang benar:
> ```javascript
> function hashPw(pw) {
>   let h = 0;
>   for (let i = 0; i < pw.length; i++) { h = Math.imul(31, h) + pw.charCodeAt(i) | 0; }
>   return 'h_' + Math.abs(h).toString(36) + pw.length;
> }
> console.log(hashPw('passwordanda'));
> ```
> Lalu masukkan hasil hash ke kolom `password_hash`.

---

## LANGKAH 2 — Edit Konfigurasi

Buka file `src/index.html`, cari baris ini (di bagian bawah, dekat `<script>`):

```javascript
const SUPA_URL = 'GANTI_SUPABASE_URL';
const SUPA_KEY = 'GANTI_SUPABASE_ANON_KEY';
```

Ganti dengan:
```javascript
const SUPA_URL = 'https://xxxx.supabase.co';   // dari langkah 1b
const SUPA_KEY = 'eyJhbGci...';                 // anon key dari langkah 1b
```

---

## LANGKAH 3 — Upload ke GitHub

### Struktur folder yang perlu di-push:
```
cuti-perawat/
├── src/
│   └── index.html    ← file utama web app
├── sql/
│   ├── 01_schema.sql
│   └── 02_functions.sql
└── PANDUAN_DEPLOY.md
```

### Cara upload:
1. Buka repository GitHub Anda
2. Drag & drop folder `src/` ke GitHub, atau gunakan:
```bash
git add .
git commit -m "Initial deploy sistem cuti perawat"
git push
```

---

## LANGKAH 4 — Deploy di Vercel

1. Buka https://vercel.com → login dengan GitHub
2. Klik **Add New Project**
3. Pilih repository GitHub yang tadi di-push
4. Di bagian **Root Directory**, ketik: `src`
5. Klik **Deploy**
6. Tunggu 1–2 menit → Vercel akan memberi URL seperti:
   `https://cuti-perawat-xxx.vercel.app`

> Bagikan URL ini ke semua perawat untuk diakses dari HP masing-masing.

---

## PENGGUNAAN ADMIN — Panduan Singkat

### Setelah login sebagai admin:
1. Tap avatar (inisial nama) di pojok kanan atas
2. Pilih **Panel Admin**

### Urutan setup awal:
1. **Tab "Kode"** → Generate kode undangan (buat 35-40 kode)
2. **Tab "Periode"** → Buka periode pengajuan untuk Juli–Desember
   - Pilih bulan → isi tanggal mulai pengajuan → Save
   - Tenggat Tier 1 otomatis terisi (+3 hari)
3. **Tab "Tier"** → Atur tier setiap perawat per bulan
   - Default semua Tier 3, tambahkan yang Tier 1 dan 2 saja
4. **Tab "Blokir"** → Blokir tanggal akreditasi dll

### Bagikan kode undangan:
- Dari tab "Kode", bagikan kode via WA grup ke masing-masing perawat
- Perawat registrasi sendiri di halaman web dengan kode tersebut

### Export rekap:
- **Tab "Rekap"** → pilih bulan → klik Download Excel
- File berisi 2 sheet: Daftar cuti + Kalender per hari

---

## TIPS

- Sistem berjalan 100% di browser — tidak perlu install apapun
- Data tersimpan di Supabase (cloud) — aman dan tidak hilang
- Jika ada perawat yang lupa password, admin bisa reset manual di Supabase Table Editor
- Untuk update vercel: cukup push ke GitHub, Vercel auto-redeploy
