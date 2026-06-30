-- ============================================================
-- FUNGSI BISNIS — jalankan setelah 01_schema.sql
-- ============================================================

-- Fungsi: cek apakah perawat boleh mengisi cuti sekarang
-- (berdasarkan tier dan window waktu)
create or replace function cek_window_tier(
  p_perawat_id uuid,
  p_bulan date
) returns table (
  boleh boolean,
  tier_perawat integer,
  pesan text
) language plpgsql as $$
declare
  v_tier integer;
  v_tenggat_tier1 date;
  v_tenggat_tier2 date;
  v_buka date;
  v_is_aktif boolean;
begin
  -- ambil tier perawat bulan ini
  select tier into v_tier
  from tier_bulanan
  where perawat_id = p_perawat_id and bulan = p_bulan;

  if v_tier is null then
    v_tier := 3; -- default tier 3
  end if;

  -- ambil pengaturan periode
  select buka_tanggal, tenggat_tier1, tenggat_tier2, is_aktif
  into v_buka, v_tenggat_tier1, v_tenggat_tier2, v_is_aktif
  from pengaturan_periode
  where bulan = p_bulan;

  if v_buka is null then
    return query select false, v_tier, 'Periode pengajuan belum dibuka admin';
    return;
  end if;

  if not v_is_aktif then
    return query select false, v_tier, 'Periode ini sudah ditutup';
    return;
  end if;

  if current_date < v_buka then
    return query select false, v_tier, 'Periode pengajuan belum dibuka';
    return;
  end if;

  -- Tier 1: boleh dari hari buka s/d tenggat_tier1 + setelahnya jika turun
  if v_tier = 1 then
    if current_date <= v_tenggat_tier1 then
      return query select true, v_tier, 'Window tier 1 aktif';
    else
      -- tier 1 melewati tenggat, dianggap tier 2
      return query select true, 2, 'Tenggat tier 1 lewat, masuk antrean tier 2';
    end if;
  end if;

  -- Tier 2: boleh setelah tenggat_tier1
  if v_tier = 2 then
    if current_date > v_tenggat_tier1 then
      return query select true, v_tier, 'Window tier 2 aktif';
    else
      return query select false, v_tier, 'Menunggu window tier 1 selesai';
    end if;
  end if;

  -- Tier 3: boleh setelah tenggat_tier2
  if v_tier = 3 then
    if current_date > v_tenggat_tier2 then
      return query select true, v_tier, 'Window tier 3 aktif';
    else
      return query select false, v_tier, 'Menunggu window tier 1 dan 2 selesai';
    end if;
  end if;
end;
$$;

-- Fungsi: hitung slot tersisa per tanggal
create or replace function slot_tersisa(p_tanggal date)
returns table (
  tanggal date,
  terpakai integer,
  slot_max integer,
  sisa integer,
  is_blokir boolean,
  alasan_blokir text
) language plpgsql as $$
declare
  v_blokir boolean := false;
  v_alasan text := null;
  v_slot_max integer := 2;
  v_terpakai integer := 0;
  v_bulan date;
begin
  v_bulan := date_trunc('month', p_tanggal)::date;

  -- cek blokir
  select true, tb.alasan into v_blokir, v_alasan
  from tanggal_blokir tb
  where tb.tanggal = p_tanggal;

  -- ambil slot max dari pengaturan
  select pp.slot_normal into v_slot_max
  from pengaturan_periode pp
  where pp.bulan = v_bulan;

  if v_slot_max is null then v_slot_max := 2; end if;

  -- hitung yang sudah terpakai (cuti aktif yang mencakup tanggal ini)
  select count(*) into v_terpakai
  from pengajuan_cuti pc
  where pc.status = 'aktif'
    and p_tanggal between pc.tanggal_mulai and pc.tanggal_selesai;

  return query select
    p_tanggal,
    v_terpakai,
    coalesce(v_slot_max, 2),
    greatest(0, coalesce(v_slot_max, 2) - v_terpakai),
    coalesce(v_blokir, false),
    v_alasan;
end;
$$;

-- Fungsi: proses pengajuan cuti dengan logika geser tier
create or replace function ajukan_cuti(
  p_perawat_id uuid,
  p_tanggal_mulai date,
  p_tanggal_selesai date
) returns jsonb language plpgsql as $$
declare
  v_bulan date;
  v_tier_efektif integer;
  v_tier_raw integer;
  v_window record;
  v_cek date;
  v_slot record;
  v_blokir record;
  v_existing record;
  v_jumlah_hari integer;
  v_new_id uuid;
  v_geser_ids uuid[];
  v_geser_id uuid;
