-- ============================================================================
-- goodnight · 单设备登录限制：sessions 表
-- 在 Supabase 控制台 SQL Editor 里单独执行本文件即可（建表 + RLS）。
-- 若已执行过完整 schema.sql，本文件可跳过（schema.sql 已含相同内容）。
-- ============================================================================

-- 登录会话：每个账号最多 1 个 PC + 1 个手机；同类型设备再次登录会覆盖旧会话（顶掉旧设备）。
create table if not exists public.sessions (
  username     text not null,
  device_type  text not null check (device_type in ('pc','phone')),
  token        text not null,
  created_at   timestamptz not null default now(),
  last_active  timestamptz not null default now(),
  primary key (username, device_type)
);

-- 与当前 MVP 一致的宽松 RLS（内测/联调用；上线前需收紧）
alter table public.sessions enable row level security;
create policy "allow all" on public.sessions for all using (true) with check (true);
