-- Jalankan setelah 013. Absensi WIB, terpisah dari perhitungan ongkos.
begin;
create table if not exists public.attendance (
 id uuid primary key default gen_random_uuid(),
 employee_id uuid not null references public.profiles(id),
 business_date date not null check(isfinite(business_date) and business_date between date '2020-01-01' and date '2100-12-31'),
 status text not null check(status in ('Hadir','Izin','Sakit')),
 check_in timestamptz,
 check_out timestamptz,
 notes text not null default '' check(length(notes)<=500),
 version integer not null default 1 check(version>0),
 updated_at timestamptz not null default clock_timestamp(),
 updated_by uuid not null references public.profiles(id),
 correction_reason text not null default '' check(length(correction_reason)<=500),
 unique(employee_id,business_date),
 check((status='Hadir' and check_in is not null and isfinite(check_in)
   and (check_in at time zone 'Asia/Jakarta')::date=business_date
   and (check_out is null or (isfinite(check_out) and check_out>=check_in and check_out<=check_in+interval '48 hours')))
  or (status in ('Izin','Sakit') and check_in is null and check_out is null))
);
create unique index if not exists attendance_one_open on public.attendance(employee_id)
 where status='Hadir' and check_out is null;
create index if not exists attendance_dates on public.attendance(business_date desc,employee_id,id);
create table if not exists public.attendance_requests (
 id uuid primary key,
 employee_id uuid not null references public.profiles(id),
 action text not null,
 notes text not null,
 attendance_id uuid not null references public.attendance(id)
);
alter table public.attendance enable row level security;
alter table public.attendance_requests enable row level security;
drop policy if exists attendance_read on public.attendance;
create policy attendance_read on public.attendance for select to authenticated
 using(public.is_active() and (employee_id=auth.uid() or public.app_role()='owner'));
revoke all on public.attendance,public.attendance_requests from public,anon,authenticated;
grant select on public.attendance to authenticated;

create or replace function public.attendance_today() returns jsonb
language plpgsql security definer set search_path=public as $$
declare moment timestamptz := clock_timestamp(); today date; current_row jsonb; open_row jsonb;
begin
 perform public.require_staff();
 today := (moment at time zone 'Asia/Jakarta')::date;
 select to_jsonb(a) into current_row from public.attendance a where employee_id=auth.uid() and business_date=today;
 select to_jsonb(a) into open_row from public.attendance a where employee_id=auth.uid() and status='Hadir' and check_out is null;
 return jsonb_build_object('server_time',moment,'date',today,'today',current_row,'open',open_row);
end $$;

create or replace function public.record_attendance(p_request_id uuid,p_action text,p_notes text default '') returns jsonb
language plpgsql security definer set search_path=public as $$
declare moment timestamptz; today date; old public.attendance; saved public.attendance; previous public.attendance_requests; note text := trim(coalesce(p_notes,''));
begin
 perform public.require_staff();
 if p_request_id is null or p_action is null or p_action not in ('in','out','Izin','Sakit') or length(note)>500 then raise exception 'Permintaan absensi tidak valid.'; end if;
 if p_action in ('Izin','Sakit') and length(note)<5 then raise exception 'Isi keterangan izin/sakit minimal 5 karakter.'; end if;
 perform pg_advisory_xact_lock(hashtextextended('attendance:'||auth.uid()::text,0));
 select * into previous from public.attendance_requests where id=p_request_id;
 if found then
  if previous.employee_id<>auth.uid() or previous.action<>p_action or previous.notes<>note then raise exception 'ID permintaan absensi sudah digunakan.'; end if;
  return (select to_jsonb(a) from public.attendance a where id=previous.attendance_id);
 end if;
 moment := clock_timestamp(); today := (moment at time zone 'Asia/Jakarta')::date;
 if p_action='out' then
  select * into old from public.attendance where employee_id=auth.uid() and status='Hadir' and check_out is null for update;
  if not found then raise exception 'Tidak ada absen masuk yang belum dipulangkan. Muat ulang daftar.'; end if;
  if moment>old.check_in+interval '48 hours' then raise exception 'Absen masuk sudah lebih dari 48 jam. Minta owner mengoreksi jam pulang.'; end if;
  update public.attendance set check_out=moment,version=version+1,updated_at=moment,updated_by=auth.uid()
   where id=old.id returning * into saved;
 else
  if exists(select 1 from public.attendance where employee_id=auth.uid() and status='Hadir' and check_out is null) then
   raise exception 'Selesaikan absen pulang sebelumnya atau minta koreksi owner.';
  end if;
  if exists(select 1 from public.attendance where employee_id=auth.uid() and business_date=today) then
   raise exception 'Absensi hari ini sudah tercatat. Muat ulang atau minta koreksi owner.';
  end if;
  insert into public.attendance(employee_id,business_date,status,check_in,notes,updated_at,updated_by)
   values(auth.uid(),today,case when p_action='in' then 'Hadir' else p_action end,
    case when p_action='in' then moment else null end,note,moment,auth.uid()) returning * into saved;
 end if;
 insert into public.attendance_requests(id,employee_id,action,notes,attendance_id) values(p_request_id,auth.uid(),p_action,note,saved.id);
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
  values(auth.uid(),'attendance.'||p_action,saved.id,case when old.id is null then null else to_jsonb(old) end,to_jsonb(saved));
 return to_jsonb(saved);
