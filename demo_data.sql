-- OPTIONAL – run ONCE in Supabase → SQL Editor (it runs as admin, so RLS does not block it).
-- 1) Authentication → Users → "Add user" (email + password, tick Auto Confirm)
-- 2) Put that email below, then Run.
do $$
declare
  em  text := 'teacher@example.com';   -- <<< CHANGE to the user you created
  uid uuid;
  sid uuid;
begin
  select id into uid from auth.users where email = em;
  if uid is null then raise exception 'Create the user in Authentication → Users first'; end if;

  insert into public.schools (name) values ('Al Noor International School') returning id into sid;

  insert into public.staff (id, school_id, role, profile) values (uid, sid, 'teacher', jsonb_build_object(
    'name', 'Syeda Aafra Fathima', 'role', 'Teacher',
    'tagline', 'Dedicated educator shaping brighter futures.',
    'empId', 'TCH-2026-014', 'joiningDate', '12 Aug 2024',
    'qualification', 'M.Sc. Mathematics, B.Ed.', 'email', em,
    'school', 'Al Noor International School',
    'assignedClass', '8', 'assignedSection', 'B',
    'quote', 'Teaching is shaping brighter tomorrows.',
    'photoSize', 'M', 'photoRadius', 20))
  on conflict (id) do update set profile = excluded.profile, school_id = excluded.school_id;

  insert into public.students (school_id, grade, section, name, roll) values
    (sid,'8','B','Ayesha Khan','801'), (sid,'8','B','Mohammad Zaid','802'),
    (sid,'8','B','Sana Fatima','803'),  (sid,'8','B','Arjun Mehta','804'),
    (sid,'8','B','Ibrahim Ali','805'),  (sid,'8','B','Zoya Siddiqui','806');

  insert into public.timetable (school_id, teacher_id, position, period, start_time, end_time, subject, class_sec, color) values
    (sid,uid,0,'Period 1','08:00','08:45','English','Class 8 – Section B','bg-pink-100 text-pink-600'),
    (sid,uid,1,'Period 2','08:50','09:35','Mathematics','Class 9 – Section A','bg-rose-100 text-rose-600'),
    (sid,uid,2,'Period 3','09:45','10:30','Science','Class 8 – Section A','bg-purple-100 text-purple-600'),
    (sid,uid,3,'Period 4','10:45','11:30','English','Class 7 – Section B','bg-teal-100 text-teal-600'),
    (sid,uid,4,'Period 5','11:35','12:20','Mathematics','Class 10 – Section A','bg-amber-100 text-amber-600');

  insert into public.subject_scores (school_id, grade, section, subject, score) values
    (sid,'8','B','English',92), (sid,'8','B','Mathematics',78), (sid,'8','B','Science',88),
    (sid,'8','B','Social Studies',85), (sid,'8','B','Urdu',90);
end $$;
