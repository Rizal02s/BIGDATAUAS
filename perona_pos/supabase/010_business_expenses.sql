-- Jalankan setelah 009. Pengeluaran yang sudah dibayar; akses khusus owner.
begin;
create table if not exists public.business_expenses (
 id uuid primary key,
 spent_on date not null check(isfinite(spent_on) and spent_on between date '2020-01-01' and date '2100-12-31'),
 title text not null check(length(trim(title)) between 1 and 150),
 category text not null check(category in ('Bahan & peralatan','Listrik & air','Sewa','Transportasi','Perawatan','Lainnya')),
 amount bigint not null check(amount between 1 and 1000000000000),
 method text not null check(method in ('Tunai','Transfer','QRIS')),
 from_drawer boolean not null default false check(not from_drawer or method='Tunai'),
 notes text not null default '' check(length(notes)<=500),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default clock_timestamp(),
 voided_at timestamptz,
 voided_by uuid references public.profiles(id),
 void_reason text
);
create index if not exists business_expenses_day on public.business_expenses(spent_on desc,created_at desc,id);
alter table public.business_expenses enable row level security;
drop policy if exists business_expenses_read on public.business_expenses;
create policy business_expenses_read on public.business_expenses for select to authenticated using(public.app_role()='owner');
revoke all on public.business_expenses from public,anon,authenticated;
grant select on public.business_expenses to authenticated;

create or replace function public.expense_report(p_start date,p_end date,p_page integer default 0)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; entries jsonb; categories jsonb;
begin
 perform public.require_owner();
 if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or
  p_start<date '2020-01-01' or p_end>date '2100-12-31' or p_end<p_start or p_page is null or p_page not between 0 and 100000 then
  raise exception 'Periode atau halaman pengeluaran tidak valid.';
 end if;
 select jsonb_build_object('total',coalesce(sum(amount) filter(where voided_at is null),0),
  'count',count(*) filter(where voided_at is null),'history_count',count(*),
  'drawer_cash',coalesce(sum(amount) filter(where voided_at is null and from_drawer),0)) into result
 from public.business_expenses where spent_on between p_start and p_end;
 select coalesce(jsonb_agg(to_jsonb(t) order by total desc,category),'[]'::jsonb) into categories from (
  select category,sum(amount) as total from public.business_expenses
  where spent_on between p_start and p_end and voided_at is null group by category
 ) t;
 select coalesce(jsonb_agg(to_jsonb(t) order by spent_on desc,created_at desc,id),'[]'::jsonb) into entries from (
  select e.*,p.name as operator_name,v.name as void_operator_name from public.business_expenses e
  join public.profiles p on p.id=e.created_by left join public.profiles v on v.id=e.voided_by
  where spent_on between p_start and p_end order by spent_on desc,created_at desc,e.id limit 30 offset (p_page*30)
 ) t;
 return result||jsonb_build_object('categories',categories,'rows',entries);
end $$;

create or replace function public.record_expense(p_id uuid,p_date date,p_title text,p_category text,p_amount bigint,p_method text,p_from_drawer boolean,p_notes text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare existing public.business_expenses; saved public.business_expenses;
begin
 perform public.require_owner();
 if p_id is null or p_date is null or not isfinite(p_date) or p_date not between date '2020-01-01' and (now() at time zone 'Asia/Jakarta')::date or
  p_title is null or length(trim(p_title)) not between 1 and 150 or p_category is null or
  p_category not in ('Bahan & peralatan','Listrik & air','Sewa','Transportasi','Perawatan','Lainnya') or
  p_amount is null or p_amount not between 1 and 1000000000000 or p_method is null or p_method not in ('Tunai','Transfer','QRIS') or
  p_from_drawer is null or (p_from_drawer and p_method<>'Tunai') or length(coalesce(p_notes,''))>500 then
  raise exception 'Tanggal, keterangan, kategori, nominal, atau metode pengeluaran tidak valid.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('expense:'||p_id::text,0));
 select * into existing from public.business_expenses where id=p_id;
 if found then
  if existing.spent_on=p_date and existing.title=trim(p_title) and existing.category=p_category and
   existing.amount=p_amount and existing.method=p_method and existing.from_drawer=p_from_drawer and
   existing.notes=trim(coalesce(p_notes,'')) and existing.created_by=auth.uid() and existing.voided_at is null then
   return to_jsonb(existing);
  end if;
  raise exception 'ID pengeluaran sudah digunakan. Muat ulang riwayat.';
 end if;
 insert into public.business_expenses(id,spent_on,title,category,amount,method,from_drawer,notes,created_by)
 values(p_id,p_date,trim(p_title),p_category,p_amount,p_method,p_from_drawer,trim(coalesce(p_notes,'')),auth.uid()) returning * into saved;
 insert into public.audit_log(actor,action,entity_id,after_data) values(auth.uid(),'expense.create',p_id,to_jsonb(saved));
 return to_jsonb(saved);
end $$;

create or replace function public.void_expense(p_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare old public.business_expenses;
begin
 perform public.require_owner();
 if p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Isi alasan koreksi 5 sampai 500 karakter.'; end if;
 select * into old from public.business_expenses where id=p_id for update;
 if not found then raise exception 'Pengeluaran tidak ditemukan.'; end if;
 if old.voided_at is not null then return; end if;
 update public.business_expenses set voided_at=clock_timestamp(),voided_by=auth.uid(),void_reason=trim(p_reason) where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'expense.void',p_id,to_jsonb(old),(select to_jsonb(e) from public.business_expenses e where id=p_id));
end $$;

-- Seperti pembayaran ongkos Tunai, biaya dari laci kas menandai perubahan data.
-- Nominal keluar tetap diisi manual dalam tutup kas, termasuk setoran/lainnya.
-- Admin hanya menerima hash; rincian biaya internal tidak ditambahkan ke laporan kas.
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
 ), expenses as (
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'amount',amount) order by id),'[]'::jsonb) as costs
  from public.business_expenses where spent_on=p_date and from_drawer and voided_at is null
 ) select to_jsonb(summary)||jsonb_build_object('date',p_date,
  'fingerprint',md5(payments::text||case when payouts='[]'::jsonb then '' else payouts::text end||
   case when costs='[]'::jsonb then '' else costs::text end))
 from summary cross join outgoing cross join expenses;
$$;
revoke all on function public.cash_day_snapshot(date),public.expense_report(date,date,integer),
 public.record_expense(uuid,date,text,text,bigint,text,boolean,text),public.void_expense(uuid,text) from public,anon,authenticated;
grant execute on function public.expense_report(date,date,integer),public.record_expense(uuid,date,text,text,bigint,text,boolean,text),
 public.void_expense(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
