create extension if not exists pgcrypto;

create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  user_id uuid not null,
  user_email text,
  created_at timestamptz not null default now()
);

alter table public.stories enable row level security;

drop policy if exists "insert own story" on public.stories;
create policy "insert own story"
on public.stories
for insert
to authenticated
with check (auth.uid() = user_id);

-- 任何人可读 approved（首页匿名可展示）
drop policy if exists "public read approved" on public.stories;
create policy "public read approved"
on public.stories
for select
to anon, authenticated
using (status = 'approved');

-- 投稿人可读自己的全部稿件
drop policy if exists "author read own" on public.stories;
create policy "author read own"
on public.stories
for select
to authenticated
using (auth.uid() = user_id);

-- 管理员可读所有稿件（含待审）
drop policy if exists "admin read all" on public.stories;
create policy "admin read all"
on public.stories
for select
to authenticated
using ((auth.jwt() ->> 'email') in ('xssdmxreckoning@gmail.com'));

-- 管理员可更新审核状态
drop policy if exists "admin update status" on public.stories;
create policy "admin update status"
on public.stories
for update
to authenticated
using ((auth.jwt() ->> 'email') in ('xssdmxreckoning@gmail.com'))
with check ((auth.jwt() ->> 'email') in ('xssdmxreckoning@gmail.com'));
