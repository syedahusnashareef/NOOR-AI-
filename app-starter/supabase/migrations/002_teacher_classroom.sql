-- NOOR AI Task 2: teacher workspace, class/subject assignment, attendance, enrolment and progress.
-- Apply only AFTER 001_initial_schema.sql in a dedicated NOOR AI Supabase project.
-- Teachers are real authenticated accounts only when teachers.user_id is linked by trusted school management.
-- Students and teachers do not receive self-service privilege escalation.

create extension if not exists pgcrypto;

alter table public.schools
  add column if not exists teachers_can_enroll_students boolean not null default false;

alter table public.students add column if not exists profile_photo_url text;
alter table public.classes add column if not exists is_active boolean not null default true, add column if not exists deactivated_at timestamptz;

alter table public.teachers
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists username text,
  add column if not exists profile_photo_url text;

create unique index if not exists teachers_user_id_uq
  on public.teachers(user_id) where user_id is not null;
create unique index if not exists teachers_username_ci_uq
  on public.teachers (lower(username)) where username is not null;
create unique index if not exists teachers_id_school_uq on public.teachers(id, school_id);

-- A new enrollment or class transfer must target an active class. Updating contact/profile fields
-- on a historical student in a class that was later deactivated remains allowed.
create or replace function public.guard_new_student_class_assignment()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.class_id is not null and (TG_OP = 'INSERT' or old.class_id is distinct from new.class_id) then
    if not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id and c.is_active) then
      raise exception 'New student enrollment must target an active class in the same school' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
create trigger guard_new_student_class before insert or update of class_id, school_id on public.students
  for each row execute function public.guard_new_student_class_assignment();
revoke all on function public.guard_new_student_class_assignment() from public, anon, authenticated;

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  code text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name),
  unique (school_id, code)
);

create table if not exists public.teacher_class_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  is_class_teacher boolean not null default false,
  is_active boolean not null default true,
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (teacher_id, class_id)
);
create index if not exists teacher_class_assignments_class_idx
  on public.teacher_class_assignments(class_id, is_active);
create index if not exists teacher_class_assignments_teacher_idx
  on public.teacher_class_assignments(teacher_id, is_active);
create unique index if not exists one_active_class_teacher_per_class
  on public.teacher_class_assignments(class_id)
  where is_active and is_class_teacher;

create table if not exists public.teacher_subject_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  is_active boolean not null default true,
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  unique (teacher_id, class_id, subject_id)
);
create index if not exists teacher_subject_assignments_teacher_idx
  on public.teacher_subject_assignments(teacher_id, is_active);

create table if not exists public.school_calendar (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  calendar_date date not null,
  is_school_day boolean not null default true,
  label text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (school_id, calendar_date)
);

