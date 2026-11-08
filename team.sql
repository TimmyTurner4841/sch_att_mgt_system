-- Run in Supabase > SQL Editor > New query > Run (once, BEFORE uploading the new pages)
create table team(
  id bigint generated always as identity primary key,
  name text not null,
  role text not null,                       -- portfolio / position
  category text not null check (category in ('management','staff')),
  photo_url text,
  sort_order int not null default 0,
  created_at timestamptz default now());
alter table team enable row level security;
create policy "public read team" on team for select using (true);
create policy "admin insert team" on team for insert with check (is_admin());
create policy "admin update team" on team for update using (is_admin());
create policy "admin delete team" on team for delete using (is_admin());
