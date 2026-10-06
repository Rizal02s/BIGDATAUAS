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
await db.exec(await readFile(new URL('../supabase/003_roles_and_wage_privacy.sql', import.meta.url), 'utf8'));
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
// New role migration preserves existing data and can be reapplied safely.
await db.exec('reset role');
await db.exec(await readFile(new URL('../supabase/003_roles_and_wage_privacy.sql', import.meta.url), 'utf8'));
const admin = randomUUID(), technician = randomUUID();
for (const [id,name] of [[admin,'Admin'],[technician,'Teknisi']]) {
 await db.query('insert into auth.users values($1,$2)',[id,JSON.stringify({name,role:'owner'})]);
}
await asUser(owner);
await db.query("select set_staff_role($1,'admin')",[admin]);
await db.query("select set_staff_role($1,'technician')",[technician]);
check((await db.query('select role from profiles where id=$1',[admin])).rows[0].role,'admin','Owner activates admin');
await asUser(admin);
check((await db.query('select count(*)::int n from services')).rows[0].n,0,'Admin cannot query raw service labor rates');
check((await db.query('select count(*)::int n from orders')).rows[0].n,0,'Admin cannot query raw order wage snapshots');
check((await db.query('select count(*)::int n from audit_log')).rows[0].n,0,'Admin cannot read audit wage snapshots');
await fails("select period_report(now()-interval '1 day',now()+interval '1 day')",[],/Akses ongkos/,'Admin cannot call wage report');
await fails('select order_payload($1)',[photoOrder],/permission denied/i,'Private helper cannot bypass redaction');
const safeServices=(await db.query('select service_catalog() data')).rows[0].data;
check(safeServices.every(s=>!('labor_fee' in s)),true,'Service catalog removes labor rates for admin');
check(safeServices.find(s=>s.id===deep.id).orderable,true,'Admin can still select services with a valid wage rate');
const safeOrder=(await db.query('select order_detail($1) data',[photoOrder])).rows[0].data;
check('labor_total' in safeOrder,false,'Admin order detail hides total wages');
check(safeOrder.items.every(item=>!('labor_fee' in item)),true,'Admin order detail hides embedded item wage rates');
check(safeOrder.order_photos.length,1,'Admin can view operational order photos');
const safeList=(await db.query("select order_list(now()-interval '1 day',now()+interval '1 day',0,null) data")).rows[0].data;
check(safeList.every(o=>!('labor_total' in o) && o.items.every(i=>!('labor_fee' in i))),true,'Admin order list has no wages');
const counts=(await db.query("select order_day_counts('2026-10-01T17:00:00Z','2026-10-02T17:00:00Z',null) data")).rows[0].data;
check(Number(counts['2']),1002,'Admin daily counts include all orders and honor WIB bounds');
const adminOrder = randomUUID(), adminItem = {id:randomUUID(),service_id:deep.id,quantity:1,worker_id:technician,status:'Masuk'};
await db.query(save,[adminOrder,0,'Order admin','','',0,JSON.stringify([adminItem])]);
await db.query('select add_payment($1,$2,$3,$4)',[randomUUID(),adminOrder,45000,'QRIS']);
check((await db.query('select order_detail($1) data',[adminOrder])).rows[0].data.payments.length,1,'Admin creates and settles order without knowing wage rates');
const adminPath=`${adminOrder}/${admin}/${randomUUID()}.png`;
await db.query("insert into storage.objects(bucket_id,name) values('order-photos',$1)",[adminPath]);
await db.query('insert into order_photos(order_id,path,created_by) values($1,$2,$3)',[adminOrder,adminPath,admin]);
check((await db.query('select order_detail($1) data',[adminOrder])).rows[0].data.order_photos.length,1,'Admin can upload and link photos despite raw order RLS');
await fails(save,[randomUUID(),0,'Wrong worker','','',0,JSON.stringify([{...adminItem,worker_id:admin}])],/pegawai aktif/,'Admin cannot be assigned technician wages');
await fails("select set_staff_role($1,'owner')",[admin],/Hanya owner/,'Admin cannot escalate privileges');
await asUser(technician);
const techOrder=(await db.query('select * from orders where id=$1',[adminOrder])).rows[0];
check(Number(techOrder.labor_total),15000,'Server still computes correct technician wages for an admin-created order');
check('labor_fee' in (await db.query('select order_detail($1) data',[adminOrder])).rows[0].data.items[0],true,'Technician can see order wages');
const techReport=(await db.query("select period_report(now()-interval '1 day',now()+interval '1 day') data")).rows[0].data;
check(techReport.wages.some(w=>w.id===technician && Number(w.amount)===15000),true,'Technician can read full team wage report');
await fails("select set_staff_role($1,'owner')",[technician],/Hanya owner/,'Technician cannot grant owner access');
await fails('select save_service($1,$2,$3,$4,$5,$6)',[deep.id,deep.name,deep.category,1,1,true],/Hanya owner/,'Technician cannot change prices');
await fails('select delete_order($1,$2,$3)',[adminOrder,2,'Salah input'],/Hanya owner/,'Technician cannot delete orders');
await asUser(pending);
await fails('select order_detail($1)',[adminOrder],/belum aktif/,'Pending cannot use redacted operational APIs');
await asUser(owner);
check((await db.query('select role from profiles where id=$1',[staff])).rows[0].role,'staff','Migration keeps existing staff accounts active');
await db.query("select set_staff_role($1,'staff')",[staff]);
check((await db.query('select role from profiles where id=$1',[staff])).rows[0].role,'technician','Legacy activation requests map to technician');
// Date migration on a populated project; older APK RPCs remain usable.
await db.exec('reset role');
const dateMigration = await readFile(new URL('../supabase/004_manual_order_dates.sql', import.meta.url), 'utf8');
await db.exec(dateMigration);
const originalRecorded = (await db.query('select created_at=recorded_at same from orders where id=$1', [adminOrder])).rows[0];
check(originalRecorded.same, true, 'Existing order recording timestamp is preserved during migration');
check((await db.query('select bool_and(paid_at=recorded_at) same from payments')).rows[0].same, true, 'Existing payment timestamps are preserved');
await asUser(owner);
const day3 = ['2026-10-02T17:00:00Z','2026-10-03T17:00:00Z'];
const datedReport = async () => (await db.query('select period_report($1,$2) data',day3)).rows[0].data;
const baseDay = await datedReport();
await asUser(admin);
const datedId = randomUUID(), dateItem = {...adminItem, id:randomUUID()};
const datedSave = 'select save_order_with_date($1,$2,$3,$4,$5,$6,$7,$8)';
const dateArgs = (version, date) => [datedId,version,'Customer 3 Oktober','','',0,JSON.stringify([dateItem]),date];
const selectedAt = '2026-10-03T03:15:00.000Z';
await db.query(datedSave,dateArgs(0,selectedAt));
let dated = (await db.query('select order_detail($1) data',[datedId])).rows[0].data;
check(new Date(dated.created_at).toISOString(), selectedAt, 'Admin can create an order for 3 October 10:15 WIB');
check('labor_total' in dated || 'labor_fee' in dated.items[0], false, 'Dated RPC still hides wages from admin');
await asUser(owner);
dated = (await db.query('select * from orders where id=$1',[datedId])).rows[0];
const recordedAt = new Date(dated.recorded_at).toISOString();
check(dated.recorded_at > dated.created_at, true, 'Backdated order retains the actual recording time');
let dayReport = await datedReport();
check([Number(dayReport.revenue)-Number(baseDay.revenue),Number(dayReport.labor)-Number(baseDay.labor)], [45000,15000], 'Backdated revenue and wages belong to the selected day');
check(dayReport.wages.some(w => w.id===technician && Number(w.amount)===15000),true,'Backdated wages belong to the assigned technician');
await asUser(admin);
const datedCounts = (await db.query("select order_day_counts('2026-09-30T17:00:00Z','2026-10-31T17:00:00Z',null) data")).rows[0].data;
check(Number(datedCounts['3']),Number(baseDay.count)+1,'Monthly date list includes the backfilled order on day 3');
const datedPayId = randomUUID();
const datedPay = 'select add_payment_with_date($1,$2,$3,$4,$5)';
await db.query(datedPay,[datedPayId,datedId,15000,'Tunai',selectedAt]);
await db.query(datedPay,[datedPayId,datedId,15000,'Tunai','2026-10-06T03:15:00Z']);
await asUser(owner);
let paymentRow = (await db.query('select * from payments where id=$1',[datedPayId])).rows[0];
check(new Date(paymentRow.paid_at).toISOString(),selectedAt,'Payment retry keeps the first selected timestamp');
check(paymentRow.recorded_at > paymentRow.paid_at,true,'Initial payment retains its actual recording time');
check((await db.query('select count(*)::int n from payments where id=$1',[datedPayId])).rows[0].n,1,'Dated payment retry does not duplicate receipts');
check(Number((await datedReport()).cash)-Number(baseDay.cash),15000,'Initial payment appears in cash report on the order date');
await db.query('select add_payment($1,$2,$3,$4)',[randomUUID(),datedId,10000,'QRIS']);
check(Number((await datedReport()).cash)-Number(baseDay.cash),15000,'Later payments use actual payment day, not the old order date');
await fails(datedPay,[randomUUID(),datedId,999999,'Tunai',selectedAt],/melebihi/,'Backdated payment cannot exceed the balance');
await fails(datedPay,[randomUUID(),datedId,1,'Tunai','infinity'],/Tanggal pembayaran/,'Non-finite payment date is rejected');
await db.query(datedSave,dateArgs(3,'2026-09-29T17:00:00Z'));
dated = (await db.query('select * from orders where id=$1',[datedId])).rows[0];
check(new Date(dated.recorded_at).toISOString(),recordedAt,'Editing the business date retains actual recording time');
dayReport = await datedReport();
check([Number(dayReport.revenue)-Number(baseDay.revenue),Number(dayReport.labor)-Number(baseDay.labor),Number(dayReport.cash)-Number(baseDay.cash)], [0,0,15000], 'Moving an order date moves wages/revenue while preserving payments');
await db.query(save,[datedId,4,'Customer edit APK lama','','',0,JSON.stringify([dateItem])]);
dated = (await db.query('select * from orders where id=$1',[datedId])).rows[0];
check(new Date(dated.created_at).toISOString(),'2026-09-29T17:00:00.000Z','Old APK editing RPC preserves a selected order date');
check([Number(dated.total),Number(dated.labor_total)],[45000,15000],'Date edits retain service price and wage snapshots');
await fails(datedSave,dateArgs(4,selectedAt),/Order telah berubah/,'Date edits enforce optimistic conflict checks');
for (const invalidDate of ['2019-12-31T00:00:00Z','2101-01-01T00:00:00Z','infinity']) {
 await fails(datedSave,[randomUUID(),0,'Invalid date','','',0,JSON.stringify([dateItem]),invalidDate],/Tanggal order/,'Out-of-range date is rejected');
}
await asUser(pending);
await fails(datedSave,[randomUUID(),0,'Pending','','',0,JSON.stringify([dateItem]),selectedAt],/belum aktif/,'Pending cannot use the dated order API');
await fails(datedPay,[randomUUID(),datedId,1,'Tunai',selectedAt],/belum aktif/,'Pending cannot use the dated payment API');
await db.exec('reset role; set role anon');
await fails(datedSave,dateArgs(5,selectedAt),/permission denied/,'Anonymous users cannot call dated order API');
await db.exec('reset role');
await db.exec(dateMigration);
dated = (await db.query('select * from orders where id=$1',[datedId])).rows[0];
check([new Date(dated.recorded_at).toISOString(),new Date(dated.created_at).toISOString()],[recordedAt,'2026-09-29T17:00:00.000Z'],'Rerunning date migration preserves selected and actual dates');
console.log(`PASS: ${checks} pemeriksaan PostgreSQL + RLS/RPC`);
await db.close();