create table if not exists public.classwork (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  teacher_id uuid references public.teachers(id) on delete set null,
  title text not null,
  instructions text,
  work_type text not null default 'assignment' check (work_type in ('assignment','homework','project','notice')),
  due_date date,
  status text not null default 'published' check (status in ('draft','published','archived')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists classwork_school_class_due_idx
  on public.classwork(school_id, class_id, due_date);

create table if not exists public.student_enrollment_history (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete restrict,
  valid_from date not null,
  valid_to date,
  changed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to >= valid_from)
);
create index if not exists student_history_date_idx
  on public.student_enrollment_history(student_id, valid_from, valid_to);

create table if not exists public.student_enrollment_requests (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete restrict,
  teacher_id uuid not null references public.teachers(id) on delete restrict,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  admission_number text not null,
  first_name text not null,
  last_name text,
  guardian_name text,
  guardian_phone text,
  profile_photo_url text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  linked_student_id uuid references public.students(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists one_pending_enrollment_request_per_admission
  on public.student_enrollment_requests(school_id, admission_number) where status = 'pending';
create index if not exists enrollment_requests_school_status_idx
  on public.student_enrollment_requests(school_id, status, created_at desc);

create table if not exists public.attendance_audit (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  attendance_record_id uuid not null,
  student_id uuid not null,
  class_id uuid,
  attendance_date date not null,
  event_type text not null check (event_type in ('created','corrected','removed')),
  old_status text,
  new_status text,
  old_note text,
  new_note text,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);
create index if not exists attendance_audit_school_date_idx
  on public.attendance_audit(school_id, attendance_date desc);

-- A teacher can only see a class while their active assignment remains in the database.
-- Security-definer functions are narrow boolean predicates; browser roles cannot execute them directly.
create or replace function public.is_assigned_teacher_class(p_class_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.teacher_class_assignments a
    join public.teachers t on t.id = a.teacher_id and t.school_id = a.school_id
    where a.class_id = p_class_id and a.is_active and t.status = 'active'
      and exists (select 1 from public.classes c where c.id = a.class_id and c.is_active)
      and t.user_id = (select auth.uid())
  ) or exists (
    select 1 from public.classes c
    join public.teachers t on t.id = c.class_teacher_id and t.school_id = c.school_id
    where c.id = p_class_id and c.is_active and t.status = 'active' and t.user_id = (select auth.uid())
  );
$$;

create or replace function public.is_assigned_teacher_school(p_school_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.teachers t
    where t.school_id = p_school_id and t.user_id = (select auth.uid()) and t.status = 'active'
      and (
        exists (select 1 from public.teacher_class_assignments a join public.classes c on c.id = a.class_id where a.teacher_id = t.id and a.is_active and c.is_active)
        or exists (select 1 from public.classes c where c.class_teacher_id = t.id and c.is_active)
      )
  );
$$;

revoke all on function public.is_assigned_teacher_class(uuid) from public, anon;
revoke all on function public.is_assigned_teacher_school(uuid) from public, anon;
grant execute on function public.is_assigned_teacher_class(uuid) to authenticated;
grant execute on function public.is_assigned_teacher_school(uuid) to authenticated;

-- Validate every assignment stays within one school's boundary.
create or replace function public.check_teaching_assignment_school()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from public.teachers t where t.id = new.teacher_id and t.school_id = new.school_id) then
    raise exception 'Teacher must belong to the assignment school' using errcode = '23514';
  end if;
  if not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
    raise exception 'Class must belong to the assignment school' using errcode = '23514';
  end if;
  if TG_TABLE_NAME = 'teacher_subject_assignments' and not exists (
    select 1 from public.subjects s where s.id = new.subject_id and s.school_id = new.school_id and s.is_active
  ) then
    raise exception 'Subject must be active and belong to the assignment school' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger teacher_class_assignment_school_check
  before insert or update on public.teacher_class_assignments
  for each row execute function public.check_teaching_assignment_school();
create trigger teacher_subject_assignment_school_check
  before insert or update on public.teacher_subject_assignments
  for each row execute function public.check_teaching_assignment_school();

create or replace function public.sync_class_teacher_designation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target_class uuid;
begin
  target_class := coalesce(new.class_id, old.class_id);
  update public.classes c
    set class_teacher_id = (
      select a.teacher_id from public.teacher_class_assignments a
      where a.class_id = target_class and a.is_active and a.is_class_teacher
      order by a.assigned_at desc limit 1
    )
  where c.id = target_class;
  if TG_OP = 'DELETE' then return old; else return new; end if;
end;
$$;
create trigger sync_class_teacher_after_assignment
  after insert or update or delete on public.teacher_class_assignments
  for each row execute function public.sync_class_teacher_designation();

-- Keep enrolment history when a student is added or transferred; past attendance and marks remain intact.
create or replace function public.record_student_class_history()
returns trigger language plpgsql security definer set search_path = '' as $$
declare local_day date;
begin
  select (now() at time zone s.timezone)::date into local_day
    from public.schools s where s.id = new.school_id;
  local_day := coalesce(local_day, current_date);

  if TG_OP = 'INSERT' then
    if new.class_id is not null then
      insert into public.student_enrollment_history(school_id, student_id, class_id, valid_from, changed_by)
      values (new.school_id, new.id, new.class_id, coalesce(new.joined_on, local_day), auth.uid());
    end if;
  elsif old.class_id is distinct from new.class_id then
    update public.student_enrollment_history h
      set valid_to = local_day - 1, changed_by = auth.uid()
      where h.student_id = new.id and h.valid_to is null and h.valid_from < local_day;
    delete from public.student_enrollment_history h
      where h.student_id = new.id and h.valid_to is null and h.valid_from >= local_day;
    if new.class_id is not null then
      insert into public.student_enrollment_history(school_id, student_id, class_id, valid_from, changed_by)
      values (new.school_id, new.id, new.class_id, local_day, auth.uid());
    end if;
  end if;
  return new;
end;
$$;
create trigger student_enrollment_history_insert
  after insert on public.students for each row execute function public.record_student_class_history();
create trigger student_enrollment_history_transfer
  after update of class_id on public.students for each row execute function public.record_student_class_history();

-- Audit initial marking and every later correction. Client-provided actor IDs are never trusted.
create or replace function public.audit_attendance_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.attendance_audit(school_id, attendance_record_id, student_id, class_id, attendance_date,
      event_type, new_status, new_note, changed_by)
    values (new.school_id, new.id, new.student_id, new.class_id, new.attendance_date,
      'created', new.status::text, new.note, auth.uid());
    return new;
  elsif TG_OP = 'UPDATE' then
    if old.status is distinct from new.status or old.note is distinct from new.note or old.class_id is distinct from new.class_id then
      insert into public.attendance_audit(school_id, attendance_record_id, student_id, class_id, attendance_date,
        event_type, old_status, new_status, old_note, new_note, changed_by)
      values (new.school_id, new.id, new.student_id, new.class_id, new.attendance_date,
        'corrected', old.status::text, new.status::text, old.note, new.note, auth.uid());
    end if;
    return new;
  else
    insert into public.attendance_audit(school_id, attendance_record_id, student_id, class_id, attendance_date,
      event_type, old_status, old_note, changed_by)
    values (old.school_id, old.id, old.student_id, old.class_id, old.attendance_date,
      'removed', old.status::text, old.note, auth.uid());
    return old;
  end if;
end;
$$;
create trigger attendance_audit_trigger
  after insert or update or delete on public.attendance_records
  for each row execute function public.audit_attendance_change();

-- Make sure class, student, assessment and attendance rows cannot use a parent from another school.
create or replace function public.check_classroom_relationships()
returns trigger language plpgsql set search_path = '' as $$
begin
  if TG_TABLE_NAME = 'classwork' then
    if not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
      raise exception 'Classwork class must belong to the same school' using errcode = '23514';
    end if;
    if new.subject_id is not null and not exists (select 1 from public.subjects s where s.id = new.subject_id and s.school_id = new.school_id) then
      raise exception 'Classwork subject must belong to the same school' using errcode = '23514';
    end if;
    if new.teacher_id is not null and not exists (select 1 from public.teachers t where t.id = new.teacher_id and t.school_id = new.school_id) then
      raise exception 'Classwork teacher must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'student_enrollment_history' then
    if not exists (select 1 from public.students s where s.id = new.student_id and s.school_id = new.school_id)
       or not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
      raise exception 'Enrollment history student and class must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'student_enrollment_requests' then
    if not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id)
       or not exists (select 1 from public.teachers t where t.id = new.teacher_id and t.school_id = new.school_id) then
      raise exception 'Enrollment request class and teacher must belong to the same school' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
create trigger classwork_relationship_check before insert or update on public.classwork
  for each row execute function public.check_classroom_relationships();
create trigger enrollment_history_relationship_check before insert or update on public.student_enrollment_history
  for each row execute function public.check_classroom_relationships();
create trigger enrollment_request_relationship_check before insert or update on public.student_enrollment_requests
  for each row execute function public.check_classroom_relationships();

-- RLS: every new table is protected; teacher access depends on active database assignments.
alter table public.subjects enable row level security;
alter table public.teacher_class_assignments enable row level security;
alter table public.teacher_subject_assignments enable row level security;
alter table public.school_calendar enable row level security;
alter table public.classwork enable row level security;
alter table public.student_enrollment_history enable row level security;
alter table public.student_enrollment_requests enable row level security;
alter table public.attendance_audit enable row level security;

-- Schools and lookup records become visible to authenticated teachers only for their assigned school.
drop policy if exists schools_select_accessible on public.schools;
create policy schools_select_accessible on public.schools for select to authenticated
  using (public.can_access_school(id) or public.is_assigned_teacher_school(id));

drop policy if exists classes_read on public.classes;
create policy classes_read on public.classes for select to authenticated
  using (public.can_access_school(school_id) or public.is_assigned_teacher_class(id));

create policy teachers_select_self on public.teachers for select to authenticated
  using (user_id = (select auth.uid()) or public.is_creator() or public.has_school_permission(school_id, 'view_teachers') or public.has_school_permission(school_id, 'manage_teachers'));

create policy academic_years_teacher_read on public.academic_years for select to authenticated
  using (public.is_assigned_teacher_school(school_id));

create policy subjects_read on public.subjects for select to authenticated
  using (public.can_access_school(school_id) or public.is_assigned_teacher_school(school_id));
create policy subjects_write on public.subjects for all to authenticated
  using (public.has_school_permission(school_id, 'manage_classes'))
  with check (public.has_school_permission(school_id, 'manage_classes'));

create policy teacher_class_assignment_read on public.teacher_class_assignments for select to authenticated
  using (public.can_access_school(school_id) or public.is_assigned_teacher_school(school_id));
create policy teacher_class_assignment_write on public.teacher_class_assignments for all to authenticated
  using (public.has_school_permission(school_id, 'manage_teachers'))
  with check (public.has_school_permission(school_id, 'manage_teachers'));

create policy teacher_subject_assignment_read on public.teacher_subject_assignments for select to authenticated
  using (public.can_access_school(school_id) or public.is_assigned_teacher_school(school_id));
create policy teacher_subject_assignment_write on public.teacher_subject_assignments for all to authenticated
  using (public.has_school_permission(school_id, 'manage_teachers'))
  with check (public.has_school_permission(school_id, 'manage_teachers'));

create policy school_calendar_read on public.school_calendar for select to authenticated
  using (public.can_access_school(school_id) or public.is_assigned_teacher_school(school_id));
create policy school_calendar_write on public.school_calendar for all to authenticated
  using (public.has_school_permission(school_id, 'manage_school_settings'))
  with check (public.has_school_permission(school_id, 'manage_school_settings'));

create policy classwork_read on public.classwork for select to authenticated
  using (public.can_access_school(school_id) or public.is_assigned_teacher_class(class_id));
create policy classwork_write on public.classwork for all to authenticated
  using (public.has_school_permission(school_id, 'manage_academics') or public.is_assigned_teacher_class(class_id))
  with check (public.has_school_permission(school_id, 'manage_academics') or public.is_assigned_teacher_class(class_id));

create policy enrollment_history_read on public.student_enrollment_history for select to authenticated
  using (public.has_school_permission(school_id, 'view_students') or public.has_school_permission(school_id, 'manage_students'));
create policy enrollment_history_teacher_read on public.student_enrollment_history for select to authenticated
  using (public.is_assigned_teacher_class(class_id));
create policy enrollment_request_teacher_insert on public.student_enrollment_requests for insert to authenticated
  with check (
    requested_by = (select auth.uid()) and public.is_assigned_teacher_class(class_id)
    and exists (select 1 from public.teachers t where t.id = student_enrollment_requests.teacher_id and t.user_id = (select auth.uid()) and t.school_id = student_enrollment_requests.school_id)
  );
create policy enrollment_request_read on public.student_enrollment_requests for select to authenticated
  using (public.has_school_permission(school_id, 'view_students') or public.has_school_permission(school_id, 'manage_students') or requested_by = (select auth.uid()));
create policy enrollment_request_review on public.student_enrollment_requests for update to authenticated
  using (public.has_school_permission(school_id, 'manage_students'))
  with check (public.has_school_permission(school_id, 'manage_students'));

create policy attendance_audit_management_read on public.attendance_audit for select to authenticated
  using (public.is_creator() or public.has_school_permission(school_id, 'view_audit_logs') or public.has_school_permission(school_id, 'manage_attendance'));

-- Extend existing policies without broadening student, school or class access beyond the assigned classroom.
drop policy if exists students_read on public.students;
create policy students_read on public.students for select to authenticated
  using (
    (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_students') or public.has_school_permission(school_id, 'manage_students')))
    or (status = 'active' and class_id is not null and public.is_assigned_teacher_class(class_id))
  );
drop policy if exists students_write on public.students;
create policy students_insert_management on public.students for insert to authenticated
  with check (public.has_school_permission(school_id, 'manage_students'));
create policy students_insert_teacher_when_enabled on public.students for insert to authenticated
  with check (
    class_id is not null and public.is_assigned_teacher_class(class_id)
    and exists (select 1 from public.schools s where s.id = school_id and s.teachers_can_enroll_students)
  );
create policy students_update_management on public.students for update to authenticated
  using (public.has_school_permission(school_id, 'manage_students'))
  with check (public.has_school_permission(school_id, 'manage_students'));
create policy students_delete_management on public.students for delete to authenticated
  using (public.has_school_permission(school_id, 'manage_students'));

-- Attendance RLS is class-based for teachers and school-permission based for management users.
drop policy if exists attendance_read on public.attendance_records;
create policy attendance_read on public.attendance_records for select to authenticated
  using (
    (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_attendance') or public.has_school_permission(school_id, 'manage_attendance')))
    or (class_id is not null and public.is_assigned_teacher_class(class_id))
  );
drop policy if exists attendance_write on public.attendance_records;
create policy attendance_insert on public.attendance_records for insert to authenticated
  with check (
    public.has_school_permission(school_id, 'manage_attendance')
    or (class_id is not null and public.is_assigned_teacher_class(class_id)
      and exists (select 1 from public.students s where s.id = student_id and s.school_id = attendance_records.school_id)
      and exists (select 1 from public.classes c where c.id = class_id and c.school_id = attendance_records.school_id))
  );
create policy attendance_update on public.attendance_records for update to authenticated
  using (public.has_school_permission(school_id, 'manage_attendance') or (class_id is not null and public.is_assigned_teacher_class(class_id)))
  with check (public.has_school_permission(school_id, 'manage_attendance') or (class_id is not null and public.is_assigned_teacher_class(class_id)));
create policy attendance_delete_management on public.attendance_records for delete to authenticated
  using (public.has_school_permission(school_id, 'manage_attendance'));

-- Assessment access inherits the assigned class boundary; teachers can manage assessments/results only in their classes.
drop policy if exists assessments_read on public.assessments;
create policy assessments_read on public.assessments for select to authenticated
  using (
    (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_academics') or public.has_school_permission(school_id, 'manage_academics')))
    or (class_id is not null and public.is_assigned_teacher_class(class_id))
  );
drop policy if exists assessments_write on public.assessments;
create policy assessments_write on public.assessments for all to authenticated
  using (public.has_school_permission(school_id, 'manage_academics') or (class_id is not null and public.is_assigned_teacher_class(class_id)))
  with check (public.has_school_permission(school_id, 'manage_academics') or (class_id is not null and public.is_assigned_teacher_class(class_id)));

drop policy if exists results_read on public.assessment_results;
create policy results_read on public.assessment_results for select to authenticated
  using (
    (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_academics') or public.has_school_permission(school_id, 'manage_academics')))
    or exists (select 1 from public.assessments a where a.id = assessment_id and a.class_id is not null and public.is_assigned_teacher_class(a.class_id))
  );
drop policy if exists results_write on public.assessment_results;
create policy results_write on public.assessment_results for all to authenticated
  using (
    public.has_school_permission(school_id, 'manage_academics')
    or exists (select 1 from public.assessments a where a.id = assessment_id and a.class_id is not null and public.is_assigned_teacher_class(a.class_id))
  )
  with check (
    public.has_school_permission(school_id, 'manage_academics')
    or exists (select 1 from public.assessments a where a.id = assessment_id and a.class_id is not null and public.is_assigned_teacher_class(a.class_id))
  );

-- Save a class register atomically. Unmarked students are omitted, never converted to present implicitly.
create or replace function public.save_class_attendance(
  p_class_id uuid,
  p_attendance_date date,
  p_records jsonb
) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare
  v_school_id uuid;
  v_timezone text;
  v_local_today date;
  v_total integer;
  v_distinct integer;
  v_saved integer := 0;
  v_item record;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select c.school_id, s.timezone into v_school_id, v_timezone
    from public.classes c join public.schools s on s.id = c.school_id where c.id = p_class_id;
  if v_school_id is null then
    raise exception 'Class not found' using errcode = 'P0002';
  end if;
  if not (public.has_school_permission(v_school_id, 'manage_attendance') or public.is_assigned_teacher_class(p_class_id)) then
    raise exception 'You are not assigned to this class' using errcode = '42501';
  end if;
  v_local_today := (now() at time zone coalesce(v_timezone, 'Asia/Kolkata'))::date;
  if p_attendance_date > v_local_today then
    raise exception 'Attendance cannot be recorded for a future school-local date' using errcode = '22007';
  end if;
  if exists (select 1 from public.school_calendar sc where sc.school_id = v_school_id and sc.calendar_date = p_attendance_date and not sc.is_school_day) then
    raise exception 'The school calendar marks this date as a non-school day' using errcode = '22007';
  end if;
  if p_records is null or jsonb_typeof(p_records) <> 'array' or jsonb_array_length(p_records) = 0 then
    raise exception 'Select at least one marked student before saving' using errcode = '22023';
  end if;
  select count(*), count(distinct x.student_id) into v_total, v_distinct
    from jsonb_to_recordset(p_records) as x(student_id uuid, status text, note text);
  if v_total <> v_distinct then
    raise exception 'Duplicate student in attendance submission' using errcode = '23505';
  end if;

  for v_item in select * from jsonb_to_recordset(p_records) as x(student_id uuid, status text, note text) loop
    if v_item.status not in ('present','absent','late','excused') then
      raise exception 'Invalid attendance status' using errcode = '22023';
    end if;
    if not exists (
      select 1 from public.students st
      where st.id = v_item.student_id and st.school_id = v_school_id
        and exists (
          select 1 from public.student_enrollment_history h
          where h.student_id = st.id and h.school_id = v_school_id and h.class_id = p_class_id
            and h.valid_from <= p_attendance_date and (h.valid_to is null or h.valid_to >= p_attendance_date)
        )
    ) then
      -- Legacy fallback is allowed only when no history exists at all for this student.
      -- Once history has been recorded, dates must fall inside an explicit enrolment interval.
      if exists (select 1 from public.student_enrollment_history h where h.student_id = v_item.student_id and h.school_id = v_school_id)
         or not exists (select 1 from public.students st where st.id = v_item.student_id and st.school_id = v_school_id and st.class_id = p_class_id) then
        raise exception 'Student is not enrolled in this class for the selected date' using errcode = '42501';
      end if;
    end if;
    insert into public.attendance_records(school_id, student_id, class_id, attendance_date, status, note, recorded_by)
      values (v_school_id, v_item.student_id, p_class_id, p_attendance_date,
        v_item.status::public.attendance_status, nullif(v_item.note, ''), (select auth.uid()))
      on conflict (student_id, attendance_date) do update set
        school_id = excluded.school_id,
        class_id = excluded.class_id,
        status = excluded.status,
        note = excluded.note,
        recorded_by = excluded.recorded_by;
    v_saved := v_saved + 1;
  end loop;

  return jsonb_build_object('saved', v_saved, 'class_id', p_class_id, 'attendance_date', p_attendance_date);
end;
$$;
revoke all on function public.save_class_attendance(uuid, date, jsonb) from public, anon;
grant execute on function public.save_class_attendance(uuid, date, jsonb) to authenticated;

-- Table access grants are kept for authenticated users; row access remains restricted by RLS.
grant select, insert, update, delete on public.subjects, public.teacher_class_assignments,
  public.teacher_subject_assignments, public.school_calendar, public.classwork,
  public.student_enrollment_history, public.student_enrollment_requests, public.attendance_audit to authenticated;

-- Transactional management actions prevent partial class-teacher changes and unsafe enrollment transfers.
create or replace function public.assign_teacher_to_class(
  p_school_id uuid, p_teacher_id uuid, p_class_id uuid, p_is_class_teacher boolean default false
) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare v_assignment_id uuid;
begin
  if not public.has_school_permission(p_school_id, 'manage_teachers') then
    raise exception 'Teacher assignment permission required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.teachers where id = p_teacher_id and school_id = p_school_id and status = 'active')
    or not exists (select 1 from public.classes where id = p_class_id and school_id = p_school_id and is_active) then
    raise exception 'Teacher or class does not belong to the selected school' using errcode = '23514';
  end if;
  if p_is_class_teacher then
    update public.teacher_class_assignments set is_class_teacher = false
      where class_id = p_class_id and school_id = p_school_id and is_active and is_class_teacher and teacher_id <> p_teacher_id;
  end if;
  insert into public.teacher_class_assignments(school_id, teacher_id, class_id, is_class_teacher, is_active, assigned_by, assigned_at, revoked_at)
    values (p_school_id, p_teacher_id, p_class_id, p_is_class_teacher, true, (select auth.uid()), now(), null)
  on conflict (teacher_id, class_id) do update set
    is_class_teacher = excluded.is_class_teacher, is_active = true, assigned_by = excluded.assigned_by,
    assigned_at = now(), revoked_at = null
  returning id into v_assignment_id;
  return v_assignment_id;
end;
$$;

create or replace function public.assign_teacher_subject(
  p_school_id uuid, p_teacher_id uuid, p_class_id uuid, p_subject_id uuid
) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare v_id uuid;
begin
  if not public.has_school_permission(p_school_id, 'manage_teachers') then
    raise exception 'Teacher subject assignment permission required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.teacher_class_assignments a where a.school_id = p_school_id and a.teacher_id = p_teacher_id and a.class_id = p_class_id and a.is_active)
    and not exists (select 1 from public.classes c join public.teachers t on t.id = c.class_teacher_id where c.id = p_class_id and c.school_id = p_school_id and c.is_active and t.id = p_teacher_id) then
    raise exception 'Assign the teacher to this class before assigning a subject' using errcode = '23514';
  end if;
  if not exists (select 1 from public.subjects where id = p_subject_id and school_id = p_school_id and is_active) then
    raise exception 'Subject does not belong to the selected school or is inactive' using errcode = '23514';
  end if;
  insert into public.teacher_subject_assignments(school_id, teacher_id, class_id, subject_id, is_active, assigned_by)
    values (p_school_id, p_teacher_id, p_class_id, p_subject_id, true, (select auth.uid()))
  on conflict (teacher_id, class_id, subject_id) do update set is_active = true, assigned_by = excluded.assigned_by, assigned_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.revoke_teacher_class_assignment(p_assignment_id uuid)
returns boolean
language plpgsql security invoker set search_path = '' as $$
declare v_row public.teacher_class_assignments%rowtype;
begin
  select * into v_row from public.teacher_class_assignments where id = p_assignment_id for update;
  if not found then raise exception 'Assignment not found' using errcode = 'P0002'; end if;
  if not public.has_school_permission(v_row.school_id, 'manage_teachers') then
    raise exception 'Teacher assignment permission required' using errcode = '42501';
  end if;
  update public.teacher_class_assignments set is_active = false, is_class_teacher = false, revoked_at = now() where id = p_assignment_id;
  update public.teacher_subject_assignments set is_active = false where teacher_id = v_row.teacher_id and class_id = v_row.class_id;
  return true;
end;
$$;

create or replace function public.set_current_academic_year(p_school_id uuid, p_academic_year_id uuid)
returns boolean
language plpgsql security invoker set search_path = '' as $$
begin
  if not public.has_school_permission(p_school_id, 'manage_school_settings') then
    raise exception 'Academic-year management permission required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.academic_years where id = p_academic_year_id and school_id = p_school_id) then
    raise exception 'Academic year does not belong to the selected school' using errcode = '23514';
  end if;
  update public.academic_years set is_current = false where school_id = p_school_id and is_current;
  update public.academic_years set is_current = true where id = p_academic_year_id and school_id = p_school_id;
  return true;
end;
$$;

create or replace function public.transfer_student_enrollment(p_school_id uuid, p_student_id uuid, p_new_class_id uuid)
returns boolean
language plpgsql security invoker set search_path = '' as $$
begin
  if not public.has_school_permission(p_school_id, 'manage_students') then
    raise exception 'Student transfer permission required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.students where id = p_student_id and school_id = p_school_id)
    or not exists (select 1 from public.classes where id = p_new_class_id and school_id = p_school_id and is_active) then
    raise exception 'Student or target class does not belong to the selected school' using errcode = '23514';
  end if;
  update public.students set class_id = p_new_class_id, status = 'active', updated_at = now()
    where id = p_student_id and school_id = p_school_id;
  return true;
end;
$$;

create or replace function public.deactivate_student_enrollment(p_school_id uuid, p_student_id uuid, p_new_status text default 'inactive')
returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_timezone text; v_day date;
begin
  if not public.has_school_permission(p_school_id, 'manage_students') then
    raise exception 'Student enrollment management permission required' using errcode = '42501';
  end if;
  if p_new_status not in ('inactive','transferred','graduated') then
    raise exception 'Invalid student status' using errcode = '22023';
  end if;
  select timezone into v_timezone from public.schools where id = p_school_id;
  if not exists (select 1 from public.students where id = p_student_id and school_id = p_school_id) then
    raise exception 'Student not found in this school' using errcode = 'P0002';
  end if;
  v_day := (now() at time zone coalesce(v_timezone, 'Asia/Kolkata'))::date;
  update public.student_enrollment_history set valid_to = v_day - 1, changed_by = (select auth.uid())
    where student_id = p_student_id and school_id = p_school_id and valid_to is null and valid_from < v_day;
  delete from public.student_enrollment_history where student_id = p_student_id and school_id = p_school_id and valid_to is null and valid_from >= v_day;
  update public.students set status = p_new_status, updated_at = now() where id = p_student_id and school_id = p_school_id;
  return true;
end;
$$;

create or replace function public.review_student_enrollment_request(p_request_id uuid, p_approve boolean, p_review_note text default null)
returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare v_req public.student_enrollment_requests%rowtype; v_student_id uuid; v_timezone text;
begin
  select * into v_req from public.student_enrollment_requests where id = p_request_id for update;
  if not found then raise exception 'Enrollment request not found' using errcode = 'P0002'; end if;
  if not public.has_school_permission(v_req.school_id, 'manage_students') then
    raise exception 'Enrollment approval permission required' using errcode = '42501';
  end if;
  if v_req.status <> 'pending' then raise exception 'This request has already been reviewed' using errcode = '23514'; end if;
  if p_approve then
    if not exists (select 1 from public.classes where id = v_req.class_id and school_id = v_req.school_id and is_active) then
      raise exception 'Enrollment target class is inactive' using errcode = '23514';
    end if;
    select timezone into v_timezone from public.schools where id = v_req.school_id;
    insert into public.students(school_id, admission_number, first_name, last_name, class_id, guardian_name, guardian_phone, profile_photo_url, status, joined_on)
      values (v_req.school_id, v_req.admission_number, v_req.first_name, v_req.last_name, v_req.class_id,
        v_req.guardian_name, v_req.guardian_phone, v_req.profile_photo_url, 'active', (now() at time zone coalesce(v_timezone, 'Asia/Kolkata'))::date)
      returning id into v_student_id;
    update public.student_enrollment_requests set status = 'approved', reviewed_by = (select auth.uid()), reviewed_at = now(), review_note = p_review_note, linked_student_id = v_student_id where id = p_request_id;
    return jsonb_build_object('approved', true, 'student_id', v_student_id);
  else
    update public.student_enrollment_requests set status = 'rejected', reviewed_by = (select auth.uid()), reviewed_at = now(), review_note = p_review_note where id = p_request_id;
    return jsonb_build_object('approved', false, 'request_id', p_request_id);
  end if;
end;
$$;

revoke all on function public.assign_teacher_to_class(uuid, uuid, uuid, boolean) from public, anon;
revoke all on function public.assign_teacher_subject(uuid, uuid, uuid, uuid) from public, anon;
revoke all on function public.revoke_teacher_class_assignment(uuid) from public, anon;
revoke all on function public.set_current_academic_year(uuid, uuid) from public, anon;
revoke all on function public.transfer_student_enrollment(uuid, uuid, uuid) from public, anon;
revoke all on function public.deactivate_student_enrollment(uuid, uuid, text) from public, anon;
revoke all on function public.review_student_enrollment_request(uuid, boolean, text) from public, anon;
grant execute on function public.assign_teacher_to_class(uuid, uuid, uuid, boolean) to authenticated;
grant execute on function public.assign_teacher_subject(uuid, uuid, uuid, uuid) to authenticated;
grant execute on function public.revoke_teacher_class_assignment(uuid) to authenticated;
grant execute on function public.set_current_academic_year(uuid, uuid) to authenticated;
grant execute on function public.transfer_student_enrollment(uuid, uuid, uuid) to authenticated;
grant execute on function public.deactivate_student_enrollment(uuid, uuid, text) to authenticated;
grant execute on function public.review_student_enrollment_request(uuid, boolean, text) to authenticated;


-- Prefer soft-deactivation for classrooms, subjects and teacher records to retain historical relationships.
drop policy if exists classes_write on public.classes;
create policy classes_insert_management on public.classes for insert to authenticated
  with check (public.has_school_permission(school_id, 'manage_classes'));
create policy classes_update_management on public.classes for update to authenticated
  using (public.has_school_permission(school_id, 'manage_classes'))
  with check (public.has_school_permission(school_id, 'manage_classes'));
-- No direct class DELETE policy is intentionally provided.
drop policy if exists subjects_write on public.subjects;
create policy subjects_insert_management on public.subjects for insert to authenticated
  with check (public.has_school_permission(school_id, 'manage_classes'));
create policy subjects_update_management on public.subjects for update to authenticated
  using (public.has_school_permission(school_id, 'manage_classes'))
  with check (public.has_school_permission(school_id, 'manage_classes'));
drop policy if exists teachers_write on public.teachers;
create policy teachers_insert_management on public.teachers for insert to authenticated
  with check (public.has_school_permission(school_id, 'manage_teachers'));
create policy teachers_update_management on public.teachers for update to authenticated
  using (public.has_school_permission(school_id, 'manage_teachers'))
  with check (public.has_school_permission(school_id, 'manage_teachers'));

create or replace function public.deactivate_school_class(p_school_id uuid, p_class_id uuid)
returns boolean
language plpgsql security invoker set search_path = '' as $$
begin
  if not public.has_school_permission(p_school_id, 'manage_classes') then
    raise exception 'Class management permission required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.classes where id = p_class_id and school_id = p_school_id) then
    raise exception 'Class not found in this school' using errcode = 'P0002';
  end if;
  update public.classes set is_active = false, deactivated_at = now() where id = p_class_id and school_id = p_school_id;
  update public.teacher_class_assignments set is_active = false, is_class_teacher = false, revoked_at = now()
    where class_id = p_class_id and school_id = p_school_id and is_active;
  update public.teacher_subject_assignments set is_active = false where class_id = p_class_id and school_id = p_school_id;
  return true;
end;
$$;
revoke all on function public.deactivate_school_class(uuid, uuid) from public, anon;
grant execute on function public.deactivate_school_class(uuid, uuid) to authenticated;

-- Internal trigger functions cannot be called directly from browser roles.
revoke all on function public.sync_class_teacher_designation() from public, anon, authenticated;
revoke all on function public.record_student_class_history() from public, anon, authenticated;
revoke all on function public.audit_attendance_change() from public, anon, authenticated;

-- Subject-level authorization: class roster/attendance access does not automatically grant access to every subject's marks.
alter table public.assessments add column if not exists subject_id uuid references public.subjects(id) on delete set null;

create or replace function public.is_current_user_teacher(p_teacher_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.teachers t where t.id = p_teacher_id and t.user_id = (select auth.uid()) and t.status = 'active');
$$;

create or replace function public.is_assigned_class_teacher(p_class_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.teacher_class_assignments a
    join public.teachers t on t.id = a.teacher_id and t.school_id = a.school_id
    join public.classes c on c.id = a.class_id and c.school_id = a.school_id
    where a.class_id = p_class_id and a.is_active and a.is_class_teacher and t.status = 'active'
      and c.is_active and t.user_id = (select auth.uid())
  ) or exists (
    select 1 from public.classes c join public.teachers t on t.id = c.class_teacher_id and t.school_id = c.school_id
    where c.id = p_class_id and c.is_active and t.status = 'active' and t.user_id = (select auth.uid())
  );
$$;

create or replace function public.is_assigned_teacher_subject(p_class_id uuid, p_subject_id uuid, p_subject_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.teacher_subject_assignments tsa
    join public.teachers t on t.id = tsa.teacher_id and t.school_id = tsa.school_id
    join public.subjects s on s.id = tsa.subject_id and s.school_id = tsa.school_id
    join public.classes c on c.id = tsa.class_id and c.school_id = tsa.school_id
    where tsa.class_id = p_class_id and tsa.is_active and t.status = 'active' and s.is_active and c.is_active
      and t.user_id = (select auth.uid())
      and (
        exists (select 1 from public.teacher_class_assignments ca where ca.teacher_id = t.id and ca.class_id = c.id and ca.is_active)
        or c.class_teacher_id = t.id
      )
      and ((p_subject_id is not null and tsa.subject_id = p_subject_id) or (p_subject_name is not null and lower(s.name) = lower(p_subject_name)))
  );
$$;

revoke all on function public.is_current_user_teacher(uuid) from public, anon;
revoke all on function public.is_assigned_class_teacher(uuid) from public, anon;
revoke all on function public.is_assigned_teacher_subject(uuid, uuid, text) from public, anon;
grant execute on function public.is_current_user_teacher(uuid) to authenticated;
grant execute on function public.is_assigned_class_teacher(uuid) to authenticated;
grant execute on function public.is_assigned_teacher_subject(uuid, uuid, text) to authenticated;

create or replace function public.check_assessment_subject_school()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.subject_id is not null and not exists (
    select 1 from public.subjects s where s.id = new.subject_id and s.school_id = new.school_id
  ) then
    raise exception 'Assessment subject must belong to the same school' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger assessment_subject_school_check before insert or update on public.assessments
  for each row execute function public.check_assessment_subject_school();
revoke all on function public.check_assessment_subject_school() from public, anon, authenticated;

create or replace function public.check_assessment_result_class()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_class_id uuid; v_assessment_date date;
begin
  select a.class_id, a.assessment_date into v_class_id, v_assessment_date
    from public.assessments a where a.id = new.assessment_id and a.school_id = new.school_id;
  if v_class_id is null then
    return new; -- School-level assessments without a class are management-only through RLS.
  end if;
  if v_assessment_date is not null then
    if not exists (
      select 1 from public.student_enrollment_history h
      where h.student_id = new.student_id and h.school_id = new.school_id and h.class_id = v_class_id
        and h.valid_from <= v_assessment_date and (h.valid_to is null or h.valid_to >= v_assessment_date)
    ) and (
      exists (select 1 from public.student_enrollment_history h where h.student_id = new.student_id and h.school_id = new.school_id)
      or not exists (select 1 from public.students st where st.id = new.student_id and st.school_id = new.school_id and st.class_id = v_class_id)
    ) then
      raise exception 'Student was not enrolled in this class on the assessment date' using errcode = '23514';
    end if;
  elsif not exists (
    select 1 from public.students st where st.id = new.student_id and st.school_id = new.school_id
      and st.class_id = v_class_id and st.status = 'active'
  ) then
    raise exception 'Student must be active in the assessment class when the test date is not set' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger assessment_result_class_check before insert or update on public.assessment_results
  for each row execute function public.check_assessment_result_class();
revoke all on function public.check_assessment_result_class() from public, anon, authenticated;
revoke all on function public.check_teaching_assignment_school() from public, anon, authenticated;
revoke all on function public.check_classroom_relationships() from public, anon, authenticated;

-- Keep teacher assignment lists private to management and their own linked teacher profile.
drop policy if exists teacher_class_assignment_read on public.teacher_class_assignments;
create policy teacher_class_assignment_read on public.teacher_class_assignments for select to authenticated
  using (public.can_access_school(school_id) or public.is_current_user_teacher(teacher_id));
drop policy if exists teacher_subject_assignment_read on public.teacher_subject_assignments;
create policy teacher_subject_assignment_read on public.teacher_subject_assignments for select to authenticated
  using (public.can_access_school(school_id) or public.is_current_user_teacher(teacher_id));
drop policy if exists subjects_read on public.subjects;
create policy subjects_read on public.subjects for select to authenticated
  using (
    public.can_access_school(school_id)
    or exists (
      select 1 from public.teacher_subject_assignments tsa
      where tsa.subject_id = subjects.id and tsa.is_active
        and public.is_assigned_teacher_class(tsa.class_id)
        and public.is_assigned_teacher_subject(tsa.class_id, tsa.subject_id, null)
    )
  );

drop policy if exists classwork_read on public.classwork;
create policy classwork_read on public.classwork for select to authenticated
  using (
    public.can_access_school(school_id)
    or (public.is_assigned_teacher_class(class_id) and (
      (subject_id is not null and public.is_assigned_teacher_subject(class_id, subject_id, null))
      or (subject_id is null and public.is_assigned_class_teacher(class_id))
    ))
  );
drop policy if exists classwork_write on public.classwork;
create policy classwork_write on public.classwork for all to authenticated
  using (
    public.has_school_permission(school_id, 'manage_academics')
    or (public.is_assigned_teacher_class(class_id) and subject_id is not null and public.is_assigned_teacher_subject(class_id, subject_id, null))
    or (public.is_assigned_teacher_class(class_id) and subject_id is null and public.is_assigned_class_teacher(class_id))
  )
  with check (
    public.has_school_permission(school_id, 'manage_academics')
    or (public.is_assigned_teacher_class(class_id) and subject_id is not null and public.is_assigned_teacher_subject(class_id, subject_id, null))
    or (public.is_assigned_teacher_class(class_id) and subject_id is null and public.is_assigned_class_teacher(class_id))
  );

drop policy if exists assessments_read on public.assessments;
create policy assessments_read on public.assessments for select to authenticated
  using (
    (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_academics') or public.has_school_permission(school_id, 'manage_academics')))
    or (class_id is not null and public.is_assigned_teacher_class(class_id) and public.is_assigned_teacher_subject(class_id, subject_id, subject))
  );
drop policy if exists assessments_write on public.assessments;
create policy assessments_write on public.assessments for all to authenticated
  using (
    public.has_school_permission(school_id, 'manage_academics')
    or (class_id is not null and public.is_assigned_teacher_class(class_id) and public.is_assigned_teacher_subject(class_id, subject_id, subject))
  )
  with check (
    public.has_school_permission(school_id, 'manage_academics')
    or (class_id is not null and public.is_assigned_teacher_class(class_id) and public.is_assigned_teacher_subject(class_id, subject_id, subject))
  );

drop policy if exists results_read on public.assessment_results;
create policy results_read on public.assessment_results for select to authenticated
  using (
    (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_academics') or public.has_school_permission(school_id, 'manage_academics')))
    or exists (
      select 1 from public.assessments a
      join public.students st on st.id = assessment_results.student_id and st.school_id = assessment_results.school_id
      where a.id = assessment_id and a.school_id = assessment_results.school_id and a.class_id is not null
        and st.status = 'active' and st.class_id = a.class_id
        and public.is_assigned_teacher_class(a.class_id) and public.is_assigned_teacher_subject(a.class_id, a.subject_id, a.subject)
    )
  );
drop policy if exists results_write on public.assessment_results;
create policy results_write on public.assessment_results for all to authenticated
  using (
    public.has_school_permission(school_id, 'manage_academics')
    or exists (
      select 1 from public.assessments a
      join public.students st on st.id = assessment_results.student_id and st.school_id = assessment_results.school_id
      where a.id = assessment_id and a.school_id = assessment_results.school_id and a.class_id is not null
        and st.status = 'active' and st.class_id = a.class_id
        and public.is_assigned_teacher_class(a.class_id) and public.is_assigned_teacher_subject(a.class_id, a.subject_id, a.subject)
    )
  )
  with check (
    public.has_school_permission(school_id, 'manage_academics')
    or exists (
      select 1 from public.assessments a
      join public.students st on st.id = assessment_results.student_id and st.school_id = assessment_results.school_id
      where a.id = assessment_id and a.school_id = assessment_results.school_id and a.class_id is not null
        and st.status = 'active' and st.class_id = a.class_id
        and public.is_assigned_teacher_class(a.class_id) and public.is_assigned_teacher_subject(a.class_id, a.subject_id, a.subject)
    )
  );

-- Backfill persisted class-teacher assignments for older classes without overwriting a different active designation.
insert into public.teacher_class_assignments(school_id, teacher_id, class_id, is_class_teacher, is_active, assigned_at)
select c.school_id, c.class_teacher_id, c.id, true, true, now()
from public.classes c
join public.teachers t on t.id = c.class_teacher_id and t.school_id = c.school_id
where c.is_active and c.class_teacher_id is not null
  and not exists (
    select 1 from public.teacher_class_assignments other
    where other.class_id = c.id and other.is_active and other.is_class_teacher and other.teacher_id <> c.class_teacher_id
  )
on conflict (teacher_id, class_id) do update
  set is_class_teacher = true, is_active = true, revoked_at = null;

-- Approved leave is a separate, management-controlled record. Teachers cannot grant their own leave approvals.