-- Jalankan setelah 012, lalu deploy Edge Function delete-employee-account.
-- Profil historis dipertahankan untuk order, ongkos, pembayaran, dan foto.
begin;
alter table public.profiles add column if not exists deleted_at timestamptz;
alter table public.profiles add column if not exists deleted_by uuid references public.profiles(id);
alter table public.profiles add column if not exists delete_reason text;
alter table public.profiles add column if not exists auth_deleted_at timestamptz;

-- Alasan penghapusan khusus owner. Direktori untuk operasional tidak memuat alasan/aktor.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
 using(id=auth.uid() or public.app_role()='owner');
create or replace function public.staff_directory() returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 perform public.require_staff();
 select coalesce(jsonb_agg(case when public.app_role()='owner' then to_jsonb(p) else
  jsonb_build_object('id',p.id,'name',p.name,'role',p.role,'created_at',p.created_at,
   'deleted_at',p.deleted_at,'auth_deleted_at',p.auth_deleted_at) end order by p.name,p.id),'[]'::jsonb)
 into result from public.profiles p;
 return result;
end $$;

create or replace function public.app_role() returns text
language sql stable security definer set search_path=public as $$
 select role from public.profiles where id=auth.uid() and deleted_at is null;
$$;

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
 if old.deleted_at is not null then raise exception 'Akun telah dihapus dan tidak dapat diaktifkan kembali.'; end if;
 update public.profiles set role=new_role where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'staff.role',p_id,to_jsonb(old),jsonb_build_object('role',new_role));
end $$;

create or replace function public.prepare_employee_deletion(p_id uuid,p_expected_role text,p_reason text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare old public.profiles;
begin
 perform public.require_owner();
 if p_id is null or p_id=auth.uid() then raise exception 'Akun sendiri tidak dapat dihapus.'; end if;
 if p_reason is null or length(trim(p_reason)) not between 5 and 500 then raise exception 'Isi alasan penghapusan 5 sampai 500 karakter.'; end if;
 select * into old from public.profiles where id=p_id for update;
 if not found then raise exception 'Akun tidak ditemukan.'; end if;
 if old.role='owner' then raise exception 'Akun owner tidak dapat dihapus melalui menu pegawai.'; end if;
 if old.deleted_at is not null then
  return jsonb_build_object('id',p_id,'name',old.name,'auth_deleted',old.auth_deleted_at is not null);
 end if;
 if p_expected_role is null or old.role<>p_expected_role then raise exception 'Peran akun telah berubah. Muat ulang daftar pegawai.'; end if;
 update public.profiles set role='disabled',deleted_at=clock_timestamp(),deleted_by=auth.uid(),delete_reason=trim(p_reason) where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(auth.uid(),'staff.delete',p_id,to_jsonb(old),(select to_jsonb(p) from public.profiles p where id=p_id));
 return jsonb_build_object('id',p_id,'name',old.name,'auth_deleted',false);
end $$;

-- Hanya fungsi server berkunci service_role yang boleh mengonfirmasi Auth.
create or replace function public.finish_employee_deletion(p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare target public.profiles;
begin
 select * into target from public.profiles where id=p_id for update;
 if not found or target.deleted_at is null or target.role<>'disabled' then raise exception 'Permintaan penghapusan akun tidak ditemukan.'; end if;
 if target.auth_deleted_at is not null then return; end if;
 if exists(select 1 from auth.users where id=p_id and deleted_at is null) then raise exception 'Login Auth belum dihapus.'; end if;
 update public.profiles set auth_deleted_at=clock_timestamp() where id=p_id;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
 values(target.deleted_by,'staff.auth_deleted',p_id,to_jsonb(target),(select to_jsonb(p) from public.profiles p where id=p_id));
end $$;
revoke all on function public.prepare_employee_deletion(uuid,text,text),public.finish_employee_deletion(uuid) from public,anon,authenticated;
revoke all on function public.staff_directory() from public,anon,authenticated;
grant execute on function public.staff_directory() to authenticated;
grant execute on function public.prepare_employee_deletion(uuid,text,text) to authenticated;
grant execute on function public.finish_employee_deletion(uuid) to service_role;
notify pgrst,'reload schema';
commit;
