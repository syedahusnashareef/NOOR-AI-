-- NOOR AI initial multi-school schema.
-- Run only in the dedicated NOOR AI Supabase project after reviewing the security model.
-- Student/teacher records do not need personal app logins; management users are authenticated.

create extension if not exists pgcrypto;

do $$ begin
  create type public.platform_role as enum ('creator', 'principal', 'manager');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.membership_role as enum ('principal', 'manager');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.attendance_status as enum ('present', 'absent', 'late', 'excused');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.payment_status as enum ('pending', 'paid', 'waived', 'overdue', 'refunded');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  platform_role public.platform_role not null default 'manager',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  school_code text unique,
  timezone text not null default 'Asia/Kolkata',
  currency_code char(3) not null default 'INR',
  academic_year_label text,
  status text not null default 'active' check (status in ('active','trial','paused','archived')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.membership_role not null,
  -- Manager permissions are explicitly granted per school. Missing flags mean false.
  permissions jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (school_id, user_id)
);

-- Optional second gate for the user's requested school key.
-- Store only a server-generated password hash, never a raw key. Do not expose this table to browser clients.
-- The key is an extra workspace gate, not a substitute for a personal authenticated account.
create table if not exists public.school_access_keys (
  school_id uuid primary key references public.schools(id) on delete cascade,
  key_hash text not null,
  rotated_at timestamptz not null default now(),
  rotated_by uuid references public.profiles(id) on delete set null
);

create table if not exists public.academic_years (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  label text not null, starts_on date not null, ends_on date not null, is_current boolean not null default false,
  created_at timestamptz not null default now(), check (ends_on >= starts_on), unique (school_id, label)
);
create unique index if not exists one_current_academic_year_per_school on public.academic_years(school_id) where is_current;

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id) on delete set null,
  name text not null, section text not null default 'A', class_teacher_id uuid,
  created_at timestamptz not null default now(), unique (school_id, academic_year_id, name, section), unique (id, school_id)
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  admission_number text not null, first_name text not null, last_name text,
  date_of_birth date, gender text, class_id uuid references public.classes(id) on delete set null, guardian_name text, guardian_phone text,
  status text not null default 'active' check (status in ('active','inactive','graduated','transferred')),
  joined_on date, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (school_id, admission_number)
);

create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  employee_code text not null, first_name text not null, last_name text, email text, phone text,
  subject_area text, joined_on date, status text not null default 'active' check (status in ('active','inactive','on_leave')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (school_id, employee_code)
);
alter table public.classes drop constraint if exists classes_class_teacher_id_fkey;
alter table public.classes add constraint classes_class_teacher_id_fkey foreign key (class_teacher_id) references public.teachers(id) on delete set null;

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade, class_id uuid references public.classes(id) on delete set null,
  attendance_date date not null, status public.attendance_status not null, note text,
  recorded_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(),
  unique (student_id, attendance_date)
);

create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id) on delete set null, class_id uuid references public.classes(id) on delete set null,
  title text not null, subject text not null, assessment_date date, max_marks numeric(8,2) not null check (max_marks > 0),
  created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.assessment_results (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  marks_obtained numeric(8,2) not null check (marks_obtained >= 0), teacher_note text,
  entered_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(),
  unique (assessment_id, student_id)
);

