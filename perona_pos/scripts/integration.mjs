// PostgreSQL lokal WASM. Auth/Storage schema stub; bukan emulator Supabase lengkap.
import { PGlite } from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
const db = new PGlite();
let checks = 0;
const check = (value, expected, label) => { assert.deepEqual(value, expected, label); checks++; };
async function fails(sql, params, pattern, label) {
  try { await db.query(sql, params); assert.fail(label); }
  catch (e) { assert.match(e.message, pattern, label); checks++; }
}
await db.exec(`
 create role anon; create role authenticated;
 create schema auth; create schema storage;
 create table auth.users(id uuid primary key,raw_user_meta_data jsonb);
 create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('app.user_id',true),'')::uuid $$;
 grant usage on schema public,auth,storage to authenticated,anon;
 grant execute on function auth.uid() to authenticated;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
 alter table storage.objects enable row level security;
 grant select,insert,delete on storage.objects to authenticated;
`);
await db.exec(await readFile(new URL('../supabase/001_schema.sql', import.meta.url), 'utf8'));
await db.exec(await readFile(new URL('../supabase/002_seed.sql', import.meta.url), 'utf8'));
const owner = randomUUID(), staff = randomUUID(), pending = randomUUID(), orderId = randomUUID();
for (const [id, name] of [[owner,'Owner'],[staff,'Pegawai'],[pending,'Pending']]) {
 await db.query('insert into auth.users values($1,$2)', [id, JSON.stringify({name,role:'owner'})]);
}
check((await db.query('select role from profiles where id=$1',[pending])).rows[0].role, 'pending', 'Metadata signup tidak bisa menaikkan role');
await db.query("update profiles set role='owner' where id=$1",[owner]);
await db.query("update profiles set role='staff' where id=$1",[staff]);
const catalog = (await db.query('select * from services order by name')).rows;
check(catalog.length, 32, '32 layanan');
const deep = catalog.find(s=>s.name==='Deep Clean'), ods = catalog.find(s=>s.name==='One Day Service');
async function asUser(id) { await db.exec('reset role'); await db.query("select set_config('app.user_id',$1,false)",[id]); await db.exec('set role authenticated'); }
await asUser(staff);
const items=[{id:randomUUID(),service_id:deep.id,quantity:2,worker_id:staff,status:'Masuk',price:1,labor_fee:1},
{id:randomUUID(),service_id:ods.id,quantity:1,worker_id:owner,status:'Masuk',price:1,labor_fee:1}];
const save='select save_order($1,$2,$3,$4,$5,$6,$7)';
const saveArgs=(version, lines=items, discount=0)=>[orderId,version,'Pelanggan','081234','Kondisi awal',discount,JSON.stringify(lines)];
await db.query(save,saveArgs(0));
let order=(await db.query('select * from orders where id=$1',[orderId])).rows[0];
check([Number(order.total),Number(order.labor_total)], [110000,40000], 'Tarif palsu dari klien diabaikan');
await fails("update services set price=1 where id=$1",[deep.id],/permission denied/i,'Staff tidak bisa tulis tarif');
await fails("select set_staff_role($1,'owner')",[staff],/Hanya owner/,'Staff tidak dapat menaikkan role');
await fails(save,saveArgs(0),/Order telah berubah/,'Retry create tidak menggandakan order');
await fails(save,saveArgs(null),/versi order wajib/,'Versi null tidak dapat melewati konflik');
await fails(save,saveArgs(1,items,110001),/Diskon tidak valid/,'Diskon berlebih ditolak');
await fails(save,saveArgs(1,[...items,{...items[0]}]),/duplikat/,'ID item duplikat ditolak');
const pay = randomUUID();
await db.query('select add_payment($1,$2,$3,$4)',[pay,orderId,50000,'Tunai']);
await db.query('select add_payment($1,$2,$3,$4)',[pay,orderId,50000,'Tunai']);
check((await db.query('select count(*)::int n from payments')).rows[0].n,1,'Retry pembayaran idempotent');
await fails('select add_payment($1,$2,$3,$4)',[randomUUID(),orderId,60001,'Tunai'],/melebihi/,'Pembayaran berlebih ditolak');
await fails(save,saveArgs(1),/Order telah berubah/,'Versi lama ditolak setelah pembayaran');
await asUser(owner);
await db.query('select save_service($1,$2,$3,$4,$5,$6)',[deep.id,deep.name,deep.category,45000,15000,true]);
await db.query(save,saveArgs(2));
order=(await db.query('select * from orders where id=$1',[orderId])).rows[0];
check([Number(order.total),Number(order.labor_total)],[110000,40000],'Tarif lama tidak berubah saat edit status/order');
const newLines=[...items,{id:randomUUID(),service_id:deep.id,quantity:1,worker_id:staff,status:'Masuk'}];
await db.query(save,saveArgs(3,newLines,10000));
order=(await db.query('select * from orders where id=$1',[orderId])).rows[0];
check([Number(order.total),Number(order.labor_total)],[145000,55000],'Item baru memakai tarif baru; diskon tidak mengubah upah');
const report=(await db.query("select period_report(now()-interval '1 day',now()+interval '1 day') report")).rows[0].report;
check([Number(report.revenue),Number(report.labor),Number(report.cash),Number(report.outstanding_all)],[145000,55000,50000,95000],'Omzet, upah, kas dan piutang terpisah');
check(report.wages.map(w=>[w.name,Number(w.amount)]).sort(),[['Owner',20000],['Pegawai',35000]],'Upah per penanggung jawab saat order masuk');
await fails('select delete_order($1,$2,$3)',[orderId,null,'Salah input'],/versi order wajib/,'Hapus dengan versi null ditolak');
await fails('select delete_order($1,$2,$3)',[orderId,4,'Salah input'],/Masih ada pembayaran/,'Order berbayar tidak dihapus tanpa koreksi');
await db.query('select void_payment($1,$2)',[pay,'Salah nominal input']);
await db.query('select delete_order($1,$2,$3)',[orderId,5,'Order duplikat']);
const after=(await db.query("select period_report(now()-interval '1 day',now()+interval '1 day') report")).rows[0].report;
check([Number(after.count),Number(after.revenue),Number(after.labor),Number(after.cash)],[0,0,0,0],'Order terkoreksi keluar rekap tanpa hard delete');
check((await db.query('select count(*)::int n from audit_log')).rows[0].n>=7,true,'Jejak audit tetap ada');
await asUser(pending);
check((await db.query('select count(*)::int n from services')).rows[0].n,0,'Pending tidak membaca master');
check((await db.query('select count(*)::int n from orders')).rows[0].n,0,'Pending tidak membaca pelanggan');
await fails("select period_report(now()-interval '1 day',now())",[],/belum aktif/,'Pending tidak bisa rekap');
await asUser(staff);
check((await db.query('select count(*)::int n from audit_log')).rows[0].n,0,'Audit hanya owner');
// Period aggregation with >1,000 rows and WIB boundary, using a privileged fixture.
await db.exec('reset role');
await db.query(`insert into orders(id,customer_name,items,total,labor_total,created_by,created_at)
 select gen_random_uuid(),'Fixture','[]',10,0,$1,'2026-10-02T00:00:00Z' from generate_series(1,1001)`,[owner]);
