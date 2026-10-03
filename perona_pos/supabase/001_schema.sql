-- Jalankan sekali di proyek Supabase BARU. Tarif dimuat oleh 002_seed.sql.
begin;
create table public.profiles (
 id uuid primary key references auth.users(id),
 name text not null,
 role text not null default 'pending' check(role in ('owner','staff','pending','disabled')),
 created_at timestamptz not null default now()
);
create table public.services (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(trim(name)) between 1 and 120),
 category text not null,
 price bigint not null check(price between 0 and 100000000),
 labor_fee bigint check(labor_fee between 0 and 100000000),
 active boolean not null default true
);
create table public.orders (
 id uuid primary key,
 number bigint generated always as identity unique,
 customer_name text not null check(length(trim(customer_name)) between 1 and 150),
 phone text not null default '',
 notes text not null default '',
 items jsonb not null check(jsonb_typeof(items)='array'),
 discount bigint not null default 0 check(discount>=0),
 total bigint not null check(total>=0),
 labor_total bigint not null check(labor_total>=0),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 version integer not null default 1,
 deleted_at timestamptz,
 delete_reason text
);
create table public.payments (
 id uuid primary key,
 order_id uuid not null references public.orders(id),
 amount bigint not null check(amount>0),
 method text not null check(method in ('Tunai','Transfer','QRIS')),
 paid_at timestamptz not null default now(),
 created_by uuid not null references public.profiles(id),
 voided_at timestamptz,
 void_reason text
);
create table public.order_photos (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.orders(id),
 path text not null unique,
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now()
);
create table public.audit_log (
 id bigint generated always as identity primary key,
 actor uuid not null references public.profiles(id),
 action text not null,
 entity_id uuid not null,
 before_data jsonb,
 after_data jsonb,
 created_at timestamptz not null default now()
);
create index orders_period on public.orders(created_at) where deleted_at is null;
create index payments_period on public.payments(paid_at) where voided_at is null;
create index payments_order on public.payments(order_id);
create index order_photos_order on public.order_photos(order_id);

create function public.on_signup() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,name) values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''),'Pegawai'));
 return new;
end $$;
create trigger create_profile after insert on auth.users for each row execute function public.on_signup();
create function public.app_role() returns text language sql stable security definer set search_path=public as $$
 select role from public.profiles where id=auth.uid()
$$;
create function public.is_active() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(public.app_role() in ('owner','staff'),false)
$$;
create function public.require_staff() returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_active() then raise exception 'Akun belum aktif atau sudah dinonaktifkan.'; end if;
end $$;
create function public.require_owner() returns void language plpgsql security definer set search_path=public as $$
begin
 if public.app_role() is distinct from 'owner' then raise exception 'Hanya owner yang diizinkan.'; end if;
end $$;

-- Input harga/upah dari HP diabaikan. Server mengambil master atau snapshot lama.
create function public.save_order(p_id uuid,p_version integer,p_customer text,p_phone text,p_notes text,p_discount bigint,p_items jsonb)
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
  if not exists(select 1 from public.profiles where id=worker and role in ('owner','staff')) and
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

create function public.add_payment(p_id uuid,p_order uuid,p_amount bigint,p_method text)
returns void language plpgsql security definer set search_path=public as $$
declare o public.orders; paid bigint; existing public.payments;
begin
 perform public.require_staff();
 select * into o from public.orders where id=p_order and deleted_at is null for update;
 if not found then raise exception 'Order tidak ditemukan.'; end if;
 select * into existing from public.payments where id=p_id;
 if found then
  if existing.order_id=p_order and existing.amount=p_amount and existing.method=p_method and existing.voided_at is null then return; end if;
  raise exception 'ID pembayaran sudah digunakan.';
 end if;
 select coalesce(sum(amount),0) into paid from public.payments where order_id=p_order and voided_at is null;
 if p_amount is null or p_amount<=0 or paid+p_amount>o.total then raise exception 'Pembayaran melebihi sisa tagihan atau tidak valid.'; end if;
 insert into public.payments(id,order_id,amount,method,created_by) values(p_id,p_order,p_amount,p_method,auth.uid());
 update public.orders set version=version+1,updated_at=now() where id=p_order;
 insert into public.audit_log(actor,action,entity_id,after_data) values(auth.uid(),'payment.create',p_id,
  jsonb_build_object('order_id',p_order,'amount',p_amount,'method',p_method));
end $$;
create function public.void_payment(p_id uuid,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare pay public.payments;
begin
 perform public.require_owner();
 if length(trim(coalesce(p_reason,'')))<5 then raise exception 'Isi alasan koreksi minimal 5 karakter.'; end if;
 -- Urutan lock selalu order lalu payment, sama seperti add_payment/save_order.
 select * into pay from public.payments where id=p_id;
 if not found then raise exception 'Pembayaran tidak ditemukan.'; end if;
 perform 1 from public.orders where id=pay.order_id for update;
 select * into pay from public.payments where id=p_id and voided_at is null for update;
 if not found then raise exception 'Pembayaran telah dikoreksi.'; end if;
 update public.payments set voided_at=now(),void_reason=p_reason where id=p_id;
 update public.orders set version=version+1,updated_at=now() where id=pay.order_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'payment.void',p_id,to_jsonb(pay),jsonb_build_object('reason',p_reason));
