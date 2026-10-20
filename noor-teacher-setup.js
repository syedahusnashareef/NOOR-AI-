/* NOOR: principal-only official teaching class/section/subject assignments. */
(()=>{'use strict';
const A=()=>window.NOOR_AI_APP||{};
const E=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const root=()=>document.getElementById('view-teacher-assignments');
let state={classes:[],sections:[],teachers:[],subjects:[],assignments:[]};
const style=document.createElement('style');style.textContent=[
'#view-teacher-assignments{font:15px/1.65 "DM Sans",sans-serif;color:#33222c}',
'#view-teacher-assignments .nts-card{padding:20px;border:1px solid #e9d5df;border-radius:20px;background:#fffdfb;margin:14px 0}',
'#view-teacher-assignments h1{color:#54243b;font:800 29px Manrope;margin:0 0 9px}',
'#view-teacher-assignments label{display:block;font-weight:750;margin:9px 0;font-size:14px}',
'#view-teacher-assignments input,#view-teacher-assignments select{display:block;width:100%;font:inherit;border:1px solid #ddc5cf;background:white;padding:11px;border-radius:10px;margin-top:4px}',
'#view-teacher-assignments button{border:0;background:#5c233b;color:white;border-radius:11px;font:750 14px "DM Sans";padding:12px 16px;min-height:44px;cursor:pointer}',
'#view-teacher-assignments button.secondary{background:#f4e4eb;color:#59243d;border:1px solid #e1c4d1}',
'#view-teacher-assignments .nts-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px 16px}',
'#view-teacher-assignments .nts-muted{font-size:13px;color:#796570}',
'@media(max-width:650px){#view-teacher-assignments .nts-grid{grid-template-columns:1fr}}'
].join('');document.head.append(style);
async function open(){
 const app=A(),el=root();
 if(!el||!app.db||!app.schoolId||!['owner','principal','manager'].includes(app.profile?.role))return;
 el.innerHTML='<h1>Teacher Class Assignments</h1><p class="nts-muted">Assign official school classes and sections. Teachers use these records for timetable, attendance, Smart Notes and papers.</p>'+
 '<section class="nts-card"><button type="button" id="ntsOpenClasses" class="secondary">Manage School Classes & Sections →</button> <button type="button" id="ntsAcademicYear" class="secondary">Academic Years →</button>'+
 '<div id="ntsStatus" role="status" class="nts-muted" style="margin-top:10px">Loading real school data…</div></section>'+
 '<section class="nts-card"><h2>Create official subject</h2><form id="ntsSubjectForm"><div class="nts-grid"><label>Class<select id="ntsSubjectClass" required></select></label><label>Subject name<input id="ntsNewSubject" maxlength="100" placeholder="e.g. Science" required></label></div><button type="submit">Save Subject</button></form></section>'+ 
 '<section class="nts-card"><h2>Assign a teacher</h2><form id="ntsForm"><div class="nts-grid">'+
 '<label>Active teacher<select id="ntsTeacher" required></select></label>'+
 '<label>School class<select id="ntsClass" required></select></label>'+
 '<label>Section<select id="ntsSection"></select></label>'+
 '<label>Subject (optional)<select id="ntsSubject"></select></label>'+
 '</div><button type="submit" id="ntsSave">Save Teacher Assignment</button></form></section>'+
 '<section class="nts-card"><h2>Current teaching assignments</h2><div id="ntsList">Loading…</div></section>';
 el.querySelector('#ntsOpenClasses').onclick=()=>app.openView('classes');
 el.querySelector('#ntsAcademicYear').onclick=()=>app.openView('academic-monitoring');
 el.querySelector('#ntsSubjectForm').onsubmit=saveSubject;
 el.querySelector('#ntsClass').onchange=syncChoices;
 el.querySelector('#ntsForm').onsubmit=save;
 await refresh();
}
function syncChoices(){
 const cl=root()?.querySelector('#ntsClass')?.value||'',secs=state.sections.filter(x=>x.class_id===cl),subs=state.subjects.filter(x=>!x.class_id||x.class_id===cl);
 const sectionOptions='<option value="">All sections / unsectioned class</option>'+secs.map(x=>'<option value="'+E(x.id)+'">'+E(x.name)+'</option>').join('');
 root().querySelector('#ntsSection').innerHTML=sectionOptions;
 root().querySelector('#ntsSubject').innerHTML='<option value="">No subject restriction</option>'+subs.map(x=>'<option value="'+E(x.id)+'">'+E(x.name)+'</option>').join('');
}
async function refresh(){
 const app=A(),el=root(),id=app.schoolId;
 if(!el)return;
 const db=app.db;
 const [teachers,classes,sections,subjects,assignments]=await Promise.all([
  db.from('profiles').select('id,full_name').eq('school_id',id).eq('role','teacher').eq('status','active').order('full_name').limit(500),
  db.from('classes').select('id,name').eq('school_id',id).eq('is_active',true).order('sort_order').limit(200),
  db.from('sections').select('id,class_id,name').eq('is_active',true).limit(500),
  db.from('subjects').select('id,class_id,name').eq('school_id',id).limit(500),
  db.from('teacher_assignments').select('id,teacher_id,class_id,section_id,subject_id,is_active').eq('school_id',id).eq('is_active',true).limit(500)
 ]);
 const err=[teachers,classes,sections,subjects,assignments].find(x=>x.error)?.error;
 const feedback=el.querySelector('#ntsStatus');
 if(err){feedback.textContent='Could not load school assignments: '+err.message;return}
 state={teachers:teachers.data||[],classes:classes.data||[],sections:sections.data||[],subjects:subjects.data||[],assignments:assignments.data||[]};
 el.querySelector('#ntsTeacher').innerHTML=state.teachers.map(x=>'<option value="'+E(x.id)+'">'+E(x.full_name)+'</option>').join('')||'<option value="">No active teachers</option>';
 el.querySelector('#ntsClass').innerHTML=state.classes.map(x=>'<option value="'+E(x.id)+'">'+E(x.name)+'</option>').join('')||'<option value="">No school classes</option>';
 el.querySelector('#ntsSubjectClass').innerHTML=state.classes.map(x=>'<option value="'+E(x.id)+'">'+E(x.name)+'</option>').join('')||'<option value="">Add classes first</option>';
 syncChoices();
 const names=new Map(state.teachers.map(x=>[x.id,x.full_name])),cs=new Map(state.classes.map(x=>[x.id,x.name])),
 ss=new Map(state.sections.map(x=>[x.id,x.name])),su=new Map(state.subjects.map(x=>[x.id,x.name]));
 el.querySelector('#ntsList').innerHTML=state.assignments.map(x=>'<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;border-top:1px solid #eddae2;padding:13px 0;flex-wrap:wrap"><div>'+
 '<b>'+E(names.get(x.teacher_id)||'Teacher')+'</b><div class="nts-muted">'+E(cs.get(x.class_id)||'Class')+
 (x.section_id?' · Section '+E(ss.get(x.section_id)||'—'):' · All sections')+
 (x.subject_id?' · '+E(su.get(x.subject_id)||'Subject'):'')+'</div></div>'+
 '<button class="secondary" type="button" data-disable="'+E(x.id)+'">Unassign</button></div>').join('')||
 '<p class="nts-muted">No assigned classes. Add a school class and assign an active teacher.</p>';
 feedback.textContent='Loaded '+state.teachers.length+' active teachers, '+state.classes.length+' classes and '+state.assignments.length+' active assignments from this school.';
 el.querySelectorAll('[data-disable]').forEach(b=>b.onclick=async()=>{
  if(!confirm('Remove this teaching assignment? Existing student records will be preserved.'))return;
  b.disabled=true;const r=await db.from('teacher_assignments').update({is_active:false}).eq('id',b.dataset.disable).eq('school_id',id);
  if(r.error){feedback.textContent=r.error.message;b.disabled=false}else await refresh();
 });
}
async function saveSubject(event){
 event.preventDefault();
 const app=A(),el=root(),name=el.querySelector('#ntsNewSubject').value.trim(),class_id=el.querySelector('#ntsSubjectClass').value;
 if(!name||!class_id){el.querySelector('#ntsStatus').textContent='Select a class and enter a subject.';return}
 const b=event.submitter;if(b)b.disabled=true;
 try{
  const r=await app.db.from('subjects').insert({school_id:app.schoolId,class_id,name,created_by:app.user.id,is_active:true});
  if(r.error)throw r.error;
  el.querySelector('#ntsNewSubject').value='';app.toast?.('School subject saved.','success');await refresh();
 }catch(err){el.querySelector('#ntsStatus').textContent='Subject could not be created: '+err.message}
 finally{if(b)b.disabled=false}
}
async function save(event){
 event.preventDefault();
 const app=A(),el=root(),btn=el.querySelector('#ntsSave'),teacher_id=el.querySelector('#ntsTeacher').value,
 class_id=el.querySelector('#ntsClass').value,section_id=el.querySelector('#ntsSection').value||null,
 subject_id=el.querySelector('#ntsSubject').value||null;
 if(!teacher_id||!class_id){el.querySelector('#ntsStatus').textContent='Choose an active teacher and official class.';return}
 btn.disabled=true;
 try{
  const r=await app.db.from('teacher_assignments').insert({school_id:app.schoolId,teacher_id,class_id,section_id,subject_id,is_active:true,created_by:app.user.id});
  if(r.error)throw r.error;
  app.toast?.('Teacher assigned successfully.','success');await refresh();
 }catch(err){el.querySelector('#ntsStatus').textContent='Assignment failed: '+err.message}
 finally{btn.disabled=false}
}
window.NOOR_TEACHER_SETUP={open};
})();