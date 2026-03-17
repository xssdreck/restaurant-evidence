-- 在 Supabase SQL Editor 一次性执行
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

-- 投稿人可新增自己的投稿
create policy if not exists "insert own story"
on public.stories for insert to authenticated
with check (auth.uid() = user_id);

-- 投稿人可查看自己稿件；任何人可查看 approved
create policy if not exists "read own or approved"
on public.stories for select
using (status = 'approved' or auth.uid() = user_id);

-- 管理员审核策略：把下面邮箱改成你的管理员邮箱（可多邮箱）
create policy if not exists "admin update status"
on public.stories for update to authenticated
using ((auth.jwt() ->> 'email') in ('xssdmxreckoning@gmail.com'))
with check ((auth.jwt() ->> 'email') in ('xssdmxreckoning@gmail.com'));
