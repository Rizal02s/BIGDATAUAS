import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';

export async function runCustomerSuggestionChecks({db,owner,admin,staff,pending,asUser,check,fails}) {
 await db.exec('reset role');
 const sql=await readFile(new URL('../supabase/011_customer_suggestions.sql',import.meta.url),'utf8');
 await db.exec(sql);await db.exec(sql);
 const put=async(name,phone,at,deleted=false)=>{
  const id=randomUUID();
  await db.query(`insert into orders(id,customer_name,phone,items,total,labor_total,created_by,created_at,deleted_at)
   values($1,$2,$3,'[]',1,777,$4,$5,case when $6 then now() end)`,[id,name,phone,owner,at,deleted]);
  return id;
 };
 await put('Zeta Riwayat','081234560001','2022-01-01T00:00:00Z');
 await put('Zeta Terbaru','+62 812-3456-0001','2022-02-01T17:00:00Z');
 await put('Zeta Terbaru','006281234560001','2022-01-03T00:00:00Z');
 await put('Zeta Terbaru','81234560001','2022-01-04T00:00:00Z');
 await put('Zeta Terbaru','081299990002','2022-03-01T00:00:00Z');
 await put('  Zeta Tanpa   Nomor ','','2022-04-01T00:00:00Z');
 await put('zeta tanpa nomor','  ','2022-04-02T00:00:00Z');
 await put('Zeta Dihapus','081234560099','2022-12-01T00:00:00Z',true);
 await put('Nama Dihapus','081234560001','2023-12-01T00:00:00Z',true);
 const search=async(q)=>(await db.query('select customer_suggestions($1) r',[q])).rows[0].r;
 await asUser(owner);
 let rows=await search('Zeta Riwayat');
 check(rows.length,1,'Old name alias finds same customer with latest identity');
 check([rows[0].identity,rows[0].customer_name,rows[0].phone,rows[0].visits,new Date(rows[0].last_visit).toISOString()],
  ['phone:6281234560001','Zeta Terbaru','+62 812-3456-0001',4,'2022-02-01T17:00:00.000Z'],'Phone formats merge visits while newest active note supplies name and phone');
 for(const term of ['081234560001','+6281234560001','006281234560001','81234560001','3456-0001']) {
  check((await search(term))[0].identity,'phone:6281234560001','Lookup normalizes equivalent or partial phone input');
 }
 rows=await search('zeta terbaru');
 check(rows.map(r=>r.identity),['phone:6281299990002','phone:6281234560001'],'Same name with different phones remains separate newest first');
 rows=await search('  ZETA   TANPA   NOMOR ');
 check([rows.length,rows[0].identity,rows[0].visits,rows[0].phone],[1,'name:zeta tanpa nomor',2,''],'No-phone customers match normalized names and whitespace');
 check(await search('Zeta Dihapus'),[],'Deleted-only customer excluded');
 check(await search('Nama Dihapus'),[],'Deleted alias cannot affect another customer search');
 check(await search(null),[],'Null query does not list all customers');
 check(await search('Z'),[],'Single letter query is ignored');
 check(await search('  '),[],'Empty query is ignored');
 check(await search('00'),[],'Bare international prefix cannot match every customer');
 check(await search('%_'),[],'SQL wildcard characters are treated literally');
 await fails('select customer_suggestions($1)',['a'.repeat(151)],/maksimal 150/,'Long query rejected');
 const before=(await db.query('select count(*)::int n from orders')).rows[0].n;
 await search('Zeta');
 check((await db.query('select count(*)::int n from orders')).rows[0].n,before,'Suggestion lookup never records an extra visit');
 await db.exec('reset role');
 for(let i=0;i<8;i++) await put('Omega Saran '+i,'081200777'+i,'2022-05-01T00:00:00Z');
 await put('Omega Saran','08120077799','2020-01-01T00:00:00Z');
 await asUser(admin);
 rows=await search('Omega Saran');
 check(rows.length,5,'At most five distinct customers returned');
 check(rows[0].customer_name,'Omega Saran','Exact name has priority even over newer partial matches');
 check(Object.keys(rows[0]).sort(),['customer_name','identity','last_visit','phone','visits'],'Admin only receives customer lookup fields without order totals wages or notes');
 check(await search('Zeta Riwayat'),await search('081234560001'),'Admin uses same canonical grouping as owner');
 await fails('select customer_phone_key($1)',['08123'],/permission denied/,'Normalization helper cannot be called by client');
 await asUser(staff);
 check((await search('Zeta Riwayat')).length,1,'Technician can select an existing operational customer');
 await asUser(pending);
 await fails('select customer_suggestions($1)',['Zeta'],/belum aktif/,'Pending users cannot read customer suggestions');
 await db.exec('reset role; set role anon');
 await fails('select customer_suggestions($1)',['Zeta'],/permission denied/,'Anonymous users cannot enumerate customers');
 await db.exec('reset role');
 // Busy customer history exceeds the usual API row cap; suggestions aggregate server-side.
 await db.query(`insert into orders(id,customer_name,phone,items,total,labor_total,created_by,created_at)
  select gen_random_uuid(),'Sigma Banyak','081211223344','[]',1,1,$1,'2021-06-01T00:00:00Z' from generate_series(1,1001)`,[owner]);
 await asUser(owner);
 check((await search('Sigma Banyak'))[0].visits,1001,'Customer visit count is not truncated at 1000 orders');
}
