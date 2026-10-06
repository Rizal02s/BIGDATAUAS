-- Jalankan setelah 003. Menambah tanggal order manual tanpa menghapus data.
-- created_at adalah tanggal bisnis/order; recorded_at mencatat waktu input nyata.
begin;
alter table public.orders add column if not exists recorded_at timestamptz;
update public.orders set recorded_at=created_at where recorded_at is null;
alter table public.orders alter column recorded_at set default now();
alter table public.orders alter column recorded_at set not null;
alter table public.payments add column if not exists recorded_at timestamptz;
update public.payments set recorded_at=paid_at where recorded_at is null;
alter table public.payments alter column recorded_at set default now();
alter table public.payments alter column recorded_at set not null;

create or replace function public.save_order_with_date(p_id uuid,p_version integer,p_customer text,p_phone text,p_notes text,p_discount bigint,p_items jsonb,p_order_at timestamptz)
returns uuid language plpgsql security definer set search_path=public as $$
declare
 old public.orders; svc public.services; previous jsonb; item jsonb; clean jsonb := '[]';
 item_id uuid; worker uuid; qty integer; price bigint; fee bigint; name text; category text;
 gross bigint := 0; labor bigint := 0; paid bigint; is_new boolean; status text; order_at timestamptz;
begin
 perform public.require_staff();
 if p_id is null or p_version is null or p_version<0 then raise exception 'ID dan versi order wajib diisi.'; end if;
 -- Serialisasi ID baru juga: retry tidak membuat dua order.
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into old from public.orders where id=p_id for update;
 is_new := not found;
 if is_new and p_version<>0 then raise exception 'Order tidak ditemukan.'; end if;
 if not is_new and (old.deleted_at is not null or old.version<>p_version) then
  raise exception 'Order telah berubah di HP lain. Muat ulang sebelum menyimpan.';
 end if;
 order_at := coalesce(p_order_at,case when is_new then now() else old.created_at end);
 if not isfinite(order_at) or (order_at at time zone 'Asia/Jakarta')::date not between date '2020-01-01' and date '2100-12-31' then
  raise exception 'Tanggal order harus antara 2020 dan 2100.';
 end if;
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 100 then
  raise exception 'Order harus berisi 1–100 layanan.';
 end if;
 for item in select value from jsonb_array_elements(p_items) loop
  item_id := (item->>'id')::uuid;
  if item_id is null or exists(select 1 from jsonb_array_elements(clean) j where j->>'id'=item_id::text) then
   raise exception 'ID item kosong atau duplikat.';
  end if;
  qty := (item->>'quantity')::integer;
  worker := (item->>'worker_id')::uuid;
  status := item->>'status';
  if qty is null or qty not between 1 and 999 or worker is null or status is null or status not in ('Masuk','Dikerjakan','Selesai','Diambil') then
   raise exception 'Jumlah, pegawai, atau status tidak valid.';
  end if;
  previous := null;
  if not is_new then
   select j into previous from jsonb_array_elements(old.items) j where j->>'id'=item_id::text;
  end if;
  if previous is not null and previous->>'service_id'=item->>'service_id' then
   price := (previous->>'price')::bigint; fee := (previous->>'labor_fee')::bigint;
   name := previous->>'name'; category := previous->>'category';
  else
   select * into svc from public.services where id=(item->>'service_id')::uuid and active;
   if not found or svc.labor_fee is null then raise exception 'Layanan tidak aktif atau ongkos belum ditetapkan.'; end if;
   price := svc.price; fee := svc.labor_fee; name := svc.name; category := svc.category;
  end if;
  -- Pegawai lama yang dinonaktifkan tetap boleh tersimpan pada order lama.
  if not exists(select 1 from public.profiles where id=worker and role in ('owner','staff','technician')) and
    (previous is null or previous->>'worker_id' is distinct from worker::text) then
   raise exception 'Pilih pegawai aktif.';
  end if;
  clean := clean || jsonb_build_array(jsonb_build_object('id',item_id,'service_id',item->>'service_id',
   'name',name,'category',category,'price',price,'labor_fee',fee,'quantity',qty,'worker_id',worker,'status',status));
  gross := gross + price*qty; labor := labor + fee*qty;
 end loop;
 if p_discount is null or p_discount<0 or p_discount>gross then raise exception 'Diskon tidak valid.'; end if;
 select coalesce(sum(amount),0) into paid from public.payments where order_id=p_id and voided_at is null;
 if gross-p_discount<paid then raise exception 'Total baru lebih kecil dari pembayaran. Koreksi pembayaran terlebih dahulu.'; end if;
 if is_new then
  insert into public.orders(id,customer_name,phone,notes,items,discount,total,labor_total,created_by,created_at)
  values(p_id,trim(p_customer),coalesce(p_phone,''),coalesce(p_notes,''),clean,p_discount,gross-p_discount,labor,auth.uid(),order_at);
 else
  update public.orders set customer_name=trim(p_customer),phone=coalesce(p_phone,''),notes=coalesce(p_notes,''),
   created_at=order_at,items=clean,discount=p_discount,total=gross-p_discount,labor_total=labor,version=version+1,updated_at=now() where id=p_id;
 end if;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),case when is_new then 'order.create' else 'order.edit' end,p_id,
 case when is_new then null else to_jsonb(old) end,(select to_jsonb(o) from public.orders o where id=p_id));
 return p_id;
