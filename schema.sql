-- Run this whole file in Supabase > SQL Editor > New query > Run

create table staff(
  id uuid primary key references auth.users on delete cascade,
  full_name text not null, phone text,
  staff_id text unique not null, department text,
  role text not null default 'staff',
  created_at timestamptz default now());

create table attendance(
  id bigint generated always as identity primary key,
  staff_id uuid not null references staff(id) on delete cascade,
  date date not null, clock_in timestamptz, clock_out timestamptz,
  status text not null default 'present',   -- present | late
  unique(staff_id, date));

create table leave_requests(
  id bigint generated always as identity primary key,
  staff_id uuid not null references staff(id) on delete cascade,
  type text not null default 'Leave',        -- Leave | Permission
  date date not null, end_date date, reason text not null,
  status text not null default 'pending',    -- pending | approved | rejected
  admin_comment text, created_at timestamptz default now());

alter table staff enable row level security;
alter table attendance enable row level security;
alter table leave_requests enable row level security;

create function is_admin() returns boolean language sql security definer stable
set search_path=public as $$ select exists(select 1 from staff where id=auth.uid() and role='admin') $$;

create policy "staff read" on staff for select using (id=auth.uid() or is_admin());
create policy "att read" on attendance for select using (staff_id=auth.uid() or is_admin());
create policy "leave read" on leave_requests for select using (staff_id=auth.uid() or is_admin());
create policy "leave insert" on leave_requests for insert with check (staff_id=auth.uid() and status='pending');
create policy "leave decide" on leave_requests for update using (is_admin());

-- Create the staff row automatically when someone registers
create function handle_new_user() returns trigger language plpgsql security definer
set search_path=public as $$ begin
  insert into staff(id, full_name, phone, staff_id, department)
  values(new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'phone',
         new.raw_user_meta_data->>'staff_id', new.raw_user_meta_data->>'department');
  return new; end $$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function handle_new_user();

-- Clock in: once per day, server time (Lagos). Late = after 08:00. Change the time below if needed.
create function clock_in() returns void language plpgsql security definer
set search_path=public as $$
declare t timestamptz := now(); d date := (now() at time zone 'Africa/Lagos')::date;
begin
  insert into attendance(staff_id, date, clock_in, status)
  values(auth.uid(), d, t,
    case when (t at time zone 'Africa/Lagos')::time > time '08:00' then 'late' else 'present' end);
end $$;

create function clock_out() returns void language plpgsql security definer
set search_path=public as $$
begin
  update attendance set clock_out=now()
  where staff_id=auth.uid() and date=(now() at time zone 'Africa/Lagos')::date and clock_out is null;
  if not found then raise exception 'Clock in first, or you already clocked out'; end if;
end $$;

create function remove_staff(p_id uuid) returns void language plpgsql security definer
set search_path=public as $$
begin
  if not is_admin() or p_id=auth.uid() then raise exception 'Not allowed'; end if;
  delete from auth.users where id=p_id;
end $$;
update staff set role='admin' where staff_id in ('HIT1','ICT01');
