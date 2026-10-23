import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';

export async function runOperationalReportChecks({db,owner,admin,staff,pending,asUser,check,fails}) {
 await db.exec('reset role');
 const sql=await readFile(new URL('../supabase/012_admin_operational_report.sql',import.meta.url),'utf8');
 await db.exec(sql);await db.exec(sql);
 const a=randomUUID(),b=randomUUID(),c=randomUUID(),old=randomUUID(),next=randomUUID(),deleted=randomUUID();
 const lines=(statuses)=>JSON.stringify(statuses.map(status=>({id:randomUUID(),name:'Clean',quantity:1,price:100000,labor_fee:77777,worker_id:staff,status})));
 for(const [id,at,total,discount,statuses,due,removed] of [
  [a,'2024-04-16T17:00:00Z',100000,10000,['Masuk','Selesai'],'2024-04-18',false],
  [b,'2024-04-17T10:00:00Z',80000,0,['Selesai','Diambil'],'2024-04-17',false],
  [c,'2024-04-17T16:59:59Z',50000,0,['Diambil'],'2024-04-17',false],
  [old,'2024-04-16T16:59:59Z',90000,0,['Dikerjakan'],'2024-04-16',false],
  [next,'2024-04-17T17:00:00Z',70000,0,['Masuk'],'2024-04-19',false],
  [deleted,'2024-04-17T10:00:00Z',99999,0,['Masuk'],'2024-04-17',true],
 ]) await db.query(`insert into orders(id,customer_name,items,total,labor_total,discount,notes,created_by,created_at,due_date,deleted_at)
  values($1,'Customer operasional',$2,$3,77777,$4,'Catatan internal rahasia',$5,$6,$7,case when $8 then now() end)`,[id,lines(statuses),total,discount,owner,at,due,removed]);
 const addPay=async(id,amount,method,at,voided=false)=>{
  const key=randomUUID();
  await db.query(`insert into payments(id,order_id,amount,method,paid_at,created_by,voided_at)
   values($1,$2,$3,$4,$5,$6,case when $7 then now() end)`,[key,id,amount,method,at,admin,voided]);
  return key;
 };
 await addPay(a,30000,'Tunai','2024-04-16T17:00:00Z');
 await addPay(a,20000,'QRIS','2024-04-17T16:59:59Z');
 await addPay(a,10000,'Transfer','2024-04-17T17:00:00Z');
 await addPay(a,99000,'Tunai','2024-04-17T10:00:00Z',true);
 await addPay(b,80000,'Transfer','2024-04-18T03:00:00Z');
 await addPay(c,50000,'Tunai','2024-04-17T03:00:00Z');
 await addPay(old,20000,'Transfer','2024-04-17T05:00:00Z');
 await addPay(deleted,99999,'Tunai','2024-04-17T05:00:00Z');
 const global=(await db.query(`select coalesce(sum(greatest(o.total-coalesce(p.amount,0),0)),0)::text n from orders o
  left join (select order_id,sum(amount) amount from payments where voided_at is null group by order_id) p on p.order_id=o.id where o.deleted_at is null`)).rows[0].n;
 const start='2024-04-16T17:00:00Z',end='2024-04-17T17:00:00Z';
 const read=async(page=0,s=start,e=end)=>(await db.query('select operational_report($1,$2,$3) r',[s,e,page])).rows[0].r;
 await asUser(admin);
 let data=await read();
 check([data.count,data.gross,data.revenue,data.discount],[3,240000,230000,10000],'Admin report aggregates note value by inclusive WIB start and exclusive end');
 check([data.pending,data.ready,data.picked_up,data.overdue],[1,1,1,1],'Mixed progress counts unfinished notes; ready and picked up are not overdue');
 check([data.received,data.cash,data.qris,data.transfer,data.receipt_count],[120000,80000,20000,20000,4],'Receipts follow actual payment date and exclude voided payments and deleted orders');
 check(data.outstanding_period,40000,'Period-note receivables use all active payments including later settlements');
 check(`${data.outstanding_all}`,global,'Global receivables include all dates independently from selected note cohort');
 check(data.payments.some(p=>p.order_id===old),true,'Receipts contain payments from notes outside the selected period');
 check(data.payments.every(p=>p.order_id!==deleted),true,'Deleted notes never appear in receipt detail');
 check(Object.keys(data).sort(),['count','gross','revenue','discount','pending','ready','picked_up','overdue','due_today','outstanding_period','outstanding_all','received','cash','qris','transfer','receipt_count','payments'].sort(),'Operational report uses explicit public field allowlist');
 check(Object.keys(data.payments[0]).sort(),['id','order_id','amount','method','paid_at','order_number','customer_name','order_at','operator_name'].sort(),'Payment detail contains no internal notes wages expenses or profile permissions');
 check(JSON.stringify(data).includes('77777')||JSON.stringify(data).includes('rahasia'),false,'Private wage amounts and internal notes cannot leak into admin report');
 check((await db.query('select count(*)::int n from orders')).rows[0].n,0,'Admin still cannot read raw orders');
 check((await db.query('select count(*)::int n from services')).rows[0].n,0,'Admin still cannot read raw service wages');
 const catalog=(await db.query('select service_catalog() r')).rows[0].r;
 check(catalog.every(s=>!('labor_fee' in s)),true,'Admin service catalog remains price-only');
 await fails('select period_report($1,$2)',[start,end],/Akses ongkos/,'Admin cannot replace operational report with wage report');
 await fails('select wage_overview($1,$2)',[start,end],/ongkos/i,'Admin cannot read payroll overview');
 await fails("select expense_report('2024-04-17','2024-04-17',0)",[],/owner/i,'Admin cannot read Internal expenses');
 const service=catalog[0];
 await fails('select save_service($1,$2,$3,$4,$5,$6)',[service.id,service.name,service.category,1,1,true],/owner/i,'Admin cannot change customer service prices');
 await fails('select delete_order($1,$2)',[a,1],/owner/i,'Admin cannot delete orders');
 await fails('select void_payment($1,$2)',[data.payments[0].id,'Salah nominal'],/owner/i,'Admin cannot correct payments');
 await fails("select set_staff_role($1,'owner')",[staff],/owner/i,'Admin cannot promote staff or enter internal management');
 for(const [s,e,p] of [[null,end,0],[start,null,0],['infinity',end,0],[end,start,0],[start,end,-1],['2019-01-01',end,0],[start,'2101-01-02',0]])
  await fails('select operational_report($1,$2,$3)',[s,e,p],/Periode atau halaman/,'Invalid report ranges and page values rejected');
 await asUser(owner);
 check(await read(),data,'Owner may read the same redacted operational report');
 await asUser(staff);
 await fails('select operational_report($1,$2,0)',[start,end],/hanya untuk owner dan admin/,'Technician cannot call owner/admin operational endpoint');
 await asUser(pending);
 await fails('select operational_report($1,$2,0)',[start,end],/belum aktif/,'Pending cannot read operational report');
 await db.exec('reset role; set role anon');
 await fails('select operational_report($1,$2,0)',[start,end],/permission denied/,'Anonymous report denied');
 await db.exec('reset role');
 for(let i=0;i<31;i++) await addPay(a,1000,'Tunai','2024-04-17T06:00:00Z');
 await asUser(admin);
 data=await read();const page2=await read(1);
 check([data.receipt_count,data.received,data.payments.length,page2.payments.length],[35,151000,30,5],'Report totals cover receipts beyond first thirty');
 check(new Set([...data.payments,...page2.payments].map(p=>p.id)).size,35,'Stable receipt pagination has no duplicate or missing fixture rows');
 await db.exec('reset role');
 await db.query(`insert into orders(id,customer_name,items,total,labor_total,created_by,created_at)
  select gen_random_uuid(),'Busy report',$2,1,77777,$1,'2024-05-02T03:00:00Z' from generate_series(1,1001)`,[owner,lines(['Diambil'])]);
 await db.query(`insert into payments(id,order_id,amount,method,created_by,paid_at)
  select gen_random_uuid(),id,1,'QRIS',$1,'2024-05-02T03:00:00Z' from orders where customer_name='Busy report'`,[admin]);
 await asUser(admin);
 data=await read(0,'2024-05-01T17:00:00Z','2024-05-02T17:00:00Z');
 check([data.count,data.revenue,data.received,data.receipt_count,data.payments.length],[1001,1001,1001,1001,30],'Operational aggregates do not depend on the 1000-row API limit');
 data=await read(33,'2024-05-01T17:00:00Z','2024-05-02T17:00:00Z');
 check(data.payments.length,11,'Operational receipt history remains available after one thousand records');
 await asUser(owner);
}
