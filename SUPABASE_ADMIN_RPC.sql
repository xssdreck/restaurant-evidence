-- 在 Supabase SQL Editor 执行（一次）
-- 安全版：仅已登录且邮箱在管理员白名单中的用户可调用

create or replace function public.admin_set_story_status(
  p_story_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  v_email := lower(coalesce(auth.jwt() ->> 'email', ''));

  if v_email not in ('xssdmxreckoning@gmail.com') then
    raise exception 'forbidden';
  end if;

  if p_status not in ('pending','approved','rejected') then
    raise exception 'invalid status';
  end if;

  update public.stories
  set status = p_status
  where id = p_story_id;
end;
$$;

revoke all on function public.admin_set_story_status(uuid,text) from public;
grant execute on function public.admin_set_story_status(uuid,text) to authenticated;
