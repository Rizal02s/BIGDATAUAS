-- Proyek berjalan: jalankan file ini, jangan ulangi 001/002.
-- Aman dijalankan ulang. Role staff lama tetap dikenali sebagai teknisi.
begin;
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
 check(role in ('owner','admin','technician','staff','pending','disabled'));

create or replace function public.is_active() returns boolean
language sql stable security definer set search_path=public as $$
 select coalesce(public.app_role() in ('owner','admin','technician','staff'),false)
$$;
create or replace function public.can_view_wages() returns boolean
language sql stable security definer set search_path=public as $$
 select coalesce(public.app_role() in ('owner','technician','staff'),false)
$$;
drop policy if exists services_read on public.services;
create policy services_read on public.services for select to authenticated using(public.can_view_wages());
drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders for select to authenticated
 using(public.can_view_wages() and (deleted_at is null or public.app_role()='owner'));

-- RLS admin sengaja tidak membaca orders mentah. Upload memakai cek keberadaan
-- yang hanya mengembalikan boolean, tanpa mengungkap snapshot ongkos.
create or replace function public.order_is_open(p_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select public.is_active() and exists(select 1 from public.orders where id=p_id and deleted_at is null)
$$;
drop policy if exists photos_insert on public.order_photos;
create policy photos_insert on public.order_photos for insert to authenticated with check(
 public.is_active() and created_by=auth.uid() and split_part(path,'/',1)=order_id::text
 and split_part(path,'/',2)=auth.uid()::text and public.order_is_open(order_id)
 and exists(select 1 from storage.objects where bucket_id='order-photos' and name=path)
);
drop policy if exists photo_object_insert on storage.objects;
create policy photo_object_insert on storage.objects for insert to authenticated with check(
 bucket_id='order-photos' and public.is_active() and split_part(name,'/',2)=auth.uid()::text
 and public.order_is_open(split_part(name,'/',1)::uuid)
);

create or replace function public.set_staff_role(p_id uuid,p_role text)
returns void language plpgsql security definer set search_path=public as $$
declare old public.profiles; new_role text;
begin
 perform public.require_owner();
 if p_id=auth.uid() then raise exception 'Owner tidak dapat mengubah peran sendiri.'; end if;
 new_role := case when p_role='staff' then 'technician' else p_role end;
 if new_role is null or new_role not in ('owner','admin','technician','disabled') then raise exception 'Peran tidak valid.'; end if;
 select * into old from public.profiles where id=p_id for update;
 if not found then raise exception 'Akun tidak ditemukan.'; end if;
 update public.profiles set role=new_role where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'staff.role',p_id,to_jsonb(old),jsonb_build_object('role',new_role));
end $$;

create or replace function public.save_order(p_id uuid,p_version integer,p_customer text,p_phone text,p_notes text,p_discount bigint,p_items jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare
 old public.orders; svc public.services; previous jsonb; item jsonb; clean jsonb := '[]';
 item_id uuid; worker uuid; qty integer; price bigint; fee bigint; name text; category text;
 gross bigint := 0; labor bigint := 0; paid bigint; is_new boolean; status text;
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
  insert into public.orders(id,customer_name,phone,notes,items,discount,total,labor_total,created_by)
  values(p_id,trim(p_customer),coalesce(p_phone,''),coalesce(p_notes,''),clean,p_discount,gross-p_discount,labor,auth.uid());
 else
  update public.orders set customer_name=trim(p_customer),phone=coalesce(p_phone,''),notes=coalesce(p_notes,''),
   items=clean,discount=p_discount,total=gross-p_discount,labor_total=labor,version=version+1,updated_at=now() where id=p_id;
 end if;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),case when is_new then 'order.create' else 'order.edit' end,p_id,
 case when is_new then null else to_jsonb(old) end,(select to_jsonb(o) from public.orders o where id=p_id));
 return p_id;
end $$;

