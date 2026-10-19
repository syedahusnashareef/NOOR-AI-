/* NOOR Teacher: beautiful dashboard attendance backed by actual assigned rosters and submitted sessions. */
(()=>{'use strict';
const APP=()=>window.NOOR_AI_APP||{},E=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const day=()=>{const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')};
const nat=new Intl.Collator('en',{numeric:true,sensitivity:'base'});
let model=null,revision=0,working=false;
const root=()=>document.getElementById('ntAttendanceEmbed');
const $=q=>root()?.querySelector(q);
const say=(s,bad=false)=>{const el=$('#ntAttStatus');if(el){el.textContent=s;el.style.color=bad?'#b93c4d':'#815a73'}};
function marks(){
 let present=0,absent=0,late=0;
 for(const x of model.students){if(model.selection[x.id]==='present')present++;else if(model.selection[x.id]==='absent')absent++;else if(model.selection[x.id]==='late')late++;}
 return {present,absent,late,unmarked:model.students.length-present-absent-late};
}
function stats(){
 if(!model)return;
 const t=marks();
 const s=$('#ntAttSummary');if(s)s.innerHTML=
 '<span class="nt-att-chip">✓ '+t.present+' Present</span><span class="nt-att-chip absent">✕ '+t.absent+' Absent</span><span class="nt-att-chip late">◷ '+t.late+' Late</span>'+
 (t.unmarked?'<span class="nt-att-chip unmarked">'+t.unmarked+' Unmarked</span>':'');
 const submit=$('#ntAttSave');if(submit)submit.disabled=working||!model.students.length||t.unmarked!==0;
 const footer=$('#ntAttFooter');if(footer)footer.textContent='Total '+model.students.length+' students · '+t.present+' Present · '+t.absent+' Absent · '+t.late+' Late · '+t.unmarked+' Unmarked';
}
function classOptions(){
 const classes=model.classes;
 $('#ntAttClass').innerHTML=classes.map(x=>'<option value="'+E(x.id)+'">'+E(x.name)+'</option>').join('');
 if(!classes.length)$('#ntAttClass').innerHTML='<option value="">No assigned classes</option>';
}
function sectionOptions(){
 const classId=$('#ntAttClass').value,as=model.assignments.filter(x=>x.class_id===classId);
 const all=as.some(x=>!x.section_id),available=model.sections.filter(x=>x.class_id===classId&&(all||as.some(y=>y.section_id===x.id)));
 $('#ntAttSection').innerHTML=(all?'<option value="">All sections</option>':'<option value="">Choose section</option>')+
 available.map(x=>'<option value="'+E(x.id)+'">'+E(x.name)+'</option>').join('');
 if(!all&&available.length)$('#ntAttSection').value=available[0].id;
}
function table(){
 const box=$('#ntAttTable'),students=model.students;
 if(!students.length){box.innerHTML='<p class="nt-empty">No active students found for this class and section.</p>';stats();return}
 box.innerHTML='<table class="nt-att-table"><thead><tr><th>Student Name</th><th>Roll No.</th><th style="text-align:center">Present</th><th style="text-align:center">Absent</th><th style="text-align:center">Late</th></tr></thead><tbody>'+
 students.map(x=>'<tr><td><b>'+E(x.full_name)+'</b></td><td>'+E(x.roll_number||'—')+'</td>'+
 ['present','absent','late'].map(status=>'<td style="text-align:center"><button type="button" class="nt-radio '+status+'" role="radio" aria-label="'+E(x.full_name)+' '+status+'" aria-checked="'+String(model.selection[x.id]===status)+'" data-student="'+E(x.id)+'" data-choice="'+status+'"></button></td>').join('')+'</tr>').join('')+'</tbody></table>';
 stats();
}
async function mount(){
 const a=APP(),box=root();if(!box||a.profile?.role!=='teacher'||a.profile?.status!=='active'||!a.schoolId)return;
 const v=++revision;model={assignments:[],classes:[],sections:[],students:[],selection:{},session:null};
 box.innerHTML='<div class="nt-att-head"><div class="nt-att-controls"><label>Date<input id="ntAttDate" type="date" max="'+day()+'" value="'+day()+'"></label><label>Class<select id="ntAttClass"></select></label><label>Section<select id="ntAttSection"></select></label></div><div class="nt-att-summary" id="ntAttSummary"><span class="nt-att-chip unmarked">Loading…</span></div></div>'+
 '<div class="nt-att-scroll" id="ntAttTable"><p class="nt-muted">Loading real class roster…</p></div>'+
 '<div class="nt-att-actions"><div><button class="nt-btn" type="button" id="ntAttMarkAll">✓ Mark all Present</button><span class="nt-muted" style="margin-left:8px">Review before saving.</span></div><button class="nt-btn primary" type="button" id="ntAttSave" disabled>Save Attendance →</button></div>'+
 '<p class="nt-muted" id="ntAttFooter"></p><p class="nt-muted" role="status" id="ntAttStatus"></p><div id="ntAttRisk"></div>';
 $('#ntAttDate').onchange=loadRoster;$('#ntAttClass').onchange=()=>{sectionOptions();loadRoster()};$('#ntAttSection').onchange=loadRoster;
 $('#ntAttTable').addEventListener('click',ev=>{const b=ev.target.closest('[data-student][data-choice]');if(!b||!model.students.some(x=>x.id===b.dataset.student))return;
 model.selection[b.dataset.student]=b.dataset.choice;
 const row=b.closest('tr');row.querySelectorAll('[data-choice]').forEach(x=>x.setAttribute('aria-checked',String(x.dataset.choice===b.dataset.choice)));stats();
 });
 $('#ntAttMarkAll').onclick=()=>{for(const x of model.students)model.selection[x.id]='present';table();say('Everyone marked Present. Check before saving.')};
 $('#ntAttSave').onclick=save;
 const db=a.db;
 const assignment=await db.from('teacher_assignments').select('class_id,section_id').eq('school_id',a.schoolId).eq('teacher_id',a.user.id).eq('is_active',true).limit(200);
 if(v!==revision||!root())return;
 if(assignment.error){$('#ntAttTable').textContent=assignment.error.message;return}
 model.assignments=assignment.data||[];
 if(!model.assignments.length){$('#ntAttTable').innerHTML='<p class="nt-empty">No classes assigned yet. Ask your Principal to assign a class and section.</p>';return}
 const ids=[...new Set(model.assignments.map(x=>x.class_id))];
 const [c,s]=await Promise.all([
 db.from('classes').select('id,name').eq('school_id',a.schoolId).eq('is_active',true).in('id',ids).limit(200),
 db.from('sections').select('id,class_id,name').eq('is_active',true).in('class_id',ids).limit(300)
 ]);
 if(v!==revision||!root())return;
 if(c.error||s.error){$('#ntAttTable').textContent=(c.error||s.error).message;return}
 model.classes=(c.data||[]).sort((x,y)=>nat.compare(x.name,y.name));model.sections=s.data||[];
 classOptions();sectionOptions();await loadRoster();
}
async function loadRoster(){
 const a=APP(),m=model,instance=++revision;
 if(!root()||!m)return;
 const classId=$('#ntAttClass').value,sectionId=$('#ntAttSection').value||null,date=$('#ntAttDate').value;
 if(!classId||!date)return;
 const all=m.assignments.some(x=>x.class_id===classId&&!x.section_id);
 if(!all&&!sectionId){say('Choose your assigned section.',true);return}
 if(date>day()){say('Attendance cannot be marked for a future date.',true);return}
 $('#ntAttTable').innerHTML='<p class="nt-muted">Reading enrolled student records…</p>';
 let q=a.db.from('profiles').select('id,full_name,roll_number').eq('school_id',a.schoolId).eq('role','student').eq('status','active').eq('class_id',classId).limit(1000);
 if(sectionId)q=q.eq('section_id',sectionId);
 let ses=a.db.from('attendance_sessions').select('id,status').eq('school_id',a.schoolId).eq('class_id',classId).eq('attendance_date',date);
 ses=sectionId?ses.eq('section_id',sectionId):ses.is('section_id',null);
 const [users,sessions]=await Promise.all([q,ses.limit(1)]);
 if(instance!==revision||!root())return;
 if(users.error||sessions.error){$('#ntAttTable').textContent=(users.error||sessions.error).message;return}
 m.students=(users.data||[]).sort((x,y)=>nat.compare(x.roll_number||'zzzz',y.roll_number||'zzzz')||nat.compare(x.full_name,y.full_name));
 m.selection={};m.session=sessions.data?.[0]||null;
 if(m.session){
 const records=await a.db.from('attendance_records').select('student_id,status').eq('school_id',a.schoolId).eq('session_id',m.session.id).limit(1000);
 if(instance!==revision||!root())return;
 if(records.error)say('Could not load existing attendance: '+records.error.message,true);
 else for(const row of records.data||[])m.selection[row.student_id]=row.status;
 }
 table();checkAbsences(instance);
}
async function save(){
 if(working||!model?.students.length)return;
 const n=marks();
 if(n.unmarked)return say('Mark Present, Absent or Late for every student first.',true);
 const a=APP(),db=a.db,classId=$('#ntAttClass').value,sectionId=$('#ntAttSection').value||null,attendance_date=$('#ntAttDate').value,m=model;
 working=true;stats();say('Saving attendance securely…');
 try{
 let session=m.session;
 if(!session){
 const newSession=await db.from('attendance_sessions').insert({school_id:a.schoolId,class_id:classId,section_id:sectionId,attendance_date,status:'draft',taken_by:a.user.id}).select('id,status').single();
 if(newSession.error?.code==='23505'){
 let q=db.from('attendance_sessions').select('id,status').eq('school_id',a.schoolId).eq('class_id',classId).eq('attendance_date',attendance_date);
 q=sectionId?q.eq('section_id',sectionId):q.is('section_id',null);const r=await q.single();if(r.error)throw r.error;session=r.data;
 }else{if(newSession.error)throw newSession.error;session=newSession.data}
 }
 const rows=m.students.map(x=>({school_id:a.schoolId,session_id:session.id,student_id:x.id,status:m.selection[x.id],marked_by:a.user.id,marked_at:new Date().toISOString()}));
 const up=await db.from('attendance_records').upsert(rows,{onConflict:'session_id,student_id'});
 if(up.error)throw up.error;
 const done=await db.from('attendance_sessions').update({status:'submitted',submitted_at:new Date().toISOString()}).eq('school_id',a.schoolId).eq('id',session.id);
 if(done.error)throw done.error;
 m.session={id:session.id,status:'submitted'};say('✓ Saved '+n.present+' Present, '+n.absent+' Absent and '+n.late+' Late to school records.');a.toast?.('Student attendance submitted.','success');
 await checkAbsences(revision);
 }catch(err){say('Attendance not fully submitted: '+(err.message||'Retry after checking permissions.'),true)}
 finally{working=false;stats()}
}
async function checkAbsences(instance){
 const box=$('#ntAttRisk');if(!box||!model?.students.length)return;
 const a=APP(),classId=$('#ntAttClass').value,sectionId=$('#ntAttSection').value||null;
 let query=a.db.from('attendance_sessions').select('id,attendance_date').eq('school_id',a.schoolId).eq('class_id',classId).in('status',['submitted','corrected']).order('attendance_date',{ascending:false}).limit(8);
 query=sectionId?query.eq('section_id',sectionId):query.is('section_id',null);
 const sessions=await query;if(instance!==revision||!root())return;
 if(sessions.error){box.innerHTML='<div class="nt-followup">Attendance history could not be loaded.</div>';return}
 const latest=sessions.data||[],ids=latest.map(x=>x.id);if(latest.length<3){box.textContent='';return}
 const r=await a.db.from('attendance_records').select('session_id,student_id,status').eq('school_id',a.schoolId).in('session_id',ids).limit(10000);
 if(instance!==revision||!root()||r.error)return;
 const mapping=new Map(latest.map(s=>[s.id,new Map()]));for(const x of r.data||[])mapping.get(x.session_id)?.set(x.student_id,x.status);
 const concern=[];
 for(const st of model.students){let count=0;for(const session of latest){if(mapping.get(session.id)?.get(st.id)==='absent')count++;else break}if(count>=3)concern.push({st,count})}
 box.innerHTML=concern.length?'<div class="nt-followup"><b>⚠ Attendance follow-up</b><div>'+concern.map(x=>E(x.st.full_name)+' (Roll '+E(x.st.roll_number||'—')+') · '+x.count+' consecutive absences').join('<br>')+'</div></div>':'';
}
window.NOOR_TEACHER_EMBED={mount};
})();