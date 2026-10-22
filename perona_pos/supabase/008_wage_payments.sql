-- Jalankan setelah 007. Pembayaran ongkos dialokasikan per pegawai dan nota.
begin;
create table if not exists public.wage_payouts (
 id uuid primary key,
 worker_id uuid not null references public.profiles(id),
 amount bigint not null check(amount between 1 and 1000000000000),
 method text not null check(method in ('Tunai','Transfer','QRIS')),
 paid_at timestamptz not null default now(),
 basis_start timestamptz not null,
 basis_end timestamptz not null check(basis_end>basis_start),
 source_fingerprint text not null,
 notes text not null default '' check(length(notes)<=500),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 voided_at timestamptz,
 voided_by uuid references public.profiles(id),
 void_reason text
);
create table if not exists public.wage_allocations (
 payout_id uuid not null references public.wage_payouts(id),
 order_id uuid not null references public.orders(id),
 amount bigint not null check(amount>0),
 primary key(payout_id,order_id)
);
create index if not exists wage_payouts_worker on public.wage_payouts(worker_id,paid_at desc,id);
create index if not exists wage_allocations_order on public.wage_allocations(order_id);
alter table public.wage_payouts enable row level security;
alter table public.wage_allocations enable row level security;
drop policy if exists wage_payouts_read on public.wage_payouts;
create policy wage_payouts_read on public.wage_payouts for select to authenticated using(public.can_view_wages());
drop policy if exists wage_allocations_read on public.wage_allocations;
create policy wage_allocations_read on public.wage_allocations for select to authenticated using(public.can_view_wages());
revoke all on public.wage_payouts,public.wage_allocations from public,anon,authenticated;
grant select on public.wage_payouts,public.wage_allocations to authenticated;

-- Helper privat. Riwayat alokasi tetap muncul jika nota dihapus/ditugaskan ulang.
create or replace function public.wage_note_balances(p_start timestamptz,p_end timestamptz,p_worker uuid default null)
returns table(order_id uuid,worker_id uuid,worker_name text,order_number bigint,customer_name text,
 order_at timestamptz,earned bigint,paid bigint,remaining bigint,excess bigint,services text,deleted boolean)
language sql stable security definer set search_path=public as $$
 with scoped as (select * from public.orders where created_at>=p_start and created_at<p_end),
 earned as (
  select o.id,(j->>'worker_id')::uuid worker,
   case when o.deleted_at is null then sum((j->>'labor_fee')::bigint*(j->>'quantity')::integer) else 0 end::bigint amount,
   string_agg((j->>'name')||' × '||(j->>'quantity'),E'\n' order by j->>'id') services
  from scoped o cross join lateral jsonb_array_elements(o.items) j
  where p_worker is null or j->>'worker_id'=p_worker::text
  group by o.id,o.deleted_at,(j->>'worker_id')::uuid
 ), allocations as (
  select a.order_id,p.worker_id,sum(case when p.voided_at is null then a.amount else 0 end)::bigint amount
  from public.wage_allocations a join public.wage_payouts p on p.id=a.payout_id
  join scoped o on o.id=a.order_id where p_worker is null or p.worker_id=p_worker
  group by a.order_id,p.worker_id
 ), keys as (select id,worker from earned union select order_id,worker_id from allocations)
 select o.id,k.worker,pr.name,o.number,o.customer_name,o.created_at,coalesce(e.amount,0),coalesce(a.amount,0),
  greatest(coalesce(e.amount,0)-coalesce(a.amount,0),0),greatest(coalesce(a.amount,0)-coalesce(e.amount,0),0),
  coalesce(e.services,'Layanan tidak lagi ditugaskan ke pegawai ini'),o.deleted_at is not null
 from keys k join scoped o on o.id=k.id join public.profiles pr on pr.id=k.worker
 left join earned e on e.id=k.id and e.worker=k.worker
 left join allocations a on a.order_id=k.id and a.worker_id=k.worker
 order by o.created_at,o.id,k.worker;
$$;

create or replace function public.wage_overview(p_start timestamptz,p_end timestamptz) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 perform public.require_staff();
 if not public.can_view_wages() then raise exception 'Akses pembayaran ongkos hanya untuk owner dan teknisi.'; end if;
 if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<=p_start then raise exception 'Periode ongkos tidak valid.'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.worker_name,t.worker_id),'[]'::jsonb) into result from (
  select worker_id,worker_name,sum(earned) earned,sum(paid) paid,sum(remaining) remaining,sum(excess) excess,count(*) note_count
  from public.wage_note_balances(p_start,p_end,null) group by worker_id,worker_name
 ) t;
 return result;