create or replace function public.period_report(p_start timestamptz,p_end timestamptz)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; wages jsonb;
begin
 perform public.require_staff();
 if not public.can_view_wages() then raise exception 'Akses ongkos hanya untuk owner dan teknisi.'; end if;
 if p_start is null or p_end is null or p_end<=p_start then raise exception 'Periode tidak valid.'; end if;
 select jsonb_build_object('count',count(*),'revenue',coalesce(sum(total),0),'labor',coalesce(sum(labor_total),0),
  'discount',coalesce(sum(discount),0)) into result
 from public.orders where deleted_at is null and created_at>=p_start and created_at<p_end;
 result := result || jsonb_build_object('cash',
  (select coalesce(sum(amount),0) from public.payments where voided_at is null and paid_at>=p_start and paid_at<p_end),
  'outstanding_all', (select coalesce(sum(o.total - coalesce(p.amount,0)),0) from public.orders o
   left join (select order_id,sum(amount) amount from public.payments where voided_at is null group by order_id) p on p.order_id=o.id
   where o.deleted_at is null));
 select coalesce(jsonb_agg(row_to_json(t)),'[]') into wages from (
  select p.id,p.name,sum((j->>'labor_fee')::bigint*(j->>'quantity')::integer) amount
  from public.orders o cross join lateral jsonb_array_elements(o.items) j
  join public.profiles p on p.id=(j->>'worker_id')::uuid
  where o.deleted_at is null and o.created_at>=p_start and o.created_at<p_end
  group by p.id,p.name order by p.name
 ) t;
 return result || jsonb_build_object('wages',wages);
end $$;

create or replace function public.service_catalog() returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 perform public.require_staff();
 select coalesce(jsonb_agg(case when public.can_view_wages() then to_jsonb(s)
  else (to_jsonb(s)-'labor_fee') || jsonb_build_object('orderable',s.labor_fee is not null)
  end order by s.name,s.id),'[]'::jsonb) into result from public.services s;
 return result;
end $$;

-- Helper privat: tidak dapat dipanggil langsung oleh klien.
create or replace function public.order_payload(p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare o public.orders; result jsonb; safe_items jsonb;
begin
 select * into o from public.orders where id=p_id and deleted_at is null;
 if not found then raise exception 'Order tidak ditemukan.'; end if;
 result := to_jsonb(o);
 if not public.can_view_wages() then
  select coalesce(jsonb_agg(value-'labor_fee' order by item_index),'[]'::jsonb)
   into safe_items from jsonb_array_elements(o.items) with ordinality as item(value,item_index);
  result := (result-'labor_total') || jsonb_build_object('items',safe_items);
 end if;
 return result || jsonb_build_object(
  'payments',(select coalesce(jsonb_agg(to_jsonb(p) order by p.paid_at,p.id),'[]'::jsonb)
   from public.payments p where p.order_id=p_id),
  'order_photos',(select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at,p.id),'[]'::jsonb)
   from public.order_photos p where p.order_id=p_id));
end $$;

create or replace function public.order_detail(p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
begin
 perform public.require_staff();
 return public.order_payload(p_id);
end $$;
create or replace function public.order_list(p_start timestamptz,p_end timestamptz,
 p_page integer default 0,p_worker uuid default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 perform public.require_staff();
 if p_start is null or p_end is null or p_end<=p_start or p_page is null or p_page<0 or p_page>100000 then
  raise exception 'Periode atau halaman tidak valid.';
 end if;
 select coalesce(jsonb_agg(public.order_payload(o.id) order by o.created_at desc,o.id),'[]'::jsonb)
 into result from (
  select id,created_at from public.orders where deleted_at is null and created_at>=p_start and created_at<p_end
   and (p_worker is null or items @> jsonb_build_array(jsonb_build_object('worker_id',p_worker::text)))
  order by created_at desc,id limit 30 offset (p_page*30)
 ) o;
 return result;
end $$;
create or replace function public.order_day_counts(p_start timestamptz,p_end timestamptz,
 p_worker uuid default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 perform public.require_staff();
 if p_start is null or p_end is null or p_end<=p_start then raise exception 'Periode tidak valid.'; end if;
 select coalesce(jsonb_object_agg(day_number,order_count),'{}'::jsonb) into result from (
  select extract(day from created_at at time zone 'Asia/Jakarta')::integer day_number,count(*) order_count
  from public.orders where deleted_at is null and created_at>=p_start and created_at<p_end
   and (p_worker is null or items @> jsonb_build_array(jsonb_build_object('worker_id',p_worker::text))) group by 1
 ) days;
 return result;
end $$;

revoke all on function public.order_is_open(uuid),public.can_view_wages(),public.service_catalog(),public.order_payload(uuid),
 public.order_detail(uuid),public.order_list(timestamptz,timestamptz,integer,uuid),
 public.order_day_counts(timestamptz,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.order_is_open(uuid),public.can_view_wages(),public.service_catalog(),public.order_detail(uuid),
 public.order_list(timestamptz,timestamptz,integer,uuid),public.order_day_counts(timestamptz,timestamptz,uuid) to authenticated;
commit;
