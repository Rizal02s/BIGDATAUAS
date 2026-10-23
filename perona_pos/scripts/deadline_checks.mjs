import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';

export async function runDeadlineChecks({db,owner,admin,staff,pending,asUser,check,fails}) {
 const migration=await readFile(new URL('../supabase/009_order_deadlines.sql',import.meta.url),'utf8');
 await db.exec('reset role'); await db.exec(migration); await db.exec(migration);
 const service=(await db.query('select * from services where active and labor_fee is not null limit 1')).rows[0];
 const id=randomUUID(),item=randomUUID();
 const items=JSON.stringify([{id:item,service_id:service.id,quantity:2,worker_id:staff,status:'Masuk'}]);
 const save='select save_order_with_estimate($1,$2,$3,$4,$5,$6,$7,$8,$9)';
 let args=[id,0,'Pelanggan estimasi','08123','Catatan',0,items,'2021-01-01T17:00:00Z','2021-01-02'];
 await asUser(admin);
 await db.query(save,args);
 let detail=(await db.query('select order_detail($1) r',[id])).rows[0].r;
 check([detail.due_date,detail.version],['2021-01-02',1],'Estimate may equal order WIB day');
 check('labor_total' in detail || detail.items.some(i=>'labor_fee' in i),false,'Admin estimate payload hides wages');
 await fails(save,args,/Order telah berubah/,'Estimate save retry cannot create duplicate order');
 args[1]=1;args[8]='2021-01-01';
 await fails(save,args,/Estimasi selesai/,'Estimate cannot precede WIB order date even when UTC day matches');
 args[8]='infinity';await fails(save,args,/Estimasi selesai/,'Infinite deadline is rejected');
 args[8]='2101-01-01';await fails(save,args,/Estimasi selesai/,'Deadline outside supported range is rejected');
 args[8]='2021-01-04';await db.query(save,args);
 detail=(await db.query('select order_detail($1) r',[id])).rows[0].r;
 check([detail.due_date,detail.version,detail.total],['2021-01-04',2,Number(service.price)*2],'Editing estimate increments version and preserves prices');
 await asUser(owner);
 const audit=(await db.query("select before_data,after_data from audit_log where entity_id=$1 and action='order.edit' order by created_at desc limit 1",[id])).rows[0];
 check([audit.before_data.due_date,audit.after_data.due_date],['2021-01-02','2021-01-04'],'Audit records previous and next deadline');
 await db.query('select save_order_with_date($1,$2,$3,$4,$5,$6,$7,$8)',[id,2,'Nama lama','','',0,items,'2021-01-01T17:00:00Z']);
 detail=(await db.query('select order_detail($1) r',[id])).rows[0].r;
 check(detail.due_date,'2021-01-04','Legacy clients preserve existing estimate');
 await asUser(staff);
 await db.query('select update_order_statuses($1,$2,$3)',[id,detail.version,JSON.stringify([{id:item,status:'Dikerjakan'}])]);
 detail=(await db.query('select order_detail($1) r',[id])).rows[0].r;
 check(detail.due_date,'2021-01-04','Quick work status preserves deadline');
 args[1]=detail.version;args[8]=null;
 await db.query(save,args);
 check((await db.query('select order_detail($1) r',[id])).rows[0].r.due_date,null,'Technician can clear optional estimate');

 // Isolated worker queue tests include old orders, mixed statuses, deleted and 31+ notes.
 await db.exec('reset role');
 const worker=randomUUID(),other=randomUUID();
 await db.query('insert into auth.users values($1,$2),($3,$4)',[worker,JSON.stringify({name:'Queue worker'}),other,JSON.stringify({name:'Other queue worker'})]);
 await db.query("update profiles set role='technician' where id=any($1::uuid[])",[[worker,other]]);
 const today=(await db.query("select to_char(now() at time zone 'Asia/Jakarta','YYYY-MM-DD') d")).rows[0].d;
 const make=async(due,status='Masuk',deleted=false,assigned=worker)=>{
  const key=randomUUID();
  await db.query(`insert into orders(id,customer_name,items,total,labor_total,created_by,created_at,due_date,deleted_at)
   values($1,'Queue customer',$2,1,1,$3,'2020-01-01T00:00:00Z',$4,case when $5 then now() end)`,
   [key,JSON.stringify([{id:randomUUID(),worker_id:assigned,quantity:1,price:1,labor_fee:1,status}]),owner,due,deleted]);
  return key;
 };
 const old=await make('2020-01-02'),dueToday=await make(today),future=await make('2100-12-31'),unset=await make(null);
 await make('2020-01-02','Selesai');await make('2020-01-02','Diambil');await make('2020-01-02','Masuk',true);
 const mixed=await make('2020-01-02','Masuk',false,other);
 await db.query("update orders set items=items||$2::jsonb where id=$1",[mixed,JSON.stringify([{worker_id:worker,status:'Selesai'}])]);
 await asUser(admin);
 const queue=async(filter='all',page=0,w=worker)=>(await db.query('select work_queue($1,$2,$3) r',[filter,page,w])).rows[0].r;
 check((await queue()).map(o=>o.id),[old,dueToday,future,unset],'Queue spans all order dates and sorts deadlines with unset last');
 check((await queue('overdue')).map(o=>o.id),[old],'Late queue excludes ready picked-up deleted and completed personal services');
 check((await queue('today')).map(o=>o.id),[dueToday],'Due-today queue uses server WIB date');
 check((await queue('upcoming')).map(o=>o.id),[future],'Upcoming queue excludes today');
 check((await queue('unscheduled')).map(o=>o.id),[unset],'No estimate is distinct from overdue');
 check((await queue('all',0,other)).map(o=>o.id),[mixed],'Another worker sees own unfinished part of mixed order');
 check((await queue()).every(o=>!('labor_total' in o)&&o.items.every(i=>!('labor_fee' in i))),true,'Admin queue never exposes wage snapshots');
 await fails('select work_queue(null,0,null)',[],/Filter atau halaman/,'Null queue filter rejected');
 await fails('select work_queue($1,-1,null)',['all'],/Filter atau halaman/,'Negative queue page rejected');
 await fails('select work_queue($1,0,null)',['unknown'],/Filter atau halaman/,'Unknown queue filter rejected');
 await db.exec('reset role');
 for(let i=0;i<31;i++) await make('2020-01-03');
 await asUser(staff);
 const first=await queue(),second=await queue('all',1);
 check([first.length,second.length,new Set([...first,...second].map(o=>o.id)).size],[30,5,35],'Queue pagination includes all notes without duplicate first-page rows');
 await asUser(owner);
 detail=(await db.query('select order_detail($1) r',[id])).rows[0].r;
 args[1]=detail.version-1;args[8]='2021-01-05';
 await fails(save,args,/Order telah berubah/,'Stale estimate edit is rejected');
 await asUser(pending);
 await fails('select work_queue()',[],/belum aktif/,'Inactive user cannot read work queue');
 args[1]=detail.version;
 await fails(save,args,/belum aktif/,'Inactive user cannot write estimates');
 await db.exec('reset role; set role anon');
 await fails('select work_queue()',[],/permission denied/,'Anonymous queue is denied');
 await fails(save,args,/permission denied/,'Anonymous estimate save is denied');
 await asUser(owner);
}
