-- NOOR AI school workspace: student identity, school directory, editable classes/sections.
-- Apply only to the dedicated NOOR AI Supabase project, not to another app's database.

create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 180),
  logo_url text,
  join_code text not null unique check (char_length(join_code) between 8 and 48),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Public-safe directory contains no join codes, creator IDs or private settings.
create table if not exists public.school_directory (
  id uuid primary key references public.schools(id) on delete cascade,
  name text not null,
  logo_url text,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.school_directory enable row level security;
create policy "Public can read active school names only" on public.school_directory
  for select to anon, authenticated using (is_active = true);
grant select on public.school_directory to anon, authenticated;

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 80),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name),
  unique (id, school_id)
);
create index if not exists classes_school_active_idx on public.classes(school_id, is_active, sort_order);

create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 40),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, name),
  unique (id, class_id)
);
create index if not exists sections_class_active_idx on public.sections(class_id, is_active, name);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '' check (char_length(full_name) <= 120),
  role text not null default 'student' check (role in ('creator','principal','manager','teacher','student')),
  status text not null default 'pending' check (status in ('pending','active','inactive')),
  school_id uuid references public.schools(id) on delete restrict,
  school_name_submitted text,
  mobile_number text,
  parent_name text,
  roll_number text,
  class_id uuid references public.classes(id) on delete restrict,
  section_id uuid references public.sections(id) on delete restrict,
  requested_class_name text,
  requested_section_name text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_roll_length check (roll_number is null or char_length(roll_number) <= 30),
  constraint section_requires_class check (section_id is null or class_id is not null)
);
create index if not exists profiles_school_role_status_idx on public.profiles(school_id, role, status);
create index if not exists profiles_class_section_idx on public.profiles(class_id, section_id, roll_number);
create unique index if not exists profiles_unique_active_roll_per_section
  on public.profiles(school_id, class_id, section_id, lower(trim(roll_number)))
  where role = 'student' and status <> 'inactive' and school_id is not null and roll_number is not null;

create table if not exists public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete restrict,
  section_id uuid references public.sections(id) on delete restrict,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint teacher_assignment_school_class_fk foreign key (class_id, school_id) references public.classes(id, school_id) on delete restrict
);
create index if not exists teacher_assignments_teacher_scope_idx on public.teacher_assignments(teacher_id, school_id, class_id, section_id) where is_active;

create table if not exists public.audit_logs (
  id bigint generated by default as identity primary key,
  school_id uuid references public.schools(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  target_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  change_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_logs_school_created_idx on public.audit_logs(school_id, created_at desc);

-- Private helper functions are not available as browser RPC endpoints. They exist for RLS policy checks.
create or replace function private.current_actor_role()
returns text
language sql stable security definer set search_path = ''
as $$
  select p.role from public.profiles p
  where p.id = (select auth.uid()) and p.status = 'active'
  limit 1
$$;
revoke all on function private.current_actor_role() from public, anon;
grant execute on function private.current_actor_role() to authenticated;

create or replace function private.current_actor_school()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select p.school_id from public.profiles p
  where p.id = (select auth.uid()) and p.status = 'active'
  limit 1
$$;
revoke all on function private.current_actor_school() from public, anon;
grant execute on function private.current_actor_school() to authenticated;

create or replace function private.is_creator()
returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'creator' and p.status = 'active'
) $$;
revoke all on function private.is_creator() from public, anon;
grant execute on function private.is_creator() to authenticated;

create or replace function private.has_school_role(target_school_id uuid, allowed_roles text[])
returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.status = 'active'
    and (p.role = 'creator' or (p.role = any (allowed_roles) and p.school_id = target_school_id))
) $$;
revoke all on function private.has_school_role(uuid, text[]) from public, anon;
grant execute on function private.has_school_role(uuid, text[]) to authenticated;

create or replace function private.can_manage_profile(target_profile_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles target
    join public.profiles actor on actor.id = (select auth.uid())
    where target.id = target_profile_id
      and actor.status = 'active'
      and (
        actor.role = 'creator'
        or (actor.role in ('principal','manager') and actor.school_id = target.school_id and target.school_id is not null)
        or (actor.role = 'teacher'
          and actor.school_id = target.school_id
          and target.role = 'student'
          and exists (
            select 1 from public.teacher_assignments ta
            where ta.teacher_id = actor.id and ta.school_id = target.school_id
              and ta.class_id = target.class_id and ta.is_active
              and (ta.section_id is null or ta.section_id = target.section_id)
          )
        )
      )
  )
