-- Jalankan setelah 010. Saran pelanggan dari nota aktif, tanpa menambah tabel pelanggan.
begin;
create or replace function public.customer_phone_key(p_phone text) returns text
language sql immutable set search_path=public as $$
 with digits as (select regexp_replace(coalesce(p_phone,''),'[^0-9]','','g') d),
 international as (select case when left(d,2)='00' then substr(d,3) else d end d from digits)
 select case when left(d,1)='0' then '62'||substr(d,2)
  when left(d,1)='8' then '62'||d else d end from international;
$$;

create or replace function public.customer_suggestions(p_query text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare term text; digits text; phone_term text; result jsonb;
begin
 perform public.require_staff();
 term := lower(trim(regexp_replace(coalesce(p_query,''),'[[:space:]]+',' ','g')));
 if length(term)>150 then raise exception 'Pencarian pelanggan maksimal 150 karakter.'; end if;
 if length(term)<2 then return '[]'::jsonb; end if;
 -- Nomor hanya dicari jika input berupa angka dan tanda pemisah nomor telepon.
 if term ~ '^[+0-9[:space:]().-]+$' then
  digits := regexp_replace(term,'[^0-9]','','g');
  if length(digits)>=2 then phone_term := nullif(public.customer_phone_key(term),''); end if;
 end if;
 with source as (
  select id,trim(regexp_replace(customer_name,'[[:space:]]+',' ','g')) as customer_name,
   trim(phone) as phone,created_at,public.customer_phone_key(phone) as phone_key,
   lower(trim(regexp_replace(customer_name,'[[:space:]]+',' ','g'))) as name_key
  from public.orders where deleted_at is null
 ), identities as (
  select *,case when phone_key='' then 'name:'||name_key else 'phone:'||phone_key end as identity from source
 ), grouped as (
  -- Cari seluruh variasi nama lama, tetapi tampilkan identitas terbaru.
  select identity,count(*) as visits,
   bool_or(strpos(name_key,term)>0 or (phone_term is not null and
    (strpos(phone_key,phone_term)>0 or strpos(phone_key,digits)>0))) as matched,
   bool_or(name_key=term or (phone_term is not null and phone_key=phone_term)) as exact
  from identities group by identity
 ), latest as (
  select distinct on(identity) identity,customer_name,phone,created_at
  from identities order by identity,created_at desc,id
 ), chosen as (
  select l.identity,l.customer_name,l.phone,l.created_at as last_visit,g.visits,g.exact
  from latest l join grouped g using(identity) where g.matched
  order by g.exact desc,l.created_at desc,l.identity limit 5
 ) select coalesce(jsonb_agg(to_jsonb(c)-'exact' order by exact desc,last_visit desc,identity),'[]'::jsonb)
 into result from chosen c;
 return result;
end $$;
revoke all on function public.customer_phone_key(text),public.customer_suggestions(text) from public,anon,authenticated;
grant execute on function public.customer_suggestions(text) to authenticated;
notify pgrst,'reload schema';
commit;
