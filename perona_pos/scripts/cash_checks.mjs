import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';

export async function runCashChecks({db,owner,admin,staff,pending,asUser,check,fails}) {
 const migration=await readFile(new URL('../supabase/007_daily_cash.sql',import.meta.url),'utf8');
 await db.exec('reset role');
 await db.exec(migration);
 await db.exec(migration);
 const oldOrder=randomUUID(), removedOrder=randomUUID(), day='2020-01-15';
 await db.query(`insert into orders(id,customer_name,items,total,labor_total,created_by,created_at,deleted_at)
  values($1,'Customer nota lama','[]',500000,12345,$3,'2020-01-01T03:00:00Z',null),
  ($2,'Nota dihapus','[]',500000,12345,$3,'2020-01-01T03:00:00Z',now())`,[oldOrder,removedOrder,owner]);
 for(const [amount,method,at,voided,order] of [
  [30000,'Tunai','2020-01-14T17:00:00Z',false,oldOrder],
  [50000,'QRIS','2020-01-15T16:59:59.999Z',false,oldOrder],
  [20000,'Transfer','2020-01-15T05:00:00Z',false,oldOrder],
  [777000,'Tunai','2020-01-15T05:00:00Z',true,oldOrder],
  [800000,'Tunai','2020-01-14T16:59:59.999Z',false,oldOrder],
  [900000,'Tunai','2020-01-15T17:00:00Z',false,oldOrder],
  [555000,'Tunai','2020-01-15T05:00:00Z',false,removedOrder],
 ]) await db.query(`insert into payments(id,order_id,amount,method,created_by,paid_at,voided_at)
  values($1,$2,$3,$4,$5,$6,case when $7 then now() else null end)`,[randomUUID(),order,amount,method,owner,at,voided]);
 const read=async()=> (await db.query('select cash_day($1) result',[day])).rows[0].result;
 await asUser(admin);
 let report=await read();
 check([report.cash,report.qris,report.transfer,report.total,report.count],[30000,50000,20000,100000,3],'Cash ledger uses receipt dates, includes old notes and all methods, excludes void/deleted and exact day end');
 check(report.payments.every(p=>p.order_id===oldOrder && p.customer_name==='Customer nota lama'),true,'Cash rows retain customer and original receipt link');
 check(JSON.stringify(report).includes('labor'),false,'Cash report never exposes wage snapshots to admin');
 check((await read()).fingerprint,report.fingerprint,'Unchanged receipts have a stable fingerprint');
 await fails('select cash_day_snapshot($1)',[day],/permission denied/,'Cash snapshot helper is private');
 await fails('select cash_day(null)',[],/tanggal kas/,'Cash report rejects null dates');
 await fails("select cash_day('2100-01-01')",[],/tanggal kas/,'Future cash dates are rejected');
 const save='select save_cash_closing($1,$2,$3,$4,$5,$6,$7,$8) result';
 const first=randomUUID();
 let args=[first,day,null,report.fingerprint,100000,10000,119000,'Selisih seribu rupiah'];
 await fails(save,[...args.slice(0,7),''],/catatan minimal 5/,'Cash discrepancies require an explanation');
 await fails(save,[randomUUID(),day,null,report.fingerprint,0,30001,0,'Uji keluar'],/melebihi saldo/,'Cash out cannot exceed available drawer cash');
 await fails(save,[randomUUID(),day,null,report.fingerprint,-1,0,0,'Uji saldo'],/Nominal/,'Negative cash inputs are rejected by server');
 await fails(save,[randomUUID(),day,null,report.fingerprint,null,0,0,'Uji null'],/Nominal/,'Null cash inputs cannot bypass validation');
 await fails(save,[randomUUID(),day,null,report.fingerprint,1000000000001,0,0,'Uji besar'],/Nominal/,'Excessively large cash amounts are rejected');
 let saved=(await db.query(save,args)).rows[0].result;
 check([Number(saved.expected_cash),Number(saved.counted_cash),Number(saved.difference)],[120000,119000,-1000],'Expected drawer balance excludes QRIS and transfer and includes opening and outflow');
 check(saved.created_by,admin,'First daily close may be recorded by admin');
 check((await db.query(save,args)).rows[0].result.id,first,'Retry uses the same closing without inserting again');
 await fails(save,[...args.slice(0,6),120000,'Diubah'],/ID tutup kas sudah/,'A retry ID cannot be reused with different contents');
 await fails('delete from cash_closings where id=$1',[first],/permission denied/,'Clients cannot remove closing history');
 await fails(save,[randomUUID(),day,first,report.fingerprint,100000,10000,120000,'Koreksi admin'],/Hanya owner/,'Only owner may revise an existing cash close');
 await asUser(owner);
 await fails(save,[randomUUID(),day,null,report.fingerprint,100000,10000,120000,'Tutup dari HP lama'],/perangkat lain/,'Stale previous-closing ID cannot overwrite a newer close');
 const second=randomUUID();
 await db.query(save,[second,day,first,report.fingerprint,100000,10000,120000,'Koreksi hitung ulang']);
 report=await read();
 check([report.closing.id,report.closing.previous_id,report.closing.operator_name],[second,first,'Owner'],'Owner revision preserves previous close and operator');
 await db.exec('reset role');
 check((await db.query("select count(*)::int n from audit_log where action='cash.close'")).rows[0].n,2,'Each saved close has one audit entry and retry adds none');
 await db.query(`insert into payments(id,order_id,amount,method,created_by,paid_at)
  values($1,$2,5000,'Tunai',$3,'2020-01-15T06:00:00Z')`,[randomUUID(),oldOrder,owner]);
 await asUser(owner);
 const changed=await read();
 check([changed.cash,changed.fingerprint!==changed.closing.source_fingerprint],[35000,true],'New receipt after closing is flagged without modifying the saved snapshot');
 await fails(save,[randomUUID(),day,second,report.fingerprint,100000,10000,125000,'Penerimaan berubah'],/Data pembayaran telah berubah/,'Closing rejects receipt data changed since screen load');
 const third=randomUUID();
 await db.query(save,[third,day,second,changed.fingerprint,100000,10000,125000,'Sesuaikan pembayaran susulan']);
 await asUser(admin);
 check((await db.query(save,args)).rows[0].result.id,first,'Late retry of an older successful request does not overwrite the latest revision');
 check((await read()).closing.id,third,'Latest close remains current after late retry');
 await db.exec('reset role');
 await db.exec(migration);
 check((await db.query('select count(*)::int n from cash_closings')).rows[0].n,3,'Rerunning cash migration preserves all closing history');
 await db.query(`insert into payments(id,order_id,amount,method,created_by,paid_at)
  select gen_random_uuid(),$1,1,'Tunai',$2,'2020-01-16T04:00:00Z' from generate_series(1,1001)`,[oldOrder,owner]);
 await asUser(admin);
 const large=(await db.query("select cash_day('2020-01-16') result")).rows[0].result;
 // 16 January also includes the payment exactly at the prior day end.
 check([large.count,large.cash,large.payments.length],[1002,901001,1002],'Cash report includes all receipts beyond the normal 1000-row API cap');
 await asUser(staff);
 await fails('select cash_day($1)',[day],/owner dan admin/,'Technicians cannot access cash report');
 await fails(save,[randomUUID(),day,third,changed.fingerprint,0,0,0,'Uji akses'],/owner dan admin/,'Technicians cannot close cash');
 check((await db.query('select * from cash_closings')).rows.length,0,'RLS hides closing history from technicians');
 await asUser(pending);
 await fails('select cash_day($1)',[day],/belum aktif/,'Pending accounts cannot access cash');
 await db.exec('reset role; set role anon');
 await fails('select cash_day($1)',[day],/permission denied/,'Anonymous clients cannot access cash');
 await asUser(owner);
}
