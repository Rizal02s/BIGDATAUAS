-- Jalankan setelah 004. Konfirmasi Ya/Tidak tanpa koreksi pembayaran manual.
-- Hanya mengubah fungsi; tidak menghapus order saat migrasi dijalankan.
begin;
create or replace function public.delete_order(
 p_id uuid,p_version integer,p_reason text default 'Dihapus oleh owner.'
) returns void language plpgsql security definer set search_path=public as $$
declare
 o public.orders;
 payment_id uuid;
 reason text := coalesce(nullif(trim(p_reason),''),'Dihapus oleh owner.');
begin
 perform public.require_owner();
 if p_id is null or p_version is null or p_version<1 then
  raise exception 'ID dan versi order wajib diisi.';
 end if;
 -- Urutan lock sama dengan add_payment/void_payment: order lalu pembayaran.
 select * into o from public.orders where id=p_id and deleted_at is null for update;
 if not found or o.version<>p_version then
  raise exception 'Order berubah. Muat ulang terlebih dahulu.';
 end if;
 -- Batalkan pencatatan pembayaran dalam transaksi yang sama agar kas juga
 -- keluar dari rekap. void_payment tetap menyimpan pembayaran dan jejak audit.
 for payment_id in
  select id from public.payments where order_id=p_id and voided_at is null order by id
 loop
  perform public.void_payment(payment_id,'Order dihapus: ' || reason);
 end loop;
 update public.orders set deleted_at=now(),delete_reason=reason,
  version=version+1,updated_at=now() where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'order.delete',p_id,to_jsonb(o),jsonb_build_object('reason',reason));
end $$;
revoke all on function public.delete_order(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.delete_order(uuid,integer,text) to authenticated;
notify pgrst,'reload schema';
commit;