$$;
revoke all on function private.can_manage_profile(uuid) from public, anon;
grant execute on function private.can_manage_profile(uuid) to authenticated;

-- Sync only public-safe columns into the school directory.
create or replace function public.sync_school_directory()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.school_directory(id, name, logo_url, is_active, updated_at)
  values (new.id, new.name, new.logo_url, new.is_active, now())
  on conflict (id) do update set name=excluded.name, logo_url=excluded.logo_url,
    is_active=excluded.is_active, updated_at=now();
  return new;
end;
$$;
revoke all on function public.sync_school_directory() from public, anon, authenticated;
drop trigger if exists schools_sync_directory on public.schools;
create trigger schools_sync_directory after insert or update of name, logo_url, is_active on public.schools
for each row execute function public.sync_school_directory();

-- Signup always creates a student. A browser-supplied role is never used for authorization.
-- A valid school ID is associated for review; the correct join code makes the initial account active.
create or replace function public.handle_noor_auth_signup()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_school_id uuid;
  v_requested_school_id uuid;
  v_class_id uuid;
  v_requested_class_id uuid;
  v_section_id uuid;
  v_requested_section_id uuid;
  v_join_code text;
  v_code_valid boolean := false;
  v_class_name text;
  v_section_name text;
begin
  begin v_requested_school_id := nullif(new.raw_user_meta_data->>'school_id','')::uuid;
  exception when others then v_requested_school_id := null; end;
  begin v_requested_class_id := nullif(new.raw_user_meta_data->>'class_id','')::uuid;
  exception when others then v_requested_class_id := null; end;
  begin v_requested_section_id := nullif(new.raw_user_meta_data->>'section_id','')::uuid;
  exception when others then v_requested_section_id := null; end;
  v_join_code := trim(coalesce(new.raw_user_meta_data->>'school_join_code',''));

  select s.id into v_school_id from public.schools s
    where s.id = v_requested_school_id and s.is_active limit 1;
  if v_school_id is not null then
    select exists(select 1 from public.schools s where s.id=v_school_id and s.join_code=v_join_code and s.is_active)
      into v_code_valid;
    select c.id, c.name into v_class_id, v_class_name from public.classes c
      where c.id=v_requested_class_id and c.school_id=v_school_id and c.is_active limit 1;
    if v_class_id is not null then
      select s.id, s.name into v_section_id, v_section_name from public.sections s
        where s.id=v_requested_section_id and s.class_id=v_class_id and s.is_active limit 1;
    end if;
  end if;

  insert into public.profiles(
    id,email,full_name,role,status,school_id,school_name_submitted,mobile_number,parent_name,
    roll_number,class_id,section_id,requested_class_name,requested_section_name
  ) values (
    new.id, coalesce(new.email,''), left(trim(coalesce(new.raw_user_meta_data->>'full_name','')),120),
    'student', case when v_code_valid and v_class_id is not null and v_section_id is not null then 'active' else 'pending' end,
    v_school_id, left(trim(coalesce(new.raw_user_meta_data->>'school_name_submitted','')),180),
    left(trim(coalesce(new.raw_user_meta_data->>'mobile_number','')),20),
    left(trim(coalesce(new.raw_user_meta_data->>'parent_name','')),120),
    left(trim(coalesce(new.raw_user_meta_data->>'roll_number','')),30), v_class_id, v_section_id,
    left(trim(coalesce(v_class_name,new.raw_user_meta_data->>'requested_class_name','')),80),
    left(trim(coalesce(v_section_name,new.raw_user_meta_data->>'requested_section_name','')),40)
  );
  return new;
end;
$$;
revoke all on function public.handle_noor_auth_signup() from public, anon, authenticated;
drop trigger if exists on_auth_user_created_noor on auth.users;
create trigger on_auth_user_created_noor after insert on auth.users
for each row execute function public.handle_noor_auth_signup();

create or replace function public.guard_noor_profile_update()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_actor_role text;
  v_actor_school uuid;
