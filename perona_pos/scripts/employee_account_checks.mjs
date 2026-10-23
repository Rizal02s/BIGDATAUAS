import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createHandler } from '../supabase/functions/delete-employee-account/handler.mjs';

export async function runEmployeeAccountChecks({db,owner,admin,staff,pending,asUser,check,fails}) {
 await db.exec('reset role');
 await db.exec(`create role service_role; grant usage on schema public,auth to service_role;
  alter table auth.users add column deleted_at timestamptz;
  create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id));`);
 const sql=await readFile(new URL('../supabase/013_delete_employee_account.sql',import.meta.url),'utf8');
 await db.exec(sql);await db.exec(sql);
 const target=randomUUID(),otherOwner=randomUUID(),invalidRoleTarget=randomUUID();
 for(const [id,name] of [[target,'Pegawai dihapus'],[otherOwner,'Owner kedua'],[invalidRoleTarget,'Peran berubah']]) {
  await db.query('insert into auth.users(id,raw_user_meta_data) values($1,$2)',[id,JSON.stringify({name})]);
 }
 await db.query("update profiles set role='technician' where id=$1",[target]);
 await db.query("update profiles set role='owner' where id=$1",[otherOwner]);
 await db.query("update profiles set role='admin' where id=$1",[invalidRoleTarget]);
 await db.query('insert into auth.sessions values($1,$2)',[randomUUID(),target]);
 const order=randomUUID(),payment=randomUUID(),photo=randomUUID(),path=`${order}/${target}/existing.jpg`;
 await db.query(`insert into orders(id,customer_name,items,total,labor_total,created_by,created_at)
  values($1,'Riwayat customer',$2,50000,10000,$3,'2025-01-02T03:00:00Z')`,[order,JSON.stringify([{id:randomUUID(),worker_id:target,name:'Clean',quantity:1,price:50000,labor_fee:10000,status:'Selesai'}]),target]);
 await db.query("insert into payments(id,order_id,amount,method,created_by,paid_at) values($1,$2,50000,'Tunai',$3,'2025-01-02T03:00:00Z')",[payment,order,target]);
 await db.query("insert into storage.objects(bucket_id,name) values('order-photos',$1)",[path]);
 await db.query('insert into order_photos(id,order_id,path,created_by) values($1,$2,$3,$4)',[photo,order,path,target]);
 await asUser(owner);
 const ledgerBefore=(await db.query("select wage_ledger($1,'2025-01-01','2025-02-01') r",[target])).rows[0].r;
 const reportBefore=(await db.query("select operational_report('2025-01-01','2025-02-01',0) r")).rows[0].r;
 await fails('select finish_employee_deletion($1)',[target],/permission denied/,'Owner client cannot falsely acknowledge Auth deletion');
 await fails('select prepare_employee_deletion($1,$2,$3)',[owner,'owner','Salah akun'],/sendiri/,'Self deletion rejected');
 await fails('select prepare_employee_deletion($1,$2,$3)',[otherOwner,'disabled','Salah akun'],/owner tidak dapat/,'Other owner cannot be deleted even with forged expected role');
 await fails('select prepare_employee_deletion($1,$2,$3)',[invalidRoleTarget,'pending','Salah akun'],/Peran akun telah berubah/,'Stale role requires fresh confirmation');
 await fails('select prepare_employee_deletion($1,$2,$3)',[target,'technician','x'],/alasan penghapusan/,'Deletion requires meaningful reason');
 let authFails=true,finishFails=false,deleteThrows=false,authCalls=0;
 const calls=[];
 const json=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json'}});
 const authTokens=new Map([['owner-token',owner],['admin-token',admin],['staff-token',staff],['target-token',target],['pending-token',pending]]);
 const handler=createHandler({url:'https://example.test',anonKey:'public-key',serviceKey:'server-only-secret',fetchImpl:async(url,options)=>{
  const path=new URL(url).pathname,token=options.headers.authorization.replace('Bearer ',''),body=options.body?JSON.parse(options.body):null;
  calls.push({path,token,body,method:options.method});
  if(path==='/auth/v1/user') {
   const id=authTokens.get(token);return id?json(200,{id}):json(401,{error:'invalid'});
  }
  if(path==='/rest/v1/rpc/prepare_employee_deletion') {
   await asUser(authTokens.get(token));
   try {return json(200,(await db.query('select prepare_employee_deletion($1,$2,$3) r',[body.p_id,body.p_expected_role,body.p_reason])).rows[0].r);}
   catch(e){return json(403,{message:e.message,code:e.code});}
  }
  if(path.startsWith('/auth/v1/admin/users/')) {
   check(token,'server-only-secret','Privileged Auth request uses only server credential');
   const id=path.split('/').at(-1);
   if(options.method==='GET') {
    await db.exec('reset role');const user=(await db.query('select id,deleted_at from auth.users where id=$1',[id])).rows[0];
    return user?json(200,user):json(404,{});
   }
   authCalls++;check(body,{should_soft_delete:true},'Auth deletion preserves historic references and Storage ownership');
   if(authFails)return json(503,{});
   await db.exec('reset role');
   await db.query('update auth.users set deleted_at=coalesce(deleted_at,now()) where id=$1',[id]);
   await db.query('delete from auth.sessions where user_id=$1',[id]);
   if(deleteThrows)throw new Error('Lost Auth response');
   return json(200,{});
  }
  if(path==='/rest/v1/rpc/finish_employee_deletion') {
   check(token,'server-only-secret','Finish RPC uses server credential');
   if(finishFails)return json(500,{});
   await db.exec('reset role;set role service_role');
   try {await db.query('select finish_employee_deletion($1)',[body.p_id]);return json(200,null);}
   catch(e){return json(400,{message:e.message});}
  }
  throw new Error('Unexpected endpoint');
 }});
 const invoke=async(token='owner-token',id=target,expected_role='technician',reason='Pegawai telah keluar')=>{
  const response=await handler(new Request('https://edge.test',{method:'POST',headers:{authorization:`Bearer ${token}`},body:JSON.stringify({id,expected_role,reason,role:'owner'})}));
  return {status:response.status,body:await response.json()};
 };
 for(const token of ['admin-token','staff-token','pending-token']) {
  check((await invoke(token)).status,403,'Nonowner request cannot reach privileged Auth deletion');
 }
 check(authCalls,0,'No Auth deletion before owner authorization');
 check((await invoke('bad-token')).status,401,'Invalid JWT rejected by Auth before RPC');
 let response=await handler(new Request('https://edge.test',{method:'POST',body:'{}'}));
 check(response.status,401,'Missing JWT rejected');
 response=await handler(new Request('https://edge.test',{method:'GET'}));check(response.status,405,'Deletion only accepts POST');
 response=await handler(new Request('https://edge.test',{method:'POST',headers:{authorization:'Bearer owner-token'},body:'not json'}));check(response.status,400,'Invalid payload rejected');
 check((await invoke('owner-token',owner)).status,400,'Edge handler also rejects self deletion');
 check((await invoke('owner-token',otherOwner,'disabled')).status,403,'Forged owner target role rejected by SQL');
 const first=await invoke();
 check([first.status,first.body.pending],[503,true],'Auth outage reports pending instead of claiming full deletion');
 await asUser(owner);
 let person=(await db.query('select * from profiles where id=$1',[target])).rows[0];
 check([person.role,person.deleted_at!==null,person.auth_deleted_at,person.delete_reason],['disabled',true,null,'Pegawai telah keluar'],'Pending deletion immediately revokes access and keeps original reason');
 await fails("select set_staff_role($1,'technician')",[target],/telah dihapus/,'Deleted account cannot be reactivated through role changes');
 await asUser(target);
 check((await db.query('select app_role() r')).rows[0].r,null,'Deleted profile never supplies an active app role to old JWT');
 check((await db.query('select count(*)::int n from orders')).rows[0].n,0,'Old JWT cannot read orders after prepare step');
 check((await db.query('select count(*)::int n from storage.objects')).rows[0].n,0,'Old JWT cannot read Storage objects');
 await fails('select staff_directory()',[],/belum aktif/,'Deleted account cannot enumerate directory');
 await fails('select customer_suggestions($1)',['Customer'],/belum aktif/,'Old JWT cannot read customers');
 await asUser(admin);
 const directory=(await db.query('select staff_directory() r')).rows[0].r;
 check(directory.some(p=>p.id===target),true,'Historic worker remains resolvable in operational directory');
 check(directory.every(p=>!('delete_reason'in p)&&!('deleted_by'in p)),true,'Directory never reveals internal deletion reasons to admin');
 check((await db.query('select id from profiles')).rows.map(p=>p.id),[admin],'Raw profile access no longer reveals another employee deletion reason');
 authFails=false;finishFails=true;
 const halfway=await invoke('owner-token',target,'disabled');
 check([halfway.status,halfway.body.pending],[503,true],'Lost finalization remains retryable');
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from auth.sessions where user_id=$1',[target])).rows[0].n,0,'Auth soft-delete session removal is represented by Auth mock');
 finishFails=false;
 const finished=await invoke('owner-token',target,'disabled');
 check([finished.status,finished.body.deleted],[200,true],'Owner completes deletion after partial failure');
 const deletesBefore=authCalls;
 check((await invoke()).status,200,'Completed deletion retry succeeds idempotently');
 check(authCalls,deletesBefore,'Completed retry does not invoke Auth again');
 await asUser(owner);
 person=(await db.query('select * from profiles where id=$1',[target])).rows[0];
 check(person.auth_deleted_at!==null,true,'Completion persists only after Auth is marked deleted');
 check((await db.query("select action from audit_log where entity_id=$1 order by action",[target])).rows.map(a=>a.action),['staff.auth_deleted','staff.delete'],'Exactly one prepare and completion audit survive all retries');
 check((await db.query('select created_by from orders where id=$1',[order])).rows[0].created_by,target,'Order historical creator preserved');
 check((await db.query('select created_by from payments where id=$1',[payment])).rows[0].created_by,target,'Customer payment historical operator preserved');
 check((await db.query('select path,created_by from order_photos where id=$1',[photo])).rows[0],{path,created_by:target},'Photo metadata and filename preserved');
 check((await db.query('select count(*)::int n from storage.objects where name=$1',[path])).rows[0].n,1,'Storage data not deleted or reassigned');
 check((await db.query("select wage_ledger($1,'2025-01-01','2025-02-01') r",[target])).rows[0].r,ledgerBefore,'Employee wage entitlement and fingerprint remain unchanged');
 check((await db.query("select operational_report('2025-01-01','2025-02-01',0) r")).rows[0].r,reportBefore,'Deleting employee changes no customer financial report');
 await db.exec('reset role;set role service_role');
 await fails('select finish_employee_deletion($1)',[invalidRoleTarget],/Permintaan penghapusan/,'Service cannot finalize an unprepared account');
 await db.exec('reset role;set role anon');
 await fails('select prepare_employee_deletion($1,$2,$3)',[target,'disabled','Salah akun'],/permission denied/,'Anonymous deletion prepare denied');
 await fails('select staff_directory()',[],/permission denied/,'Anonymous directory denied');
 await asUser(owner);
 // Missing server environment never exposes a credential or starts deletion.
 const unconfigured=createHandler({url:'https://edge.test',anonKey:'public-key'});
 response=await unconfigured(new Request('https://edge.test',{method:'POST'}));
 check(response.status,503,'Unconfigured function fails safely');
 check(JSON.stringify(finished.body).includes('server-only-secret'),false,'Privileged credentials never returned to app');
 deleteThrows=true;
 const lost=await invoke('owner-token',invalidRoleTarget,'admin');
 check([lost.status,lost.body.pending],[503,true],'Lost Auth response does not claim unverified success');
 deleteThrows=false;authFails=true;
 const recovered=await invoke('owner-token',invalidRoleTarget,'disabled');
 check([recovered.status,recovered.body.deleted],[200,true],'Retry checks Auth deleted_at after ambiguous or failed repeat DELETE');
 await asUser(owner);
}