create table if not exists public.fee_accounts (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade, academic_year_id uuid references public.academic_years(id) on delete set null,
  fee_name text not null, amount_due numeric(12,2) not null check (amount_due >= 0), due_date date,
  status public.payment_status not null default 'pending', created_at timestamptz not null default now()
);
create table if not exists public.fee_transactions (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  fee_account_id uuid not null references public.fee_accounts(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0), paid_at timestamptz, method text, reference text,
  status public.payment_status not null default 'pending', recorded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.growth_snapshots (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  snapshot_date date not null, class_id uuid references public.classes(id) on delete set null,
  measure_key text not null, measure_label text not null, measure_value numeric(12,3) not null,
  unit text not null default 'index', methodology text not null default 'school_defined',
  created_at timestamptz not null default now(), unique (school_id, snapshot_date, class_id, measure_key)
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key, school_id uuid references public.schools(id) on delete set null,
  actor_user_id uuid references public.profiles(id) on delete set null, action text not null,
  entity_type text not null, entity_id text, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_memberships_user on public.school_memberships(user_id, school_id);
create index if not exists idx_students_school_class on public.students(school_id, class_id, status);
create index if not exists idx_attendance_school_date on public.attendance_records(school_id, attendance_date);
create index if not exists idx_results_school_student on public.assessment_results(school_id, student_id);
create index if not exists idx_fee_accounts_school_status on public.fee_accounts(school_id, status);
create index if not exists idx_audit_logs_school_created on public.audit_logs(school_id, created_at desc);

-- Ensure linked records always stay inside the same school boundary, even if someone guesses a UUID.
create or replace function public.check_school_relationships()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if TG_TABLE_NAME = 'classes' then
    if new.academic_year_id is not null and not exists (select 1 from public.academic_years y where y.id = new.academic_year_id and y.school_id = new.school_id) then
      raise exception 'Academic year must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'students' then
    if new.class_id is not null and not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
      raise exception 'Class must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'attendance_records' then
    if not exists (select 1 from public.students s where s.id = new.student_id and s.school_id = new.school_id) then
      raise exception 'Student must belong to the same school' using errcode = '23514';
    end if;
    if new.class_id is not null and not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
      raise exception 'Class must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'assessments' then
    if new.academic_year_id is not null and not exists (select 1 from public.academic_years y where y.id = new.academic_year_id and y.school_id = new.school_id) then
      raise exception 'Academic year must belong to the same school' using errcode = '23514';
    end if;
    if new.class_id is not null and not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
      raise exception 'Class must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'assessment_results' then
    if not exists (select 1 from public.assessments a where a.id = new.assessment_id and a.school_id = new.school_id) then
      raise exception 'Assessment must belong to the same school' using errcode = '23514';
    end if;
    if not exists (select 1 from public.students s where s.id = new.student_id and s.school_id = new.school_id) then
      raise exception 'Student must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'fee_accounts' then
    if not exists (select 1 from public.students s where s.id = new.student_id and s.school_id = new.school_id) then
      raise exception 'Student must belong to the same school' using errcode = '23514';
    end if;
    if new.academic_year_id is not null and not exists (select 1 from public.academic_years y where y.id = new.academic_year_id and y.school_id = new.school_id) then
      raise exception 'Academic year must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'fee_transactions' then
    if not exists (select 1 from public.fee_accounts f where f.id = new.fee_account_id and f.school_id = new.school_id) then
      raise exception 'Fee account must belong to the same school' using errcode = '23514';
    end if;
  elsif TG_TABLE_NAME = 'growth_snapshots' then
    if new.class_id is not null and not exists (select 1 from public.classes c where c.id = new.class_id and c.school_id = new.school_id) then
      raise exception 'Class must belong to the same school' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger classes_school_relationships before insert or update on public.classes for each row execute function public.check_school_relationships();
create trigger students_school_relationships before insert or update on public.students for each row execute function public.check_school_relationships();
create trigger attendance_school_relationships before insert or update on public.attendance_records for each row execute function public.check_school_relationships();
create trigger assessments_school_relationships before insert or update on public.assessments for each row execute function public.check_school_relationships();
create trigger results_school_relationships before insert or update on public.assessment_results for each row execute function public.check_school_relationships();
create trigger fees_school_relationships before insert or update on public.fee_accounts for each row execute function public.check_school_relationships();
create trigger fee_tx_school_relationships before insert or update on public.fee_transactions for each row execute function public.check_school_relationships();
create trigger growth_school_relationships before insert or update on public.growth_snapshots for each row execute function public.check_school_relationships();

-- Avoid allowing a normal authenticated user to promote themselves to Creator.
create or replace function public.is_creator()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.platform_role = 'creator'::public.platform_role);
$$;

create or replace function public.can_access_school(p_school_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_creator() or exists (
    select 1 from public.school_memberships sm where sm.school_id = p_school_id and sm.user_id = (select auth.uid())
  );
$$;

create or replace function public.has_school_permission(p_school_id uuid, p_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_creator() or exists (
    select 1 from public.school_memberships sm
    where sm.school_id = p_school_id and sm.user_id = (select auth.uid())
      and (sm.role = 'principal'::public.membership_role or coalesce((sm.permissions ->> p_permission)::boolean, false))
  );
$$;

create or replace function public.is_school_principal(p_school_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.school_memberships sm where sm.school_id = p_school_id and sm.user_id = (select auth.uid()) and sm.role = 'principal'::public.membership_role);
$$;

-- New sign-ups receive the least-privileged role. Creator status must be granted out of band.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, platform_role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), 'manager'::public.platform_role)
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_noor_profile on auth.users;
create trigger on_auth_user_created_noor_profile after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Enable RLS on every school-owned table, including the sensitive optional key table.
alter table public.profiles enable row level security;
alter table public.schools enable row level security;
alter table public.school_memberships enable row level security;
alter table public.school_access_keys enable row level security;
alter table public.academic_years enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.teachers enable row level security;
alter table public.attendance_records enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_results enable row level security;
alter table public.fee_accounts enable row level security;
alter table public.fee_transactions enable row level security;
alter table public.growth_snapshots enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles are readable by owner; Creator can review profiles platform-wide. No self-service role updates.
drop policy if exists profiles_select_self_or_creator on public.profiles;
create policy profiles_select_self_or_creator on public.profiles for select to authenticated
using (id = (select auth.uid()) or public.is_creator());

-- Schools and memberships are visible only to Creator or members of that school.
create policy schools_select_accessible on public.schools for select to authenticated
using (public.can_access_school(id));
create policy schools_insert_creator on public.schools for insert to authenticated
with check (public.is_creator());
create policy schools_update_creator on public.schools for update to authenticated
using (public.is_creator()) with check (public.is_creator());
create policy schools_delete_creator on public.schools for delete to authenticated
using (public.is_creator());

create policy memberships_select_accessible on public.school_memberships for select to authenticated
using (public.is_creator() or user_id = (select auth.uid()) or public.has_school_permission(school_id, 'manage_access'));
create policy memberships_insert_admin on public.school_memberships for insert to authenticated
with check (public.is_creator() or (public.is_school_principal(school_id) and role = 'manager'::public.membership_role));
create policy memberships_update_admin on public.school_memberships for update to authenticated
using (public.is_creator() or (public.is_school_principal(school_id) and role = 'manager'::public.membership_role))
with check (public.is_creator() or (public.is_school_principal(school_id) and role = 'manager'::public.membership_role));
create policy memberships_delete_admin on public.school_memberships for delete to authenticated
using (public.is_creator() or (public.is_school_principal(school_id) and role = 'manager'::public.membership_role));

-- School keys deliberately have no policies for authenticated users; use a server-only function/Edge Function.
-- Table is not readable or writable by browser clients. Service role bypasses RLS; protect it server-side.

-- Read/write policies with separate manager capabilities for the data modules.
create policy academic_years_read on public.academic_years for select to authenticated using (public.can_access_school(school_id));
create policy academic_years_write on public.academic_years for all to authenticated using (public.has_school_permission(school_id, 'manage_school_settings')) with check (public.has_school_permission(school_id, 'manage_school_settings'));

create policy classes_read on public.classes for select to authenticated using (public.can_access_school(school_id));
create policy classes_write on public.classes for all to authenticated using (public.has_school_permission(school_id, 'manage_classes')) with check (public.has_school_permission(school_id, 'manage_classes'));

create policy students_read on public.students for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_students') or public.has_school_permission(school_id, 'manage_students')));
create policy students_write on public.students for all to authenticated using (public.has_school_permission(school_id, 'manage_students')) with check (public.has_school_permission(school_id, 'manage_students'));

create policy teachers_read on public.teachers for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_teachers') or public.has_school_permission(school_id, 'manage_teachers')));
create policy teachers_write on public.teachers for all to authenticated using (public.has_school_permission(school_id, 'manage_teachers')) with check (public.has_school_permission(school_id, 'manage_teachers'));

create policy attendance_read on public.attendance_records for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_attendance') or public.has_school_permission(school_id, 'manage_attendance')));
create policy attendance_write on public.attendance_records for all to authenticated using (public.has_school_permission(school_id, 'manage_attendance')) with check (public.has_school_permission(school_id, 'manage_attendance'));

create policy assessments_read on public.assessments for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_academics') or public.has_school_permission(school_id, 'manage_academics')));
create policy assessments_write on public.assessments for all to authenticated using (public.has_school_permission(school_id, 'manage_academics')) with check (public.has_school_permission(school_id, 'manage_academics'));
create policy results_read on public.assessment_results for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_academics') or public.has_school_permission(school_id, 'manage_academics')));
create policy results_write on public.assessment_results for all to authenticated using (public.has_school_permission(school_id, 'manage_academics')) with check (public.has_school_permission(school_id, 'manage_academics'));

create policy fee_accounts_read on public.fee_accounts for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_fees') or public.has_school_permission(school_id, 'manage_fees')));
create policy fee_accounts_write on public.fee_accounts for all to authenticated using (public.has_school_permission(school_id, 'manage_fees')) with check (public.has_school_permission(school_id, 'manage_fees'));
create policy fee_transactions_read on public.fee_transactions for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_fees') or public.has_school_permission(school_id, 'manage_fees')));
create policy fee_transactions_write on public.fee_transactions for all to authenticated using (public.has_school_permission(school_id, 'manage_fees')) with check (public.has_school_permission(school_id, 'manage_fees'));

create policy growth_read on public.growth_snapshots for select to authenticated using (public.can_access_school(school_id) and (public.has_school_permission(school_id, 'view_analytics') or public.has_school_permission(school_id, 'manage_analytics')));
create policy growth_write on public.growth_snapshots for all to authenticated using (public.has_school_permission(school_id, 'manage_analytics')) with check (public.has_school_permission(school_id, 'manage_analytics'));

create policy audit_read on public.audit_logs for select to authenticated using (public.is_creator() or (school_id is not null and public.has_school_permission(school_id, 'view_audit_logs')));
create policy audit_insert on public.audit_logs for insert to authenticated with check (public.is_creator() or (school_id is not null and public.can_access_school(school_id)));

-- NOTE: production hardening still required before real student records:
-- 1) verify linked child-row school_ids match parent student/class/assessment school_ids in a controlled RPC/trigger,
-- 2) configure authenticated invitations and Creator bootstrap via a server-only Admin API,
-- 3) configure backups, retention, rate limiting, MFA, and audit log write path,
-- 4) use a vetted server-side password hashing strategy for the optional school key, and never log raw keys.