await db.query(`insert into orders(id,customer_name,items,total,labor_total,created_by,created_at)
 values(gen_random_uuid(),'Before WIB','[]',10,0,$1,'2026-10-01T16:59:59Z'),
 (gen_random_uuid(),'Start WIB','[]',10,0,$1,'2026-10-01T17:00:00Z'),
 (gen_random_uuid(),'End WIB','[]',10,0,$1,'2026-10-02T17:00:00Z')`,[owner]);
await asUser(owner);
const big=(await db.query("select period_report('2026-10-01T17:00:00Z','2026-10-02T17:00:00Z') report")).rows[0].report;
check([Number(big.count),Number(big.revenue)],[1002,10020],'Rekap >1000 baris dan batas WIB');
// Storage policies: active users can upload for a valid order, pending cannot read.
const photoOrder=randomUUID();
await db.query(save,[photoOrder,0,'Foto','','',0,JSON.stringify(items)]);
const ownPath=`${photoOrder}/${owner}/${randomUUID()}.jpg`;
await db.query("insert into storage.objects(bucket_id,name) values('order-photos',$1)",[ownPath]);
await db.query('insert into order_photos(order_id,path,created_by) values($1,$2,$3)',[photoOrder,ownPath,owner]);
await fails('insert into order_photos(order_id,path,created_by) values($1,$2,$3)',[photoOrder,`${photoOrder}/${owner}/missing.jpg`,owner],/row-level security/,'Foto metadata tanpa objek ditolak');
await db.query('delete from storage.objects where name=$1',[ownPath]);
check((await db.query('select count(*)::int n from storage.objects where name=$1',[ownPath])).rows[0].n,1,'Foto terhubung tidak terhapus lewat cleanup');
await asUser(staff);
await fails("insert into storage.objects(bucket_id,name) values('order-photos',$1)",[`${photoOrder}/${owner}/other.jpg`],/row-level security/,'Tidak bisa upload sebagai pegawai lain');
await asUser(pending);
check((await db.query('select count(*)::int n from storage.objects')).rows[0].n,0,'Pending tidak membaca foto');
console.log(`PASS: ${checks} pemeriksaan PostgreSQL + RLS/RPC`);
await db.close();