begin
  if tg_op = 'UPDATE' then
    -- Trusted SQL editor / migration operations run without an end-user JWT.
    if (select auth.uid()) is null then new.updated_at := now(); return new; end if;
    select p.role, p.school_id into v_actor_role, v_actor_school
      from public.profiles p where p.id = (select auth.uid()) and p.status = 'active';

    if (select auth.uid()) = old.id then
      if new.role is distinct from old.role
        or new.status is distinct from old.status
        or new.school_id is distinct from old.school_id
        or new.email is distinct from old.email
        or new.roll_number is distinct from old.roll_number
        or new.class_id is distinct from old.class_id
        or new.section_id is distinct from old.section_id then
        raise exception 'Students cannot edit school-controlled fields.' using errcode='42501';
      end if;
    elsif coalesce(v_actor_role,'') = 'creator' then
      null; -- Creator actions still require RLS to permit the target row.
    elsif v_actor_role in ('principal','manager') then
      if old.school_id is distinct from v_actor_school or new.school_id is distinct from old.school_id then
        raise exception 'School staff can only manage records in their own school.' using errcode='42501';
      end if;
      if new.role is distinct from old.role then raise exception 'Only a platform creator can change a role.' using errcode='42501'; end if;
    elsif v_actor_role = 'teacher' then
      if old.school_id is distinct from v_actor_school or new.school_id is distinct from old.school_id
        or new.role is distinct from old.role or new.status is distinct from old.status or new.email is distinct from old.email then
        raise exception 'Teachers cannot change school membership, roles or approval status.' using errcode='42501';
      end if;
    else
      raise exception 'Not authorised to edit this profile.' using errcode='42501';
    end if;
    if new.school_id is not null and new.class_id is not null and not exists(
      select 1 from public.classes c where c.id=new.class_id and c.school_id=new.school_id
    ) then raise exception 'Selected class does not belong to the student school.' using errcode='23514'; end if;
    if new.section_id is not null and not exists(
      select 1 from public.sections s where s.id=new.section_id and s.class_id=new.class_id
    ) then raise exception 'Selected section does not belong to the selected class.' using errcode='23514'; end if;
    new.updated_at := now();
  end if;
  return new;
end;
$$;
revoke all on function public.guard_noor_profile_update() from public, anon, authenticated;
drop trigger if exists profiles_guard_update on public.profiles;
create trigger profiles_guard_update before update on public.profiles
for each row execute function public.guard_noor_profile_update();

create or replace function public.audit_noor_profile_update()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare v_changes jsonb := '{}'::jsonb;
begin
  if old.full_name is distinct from new.full_name then v_changes := v_changes || jsonb_build_object('full_name_changed',true); end if;
  if old.mobile_number is distinct from new.mobile_number then v_changes := v_changes || jsonb_build_object('mobile_number_changed',true); end if;
  if old.parent_name is distinct from new.parent_name then v_changes := v_changes || jsonb_build_object('parent_name_changed',true); end if;
  if old.roll_number is distinct from new.roll_number then v_changes := v_changes || jsonb_build_object('roll_number_changed',true); end if;
  if old.class_id is distinct from new.class_id then v_changes := v_changes || jsonb_build_object('class_changed',true); end if;
  if old.section_id is distinct from new.section_id then v_changes := v_changes || jsonb_build_object('section_changed',true); end if;
  if old.status is distinct from new.status then v_changes := v_changes || jsonb_build_object('status_changed',true); end if;
  if old.avatar_path is distinct from new.avatar_path then v_changes := v_changes || jsonb_build_object('photo_changed',true); end if;
  if v_changes <> '{}'::jsonb then
    insert into public.audit_logs(school_id,actor_id,target_profile_id,action,change_summary)
    values (new.school_id,(select auth.uid()),new.id,'profile_updated',v_changes);
  end if;
  return new;
end;
$$;
revoke all on function public.audit_noor_profile_update() from public, anon, authenticated;
drop trigger if exists profiles_audit_update on public.profiles;
create trigger profiles_audit_update after update on public.profiles
for each row execute function public.audit_noor_profile_update();

-- Enable RLS everywhere browser-accessible data exists.
alter table public.schools enable row level security;
alter table public.classes enable row level security;
alter table public.sections enable row level security;
alter table public.profiles enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.audit_logs enable row level security;

-- Clear default grants before adding the narrow permissions required by this client.
revoke all on public.schools, public.school_directory, public.classes, public.sections, public.profiles, public.teacher_assignments, public.audit_logs from public, anon, authenticated;

-- School records: platform creator can create; only the creator or assigned school staff can read/update a workspace.
create policy "Creator and school staff read authorised school" on public.schools
  for select to authenticated using (private.is_creator() or id = (select private.current_actor_school()));
create policy "Creator creates school" on public.schools
  for insert to authenticated with check (private.is_creator() and created_by=(select auth.uid()));
create policy "Creator updates school" on public.schools
  for update to authenticated using (private.is_creator()) with check (private.is_creator());

