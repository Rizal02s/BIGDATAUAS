import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';

export async function runExpenseChecks({db,owner,admin,staff,pending,asUser,check,fails}) {
 await asUser(owner);
 const cash=async(d='2020-02-03')=>(await db.query('select cash_day($1) r',[d])).rows[0].r;
 const before=await cash();
 const migration=await readFile(new URL('../supabase/010_business_expenses.sql',import.meta.url),'utf8');
 await db.exec('reset role');await db.exec(migration);await db.exec(migration);
 await asUser(owner);
 check((await cash()).fingerprint,before.fingerprint,'Empty expense migration preserves existing cash fingerprints');
 const save='select record_expense($1,$2,$3,$4,$5,$6,$7,$8) r';
 const id=randomUUID();
 const args=[id,'2020-02-03','  Beli cairan  ','Bahan & peralatan',25000,'Tunai',true,'  Nota pembelian  '];
 const report=async(s='2020-02-03',e=s,page=0)=>(await db.query('select expense_report($1,$2,$3) r',[s,e,page])).rows[0].r;
 const saved=(await db.query(save,args)).rows[0].r;
 check([saved.title,saved.notes,saved.created_by,saved.spent_on],['Beli cairan','Nota pembelian',owner,'2020-02-03'],'Expense stores trimmed business fields and actual operator');
 check((await db.query(save,args)).rows[0].r.id,id,'Lost response retries reuse same expense without duplication');
 let r=await report();
 check([r.total,r.count,r.history_count,r.drawer_cash,r.rows.length],[25000,1,1,25000,1],'Expense totals count only paid costs in inclusive date range');
 check([r.categories,r.rows[0].operator_name],[[{category:'Bahan & peralatan',total:25000}],'Owner'],'Expense report includes category totals and operator');
 const changed=await cash();
 check([changed.fingerprint!==before.fingerprint,changed.total,changed.cash],[true,before.total,before.cash],'Drawer expense changes fingerprint without changing customer receipts or cash out');
 await fails(save,[...args.slice(0,4),30000,...args.slice(5)],/ID pengeluaran/,'Reusing ID with changed amount rejected');
 for (const [index,value] of [[0,null],[1,null],[1,'infinity'],[1,'2100-12-31'],[2,'   '],[2,'a'.repeat(151)],[3,'Gaji'],[3,null],[4,0],[4,-1],[4,null],[4,1000000000001],[5,'Kartu'],[5,null],[6,null],[7,'a'.repeat(501)]]) {
  const invalid=[...args];invalid[0]=randomUUID();invalid[index]=value;
  await fails(save,invalid,/tidak valid/,'Invalid expense field is rejected');
 }
 await fails(save,[randomUUID(),...args.slice(1,5),'Transfer',true,''],/tidak valid/,'Noncash expense cannot claim money from drawer');
 const reportBeforeVoid=await report();
 for (const [method,drawer,day] of [['Transfer',false,'2020-02-03'],['QRIS',false,'2020-02-03'],['Tunai',false,'2020-02-03'],['Tunai',true,'2020-02-02'],['Tunai',true,'2020-02-04']]) {
  await db.query(save,[randomUUID(),day,'Biaya lain','Lainnya',1000,method,drawer,'']);
 }
 check((await cash()).fingerprint,changed.fingerprint,'Noncash personal cash and other-day expenses do not change selected drawer day');
 r=await report();check([r.total,r.drawer_cash,r.count],[28000,25000,4],'All methods count as expenses but only drawer cash affects cash total');
 check((await report('2020-02-02','2020-02-04')).total,30000,'Both endpoints of expense date range included');
 await fails('select expense_report(null,$1,0)',['2020-02-03'],/Periode/,'Null expense range rejected');
 await fails("select expense_report('2020-02-04','2020-02-03',0)",[],/Periode/,'Reversed expense dates rejected');
 await fails("select expense_report('2020-02-03','2020-02-03',-1)",[],/Periode/,'Negative expense page rejected');
 await fails('select void_expense($1,$2)',[id,'x'],/alasan koreksi/,'Expense correction requires meaningful reason');
 await db.query('select void_expense($1,$2)',[id,'Salah nominal pada nota']);
 await db.query('select void_expense($1,$2)',[id,'Percobaan ulang koreksi']);
 r=await report();
 check([r.total,r.count,r.history_count,r.rows.find(e=>e.id===id).void_reason],[3000,3,4,'Salah nominal pada nota'],'Correction excluded from totals but history and original reason retained');
 check((await cash()).fingerprint,before.fingerprint,'Voiding drawer expense updates cash reconciliation fingerprint');
 await fails(save,args,/ID pengeluaran/,'Retry cannot resurrect corrected expense');
 const audits=(await db.query("select action from audit_log where entity_id=$1 order by created_at,action",[id])).rows;
 check(audits.map(a=>a.action).sort(),['expense.create','expense.void'],'Expense save and correction each create exactly one audit row');
 await fails('insert into business_expenses(id) values($1)',[randomUUID()],/permission denied/,'Direct expense insert is denied even to owner');
 await fails('delete from business_expenses where id=$1',[id],/permission denied/,'Expense history cannot be hard-deleted by app');
 for(const role of [admin,staff,pending]) {
  await asUser(role);
  check((await db.query('select count(*)::int n from business_expenses')).rows[0].n,0,'Nonowners cannot read internal expenses through table');
  await fails('select expense_report($1,$2,0)',['2020-02-03','2020-02-03'],/owner/i,'Nonowner expense report denied');
  await fails(save,[randomUUID(),...args.slice(1)],/owner/i,'Nonowner expense writes denied');
  await fails('select void_expense($1,$2)',[id,'Salah input biaya'],/owner/i,'Nonowner expense corrections denied');
 }
 await asUser(admin);
 const safe=await cash();
 check(Object.keys(safe).sort(),Object.keys(before).sort(),'Admin cash JSON adds no internal expense fields');
 check(JSON.stringify(safe).includes('Beli cairan'),false,'Admin cash report contains no expense descriptions');
 await db.exec('reset role; set role anon');
 await fails('select expense_report($1,$2,0)',['2020-02-03','2020-02-03'],/permission denied/,'Anonymous expenses denied');
 await db.exec('reset role');
 await db.query(`insert into business_expenses(id,spent_on,title,category,amount,method,created_by)
  select gen_random_uuid(),'2020-03-01','Banyak biaya','Lainnya',10,'Transfer',$1 from generate_series(1,1001)`,[owner]);
 await asUser(owner);
 const large=await report('2020-03-01');
 check([large.total,large.count,large.history_count,large.rows.length],[10010,1001,1001,30],'Expense aggregation is not truncated by row pagination or 1000-row API cap');
 const last=await report('2020-03-01','2020-03-01',33);
 check(last.rows.length,11,'Expense page after 1000 rows still available');
}