end $$;

create or replace function public.wage_ledger(p_worker uuid,p_start timestamptz,p_end timestamptz) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb; history jsonb; worker_name text;
begin
 perform public.require_staff();
 if not public.can_view_wages() then raise exception 'Akses pembayaran ongkos hanya untuk owner dan teknisi.'; end if;
 if p_worker is null or p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<=p_start then raise exception 'Pegawai atau periode ongkos tidak valid.'; end if;
 select name into worker_name from public.profiles where id=p_worker;
 if not found then raise exception 'Pegawai tidak ditemukan.'; end if;
 select jsonb_build_object('earned',coalesce(sum(earned),0),'paid',coalesce(sum(paid),0),
  'remaining',coalesce(sum(remaining),0),'excess',coalesce(sum(excess),0),
  'notes',coalesce(jsonb_agg(to_jsonb(n) order by order_at,order_id),'[]'::jsonb)) into result
 from public.wage_note_balances(p_start,p_end,p_worker) n;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.paid_at desc,t.id),'[]'::jsonb) into history from (
  select p.id,p.amount,p.method,p.paid_at,p.created_at,p.notes,p.voided_at,p.void_reason,pr.name as operator_name,
   sum(a.amount) as allocated_amount,
   jsonb_agg(jsonb_build_object('order_id',o.id,'order_number',o.number,'customer_name',o.customer_name,'amount',a.amount)
    order by o.created_at,o.id) as allocations
  from public.wage_payouts p join public.profiles pr on pr.id=p.created_by
  join public.wage_allocations a on a.payout_id=p.id join public.orders o on o.id=a.order_id
  where p.worker_id=p_worker and o.created_at>=p_start and o.created_at<p_end
  group by p.id,pr.name
 ) t;
 return result||jsonb_build_object('worker_id',p_worker,'worker_name',worker_name,'history',history,
  'fingerprint',md5((result->'notes')::text));
end $$;

create or replace function public.pay_wages(p_id uuid,p_worker uuid,p_start timestamptz,p_end timestamptz,
 p_fingerprint text,p_amount bigint,p_method text,p_paid_at timestamptz,p_notes text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare existing public.wage_payouts; saved public.wage_payouts; ledger jsonb; n jsonb; left_amount bigint; allocated bigint; at_value timestamptz;
begin
 perform public.require_owner();
 if p_id is null or p_worker is null or p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<=p_start then raise exception 'ID, pegawai, dan periode wajib diisi.'; end if;
 if p_amount is null or p_amount not between 1 and 1000000000000 or p_method is null or p_method not in ('Tunai','Transfer','QRIS') or length(coalesce(p_notes,''))>500 then raise exception 'Nominal, metode, atau catatan pembayaran tidak valid.'; end if;
 perform pg_advisory_xact_lock(hashtext('perona-wages:'||p_worker::text));
 select * into existing from public.wage_payouts where id=p_id;
 if found then
  if existing.worker_id=p_worker and existing.basis_start=p_start and existing.basis_end=p_end and
   existing.source_fingerprint=p_fingerprint and existing.amount=p_amount and existing.method=p_method and
   (p_paid_at is null or existing.paid_at=p_paid_at) and existing.notes=trim(coalesce(p_notes,'')) and
   existing.created_by=auth.uid() and existing.voided_at is null then return to_jsonb(existing); end if;
  raise exception 'ID pembayaran ongkos sudah digunakan atau dikoreksi.';
 end if;
 at_value:=coalesce(p_paid_at,now());
 if not isfinite(at_value) or at_value<('2020-01-01'::timestamp at time zone 'Asia/Jakarta') or at_value>now() then raise exception 'Waktu pembayaran harus dari tahun 2020 sampai saat ini.'; end if;
 ledger:=public.wage_ledger(p_worker,p_start,p_end);
 if p_fingerprint is null or ledger->>'fingerprint'<>p_fingerprint then raise exception 'Data ongkos atau pembayaran berubah. Muat ulang sebelum menyimpan.'; end if;
 if p_amount>(ledger->>'remaining')::bigint then raise exception 'Pembayaran melebihi sisa ongkos periode ini.'; end if;
 insert into public.wage_payouts(id,worker_id,amount,method,paid_at,basis_start,basis_end,source_fingerprint,notes,created_by)
 values(p_id,p_worker,p_amount,p_method,at_value,p_start,p_end,p_fingerprint,trim(coalesce(p_notes,'')),auth.uid()) returning * into saved;
 left_amount:=p_amount;
 for n in select value from jsonb_array_elements(ledger->'notes') loop
  allocated:=least(left_amount,(n->>'remaining')::bigint);
  if allocated>0 then
   insert into public.wage_allocations(payout_id,order_id,amount) values(p_id,(n->>'order_id')::uuid,allocated);
   left_amount:=left_amount-allocated;
  end if;
  exit when left_amount=0;
 end loop;
 if left_amount<>0 then raise exception 'Alokasi pembayaran gagal. Muat ulang dahulu.'; end if;
 insert into public.audit_log(actor,action,entity_id,after_data)
 values(auth.uid(),'wage.pay',p_id,to_jsonb(saved)||jsonb_build_object('allocations',(select jsonb_agg(to_jsonb(a)) from public.wage_allocations a where payout_id=p_id)));
 return to_jsonb(saved);
end $$;

create or replace function public.void_wage_payout(p_id uuid,p_reason text) returns void
language plpgsql security definer set search_path=public as $$
declare old public.wage_payouts;
begin
 perform public.require_owner();
 if length(trim(coalesce(p_reason,'')))<5 or length(p_reason)>500 then raise exception 'Alasan koreksi minimal 5 dan maksimal 500 karakter.'; end if;
 select * into old from public.wage_payouts where id=p_id;
 if not found then raise exception 'Pembayaran ongkos tidak ditemukan.'; end if;
 perform pg_advisory_xact_lock(hashtext('perona-wages:'||old.worker_id::text));
 select * into old from public.wage_payouts where id=p_id for update;
 if old.voided_at is not null then return; end if;
 update public.wage_payouts set voided_at=now(),voided_by=auth.uid(),void_reason=trim(p_reason) where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'wage.void',p_id,to_jsonb(old),(select to_jsonb(p) from public.wage_payouts p where id=p_id));
