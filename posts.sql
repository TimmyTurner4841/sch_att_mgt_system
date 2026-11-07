create table posts(
  id bigint generated always as identity primary key,
  type text not null check (type in ('announcement','blog','social')),
  title text not null, body text not null,
  image_url text, link_url text,
  published boolean not null default true,
  created_at timestamptz default now());
alter table posts enable row level security;
create policy "public read posts" on posts for select using (published or is_admin());
create policy "admin insert posts" on posts for insert with check (is_admin());
create policy "admin update posts" on posts for update using (is_admin());
create policy "admin delete posts" on posts for delete using (is_admin());

insert into storage.buckets(id,name,public) values('posts','posts',true) on conflict do nothing;
create policy "public read post images" on storage.objects for select using (bucket_id='posts');
create policy "admin upload post images" on storage.objects for insert with check (bucket_id='posts' and is_admin());
create policy "admin delete post images" on storage.objects for delete using (bucket_id='posts' and is_admin());
