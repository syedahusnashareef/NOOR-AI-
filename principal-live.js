/* NOOR Principal Live: only authorised, persisted Supabase records. */
(()=>{'use strict';
const a=()=>window.NOOR_AI_APP||{}, e=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const permitted=()=>['owner','principal'].includes(a().profile?.role)&&a().profile?.status==='active'&&a().profile?.school_id===a().schoolId&&a().school?.verification_status==='verified'&&a().school?.account_status==='active'&&a().school?.is_active===true;
const root=()=>document.getElementById('view-principal-studio');
let loading=false,channel=null,identity='',timer=null;
const css=[
'#noor-principal{--p-ink:#392431;--p-muted:#806776;--p-line:#eddae3;--p-card:#fff;--p-bg:#fff8f8;color:var(--p-ink);background:var(--p-bg);padding:18px;border-radius:23px;font:15px/1.5 "DM Sans",system-ui,sans-serif}',
'#noor-principal *{box-sizing:border-box}#noor-principal .pd-head{display:flex;justify-content:space-between;align-items:center;gap:15px;flex-wrap:wrap;padding:22px;border:1px solid var(--p-line);border-radius:22px;background:linear-gradient(120deg,#fffdfa,#fae8ef)}',
'#noor-principal h1{font:800 clamp(24px,3vw,35px) Manrope,sans-serif;margin:4px 0 8px}#noor-principal h2{font:800 19px Manrope,sans-serif;margin:0 0 6px}#noor-principal .pd-muted{font-size:13px;color:var(--p-muted)}',
'#noor-principal .pd-btn{min-height:44px;border:1px solid #dbc0ce;background:white;color:#642b47;border-radius:12px;padding:10px 13px;font-size:13px;font-weight:750;cursor:pointer}#noor-principal .pd-btn:hover{background:#f9e9f0}#noor-principal .pd-btn.primary{background:#642b47;color:white}#noor-principal .pd-actions{display:flex;flex-wrap:wrap;gap:8px;margin:15px 0}',
'#noor-principal .pd-kpis{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin:16px 0}#noor-principal .pd-kpi{min-width:0;border-radius:19px;padding:19px;color:white;min-height:140px;box-shadow:0 10px 24px #541e3b12}#noor-principal .pd-kpi small{font-size:12px;font-weight:800}#noor-principal .pd-kpi strong{display:block;font:800 clamp(24px,3vw,36px) Manrope;margin:12px 0 5px}#noor-principal .pd-kpi p{font-size:12px;margin:0}',
'#noor-principal .pd-kpi:nth-child(1){background:linear-gradient(135deg,#672c4b,#ba6685)}#noor-principal .pd-kpi:nth-child(2){background:linear-gradient(135deg,#51358d,#9c7adc)}#noor-principal .pd-kpi:nth-child(3){background:linear-gradient(135deg,#087879,#51bdae)}#noor-principal .pd-kpi:nth-child(4){background:linear-gradient(135deg,#be781e,#efb75b)}#noor-principal .pd-kpi:nth-child(5){background:linear-gradient(135deg,#365fa4,#64b4e7)}#noor-principal .pd-kpi:nth-child(6){background:linear-gradient(135deg,#a1396e,#eb7295)}',
'#noor-principal .pd-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}#noor-principal .pd-card{border:1px solid var(--p-line);background:var(--p-card);border-radius:20px;padding:19px;min-width:0;box-shadow:0 8px 24px #541e3b0b}#noor-principal .pd-full{grid-column:1/-1}',
'#noor-principal .pd-row{display:flex;justify-content:space-between;align-items:center;gap:11px;border-top:1px solid var(--p-line);padding:11px 0}#noor-principal .pd-row:first-child{border-top:0}#noor-principal .pd-row strong{display:block;font-size:14px}#noor-principal .pd-row small{display:block;color:var(--p-muted);font-size:12px}#noor-principal .pd-tag{border-radius:25px;background:#f5e2ec;color:#702a4e;font-size:12px;font-weight:750;padding:5px 9px;white-space:nowrap}#noor-principal .pd-tag.done{background:#e1f6e8;color:#24784d}#noor-principal .pd-tag.now{background:#deeffe;color:#235f8c}',
'#noor-principal .pd-chart{height:150px;display:flex;gap:10px;align-items:flex-end;margin:12px 0}#noor-principal .pd-col{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:end;gap:5px;height:100%}#noor-principal .pd-bar{width:min(40px,78%);border-radius:8px 8px 0 0;background:linear-gradient(0deg,#6d49aa,#cb84e1)}#noor-principal .pd-col b,#noor-principal .pd-col small{font-size:11px}#noor-principal .pd-empty{color:var(--p-muted);padding:16px 0;font-size:14px}#noor-principal .pd-alert{margin:12px 0;background:#fff1e3;color:#874922;padding:12px;border-radius:12px}',
'#noor-principal.pd-dark{--p-ink:#fff1f7;--p-muted:#d6bccb;--p-line:#57394b;--p-card:#30232f;--p-bg:#211924}#noor-principal.pd-dark .pd-head{background:linear-gradient(120deg,#362537,#4b3044)}#noor-principal.pd-dark .pd-btn{background:#4c3446;color:#fff;border-color:#74566c}#noor-principal :focus-visible{outline:3px solid #edb25e;outline-offset:3px}',
'@media(max-width:820px){#noor-principal .pd-kpis{grid-template-columns:repeat(2,minmax(0,1fr))}#noor-principal .pd-grid{grid-template-columns:1fr}#noor-principal{padding:11px}}@media(max-width:390px){#noor-principal .pd-kpi{padding:12px;min-height:130px}#noor-principal .pd-kpi strong{font-size:24px}}'
].join('');
const style=document.createElement('style');style.id='noor-principal-live-style';style.textContent=css;document.head.append(style);
const row=(name,detail,status,kind)=>'<div class="pd-row"><div><strong>'+e(name)+'</strong><small>'+e(detail||'')+'</small></div><span class="pd-tag '+e(kind||'')+'">'+e(status)+'</span></div>';
const kpi=(label,num,detail)=>'<div class="pd-kpi"><small>'+e(label)+'</small><strong>'+e(num)+'</strong><p>'+e(detail)+'</p></div>';
function clock(tz){
 const parts=new Intl.DateTimeFormat('en-GB',{timeZone:tz,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',weekday:'short',hourCycle:'h23'}).formatToParts(new Date());
 const get=k=>parts.find(x=>x.type===k)?.value||'';
 return {day:get('year')+'-'+get('month')+'-'+get('day'),time:get('hour')+':'+get('minute'),weekday:['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].indexOf(get('weekday'))};
}
function setup(){
 const r=root(),user=a().user,school=a().school,p=a().profile;if(!r||!user||!school)return;
 const key=user.id+':'+school.id;
 if(r.dataset.liveIdentity!==key){
  r.dataset.liveIdentity=key;r.replaceChildren();
  const now=new Date(),h=now.getHours(),greet=h<12?'Good Morning':h<17?'Good Afternoon':'Good Evening';
  r.innerHTML='<div id="noor-principal"><div class="pd-head"><div><div class="pd-muted">NOOR · PRINCIPAL DASHBOARD</div><h1>'+e(greet)+', '+e(p.full_name||'Principal')+'</h1><div class="pd-muted">'+e(school.name)+' · Actual school records</div></div><div class="pd-actions"><button type="button" class="pd-btn" id="pd-mode">☾ Theme</button><button type="button" class="pd-btn" id="pd-refresh">↻ Refresh</button><button type="button" class="pd-btn primary" data-route="school-tasks">+ New task</button></div></div><p class="pd-muted" id="pd-status" role="status">Loading school data…</p><div class="pd-kpis" id="pd-kpis"></div><div class="pd-actions"><button class="pd-btn" data-route="student-directory">Students</button><button class="pd-btn" data-route="staff-management">Staff</button><button class="pd-btn" data-route="notices">Notices</button><button class="pd-btn" data-route="meetings">Meetings</button><button class="pd-btn" data-route="school-calendar">Calendar</button><button class="pd-btn" data-route="academic-monitoring">Progress</button><button class="pd-btn" data-route="parent-support">Parent Follow-ups</button><button class="pd-btn" data-route="command-centre">Command Centre</button></div><div id="pd-errors"></div><div class="pd-grid"><section class="pd-card"><h2>Recorded attendance trend</h2><p class="pd-muted">Last seven calendar days</p><div id="pd-trend"></div></section><section class="pd-card"><h2>Classes & Sections</h2><div id="pd-classes"></div></section><section class="pd-card pd-full"><h2>Live Teacher Period Tracker</h2><p class="pd-muted">Teacher start / completion status from saved records</p><div id="pd-periods"></div></section><section class="pd-card"><h2>School Tasks</h2><div id="pd-tasks"></div></section><section class="pd-card"><h2>Notices & Upcoming Events</h2><div id="pd-events"></div></section></div></div>';
  const host=r.querySelector('#noor-principal');
  r.onclick=event=>{const button=event.target.closest('[data-route]');if(button&&r.contains(button))a().openView?.(button.dataset.route)};
  host.querySelector('#pd-refresh').onclick=refresh;
  host.querySelector('#pd-mode').onclick=()=>{host.classList.toggle('pd-dark');const dark=host.classList.contains('pd-dark');host.querySelector('#pd-mode').textContent=dark?'☀ Light':'☾ Theme';try{localStorage.setItem('noor.principal.theme.'+key,dark?'dark':'light')}catch{}};
  try{if(localStorage.getItem('noor.principal.theme.'+key)==='dark'){host.classList.add('pd-dark');host.querySelector('#pd-mode').textContent='☀ Light'}}catch{}
 }
}
async function refresh(){
 if(loading||!permitted()||!root()?.classList.contains('active'))return;
 const ctx=a(),sid=ctx.schoolId,uid=ctx.user.id,db=ctx.db,r=root();if(!db)return;
 loading=true;r.querySelector('#pd-status').textContent='Syncing with Supabase…';
 try{
  const settings=await db.from('school_settings').select('timezone').eq('school_id',sid).maybeSingle(),d=clock(settings.data?.timezone||'Asia/Kolkata');
  const first=new Date(d.day+'T00:00:00Z');first.setUTCDate(first.getUTCDate()-6);
  const [students,teachers,staff,periods,runs,sessions,tasks,events,notices,classes,sections]=await Promise.all([
   db.from('profiles').select('id',{count:'exact',head:true}).eq('school_id',sid).eq('role','student').eq('status','active'),
   db.from('profiles').select('id,full_name').eq('school_id',sid).eq('role','teacher').eq('status','active').limit(500),
   db.from('noor_staff_attendance').select('teacher_id,status').eq('school_id',sid).eq('attendance_date',d.day).limit(500),
   db.from('noor_teacher_periods').select('id,teacher_id,weekday,period_number,start_time,end_time,subject_name,class_label,approval_status,block_type').eq('school_id',sid).eq('weekday',d.weekday).eq('approval_status','approved').order('start_time').limit(500),
   db.from('noor_teacher_period_runs').select('period_id,teacher_id,status').eq('school_id',sid).eq('class_date',d.day).limit(500),
   db.from('attendance_sessions').select('id,attendance_date').eq('school_id',sid).gte('attendance_date',first.toISOString().slice(0,10)).lte('attendance_date',d.day).limit(500),
   db.from('school_tasks').select('title,status,priority,due_at').eq('school_id',sid).limit(150),
   db.from('calendar_events').select('title,starts_at,event_type,status').eq('school_id',sid).gte('starts_at',new Date().toISOString()).order('starts_at').limit(15),
   db.from('school_notices').select('title,starts_at,ends_at,is_active').eq('school_id',sid).eq('is_active',true).order('starts_at',{ascending:false}).limit(30),
   db.from('classes').select('id,name,sort_order').eq('school_id',sid).eq('is_active',true).order('sort_order').limit(150),
   db.from('sections').select('id,class_id,name').eq('is_active',true).limit(500)
  ]);
  if(a().schoolId!==sid||a().user?.id!==uid||!permitted())return;
  const errors=[['students',students],['teachers',teachers],['staff attendance',staff],['periods',periods],['period runs',runs],['attendance',sessions],['tasks',tasks],['calendar',events],['notices',notices],['classes',classes],['sections',sections]].filter(x=>x[1].error).map(x=>x[0]);
  const sessionsRows=sessions.data||[],ids=sessionsRows.map(x=>x.id);
  const records=ids.length?await db.from('attendance_records').select('session_id,status').eq('school_id',sid).in('session_id',ids).limit(5000):{data:[],error:null};
  if(records.error)errors.push('attendance marks');
  const all=records.data||[],dayIds=new Set(sessionsRows.filter(x=>x.attendance_date===d.day).map(x=>x.id));
  const marked=all.filter(x=>dayIds.has(x.session_id)&&['present','late','absent'].includes(x.status)),attended=marked.filter(x=>x.status!=='absent').length;
  const pct=marked.length?Math.round(100*attended/marked.length)+'%':'—';
  const teacherRows=teachers.data||[],staffRows=staff.data||[],periodRows=(periods.data||[]).filter(x=>x.block_type==='class');
  const pending=(tasks.data||[]).filter(x=>!['done','completed','cancelled'].includes(String(x.status).toLowerCase()));
  const upcoming=(events.data||[]).filter(x=>!['cancelled','deleted'].includes(String(x.status).toLowerCase()));
  const noticeRows=(notices.data||[]).filter(x=>(!x.starts_at||Date.parse(x.starts_at)<=Date.now())&&(!x.ends_at||Date.parse(x.ends_at)>Date.now()));
  const count=(res,v)=>res.error?'—':Number(v).toLocaleString('en-IN');
  r.querySelector('#pd-kpis').innerHTML=[
   kpi('ACTIVE STUDENTS',count(students,students.count),'Registered school students'),
   kpi('ACTIVE TEACHERS',count(teachers,teacherRows.length),'Current staff records'),
   kpi('ATTENDANCE TODAY',sessions.error||records.error?'—':pct,marked.length?attended+' attended · '+(marked.length-attended)+' absent':'Not marked yet'),
   kpi('STAFF CHECK-IN',teachers.error||staff.error?'—':staffRows.filter(x=>x.status==='present').length+'/'+teacherRows.length,'Today · '+(staffRows.length?'Recorded':'Not recorded')),
   kpi('PENDING TASKS',count(tasks,pending.length),'Open school tasks'),
   kpi('UPCOMING EVENTS',count(events,upcoming.length),'School calendar')
  ].join('');
  const dates=new Map(sessionsRows.map(x=>[x.id,x.attendance_date])),bars=[];
  for(let j=6;j>=0;j--){const date=new Date(d.day+'T00:00:00Z');date.setUTCDate(date.getUTCDate()-j);const key=date.toISOString().slice(0,10);const marks=all.filter(x=>dates.get(x.session_id)===key&&['present','late','absent'].includes(x.status));bars.push({label:date.toLocaleDateString('en-GB',{weekday:'short',timeZone:'UTC'}),pct:marks.length?Math.round(marks.filter(x=>x.status!=='absent').length*100/marks.length):null})}
  r.querySelector('#pd-trend').innerHTML=bars.some(x=>x.pct!==null)?'<div class="pd-chart">'+bars.map(x=>'<div class="pd-col"><b>'+(x.pct===null?'—':x.pct+'%')+'</b><div class="pd-bar" style="height:'+(x.pct===null?0:Math.max(2,x.pct))+'%"></div><small>'+e(x.label)+'</small></div>').join('')+'</div>':'<p class="pd-empty">No attendance records for the past seven days.</p>';
  r.querySelector('#pd-classes').innerHTML=(classes.data||[]).map(c=>row(c.name,(sections.data||[]).filter(x=>x.class_id===c.id).map(x=>x.name).join(', ')||'No section added','Active')).join('')||'<p class="pd-empty">No classes created yet.</p>';
  const runMap=new Map((runs.data||[]).map(x=>[x.period_id,x])),nameMap=new Map(teacherRows.map(x=>[x.id,x.full_name]));
  r.querySelector('#pd-periods').innerHTML=periodRows.map(p=>{const run=runMap.get(p.id),now=p.start_time?.slice(0,5)<=d.time&&p.end_time?.slice(0,5)>d.time;const tag=run?.status==='done'?'Completed':run?.status==='ongoing'?'In progress':now?'Scheduled now':'Scheduled';return row(nameMap.get(p.teacher_id)||'Teacher',p.class_label+' · '+p.subject_name+' · Period '+p.period_number+' ('+String(p.start_time).slice(0,5)+'–'+String(p.end_time).slice(0,5)+')',tag,run?.status==='done'?'done':run?.status==='ongoing'?'now':'')}).join('')||'<p class="pd-empty">No approved class periods for today.</p>';
  r.querySelector('#pd-tasks').innerHTML=pending.slice(0,8).map(x=>row(x.title,x.due_at?'Due '+new Date(x.due_at).toLocaleDateString('en-IN'):'No due date',x.priority||x.status||'Open')).join('')||'<p class="pd-empty">No open school tasks.</p>';
  r.querySelector('#pd-events').innerHTML=noticeRows.slice(0,5).map(x=>row(x.title,'School notice','Notice')).concat(upcoming.slice(0,5).map(x=>row(x.title,new Date(x.starts_at).toLocaleString('en-IN'),x.event_type||'Event'))).join('')||'<p class="pd-empty">No active notices or upcoming events.</p>';
  r.querySelector('#pd-errors').innerHTML=errors.length?'<div class="pd-alert">Some school data could not be loaded: '+e(errors.join(', '))+'. Missing values have not been estimated.</div>':'';
  r.querySelector('#pd-status').textContent='School records updated '+new Date().toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'})+' · Saved records only';
 }catch(err){const node=r.querySelector('#pd-errors');if(node)node.innerHTML='<div class="pd-alert">'+e(err?.message||'School data could not be loaded.')+'</div>';r.querySelector('#pd-status').textContent='Live refresh unsuccessful';}
 finally{loading=false}
}
function connect(){
 const key=a().user?.id+':'+a().schoolId;
 if(channel&&identity!==key){try{a().db.removeChannel(channel)}catch{}channel=null}
 if(channel&&identity===key)return;
 identity=key;const db=a().db,sid=a().schoolId;if(!db||!sid)return;
 channel=db.channel('noor-principal-'+key);
 for(const table of ['noor_teacher_periods','noor_teacher_period_runs','noor_staff_attendance','attendance_sessions','attendance_records','school_tasks','school_notices']){
  channel=channel.on('postgres_changes',{event:'*',schema:'public',table,filter:'school_id=eq.'+sid},()=>{if(root()?.classList.contains('active'))refresh()});
 }
 channel.subscribe();
 if(!timer)timer=setInterval(()=>{if(!document.hidden&&root()?.classList.contains('active'))refresh()},30000);
}
function render(){const r=root();if(!r)return;if(!permitted()){r.replaceChildren();return;}setup();connect();refresh()}
window.NOOR_PRINCIPAL_LIVE={render,refresh};
})();