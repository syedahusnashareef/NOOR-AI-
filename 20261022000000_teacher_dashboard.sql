-- Noor School Management – Teacher Dashboard schema
-- Every table: RLS ON, school-scoped, explicit grants (nothing for anon).

create schema if not exists private;

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand jsonb not null default '{"logoLetter":"N","name":"NOOR","subtitle":"SCHOOL MANAGEMENT","motto1":"Learn • Teach • Grow","motto2":"A Brighter Tomorrow"}'::jsonb
);

-- One row per login (teacher / principal). `profile` holds every editable profile field.
create table public.staff (
  id uuid primary key references auth.users (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  role text not null default 'teacher' check (role in ('teacher', 'principal')),
  profile jsonb not null default '{}'::jsonb
);
create index staff_school_id_idx on public.staff (school_id);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  grade text not null,
  section text not null,
  name text not null,
  roll text not null,
  unique (school_id, grade, section, roll)
);

create table public.student_attendance (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  date date not null default current_date,
  status text not null check (status in ('Present', 'Absent', 'Late')),
  remarks text not null default '',
  marked_by uuid references public.staff (id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (student_id, date)
);
create index student_attendance_school_date_idx on public.student_attendance (school_id, date);
create index student_attendance_marked_by_idx on public.student_attendance (marked_by);

create table public.teacher_checkins (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  teacher_id uuid not null references public.staff (id) on delete cascade,
  date date not null default current_date,
  checked_in_at timestamptz not null default now(),
  unique (teacher_id, date)
);
create index teacher_checkins_school_date_idx on public.teacher_checkins (school_id, date);

create table public.timetable (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools (id) on delete cascade,
  teacher_id uuid not null references public.staff (id) on delete cascade,
  position int not null default 0,
  period text not null,
  start_time time not null,
  end_time time not null,
  subject text not null,
  class_sec text not null,
  color text
);
create index timetable_teacher_idx on public.timetable (teacher_id, position);
create index timetable_school_idx on public.timetable (school_id);

create table public.notices (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  author_id uuid not null references public.staff (id) on delete cascade,
  title text not null,
  body text not null default '',
  audience text not null default 'All',
  category text not null default 'General',
  requires_approval boolean not null default false,
  status text not null default 'published' check (status in ('published', 'pending')),
  created_at timestamptz not null default now()
);
create index notices_school_created_idx on public.notices (school_id, created_at desc);
create index notices_author_idx on public.notices (author_id);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  teacher_id uuid not null references public.staff (id) on delete cascade,
  title text not null,
  sub text not null default '',
  type text not null default 'general',
  created_at timestamptz not null default now()
);
create index activities_school_created_idx on public.activities (school_id, created_at desc);
create index activities_teacher_idx on public.activities (teacher_id);

create table public.subject_scores (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  grade text not null,
  section text not null,
  subject text not null,
  score int not null check (score between 0 and 100),
  unique (school_id, grade, section, subject)
);

-- ---------- helpers (private schema = not exposed through the API) ----------
create function private.my_school_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select school_id from public.staff where id = (select auth.uid())
$$;

create function private.is_principal() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.staff where id = (select auth.uid()) and role = 'principal')
$$;

revoke all on function private.my_school_id(), private.is_principal() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.my_school_id(), private.is_principal() to authenticated;

-- ---------- grants (RLS decides rows, grants decide tables/columns) ----------
revoke all on public.schools, public.staff, public.students, public.student_attendance,
  public.teacher_checkins, public.timetable, public.notices, public.activities, public.subject_scores
  from anon, authenticated;

grant select on public.schools, public.staff to authenticated;
grant update (brand) on public.schools to authenticated;     -- principal only (policy)
grant update (profile) on public.staff to authenticated;     -- role/school can NOT be changed by users
grant select, insert, update on public.students, public.student_attendance,
  public.teacher_checkins, public.subject_scores to authenticated;
grant select, insert, update, delete on public.timetable, public.notices to authenticated;
grant select, insert on public.activities to authenticated;

