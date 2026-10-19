/* NOOR Teacher Studio — scoped to authenticated teacher workspace.
   Requires no framework and does not overwrite existing dashboards. */
(function(){
'use strict';
const css=`
.noor-teacher-studio{--tp:#5c529e;--tl:#f2efff;color:#28253f}
.noor-teacher-studio .nts-hero{padding:23px;border-radius:22px;background:linear-gradient(115deg,#5b529b,#8c76c5);color:white;margin-bottom:17px}
.noor-teacher-studio .nts-hero h2{margin:5px 0;font-size:25px;color:white}
.noor-teacher-studio .nts-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}
.noor-teacher-studio .nts-card{background:white;border:1px solid #e7e1f6;border-radius:20px;padding:20px;box-shadow:0 12px 30px #5c529e12;margin-bottom:15px}
.noor-teacher-studio .nts-card h3{margin:0 0 14px;color:#342d65}
.noor-teacher-studio .nts-chip{border-radius:50px;background:#efeaff;color:#564a99;padding:6px 10px;font-size:11px;font-weight:800}
.noor-teacher-studio .nts-period{display:flex;gap:14px;border-left:3px solid #b9aceb;padding:12px 0 12px 18px;margin-left:8px}
.noor-teacher-studio .nts-period.current{border-color:#57a899;background:#f0faf8}
.noor-teacher-studio .nts-period.done{border-color:#7b6ac3}
.noor-teacher-studio .nts-period strong{display:block}
.noor-teacher-studio .nts-period small{color:#736e86}
.noor-teacher-studio .nts-actions{display:flex;flex-wrap:wrap;gap:8px;margin-top:9px}
.noor-teacher-studio button{border:0;border-radius:30px;background:#6255a7;color:white;padding:9px 14px;font-weight:700}
.noor-teacher-studio button:disabled{opacity:.6}
.noor-teacher-studio .nts-muted{color:#756f8c;font-size:12px}
@media(max-width:760px){.noor-teacher-studio .nts-grid{grid-template-columns:1fr}.noor-teacher-studio .nts-card{padding:15px}}
@media(prefers-reduced-motion:reduce){.noor-teacher-studio *{animation:none!important;transition:none!important}}
`;
let style=document.createElement('style');style.textContent=css;document.head.append(style);
const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const time=t=>t?String(t).slice(0,5):'—';
const today=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-')};
let currentKey='',busy=false;
async function mount(){
 const app=window.NOOR_AI_APP,root=document.getElementById('view-overview');
 if(!app?.user||app.profile?.role!=='teacher'||!app.schoolId||!root)return;
 const key=app.user.id+':'+app.schoolId;
 if(busy||root.querySelector('.noor-teacher-studio')?.dataset.key===key)return;
 busy=true;
 try{
  const db=app.db,school=app.schoolId,user=app.user.id;
  const [att,periods,tasks]=await Promise.all([
   db.from('noor_staff_attendance').select('id,status,checked_in_at').eq('school_id',school).eq('teacher_id',user).eq('attendance_date',today()).maybeSingle(),
   db.from('noor_teacher_periods').select('id,weekday,period_number,start_time,end_time,subject_name,class_label,status,approval_status').eq('school_id',school).eq('teacher_id',user).eq('weekday',new Date().getDay()).order('start_time'),
   db.from('noor_teacher_tasks').select('id,title,status,due_date,priority').eq('school_id',school).eq('teacher_id',user).order('due_date',{ascending:true}).limit(8)
  ]);
  const errors=[att.error,periods.error,tasks.error].filter(Boolean);
  const present=att.data?.status==='present';
  const now=new Date().toTimeString().slice(0,5);
  const periodHtml=(periods.data||[]).map(p=>{
   const approved=p.approval_status==='approved';const state=!approved?'upcoming':p.status==='done'?'done':time(p.start_time)<=now&&now<time(p.end_time)?'current':'upcoming';
   return `<div class="nts-period ${state}"><span class="nts-chip">P${Number(p.period_number)||'?'}</span><div><strong>${escape(p.subject_name)} · ${escape(p.class_label)}</strong><small>${escape(time(p.start_time))}–${escape(time(p.end_time))} · ${approved?state:'Awaiting Principal approval'}</small><div class="nts-actions"><button data-period="${escape(p.id)}" data-action="start" ${!approved||state==='done'?'disabled':''}>Start class</button><button data-period="${escape(p.id)}" data-action="done" ${!approved||state==='done'?'disabled':''}>Finish class</button></div></div></div>`;
  }).join('');
  const box=document.createElement('section');box.className='noor-teacher-studio';box.dataset.key=key;
  box.innerHTML=`<div class="nts-hero"><small>NOOR · TEACHER WORKSPACE</small><h2>Hello, ${escape(app.profile.full_name||'Teacher')}</h2><span>Today's timetable, attendance and priorities</span></div>
  <div class="nts-grid"><div class="nts-card"><h3>My profile</h3><strong>${escape(app.profile.full_name)}</strong><p class="nts-muted">${escape(app.profile.email||app.user.email||'')}</p><button data-open="profile">View profile</button></div>
  <div class="nts-card"><h3>Staff check-in</h3><p class="nts-chip">${present?'Present · '+escape(new Date(att.data.checked_in_at).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'})):'Not checked in'}</p><p><button id="ntsCheckin" ${present||att.error?'disabled':''}>${present?'Checked in':'Mark Present'}</button></p></div>
  <div class="nts-card"><h3>My priorities</h3><strong>${tasks.data?.filter(x=>x.status!=='done').length||0} pending tasks</strong><p class="nts-muted">Assigned tasks and due dates</p><button data-open="notifications">Notifications</button></div></div>
  <div class="nts-grid"><div class="nts-card" style="grid-column:span 2"><h3>Today's timetable</h3>${periodHtml||'<p class="nts-muted">No periods assigned for today.</p>'}<button data-open="schedules">Full schedule</button></div>
  <div class="nts-card"><h3>Task board</h3>${(tasks.data||[]).map(t=>`<p><strong>${escape(t.title)}</strong><br><small class="nts-muted">${escape(t.status)} · ${escape(t.due_date||'No deadline')} · ${escape(t.priority||'normal')}</small></p>`).join('')||'<p class="nts-muted">No tasks assigned.</p>'}<button data-open="notices">School notices</button></div></div>
  ${errors.length?'<p role="status" class="nts-muted">Some teacher modules are unavailable until the database migration is applied.</p>':''}`;
  root.prepend(box);
  box.addEventListener('click',async e=>{
   const b=e.target.closest('button');if(!b)return;
   if(b.dataset.open){app.openView(b.dataset.open);return;}
   if(b.id==='ntsCheckin'){
    b.disabled=true;
    const {error}=await db.from('noor_staff_attendance').insert({school_id:school,teacher_id:user,attendance_date:today(),status:'present',checked_in_at:new Date().toISOString()});
    if(error){app.toast(error.message,'error');b.disabled=false;}else{app.toast('Attendance recorded','success');box.remove();mount();}
   }
   if(b.dataset.period){
    b.disabled=true;
    const status=b.dataset.action==='done'?'done':'ongoing';
    const {error}=await db.from('noor_teacher_periods').update({status}).eq('id',b.dataset.period).eq('school_id',school).eq('teacher_id',user);
    if(error){app.toast(error.message,'error');b.disabled=false;}else{app.toast('Period updated','success');box.remove();mount();}
   }
  });
 }finally{busy=false;}
}
const observer=new MutationObserver(()=>{if(document.getElementById('workspace')&&!document.getElementById('workspace').classList.contains('hidden'))mount();});
observer.observe(document.body,{childList:true,subtree:true});
setInterval(()=>{if(!document.hidden)mount()},30000);
})();