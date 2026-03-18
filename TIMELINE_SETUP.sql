-- 时间线事件表
CREATE TABLE IF NOT EXISTS public.timeline_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email text,
  title text NOT NULL,
  description text,
  event_date timestamptz NOT NULL,
  tags text[] DEFAULT '{}',
  evidence jsonb DEFAULT '[]',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 启用RLS
ALTER TABLE public.timeline_events ENABLE ROW LEVEL SECURITY;

-- 用户只能看到自己的事件
DROP POLICY IF EXISTS "users can view own events" ON public.timeline_events;
CREATE POLICY "users can view own events"
ON public.timeline_events
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 用户只能插入自己的事件
DROP POLICY IF EXISTS "users can insert own events" ON public.timeline_events;
CREATE POLICY "users can insert own events"
ON public.timeline_events
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 用户只能更新自己的事件
DROP POLICY IF EXISTS "users can update own events" ON public.timeline_events;
CREATE POLICY "users can update own events"
ON public.timeline_events
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 用户只能删除自己的事件
DROP POLICY IF EXISTS "users can delete own events" ON public.timeline_events;
CREATE POLICY "users can delete own events"
ON public.timeline_events
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- 创建更新时间戳的函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器
DROP TRIGGER IF EXISTS update_timeline_events_updated_at ON public.timeline_events;
CREATE TRIGGER update_timeline_events_updated_at
  BEFORE UPDATE ON public.timeline_events
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 创建存储证据文件的bucket（如果不存在）
INSERT INTO storage.buckets (id, name, public)
VALUES ('timeline-evidence', 'timeline-evidence', true)
ON CONFLICT (id) DO NOTHING;

-- 存储访问策略：用户只能访问自己的文件
DROP POLICY IF EXISTS "users can upload own evidence" ON storage.objects;
CREATE POLICY "users can upload own evidence"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'timeline-evidence' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "users can read own evidence" ON storage.objects;
CREATE POLICY "users can read own evidence"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'timeline-evidence' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "users can delete own evidence" ON storage.objects;
CREATE POLICY "users can delete own evidence"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'timeline-evidence' AND (storage.foldername(name))[1] = auth.uid()::text);
