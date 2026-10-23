-- Jalankan setelah 008. Estimasi per nota, opsional; tidak menebak tanggal order lama.
begin;
alter table public.orders add column if not exists due_date date;
alter table public.orders drop constraint if exists orders_due_date_check;
alter table public.orders add constraint orders_due_date_check check(
 due_date is null or (isfinite(due_date) and due_date between date '2020-01-01' and date '2100-12-31'
 and due_date >= (created_at at time zone 'Asia/Jakarta')::date));
create index if not exists orders_due_date on public.orders(due_date,created_at,id) where deleted_at is null;
create or replace function public.save_order_with_estimate(p_id uuid,p_version integer,p_customer text,p_phone text,p_notes text,p_discount bigint,p_items jsonb,p_order_at timestamptz,p_due_date date)
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
 if p_due_date is not null and (not isfinite(p_due_date) or p_due_date not between date '2020-01-01' and date '2100-12-31' or p_due_date<(order_at at time zone 'Asia/Jakarta')::date) then
  raise exception 'Estimasi selesai tidak boleh sebelum tanggal order dan harus antara 2020 dan 2100.';
 end if;
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 100 then
  raise exception 'Order harus berisi 1 sampai 100 layanan.';
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
  insert into public.orders(id,customer_name,phone,notes,items,discount,total,labor_total,created_by,created_at,due_date)
  values(p_id,trim(p_customer),coalesce(p_phone,''),coalesce(p_notes,''),clean,p_discount,gross-p_discount,labor,auth.uid(),order_at,p_due_date);
 else
  update public.orders set customer_name=trim(p_customer),phone=coalesce(p_phone,''),notes=coalesce(p_notes,''),
   created_at=order_at,due_date=p_due_date,items=clean,discount=p_discount,total=gross-p_discount,labor_total=labor,version=version+1,updated_at=now() where id=p_id;
 end if;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),case when is_new then 'order.create' else 'order.edit' end,p_id,
 case when is_new then null else to_jsonb(old) end,(select to_jsonb(o) from public.orders o where id=p_id));
 return p_id;
end $$;

-- Semua tanggal bisnis, tanpa batas periode laporan. Payload memakai redaksi ongkos yang sama.
create or replace function public.work_queue(p_filter text default 'all',p_page integer default 0,p_worker uuid default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; today date := (now() at time zone 'Asia/Jakarta')::date;
begin
 perform public.require_staff();
 if p_filter is null or p_filter not in ('all','overdue','today','upcoming','unscheduled') or p_page is null or p_page not between 0 and 100000 then
  raise exception 'Filter atau halaman pengerjaan tidak valid.';
 end if;
 select coalesce(jsonb_agg(public.order_payload(o.id) order by o.due_date nulls last,o.created_at,o.id),'[]'::jsonb)
 into result from (
  select id,due_date,created_at from public.orders o where deleted_at is null
   and exists(select 1 from jsonb_array_elements(o.items) i
    where coalesce(i->>'status','Masuk') not in ('Selesai','Diambil')
    and (p_worker is null or i->>'worker_id'=p_worker::text))
   and (p_filter='all' or (p_filter='overdue' and due_date<today)
    or (p_filter='today' and due_date=today) or (p_filter='upcoming' and due_date>today)
    or (p_filter='unscheduled' and due_date is null))
  order by due_date nulls last,created_at,id limit 30 offset (p_page*30)
 ) o;
 return result;
end $$;
revoke all on function public.save_order_with_estimate(uuid,integer,text,text,text,bigint,jsonb,timestamptz,date),
 public.work_queue(text,integer,uuid) from public,anon,authenticated;
grant execute on function public.save_order_with_estimate(uuid,integer,text,text,text,bigint,jsonb,timestamptz,date),
 public.work_queue(text,integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