-- ---------- RLS ----------
alter table public.schools enable row level security;
alter table public.staff enable row level security;
alter table public.students enable row level security;
alter table public.student_attendance enable row level security;
alter table public.teacher_checkins enable row level security;
alter table public.timetable enable row level security;
alter table public.notices enable row level security;
alter table public.activities enable row level security;
alter table public.subject_scores enable row level security;

create policy "school: read own" on public.schools for select to authenticated
  using (id = (select private.my_school_id()));
create policy "school: principal edits brand" on public.schools for update to authenticated
  using (id = (select private.my_school_id()) and (select private.is_principal()))
  with check (id = (select private.my_school_id()));

create policy "staff: read same school" on public.staff for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "staff: edit own profile" on public.staff for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- students / scores: anyone in the school can read, add, edit (teachers fix names & marks)
create policy "students: read" on public.students for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "students: insert" on public.students for insert to authenticated
  with check (school_id = (select private.my_school_id()));
create policy "students: update" on public.students for update to authenticated
  using (school_id = (select private.my_school_id())) with check (school_id = (select private.my_school_id()));

create policy "scores: read" on public.subject_scores for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "scores: insert" on public.subject_scores for insert to authenticated
  with check (school_id = (select private.my_school_id()));
create policy "scores: update" on public.subject_scores for update to authenticated
  using (school_id = (select private.my_school_id())) with check (school_id = (select private.my_school_id()));

-- attendance: school can read (Principal dashboard sees it live); writes only as yourself
create policy "attendance: read" on public.student_attendance for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "attendance: insert" on public.student_attendance for insert to authenticated
  with check (school_id = (select private.my_school_id()) and marked_by = (select auth.uid()));
create policy "attendance: update" on public.student_attendance for update to authenticated
  using (school_id = (select private.my_school_id()))
  with check (school_id = (select private.my_school_id()) and marked_by = (select auth.uid()));

create policy "checkins: read" on public.teacher_checkins for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "checkins: insert own" on public.teacher_checkins for insert to authenticated
  with check (school_id = (select private.my_school_id()) and teacher_id = (select auth.uid()));
create policy "checkins: update own" on public.teacher_checkins for update to authenticated
  using (teacher_id = (select auth.uid()))
  with check (school_id = (select private.my_school_id()) and teacher_id = (select auth.uid()));

create policy "timetable: read" on public.timetable for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "timetable: write own or principal" on public.timetable for insert to authenticated
  with check (school_id = (select private.my_school_id()) and (teacher_id = (select auth.uid()) or (select private.is_principal())));
create policy "timetable: update own or principal" on public.timetable for update to authenticated
  using (teacher_id = (select auth.uid()) or (select private.is_principal()))
  with check (school_id = (select private.my_school_id()));
create policy "timetable: delete own or principal" on public.timetable for delete to authenticated
  using (teacher_id = (select auth.uid()) or (select private.is_principal()));

create policy "notices: read" on public.notices for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "notices: insert as self" on public.notices for insert to authenticated
  with check (school_id = (select private.my_school_id()) and author_id = (select auth.uid()));
create policy "notices: update own or principal" on public.notices for update to authenticated
  using (author_id = (select auth.uid()) or (select private.is_principal()))
  with check (school_id = (select private.my_school_id()));
create policy "notices: delete own or principal" on public.notices for delete to authenticated
  using (author_id = (select auth.uid()) or (select private.is_principal()));

create policy "activities: read" on public.activities for select to authenticated
  using (school_id = (select private.my_school_id()));
create policy "activities: insert as self" on public.activities for insert to authenticated
  with check (school_id = (select private.my_school_id()) and teacher_id = (select auth.uid()));

-- ---------- profile photos (public bucket, each user writes only in own folder) ----------
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars: upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars: read own folder" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars: replace own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------- realtime (Principal dashboard updates the moment a teacher saves) ----------
alter publication supabase_realtime add table
  public.student_attendance, public.notices, public.activities, public.teacher_checkins;
