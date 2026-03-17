-- 在 Supabase SQL Editor 执行（一次）
-- 设置一个审核密码（可改）
-- 目前示例：1031xpp

create or replace function public.admin_set_story_status(
  p_story_id uuid,
  p_status text,
  p_secret text
)
returns void
language plpgsql
security definer
as $$
begin
  if p_secret <> '1031xpp' then
    raise exception 'invalid admin secret';
  end if;

  if p_status not in ('pending','approved','rejected') then
    raise exception 'invalid status';
  end if;

  update public.stories
  set status = p_status
  where id = p_story_id;
end;
$$;

revoke all on function public.admin_set_story_status(uuid,text,text) from public;
grant execute on function public.admin_set_story_status(uuid,text,text) to anon, authenticated;