end $$;

-- APK lama tetap dapat memakai fungsi tujuh parameter. Saat edit tanpa tanggal,
-- tanggal bisnis yang sudah tersimpan dipertahankan.
create or replace function public.save_order(p_id uuid,p_version integer,p_customer text,p_phone text,p_notes text,p_discount bigint,p_items jsonb)
returns uuid language sql security definer set search_path=public as $$
 select public.save_order_with_date(p_id,p_version,p_customer,p_phone,p_notes,p_discount,p_items,null);
$$;
revoke all on function public.save_order_with_date(uuid,integer,text,text,text,bigint,jsonb,timestamptz) from public,anon,authenticated;
grant execute on function public.save_order_with_date(uuid,integer,text,text,text,bigint,jsonb,timestamptz) to authenticated;

-- Pembayaran awal pada order yang dicatat mundur mengikuti tanggal order.
-- Pembayaran susulan/APK lama tetap memakai waktu sekarang melalui add_payment.
create or replace function public.add_payment_with_date(p_id uuid,p_order uuid,p_amount bigint,p_method text,p_paid_at timestamptz)
returns void language plpgsql security definer set search_path=public as $$
declare o public.orders; paid bigint; existing public.payments; paid_at_value timestamptz;
begin
 perform public.require_staff();
 select * into o from public.orders where id=p_order and deleted_at is null for update;
 if not found then raise exception 'Order tidak ditemukan.'; end if;
 select * into existing from public.payments where id=p_id;
 if found then
  -- Retry mempertahankan tanggal pembayaran yang pertama tersimpan.
  if existing.order_id=p_order and existing.amount=p_amount and existing.method=p_method and existing.voided_at is null then return; end if;
  raise exception 'ID pembayaran sudah digunakan.';
 end if;
 paid_at_value := coalesce(p_paid_at,now());
 if not isfinite(paid_at_value) or (paid_at_value at time zone 'Asia/Jakarta')::date not between date '2020-01-01' and date '2100-12-31' then
  raise exception 'Tanggal pembayaran harus antara 2020 dan 2100.';
 end if;
 select coalesce(sum(amount),0) into paid from public.payments where order_id=p_order and voided_at is null;
 if p_amount is null or p_amount<=0 or paid+p_amount>o.total then raise exception 'Pembayaran melebihi sisa tagihan atau tidak valid.'; end if;
 insert into public.payments(id,order_id,amount,method,created_by,paid_at)
 values(p_id,p_order,p_amount,p_method,auth.uid(),paid_at_value);
 update public.orders set version=version+1,updated_at=now() where id=p_order;
 insert into public.audit_log(actor,action,entity_id,after_data) values(auth.uid(),'payment.create',p_id,
  (select to_jsonb(p) from public.payments p where id=p_id));
end $$;

create or replace function public.add_payment(p_id uuid,p_order uuid,p_amount bigint,p_method text)
returns void language sql security definer set search_path=public as $$
 select public.add_payment_with_date(p_id,p_order,p_amount,p_method,null);
$$;
revoke all on function public.add_payment_with_date(uuid,uuid,bigint,text,timestamptz) from public,anon,authenticated;
grant execute on function public.add_payment_with_date(uuid,uuid,bigint,text,timestamptz) to authenticated;
notify pgrst,'reload schema';
commit;