end $$;

create or replace function public.correct_attendance(p_employee uuid,p_date date,p_version integer,p_status text,p_in timestamptz,p_out timestamptz,p_notes text,p_reason text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare old public.attendance; saved public.attendance; moment timestamptz := clock_timestamp(); note text := trim(coalesce(p_notes,'')); reason text := trim(coalesce(p_reason,''));
begin
 perform public.require_owner();
 if p_employee is null or p_date is null or not isfinite(p_date) or p_date not between date '2020-01-01' and (moment at time zone 'Asia/Jakarta')::date
  or p_version is null or p_version<0 or p_status is null or p_status not in ('Hadir','Izin','Sakit') or length(note)>500 or length(reason) not between 5 and 500 then
  raise exception 'Pegawai, tanggal, status, atau alasan koreksi tidak valid.';
 end if;
 if p_status='Hadir' then
  if p_in is null or not isfinite(p_in) or (p_in at time zone 'Asia/Jakarta')::date<>p_date or p_in>moment or
   (p_out is not null and (not isfinite(p_out) or p_out<p_in or p_out>moment or p_out>p_in+interval '48 hours')) then
   raise exception 'Jam masuk/pulang tidak valid. Gunakan tanggal masuk yang dipilih, durasi maksimal 48 jam, dan waktu yang sudah lewat.';
  end if;
 elsif p_in is not null or p_out is not null or length(note)<5 then raise exception 'Izin/sakit memerlukan keterangan minimal 5 karakter dan tanpa jam masuk/pulang.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('attendance:'||p_employee::text,0));
 select * into old from public.attendance where employee_id=p_employee and business_date=p_date for update;
 if old.id is null then
  if p_version<>0 then raise exception 'Absensi tidak ditemukan. Muat ulang.'; end if;
  if not exists(select 1 from public.profiles where id=p_employee and deleted_at is null and role in ('owner','admin','staff','technician')) then
   raise exception 'Pilih pegawai aktif untuk catatan baru.';
  end if;
 else
  -- Retry setelah respons hilang aman selama data tersimpan masih sama.
  if old.version=p_version+1 and old.status=p_status and old.check_in is not distinct from p_in and old.check_out is not distinct from p_out and old.notes=note and old.correction_reason=reason and old.updated_by=auth.uid() then return to_jsonb(old); end if;
  if old.version<>p_version then raise exception 'Absensi telah berubah. Muat ulang sebelum mengoreksi.'; end if;
 end if;
 if p_status='Hadir' and p_out is null and exists(select 1 from public.attendance where employee_id=p_employee and status='Hadir' and check_out is null and id is distinct from old.id) then
  raise exception 'Pegawai masih memiliki absen masuk terbuka pada tanggal lain.';
 end if;
 if old.id is null then
  insert into public.attendance(employee_id,business_date,status,check_in,check_out,notes,updated_by,updated_at,correction_reason)
   values(p_employee,p_date,p_status,p_in,p_out,note,auth.uid(),moment,reason) returning * into saved;
 else
  update public.attendance set status=p_status,check_in=p_in,check_out=p_out,notes=note,version=version+1,
   updated_by=auth.uid(),updated_at=moment,correction_reason=reason where id=old.id returning * into saved;
 end if;
 insert into public.audit_log(actor,action,entity_id,before_data,after_data)
  values(auth.uid(),'attendance.correct',saved.id,case when old.id is null then null else to_jsonb(old) end,to_jsonb(saved));
 return to_jsonb(saved);
end $$;

create or replace function public.attendance_report(p_start date,p_end date,p_employee uuid default null,p_page integer default 0) returns jsonb
language plpgsql security definer set search_path=public as $$
declare target uuid; result jsonb; employees jsonb; entries jsonb; records bigint;
begin
 perform public.require_staff();
 if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<p_start or p_end-p_start>365 or
  p_start<date '2020-01-01' or p_end>date '2100-12-31' or p_page is null or p_page not between 0 and 100000 then
  raise exception 'Pilih periode absensi maksimal 366 hari dan halaman yang valid.';
 end if;
 if public.app_role()='owner' then target := p_employee;
 else
  if p_employee is not null and p_employee<>auth.uid() then raise exception 'Anda hanya dapat melihat absensi sendiri.'; end if;
  target := auth.uid();
 end if;
 select count(*),jsonb_build_object('present',count(*) filter(where status='Hadir'),
  'permission',count(*) filter(where status='Izin'),'sick',count(*) filter(where status='Sakit'),
  'open',count(*) filter(where status='Hadir' and check_out is null),
  'minutes',coalesce(sum(floor(extract(epoch from (check_out-check_in))/60)) filter(where check_out is not null),0))
 into records,result from public.attendance where business_date between p_start and p_end and (target is null or employee_id=target);
 select coalesce(jsonb_agg(to_jsonb(w) order by name,employee_id),'[]'::jsonb) into employees from (
  select a.employee_id,p.name,count(*) filter(where a.status='Hadir') as present,count(*) filter(where a.status='Izin') as permission,
   count(*) filter(where a.status='Sakit') as sick,count(*) filter(where a.status='Hadir' and a.check_out is null) as open,
   coalesce(sum(floor(extract(epoch from (a.check_out-a.check_in))/60)) filter(where a.check_out is not null),0) as minutes
  from public.attendance a join public.profiles p on p.id=a.employee_id
  where a.business_date between p_start and p_end and (target is null or a.employee_id=target) group by a.employee_id,p.name
 ) w;
 select coalesce(jsonb_agg(to_jsonb(r) order by business_date desc,employee_name,id),'[]'::jsonb) into entries from (
  select a.*,p.name as employee_name from public.attendance a join public.profiles p on p.id=a.employee_id
  where a.business_date between p_start and p_end and (target is null or a.employee_id=target)
  order by business_date desc,employee_name,a.id limit 30 offset (p_page*30)
 ) r;
 return result||jsonb_build_object('count',records,'employees',employees,'rows',entries,'has_more',records>(p_page+1)*30);
end $$;

create or replace function public.attendance_history(p_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 perform public.require_owner();
 select coalesce(jsonb_agg(jsonb_build_object('action',l.action,'at',l.created_at,'actor_name',p.name,'before',l.before_data,'after',l.after_data) order by l.created_at,l.id),'[]'::jsonb)
 into result from public.audit_log l join public.profiles p on p.id=l.actor where l.entity_id=p_id and l.action like 'attendance.%';
 return result;
end $$;
revoke all on function public.attendance_today(),public.record_attendance(uuid,text,text),
 public.correct_attendance(uuid,date,integer,text,timestamptz,timestamptz,text,text),
 public.attendance_report(date,date,uuid,integer),public.attendance_history(uuid) from public,anon,authenticated;
grant execute on function public.attendance_today(),public.record_attendance(uuid,text,text),
 public.correct_attendance(uuid,date,integer,text,timestamptz,timestamptz,text,text),
 public.attendance_report(date,date,uuid,integer),public.attendance_history(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