begin
  v_bulan := date_trunc('month', p_tanggal_mulai)::date;
  v_jumlah_hari := p_tanggal_selesai - p_tanggal_mulai + 1;

  -- Validasi durasi
  if v_jumlah_hari < 1 or v_jumlah_hari > 6 then
    return jsonb_build_object('ok', false, 'pesan', 'Durasi cuti harus 1–6 hari');
  end if;

  -- Validasi bulan sama
  if date_trunc('month', p_tanggal_mulai) != date_trunc('month', p_tanggal_selesai) then
    return jsonb_build_object('ok', false, 'pesan', 'Cuti tidak boleh melewati bulan');
  end if;

  -- Cek sudah punya cuti aktif bulan ini
  select * into v_existing
  from pengajuan_cuti
  where perawat_id = p_perawat_id
    and bulan = v_bulan
    and status = 'aktif';

  if v_existing.id is not null then
    return jsonb_build_object('ok', false, 'pesan', 'Anda sudah punya cuti aktif bulan ini');
  end if;

  -- Cek window tier
  select * into v_window from cek_window_tier(p_perawat_id, v_bulan);
  if not v_window.boleh then
    return jsonb_build_object('ok', false, 'pesan', v_window.pesan);
  end if;
  v_tier_efektif := v_window.tier_perawat;

  -- Ambil tier asli perawat
  select tier into v_tier_raw from tier_bulanan
  where perawat_id = p_perawat_id and bulan = v_bulan;
  if v_tier_raw is null then v_tier_raw := 3; end if;

  -- Cek tiap tanggal dalam range
  v_cek := p_tanggal_mulai;
  while v_cek <= p_tanggal_selesai loop
    -- Cek blokir
    select * into v_blokir from tanggal_blokir where tanggal = v_cek;
    if v_blokir.id is not null then
      return jsonb_build_object('ok', false, 'pesan',
        'Tanggal ' || to_char(v_cek, 'DD Mon') || ' diblokir: ' || v_blokir.alasan);
    end if;

    -- Cek slot dan kemungkinan geser
    select * into v_slot from slot_tersisa(v_cek);

    if v_slot.sisa = 0 then
      -- Tidak ada slot kosong — cek apakah bisa geser tier lebih rendah
      if v_tier_efektif < 3 then
        -- cari tier 3 yang bisa digeser
        select pc.id into v_geser_id
        from pengajuan_cuti pc
        where pc.status = 'aktif'
          and v_cek between pc.tanggal_mulai and pc.tanggal_selesai
          and pc.tier_saat_pengajuan > v_tier_efektif
        order by pc.tier_saat_pengajuan desc, pc.submitted_at desc
        limit 1;

        if v_geser_id is null then
          return jsonb_build_object('ok', false, 'pesan',
            'Tanggal ' || to_char(v_cek, 'DD Mon') || ' sudah penuh (tidak ada yang bisa digeser)');
        end if;
        v_geser_ids := array_append(v_geser_ids, v_geser_id);
      else
        return jsonb_build_object('ok', false, 'pesan',
          'Tanggal ' || to_char(v_cek, 'DD Mon') || ' sudah penuh');
      end if;
    end if;

    v_cek := v_cek + 1;
  end loop;

  -- Batalkan yang digeser
  if v_geser_ids is not null then
    foreach v_geser_id in array v_geser_ids loop
      update pengajuan_cuti
      set status = 'dibatalkan_sistem',
          dibatalkan_karena = 'Digeser oleh perawat tier lebih tinggi',
          updated_at = now()
      where id = v_geser_id;

      -- Kirim notifikasi ke yang digeser
      insert into notifikasi (perawat_id, judul, pesan)
      select perawat_id,
        'Cuti Dibatalkan Sistem',
        'Cuti Anda untuk periode ' || to_char(p_tanggal_mulai, 'DD Mon') ||
        ' – ' || to_char(p_tanggal_selesai, 'DD Mon') ||
        ' dibatalkan karena ada perawat tier lebih tinggi. Silakan pilih tanggal lain.'
      from pengajuan_cuti where id = v_geser_id;
    end loop;
  end if;

  -- Simpan pengajuan baru
  insert into pengajuan_cuti (
    perawat_id, bulan, tanggal_mulai, tanggal_selesai,
    tier_saat_pengajuan, status
  ) values (
    p_perawat_id, v_bulan, p_tanggal_mulai, p_tanggal_selesai,
    v_tier_efektif, 'aktif'
  ) returning id into v_new_id;

  -- Notifikasi sukses
  insert into notifikasi (perawat_id, judul, pesan)
  values (
    p_perawat_id, 'Cuti Berhasil Diajukan',
    'Cuti ' || to_char(p_tanggal_mulai, 'DD Mon') || ' – ' ||
    to_char(p_tanggal_selesai, 'DD Mon') || ' (' || v_jumlah_hari || ' hari) berhasil diajukan.'
  );

  return jsonb_build_object('ok', true, 'id', v_new_id,
    'pesan', 'Cuti berhasil diajukan', 'tier', v_tier_efektif);
end;
$$;

-- Fungsi: batalkan cuti oleh perawat sendiri
create or replace function batalkan_cuti(
  p_cuti_id uuid,
  p_perawat_id uuid
) returns jsonb language plpgsql as $$
begin
  update pengajuan_cuti
  set status = 'dibatalkan_perawat', updated_at = now()
  where id = p_cuti_id
    and perawat_id = p_perawat_id
    and status = 'aktif';

  if not found then
    return jsonb_build_object('ok', false, 'pesan', 'Cuti tidak ditemukan atau sudah dibatalkan');
  end if;

  return jsonb_build_object('ok', true, 'pesan', 'Cuti berhasil dibatalkan');
end;
$$;