-- Class and section names are safe to show in the registration selectors; write access is role-checked.
create policy "Read active public class names" on public.classes
  for select to anon, authenticated using (
    is_active = true and exists (select 1 from public.school_directory d where d.id=school_id and d.is_active=true)
  );
create policy "School staff manage classes" on public.classes
  for all to authenticated
  using (private.has_school_role(school_id, array['principal','manager','teacher']))
  with check (private.has_school_role(school_id, array['principal','manager','teacher']) and (created_by is null or created_by=(select auth.uid())));
create policy "Read active public section names" on public.sections
  for select to anon, authenticated using (
    is_active = true and exists (
      select 1 from public.classes c join public.school_directory d on d.id=c.school_id
      where c.id=class_id and c.is_active=true and d.is_active=true
    )
  );
create policy "School staff manage sections" on public.sections
  for all to authenticated
  using (exists (select 1 from public.classes c where c.id=class_id and private.has_school_role(c.school_id,array['principal','manager','teacher'])))
  with check (exists (select 1 from public.classes c where c.id=class_id and private.has_school_role(c.school_id,array['principal','manager','teacher'])) and (created_by is null or created_by=(select auth.uid())));

-- Own profile + authorised roster only. Teachers can see/edit students only in an assigned class/section.
create policy "Read own or authorised profiles" on public.profiles
  for select to authenticated using (id=(select auth.uid()) or private.can_manage_profile(id));
create policy "Users update own permitted profile fields" on public.profiles
  for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
create policy "Authorised staff update roster profiles" on public.profiles
  for update to authenticated using (private.can_manage_profile(id)) with check (private.can_manage_profile(id));
-- Profile creation is exclusively through the trusted auth trigger; do not grant browser INSERT.

create policy "Teacher reads own assignments and leadership manages assignments" on public.teacher_assignments
  for select to authenticated using (
    teacher_id=(select auth.uid()) or private.has_school_role(school_id,array['principal','manager'])
  );
create policy "Leadership manages teacher assignments" on public.teacher_assignments
  for all to authenticated
  using (private.has_school_role(school_id,array['principal','manager']))
  with check (private.has_school_role(school_id,array['principal','manager']));

create policy "School leadership reads audit records" on public.audit_logs
  for select to authenticated using (private.is_creator() or private.has_school_role(school_id,array['principal','manager']));
-- Audit rows are written only by the trigger; browser roles receive no direct write policy.

-- Private profile-photo storage. File paths begin with the authenticated owner's UUID.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('student-photos','student-photos',false,3145728,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=3145728,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "Student uploads own profile photo" on storage.objects;
create policy "Student uploads own profile photo" on storage.objects
  for insert to authenticated with check (bucket_id='student-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Student replaces own profile photo" on storage.objects;
create policy "Student replaces own profile photo" on storage.objects
  for update to authenticated using (bucket_id='student-photos' and (storage.foldername(name))[1]=(select auth.uid())::text)
  with check (bucket_id='student-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Student or authorised staff reads profile photos" on storage.objects;
create policy "Student or authorised staff reads profile photos" on storage.objects
  for select to authenticated using (
    bucket_id='student-photos' and (
      (storage.foldername(name))[1]=(select auth.uid())::text
      or exists (select 1 from public.profiles p where p.id::text=(storage.foldername(name))[1] and private.can_manage_profile(p.id))
    )
  );
drop policy if exists "Student deletes own profile photo" on storage.objects;
create policy "Student deletes own profile photo" on storage.objects
  for delete to authenticated using (bucket_id='student-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);

-- Least-privilege Data API grants; no anonymous access to school roster or join codes.
revoke all on public.schools, public.profiles, public.teacher_assignments, public.audit_logs from anon;
grant select (id,name,logo_url,is_active) on public.schools to anon, authenticated;
grant select on public.school_directory to anon, authenticated;
grant select, insert, update on public.classes to authenticated;
grant select on public.classes to anon;
grant select, insert, update on public.sections to authenticated;
grant select on public.sections to anon;
grant select, update on public.profiles to authenticated;
grant select on public.teacher_assignments to authenticated;
grant insert, update on public.teacher_assignments to authenticated;
grant select on public.audit_logs to authenticated;
-- Authenticated creator/staff needs the school's join_code, but row policies hide other school records.
grant select (join_code,created_by,created_at,updated_at) on public.schools to authenticated;
grant insert (name,logo_url,join_code,is_active,created_by) on public.schools to authenticated;
grant update (name,logo_url,is_active,updated_at) on public.schools to authenticated;

-- Safe default for future school additions: nothing is public except the curated directory and active class labels.
