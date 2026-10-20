/* NOOR: school-scoped teacher assignments and student submissions. All access is RLS-protected. */
(()=>{'use strict';
const A=()=>window.NOOR_AI_APP||{};
const E=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const date=s=>s?new Date(s).toLocaleString('en-IN',{dateStyle:'medium',timeStyle:'short'}):'—';
const style=document.createElement('style');style.textContent=[
'.na-wrap{max-width:1160px;margin:0 auto;color:#35242d;font:15px/1.6 "DM Sans",sans-serif}',
'.na-wrap h1{font:800 29px Manrope,sans-serif;color:#58283f;margin:0 0 8px}',
'.na-wrap h2{font:800 18px Manrope,sans-serif;color:#58283f;margin:0 0 9px}',
'.na-card{background:#fffdfb;border:1px solid #ecd6df;border-radius:19px;padding:20px;margin:14px 0;box-shadow:0 6px 23px #43152b0b}',
'.na-muted{color:#77626d;font-size:13px}.na-btn{background:#632b44;color:#fff;border:0;padding:11px 15px;border-radius:11px;font-weight:750;font-size:14px;cursor:pointer}',
'.na-btn.soft{background:#faeaf1;color:#5d2941;border:1px solid #e9c5d5}.na-btn:disabled{opacity:.55}',
'.na-card textarea,.na-card input{width:100%;border:1px solid #d9c0cb;border-radius:10px;padding:11px;font-size:14px;color:#302029;background:#fff;box-sizing:border-box}',
'.na-card textarea{min-height:130px;resize:vertical}.na-row{display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:space-between}',
'.na-tag{background:#f4e4eb;border-radius:20px;padding:5px 10px;font-weight:750;color:#633147;font-size:12px}',
'@media(max-width:580px){.na-card{padding:15px}.na-wrap h1{font-size:24px}.na-btn{min-height:44px}}'
].join('');document.head.append(style);
const view=()=>document.getElementById('view-assignments');
const inform=(msg,bad=false)=>{const el=document.getElementById('naFeedback');if(el){el.textContent=msg;el.style.color=bad?'#a33e49':'#26704d'}};
async function open(){
 const app=A(),p=app.profile,root=view();
 if(!root||p?.role!=='student'||!app.schoolId||!app.db)return;
 root.innerHTML='<div class="na-wrap"><h1>My Assignments</h1><p class="na-muted">Only assignments published for your school, class and section appear here.</p><div id="naFeedback" role="status"></div><div id="naList" class="na-card">Loading assigned work…</div></div>';
 if(!p.class_id){document.getElementById('naList').textContent='Your class has not been assigned yet. Contact school administration.';return;}
 const [assignments,submissions]=await Promise.all([
  app.db.from('noor_class_assignments').select('id,title,body,max_marks,due_at,section_id,subject_id,created_at').eq('school_id',app.schoolId).eq('class_id',p.class_id).eq('status','published').order('due_at',{ascending:true}).limit(150),
  app.db.from('noor_assignment_submissions').select('id,assignment_id,answer_text,marks_obtained,feedback,graded_at,submitted_at').eq('school_id',app.schoolId).eq('student_id',app.user.id).limit(250)
 ]);
 const list=document.getElementById('naList');if(!list)return;
 if(assignments.error||submissions.error){list.textContent='Could not load assignments: '+(assignments.error||submissions.error).message;return}
 const rows=assignments.data||[],submitted=new Map((submissions.data||[]).map(s=>[s.assignment_id,s]));
 if(!rows.length){list.innerHTML='<p class="na-muted">No assignments published for your class yet.</p>';return}
 list.outerHTML='<div id="naList">'+rows.map(x=>{
  const submission=submitted.get(x.id),late=new Date(x.due_at)<new Date();
  return '<section class="na-card" data-assignment="'+E(x.id)+'">'+
   '<div class="na-row"><h2>'+E(x.title)+'</h2><span class="na-tag">'+(submission?'Submitted':'To do')+'</span></div>'+
   '<p class="na-muted">Due: '+E(date(x.due_at))+(late&&!submission?' · Due date passed':'')+' · Max '+E(x.max_marks)+' marks</p>'+
   '<div style="white-space:pre-wrap;overflow-wrap:anywhere">'+E(x.body)+'</div>'+
   '<label style="display:block;margin-top:15px;font-weight:700">My written response<textarea data-answer="'+E(x.id)+'" placeholder="Enter your answers here">'+E(submission?.answer_text||'')+'</textarea></label>'+
   '<div class="na-row"><button class="na-btn" data-submit="'+E(x.id)+'">'+(submission?'Update Response':'Submit Assignment')+'</button>'+
   '<span class="na-muted">'+(submission?.graded_at?'Marks: '+E(submission.marks_obtained)+' / '+E(x.max_marks)+' · Feedback: '+E(submission.feedback||'—'):submission?'Submitted '+E(date(submission.submitted_at)):'Not submitted yet')+'</span></div></section>'
 }).join('')+'</div>';
 root.querySelectorAll('[data-submit]').forEach(button=>button.onclick=async()=>{
  const id=button.dataset.submit,answer=root.querySelector('[data-answer="'+id+'"]')?.value.trim(),existing=submitted.get(id);
  if(!answer)return inform('Write an answer before submitting.',true);
  if(existing?.graded_at)return inform('This assignment has already been graded. Contact your teacher.',true);
  button.disabled=true;inform('Saving your submission…');
  try{
   const req=existing?await app.db.from('noor_assignment_submissions').update({answer_text:answer}).eq('id',existing.id).eq('school_id',app.schoolId).eq('student_id',app.user.id):
     await app.db.from('noor_assignment_submissions').insert({school_id:app.schoolId,assignment_id:id,student_id:app.user.id,answer_text:answer});
   if(req.error)throw req.error;app.toast?.('Assignment submitted securely.','success');await open();
  }catch(err){inform('Submission failed: '+err.message,true)}finally{button.disabled=false}
 });
}
async function publish({title,body,context,due_at,max_marks,paper_draft_id}){
 const app=A();if(app.profile?.role!=='teacher'||!app.schoolId)throw Error('Teacher account required.');
 if(!context?.class_id||!title?.trim()||!body?.trim()||!due_at)throw Error('Class, title, questions and due date are required.');
 if(!Number.isInteger(Number(max_marks))||Number(max_marks)<1||Number(max_marks)>1000)throw Error('Marks must be between 1 and 1000.');
 const r=await app.db.from('noor_class_assignments').insert({
  school_id:app.schoolId,teacher_id:app.user.id,class_id:context.class_id,
  section_id:context.section_id||null,subject_id:context.subject_id||null,paper_draft_id:paper_draft_id||null,
  title:title.trim().slice(0,180),body:body.trim(),max_marks:Number(max_marks),due_at:new Date(due_at).toISOString(),status:'published'
 }).select('id').single();
 if(r.error)throw r.error;app.toast?.('Assignment published to the selected school class.','success');return r.data;
}
async function teacherInbox(){
 const app=A(),area=document.getElementById('ppPublished');
 if(!area||app.profile?.role!=='teacher')return;
 const r=await app.db.from('noor_class_assignments').select('id,title,due_at,max_marks').eq('school_id',app.schoolId).eq('teacher_id',app.user.id).order('created_at',{ascending:false}).limit(50);
 if(r.error){area.textContent=r.error.message;return}
 const assignments=r.data||[];
 area.innerHTML=assignments.map(x=>'<div style="margin:8px 0;padding:12px;border:1px solid #ead7df;border-radius:10px">'+
  '<b>'+E(x.title)+'</b><p style="margin:4px 0;font-size:12px">Due '+E(date(x.due_at))+'</p><button class="na-btn soft" data-inbox="'+E(x.id)+'" type="button">View submissions & grade</button><div data-inbox-content="'+E(x.id)+'"></div></div>').join('')||'<p>No assignments published yet.</p>';
 area.querySelectorAll('[data-inbox]').forEach(button=>button.onclick=async()=>{
  const asg=assignments.find(x=>x.id===button.dataset.inbox),panel=area.querySelector('[data-inbox-content="'+asg.id+'"]');
  panel.textContent='Loading student responses…';
  const data=await app.db.from('noor_assignment_submissions').select('id,student_id,answer_text,marks_obtained,feedback,graded_at').eq('school_id',app.schoolId).eq('assignment_id',asg.id).limit(500);
  if(data.error){panel.textContent=data.error.message;return}
  const studentIds=[...new Set((data.data||[]).map(x=>x.student_id))];
  const profiles=studentIds.length?await app.db.from('profiles').select('id,full_name,roll_number').eq('school_id',app.schoolId).in('id',studentIds):{data:[],error:null};
  const studentNames=new Map((profiles.data||[]).map(x=>[x.id,x.full_name+(x.roll_number?' · Roll '+x.roll_number:'')]));
  panel.innerHTML=(data.data||[]).map(sub=>'<section style="border-top:1px solid #ead7df;padding:10px 0" data-mark="'+E(sub.id)+'">'+
   '<b>'+E(studentNames.get(sub.student_id)||'Student record')+'</b><p style="white-space:pre-wrap">'+E(sub.answer_text)+'</p>'+
   '<label>Marks (max '+E(asg.max_marks)+')<input type="number" min="0" max="'+E(asg.max_marks)+'" step=".5" data-score value="'+E(sub.marks_obtained??'')+'"></label>'+
   '<label>Feedback<input data-feedback value="'+E(sub.feedback||'')+'"></label><button type="button" class="na-btn" data-grade>Save grade</button></section>').join('')||'<p>No student submissions yet.</p>';
  panel.querySelectorAll('[data-grade]').forEach(btn=>btn.onclick=async()=>{
   const row=btn.closest('[data-mark]'),score=Number(row.querySelector('[data-score]').value);
   if(!row.querySelector('[data-score]').value||score<0||score>asg.max_marks)return app.toast?.('Enter a valid grade.','error');
   btn.disabled=true;
   const result=await app.db.from('noor_assignment_submissions').update({marks_obtained:score,feedback:row.querySelector('[data-feedback]').value.trim()||null}).eq('id',row.dataset.mark).eq('school_id',app.schoolId);
   if(result.error)app.toast?.(result.error.message,'error');else app.toast?.('Student grade saved.','success');
   btn.disabled=false;
  });
 });
}
window.NOOR_ASSIGNMENT_PORTAL={open,publish,teacherInbox};
})();