-- Jalankan setelah 011. Laporan operasional owner/admin tanpa data ongkos/internal.
begin;
create or replace function public.operational_report(p_start timestamptz,p_end timestamptz,p_page integer default 0)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; receipts jsonb; today date := (now() at time zone 'Asia/Jakarta')::date;
begin
 perform public.require_staff();
 if public.app_role() not in ('owner','admin') then raise exception 'Laporan operasional hanya untuk owner dan admin.'; end if;
 if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<=p_start or
  p_start<(timestamp '2020-01-01' at time zone 'Asia/Jakarta') or
  p_end>(timestamp '2101-01-01' at time zone 'Asia/Jakarta') or
  p_page is null or p_page not between 0 and 100000 then raise exception 'Periode atau halaman laporan tidak valid.'; end if;
 with paid as (
  select order_id,sum(amount) as amount from public.payments where voided_at is null group by order_id
 ), all_orders as (
  select o.id,o.total,o.discount,o.created_at,o.due_date,
   greatest(o.total-coalesce(p.amount,0),0) as remaining,
   exists(select 1 from jsonb_array_elements(o.items) i where coalesce(i->>'status','Masuk') not in ('Selesai','Diambil')) as needs_work,
   exists(select 1 from jsonb_array_elements(o.items) i where i->>'status'='Selesai') as ready,
   jsonb_array_length(o.items)>0 and not exists(select 1 from jsonb_array_elements(o.items) i where coalesce(i->>'status','Masuk')<>'Diambil') as picked_up
  from public.orders o left join paid p on p.order_id=o.id where o.deleted_at is null
 ), cohort as (
  select * from all_orders where created_at>=p_start and created_at<p_end
 ), incoming as (
  select p.amount,p.method from public.payments p join public.orders o on o.id=p.order_id
  where p.voided_at is null and o.deleted_at is null and p.paid_at>=p_start and p.paid_at<p_end
 ) select jsonb_build_object(
  'count',count(*),'gross',coalesce(sum(total+discount),0),'revenue',coalesce(sum(total),0),'discount',coalesce(sum(discount),0),
  'pending',count(*) filter(where needs_work),'ready',count(*) filter(where not needs_work and ready),
  'picked_up',count(*) filter(where picked_up),
  'overdue',count(*) filter(where needs_work and due_date<today),
  'due_today',count(*) filter(where needs_work and due_date=today),
  'outstanding_period',coalesce(sum(remaining),0),
  'outstanding_all',(select coalesce(sum(remaining),0) from all_orders),
  'received',(select coalesce(sum(amount),0) from incoming),
  'cash',(select coalesce(sum(amount) filter(where method='Tunai'),0) from incoming),
  'qris',(select coalesce(sum(amount) filter(where method='QRIS'),0) from incoming),
  'transfer',(select coalesce(sum(amount) filter(where method='Transfer'),0) from incoming),
  'receipt_count',(select count(*) from incoming)
 ) into result from cohort;
 select coalesce(jsonb_agg(to_jsonb(r) order by paid_at desc,id),'[]'::jsonb) into receipts from (
  select p.id,p.order_id,p.amount,p.method,p.paid_at,o.number as order_number,
   o.customer_name,o.created_at as order_at,pr.name as operator_name
  from public.payments p join public.orders o on o.id=p.order_id join public.profiles pr on pr.id=p.created_by
  where p.voided_at is null and o.deleted_at is null and p.paid_at>=p_start and p.paid_at<p_end
  order by p.paid_at desc,p.id limit 30 offset (p_page*30)
 ) r;
 return result||jsonb_build_object('payments',receipts);
end $$;
revoke all on function public.operational_report(timestamptz,timestamptz,integer) from public,anon,authenticated;
grant execute on function public.operational_report(timestamptz,timestamptz,integer) to authenticated;
notify pgrst,'reload schema';
commit;