end $$;

-- Kas tetap menampilkan penerimaan pelanggan saja. Pembayaran ongkos Tunai
-- mengubah fingerprint agar hasil tutup kas ditandai perlu diperiksa ulang.
-- Total tunai keluar tetap diisi petugas saat pencocokan, tanpa penggandaan.
create or replace function public.cash_day_snapshot(p_date date) returns jsonb
language sql stable security definer set search_path=public as $$
 with receipts as (
  select p.id,p.order_id,p.amount,p.method,p.paid_at,
   o.number as order_number,o.customer_name,o.created_at as order_at
  from public.payments p join public.orders o on o.id=p.order_id
  where p.voided_at is null and o.deleted_at is null
   and p.paid_at>=(p_date::timestamp at time zone 'Asia/Jakarta')
   and p.paid_at<((p_date+1)::timestamp at time zone 'Asia/Jakarta')
 ), summary as (
  select coalesce(sum(amount) filter(where method='Tunai'),0) as cash,
   coalesce(sum(amount) filter(where method='QRIS'),0) as qris,
   coalesce(sum(amount) filter(where method='Transfer'),0) as transfer,
   coalesce(sum(amount),0) as total,count(*) as count,
   coalesce(jsonb_agg(to_jsonb(receipts) order by paid_at desc,id),'[]'::jsonb) as payments from receipts
 ), outgoing as (
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'amount',amount,'paid_at',paid_at) order by paid_at,id),'[]'::jsonb) as payouts
  from public.wage_payouts where method='Tunai' and voided_at is null
   and paid_at>=(p_date::timestamp at time zone 'Asia/Jakarta')
   and paid_at<((p_date+1)::timestamp at time zone 'Asia/Jakarta')
 ) select to_jsonb(summary)||jsonb_build_object('date',p_date,
  'fingerprint',md5(payments::text||case when payouts='[]'::jsonb then '' else payouts::text end))
 from summary cross join outgoing;
$$;
revoke all on function public.cash_day_snapshot(date) from public,anon,authenticated;

revoke all on function public.wage_note_balances(timestamptz,timestamptz,uuid),public.wage_overview(timestamptz,timestamptz),
 public.wage_ledger(uuid,timestamptz,timestamptz),public.pay_wages(uuid,uuid,timestamptz,timestamptz,text,bigint,text,timestamptz,text),
 public.void_wage_payout(uuid,text) from public,anon,authenticated;
grant execute on function public.wage_overview(timestamptz,timestamptz),public.wage_ledger(uuid,timestamptz,timestamptz),
 public.pay_wages(uuid,uuid,timestamptz,timestamptz,text,bigint,text,timestamptz,text),public.void_wage_payout(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
