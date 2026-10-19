-- Run in Supabase SQL editor after reviewing existing school membership policies.
create table if not exists public.noor_staff_attendance (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id),
 teacher_id uuid not null references auth.users(id), attendance_date date not null,
 status text not null check(status in ('present','absent','leave','late')),
 checked_in_at timestamptz, unique(school_id,teacher_id,attendance_date)
);
create table if not exists public.noor_teacher_periods (
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id),
 teacher_id uuid not null references auth.users(id),weekday int not null check(weekday between 0 and 6),
 period_number int not null,start_time time not null,end_time time not null,
 subject_name text not null,class_label text not null,status text not null default 'upcoming'
 check(status in ('upcoming','ongoing','done')),check(start_time<end_time)
);
create table if not exists public.noor_teacher_tasks (
 id uuid primary key default gen_random_uuid(),school_id uuid not null references public.schools(id),
 teacher_id uuid not null references auth.users(id),title text not null,
 status text not null default 'todo' check(status in ('todo','in_progress','done')),
 priority text default 'normal',due_date date
);
alter table public.noor_staff_attendance enable row level security;
alter table public.noor_teacher_periods enable row level security;
alter table public.noor_teacher_tasks enable row level security;
-- Teachers can access only their own school-scoped records.
-- Principal SELECT policies must be added after verifying the existing membership schema.
create policy "teacher own attendance select" on public.noor_staff_attendance for select to authenticated using(teacher_id=auth.uid());
create policy "teacher own attendance insert" on public.noor_staff_attendance for insert to authenticated with check(teacher_id=auth.uid() and status='present' and checked_in_at is not null);
create policy "teacher own periods select" on public.noor_teacher_periods for select to authenticated using(teacher_id=auth.uid());
create policy "teacher own periods update" on public.noor_teacher_periods for update to authenticated using(teacher_id=auth.uid()) with check(teacher_id=auth.uid());
create policy "teacher own tasks select" on public.noor_teacher_tasks for select to authenticated using(teacher_id=auth.uid());
-- IMPORTANT: add school-membership verification to all policies before production.
