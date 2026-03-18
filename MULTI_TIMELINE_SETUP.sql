-- ========================================
-- 多账户时间线管理系统数据库设计
-- ========================================

-- 1. 时间线表 (每个账户可创建多条时间线)
CREATE TABLE IF NOT EXISTS public.timelines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email text,
  title text NOT NULL,                    -- 时间线名称
  description text,                       -- 时间线描述
  category text DEFAULT 'default',        -- 分类：案件/项目/个人/其他
  is_public boolean DEFAULT false,        -- 是否公开
  status text DEFAULT 'active',           -- 状态：active/archived/deleted
  event_count integer DEFAULT 0,          -- 事件数量统计
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2. 事件表 (每个时间线可包含多个事件)
CREATE TABLE IF NOT EXISTS public.timeline_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  timeline_id uuid NOT NULL REFERENCES public.timelines(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,                    -- 事件标题
  description text,                       -- 事件描述
  event_date timestamptz NOT NULL,        -- 事件发生时间
  event_location text,                    -- 事件地点
  event_type text DEFAULT 'default',      -- 事件类型
  tags text[] DEFAULT '{}',               -- 标签数组
  importance text DEFAULT 'normal',       -- 重要程度：low/normal/high/critical
  status text DEFAULT 'active',           -- 状态：active/completed/archived
  evidence jsonb DEFAULT '[]',            -- 证据附件 [{name, type, url, path}]
  notes text,                             -- 备注
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. 协作成员表 (支持多用户协作一条时间线)
CREATE TABLE IF NOT EXISTS public.timeline_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  timeline_id uuid NOT NULL REFERENCES public.timelines(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email text,
  role text DEFAULT 'viewer',             -- 角色：owner/editor/viewer
  invited_by uuid REFERENCES auth.users(id),
  invited_at timestamptz DEFAULT now(),
  accepted_at timestamptz,
  UNIQUE(timeline_id, user_id)
);

-- ========================================
-- 启用RLS (行级安全)
-- ========================================

ALTER TABLE public.timelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timeline_members ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 时间线表策略
-- ========================================

-- 用户可以查看自己的时间线
CREATE POLICY "users can view own timelines" ON public.timelines
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- 用户可以查看被邀请协作的时间线
CREATE POLICY "users can view collaborated timelines" ON public.timelines
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.timeline_members
    WHERE timeline_id = id AND user_id = auth.uid()
  )
);

-- 用户可以创建自己的时间线
CREATE POLICY "users can create own timelines" ON public.timelines
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的时间线
CREATE POLICY "users can update own timelines" ON public.timelines
FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 用户可以删除自己的时间线
CREATE POLICY "users can delete own timelines" ON public.timelines
FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- ========================================
-- 事件表策略
-- ========================================

-- 用户可以查看自己时间线的事件
CREATE POLICY "users can view own events" ON public.timeline_events
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.timelines
    WHERE id = timeline_id AND user_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM public.timeline_members
    WHERE timeline_id = timeline_events.timeline_id AND user_id = auth.uid()
  )
);

-- 用户可以创建自己时间线的事件
CREATE POLICY "users can create own events" ON public.timeline_events
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.timelines
    WHERE id = timeline_id AND user_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM public.timeline_members
    WHERE timeline_id = timeline_events.timeline_id 
    AND user_id = auth.uid() 
    AND role IN ('owner', 'editor')
  )
);

-- 用户可以更新自己时间线的事件
CREATE POLICY "users can update own events" ON public.timeline_events
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.timelines
    WHERE id = timeline_id AND user_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM public.timeline_members
    WHERE timeline_id = timeline_events.timeline_id 
    AND user_id = auth.uid() 
    AND role IN ('owner', 'editor')
  )
);

-- 用户可以删除自己时间线的事件
CREATE POLICY "users can delete own events" ON public.timeline_events
FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.timelines
    WHERE id = timeline_id AND user_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM public.timeline_members
    WHERE timeline_id = timeline_events.timeline_id 
    AND user_id = auth.uid() 
    AND role = 'owner'
  )
);

-- ========================================
-- 协作成员表策略
-- ========================================

CREATE POLICY "members can view own memberships" ON public.timeline_members
FOR SELECT TO authenticated
USING (user_id = auth.uid() OR invited_by = auth.uid());

CREATE POLICY "owners can add members" ON public.timeline_members
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.timelines
    WHERE id = timeline_id AND user_id = auth.uid()
  )
);

CREATE POLICY "owners can remove members" ON public.timeline_members
FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.timelines
    WHERE id = timeline_id AND user_id = auth.uid()
  )
);

-- ========================================
-- 触发器：自动更新时间戳
-- ========================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_timelines_updated_at ON public.timelines;
CREATE TRIGGER update_timelines_updated_at
  BEFORE UPDATE ON public.timelines
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_timeline_events_updated_at ON public.timeline_events;
CREATE TRIGGER update_timeline_events_updated_at
  BEFORE UPDATE ON public.timeline_events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- 触发器：自动更新事件数量
-- ========================================

CREATE OR REPLACE FUNCTION update_timeline_event_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.timelines SET event_count = event_count + 1 WHERE id = NEW.timeline_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.timelines SET event_count = event_count - 1 WHERE id = OLD.timeline_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_event_count ON public.timeline_events;
CREATE TRIGGER update_event_count
  AFTER INSERT OR DELETE ON public.timeline_events
  FOR EACH ROW EXECUTE FUNCTION update_timeline_event_count();

-- ========================================
-- 存储桶：用于存储证据文件
-- ========================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('timeline-evidence', 'timeline-evidence', true)
ON CONFLICT (id) DO NOTHING;

-- 存储策略
CREATE POLICY "users can upload own evidence" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'timeline-evidence' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "users can read own evidence" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'timeline-evidence' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "users can delete own evidence" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'timeline-evidence' AND (storage.foldername(name))[1] = auth.uid()::text);
