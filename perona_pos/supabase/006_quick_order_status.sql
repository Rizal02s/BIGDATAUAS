-- Jalankan setelah 005. Hanya menambah fungsi perubahan status dan jejak audit.
begin;
create or replace function public.update_order_statuses(
 p_id uuid,p_version integer,p_statuses jsonb
) returns void language plpgsql security definer set search_path=public as $$
declare
 old public.orders;
 change jsonb;
 changed_items jsonb;
 item_id uuid;
 seen uuid[] := '{}';
begin
 perform public.require_staff();
 if p_id is null or p_version is null or p_version<1 then
  raise exception 'ID dan versi order wajib diisi.';
 end if;
 select * into old from public.orders where id=p_id and deleted_at is null for update;
 if not found then raise exception 'Order tidak ditemukan.'; end if;
 if old.version<>p_version then
  raise exception 'Order telah berubah di HP lain. Muat ulang sebelum menyimpan.';
 end if;
 if jsonb_typeof(p_statuses) is distinct from 'array' then
  raise exception 'Daftar status tidak valid.';
 end if;
 if jsonb_array_length(p_statuses) not between 1 and 100 then
  raise exception 'Pilih 1 sampai 100 layanan.';
 end if;
 for change in select value from jsonb_array_elements(p_statuses) loop
  item_id := (change->>'id')::uuid;
  if item_id is null or item_id=any(seen) then
   raise exception 'ID layanan kosong atau duplikat.';
  end if;
  seen := array_append(seen,item_id);
  if change->>'status' is null or change->>'status' not in ('Masuk','Dikerjakan','Selesai','Diambil') then
   raise exception 'Status pengerjaan tidak valid.';
  end if;
  if not exists(select 1 from jsonb_array_elements(old.items) item where item->>'id'=item_id::text) then
   raise exception 'Layanan tidak ditemukan pada order ini.';
  end if;
 end loop;
 -- Pertahankan urutan, snapshot harga/upah, dan seluruh data selain status.
 select jsonb_agg(
  case when c.value is null then i.value
   else jsonb_set(i.value,'{status}',c.value->'status') end order by i.position
 ) into changed_items
 from jsonb_array_elements(old.items) with ordinality as i(value,position)
 left join jsonb_array_elements(p_statuses) c(value) on c.value->>'id'=i.value->>'id';
 if changed_items=old.items then return; end if;
 update public.orders set items=changed_items,version=version+1,updated_at=now() where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'order.status',p_id,to_jsonb(old),
  (select to_jsonb(o) from public.orders o where id=p_id));
end $$;
revoke all on function public.update_order_statuses(uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.update_order_statuses(uuid,integer,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
