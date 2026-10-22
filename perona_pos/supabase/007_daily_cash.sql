-- Jalankan setelah 006. Menambah laporan pembayaran harian dan riwayat tutup kas.
begin;
create table if not exists public.cash_closings (
 id uuid primary key,
 business_date date not null,
 previous_id uuid references public.cash_closings(id),
 opening_cash bigint not null check(opening_cash between 0 and 1000000000000),
 cash_out bigint not null check(cash_out between 0 and 1000000000000),
 counted_cash bigint not null check(counted_cash between 0 and 1000000000000),
 cash_received bigint not null check(cash_received>=0),
 qris_received bigint not null check(qris_received>=0),
 transfer_received bigint not null check(transfer_received>=0),
 payment_count integer not null check(payment_count>=0),
 expected_cash bigint generated always as (opening_cash+cash_received-cash_out) stored,
 difference bigint generated always as (counted_cash-opening_cash-cash_received+cash_out) stored,
 source_fingerprint text not null,
 notes text not null default '' check(length(notes)<=500),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default clock_timestamp(),
 check(cash_out<=opening_cash+cash_received)
);
create index if not exists cash_closings_day on public.cash_closings(business_date,created_at desc,id);
alter table public.cash_closings enable row level security;
drop policy if exists cash_closings_read on public.cash_closings;
create policy cash_closings_read on public.cash_closings for select to authenticated
 using(public.app_role() in ('owner','admin'));
revoke all on public.cash_closings from public,anon,authenticated;
grant select on public.cash_closings to authenticated;

-- Helper privat: seluruh pembayaran dalam tanggal WIB, tanpa snapshot ongkos.
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
   coalesce(jsonb_agg(to_jsonb(receipts) order by paid_at desc,id),'[]'::jsonb) as payments
  from receipts
 ) select to_jsonb(summary)||jsonb_build_object('date',p_date,'fingerprint',md5(payments::text)) from summary;
$$;

create or replace function public.cash_day(p_date date) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb; closing jsonb;
begin
 perform public.require_staff();
 if public.app_role() not in ('owner','admin') then raise exception 'Kas harian hanya untuk owner dan admin.'; end if;
 if p_date is null or not isfinite(p_date) or p_date not between date '2020-01-01' and (now() at time zone 'Asia/Jakarta')::date then
  raise exception 'Pilih tanggal kas dari tahun 2020 sampai hari ini.';
 end if;
 result := public.cash_day_snapshot(p_date);
 select to_jsonb(c)||jsonb_build_object('operator_name',p.name) into closing
 from public.cash_closings c join public.profiles p on p.id=c.created_by
 where c.business_date=p_date order by c.created_at desc,c.id limit 1;
 return result||jsonb_build_object('closing',closing);
end $$;

create or replace function public.save_cash_closing(
 p_id uuid,p_date date,p_previous_id uuid,p_fingerprint text,
 p_opening bigint,p_cash_out bigint,p_counted bigint,p_notes text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare existing public.cash_closings; previous public.cash_closings; saved public.cash_closings; snapshot jsonb;
begin
 perform public.require_staff();
 if public.app_role() not in ('owner','admin') then raise exception 'Tutup kas hanya untuk owner dan admin.'; end if;
 if p_id is null or p_date is null or not isfinite(p_date) or p_date not between date '2020-01-01' and (now() at time zone 'Asia/Jakarta')::date then
  raise exception 'ID dan tanggal tutup kas tidak valid.';
 end if;
 if p_opening is null or p_opening not between 0 and 1000000000000 or
    p_cash_out is null or p_cash_out not between 0 and 1000000000000 or
    p_counted is null or p_counted not between 0 and 1000000000000 or
    length(coalesce(p_notes,''))>500 then raise exception 'Nominal atau catatan tutup kas tidak valid.'; end if;
 perform pg_advisory_xact_lock(hashtext('perona-cash:'||p_date::text));
 select * into existing from public.cash_closings where id=p_id;
 if found then
  if existing.business_date=p_date and existing.previous_id is not distinct from p_previous_id and
     existing.opening_cash=p_opening and existing.cash_out=p_cash_out and existing.counted_cash=p_counted and
     existing.source_fingerprint=p_fingerprint and existing.notes=trim(coalesce(p_notes,'')) and existing.created_by=auth.uid() then
   return to_jsonb(existing);
  end if;
  raise exception 'ID tutup kas sudah digunakan.';
 end if;
 select * into previous from public.cash_closings where business_date=p_date order by created_at desc,id limit 1;
 if previous.id is distinct from p_previous_id then
  raise exception 'Tutup kas telah berubah di perangkat lain. Muat ulang dahulu.';
 end if;
 if previous.id is not null and public.app_role()<>'owner' then raise exception 'Hanya owner yang dapat memperbarui tutup kas.'; end if;
 snapshot := public.cash_day_snapshot(p_date);
 if p_fingerprint is null or snapshot->>'fingerprint'<>p_fingerprint then
  raise exception 'Data pembayaran telah berubah. Muat ulang sebelum tutup kas.';
 end if;
 if p_cash_out>p_opening+(snapshot->>'cash')::bigint then raise exception 'Tunai keluar melebihi saldo kas yang tersedia.'; end if;
 if (previous.id is not null or p_counted<>p_opening+(snapshot->>'cash')::bigint-p_cash_out) and length(trim(coalesce(p_notes,'')))<5 then
  raise exception 'Isi catatan minimal 5 karakter untuk selisih atau pembaruan tutup kas.';
 end if;
 insert into public.cash_closings(id,business_date,previous_id,opening_cash,cash_out,counted_cash,
  cash_received,qris_received,transfer_received,payment_count,source_fingerprint,notes,created_by)
 values(p_id,p_date,p_previous_id,p_opening,p_cash_out,p_counted,(snapshot->>'cash')::bigint,
  (snapshot->>'qris')::bigint,(snapshot->>'transfer')::bigint,(snapshot->>'count')::integer,p_fingerprint,trim(coalesce(p_notes,'')),auth.uid())
 returning * into saved;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'cash.close',p_id,case when previous.id is null then null else to_jsonb(previous) end,to_jsonb(saved));
 return to_jsonb(saved);
end $$;

revoke all on function public.cash_day_snapshot(date),public.cash_day(date),
 public.save_cash_closing(uuid,date,uuid,text,bigint,bigint,bigint,text) from public,anon,authenticated;
grant execute on function public.cash_day(date),public.save_cash_closing(uuid,date,uuid,text,bigint,bigint,bigint,text) to authenticated;
notify pgrst,'reload schema';
commit;