end $$;
create function public.delete_order(p_id uuid,p_version integer,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare o public.orders;
begin
 perform public.require_owner();
 if p_id is null or p_version is null or p_version<1 then raise exception 'ID dan versi order wajib diisi.'; end if;
 select * into o from public.orders where id=p_id and deleted_at is null for update;
 if not found or o.version<>p_version then raise exception 'Order berubah. Muat ulang terlebih dahulu.'; end if;
 if length(trim(coalesce(p_reason,'')))<5 then raise exception 'Isi alasan penghapusan minimal 5 karakter.'; end if;
 if exists(select 1 from public.payments where order_id=p_id and voided_at is null) then
  raise exception 'Masih ada pembayaran. Penghapusan hanya untuk koreksi order; koreksi pembayaran lebih dahulu. Pengembalian uang perlu dicatat terpisah.';
 end if;
 update public.orders set deleted_at=now(),delete_reason=p_reason,version=version+1 where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'order.delete',p_id,to_jsonb(o),jsonb_build_object('reason',p_reason));
end $$;

create function public.save_service(p_id uuid,p_name text,p_category text,p_price bigint,p_labor bigint,p_active boolean)
returns void language plpgsql security definer set search_path=public as $$
declare old public.services;
begin
 perform public.require_owner();
 select * into old from public.services where id=p_id for update;
 if p_active and p_labor is null then raise exception 'Tarif ongkos wajib diisi untuk layanan aktif.'; end if;
 insert into public.services(id,name,category,price,labor_fee,active) values(p_id,trim(p_name),trim(p_category),p_price,p_labor,p_active)
 on conflict(id) do update set name=excluded.name,category=excluded.category,price=excluded.price,labor_fee=excluded.labor_fee,active=excluded.active;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'service.save',p_id,to_jsonb(old),(select to_jsonb(s) from public.services s where id=p_id));
end $$;
create function public.set_staff_role(p_id uuid,p_role text) returns void language plpgsql security definer set search_path=public as $$
declare old public.profiles;
begin
 perform public.require_owner();
 if p_id=auth.uid() then raise exception 'Owner tidak dapat mengubah peran sendiri.'; end if;
 if p_role not in ('owner','staff','disabled') or p_role is null then raise exception 'Peran tidak valid.'; end if;
 select * into old from public.profiles where id=p_id for update;
 if not found then raise exception 'Akun tidak ditemukan.'; end if;
 update public.profiles set role=p_role where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'staff.role',p_id,to_jsonb(old),jsonb_build_object('role',p_role));
end $$;

-- Rekap dihitung server: tidak terpotong limit 1.000 baris API.
-- Upah diakui pada created_at order sesuai pilihan user: saat order masuk.
create function public.period_report(p_start timestamptz,p_end timestamptz)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; wages jsonb;
begin
 perform public.require_staff();
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

alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;
alter table public.order_photos enable row level security;
alter table public.audit_log enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_active());
create policy services_read on public.services for select to authenticated using(public.is_active());
create policy orders_read on public.orders for select to authenticated using(public.is_active() and (deleted_at is null or public.app_role()='owner'));
create policy payments_read on public.payments for select to authenticated using(public.is_active());
create policy photos_read on public.order_photos for select to authenticated using(public.is_active());
create policy audit_read on public.audit_log for select to authenticated using(public.app_role()='owner');
create policy photos_insert on public.order_photos for insert to authenticated with check(
 public.is_active() and created_by=auth.uid() and split_part(path,'/',1)=order_id::text and
 split_part(path,'/',2)=auth.uid()::text and exists(select 1 from public.orders where id=order_id and deleted_at is null)
 and exists(select 1 from storage.objects where bucket_id='order-photos' and name=path)
);
-- Transaksi, harga, dan peran hanya boleh ditulis melalui RPC tervalidasi.
revoke all on public.profiles,public.services,public.orders,public.payments,public.order_photos,public.audit_log from anon,authenticated;
grant select on public.profiles,public.services,public.orders,public.payments,public.order_photos,public.audit_log to authenticated;
grant insert on public.order_photos to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('order-photos','order-photos',false,2097152,array['image/jpeg','image/png','image/webp']);
create policy photo_object_read on storage.objects for select to authenticated using(bucket_id='order-photos' and public.is_active());
create policy photo_object_insert on storage.objects for insert to authenticated with check(
 bucket_id='order-photos' and public.is_active() and split_part(name,'/',2)=auth.uid()::text and
 exists(select 1 from public.orders where id::text=split_part(name,'/',1) and deleted_at is null)
);
-- Cleanup hanya foto milik sendiri yang belum terhubung ke order.
create policy photo_object_cleanup on storage.objects for delete to authenticated using(
 bucket_id='order-photos' and public.is_active() and split_part(name,'/',2)=auth.uid()::text and
 not exists(select 1 from public.order_photos where path=name)
);
-- PostgreSQL secara default memberi EXECUTE ke PUBLIC: cabut satu per satu.
do $$ declare f record; begin
 for f in select oid::regprocedure signature from pg_proc where pronamespace='public'::regnamespace and proname in
 ('on_signup','app_role','is_active','require_staff','require_owner','save_order','add_payment','void_payment','delete_order','save_service','set_staff_role','period_report') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  if split_part(f.signature::text,'(',1) not in ('on_signup','require_staff','require_owner') then
   execute format('grant execute on function %s to authenticated',f.signature);
  end if;
 end loop;
end $$;
commit;
