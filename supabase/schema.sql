-- ============================================================================
-- goodnight 校园论坛 · Supabase 后端 schema
-- 在 Supabase 控制台 SQL Editor 里一次性执行本文件即可。
-- ============================================================================

-- 1) 帖子（评论以 jsonb 存为嵌套树，与 App 端 Comment 结构一致；images 为图片 URL 数组）
create table if not exists public.posts (
  id            bigint generated always as identity primary key,
  board         text        not null,
  title         text        not null,
  body          text        default '',
  image_caption text        default '',
  color         text        default '#3B6FE0',
  author        text        not null,
  views         int         default 0,
  likes         int         default 0,
  comments      jsonb       default '[]'::jsonb,
  uncertain     boolean     default false,
  hidden        boolean     default false,
  images        text[]      default '{}',
  time          text        default '刚刚',
  sold          boolean     default false,
  created_at    timestamptz default now()
);

-- 黑市「已售出」标记（重复执行安全：表已存在时只补列，不报错）
alter table public.posts add column if not exists sold boolean default false;

-- 2) 用户（avatar_url 为头像图片 URL，替代原本地路径）
create table if not exists public.users (
  username      text primary key,
  role          text default 'user',
  password_hash text,
  avatar_emoji  text default '',
  avatar_color  text default '#3B6FE0',
  avatar_url    text,
  bio           text,
  region        text,
  gender        text,
  grade         text,
  major         text
);

-- 3) 用户元数据（点赞 / 收藏 / 浏览历史，按用户名隔离）
create table if not exists public.user_meta (
  username  text primary key references public.users(username) on delete cascade,
  liked     int[] default '{}',
  collected int[] default '{}',
  history   int[] default '{}'
);

-- 4) 好友（双向各存一行；列名避开了 SQL 保留字 user）
create table if not exists public.friends (
  username text not null,
  friend   text not null,
  primary key (username, friend)
);

-- 5) 好友请求（from/to 改为 requester/addressee，避开保留字）
create table if not exists public.friend_requests (
  id         bigint generated always as identity primary key,
  requester  text not null,
  addressee  text not null,
  status     text default 'pending',
  time       text default ''
);

-- 6) 私信（from/to 改为 sender/receiver，避开保留字）
create table if not exists public.messages (
  id        bigint generated always as identity primary key,
  sender    text not null,
  receiver  text not null,
  text      text,
  image_url text,
  sticker   text,
  time      text default '',
  read      boolean default false,
  recalled  boolean default false
);

-- 7) 举报 / 审核队列
create table if not exists public.reports (
  id           bigint generated always as identity primary key,
  type         text not null,
  target_id    bigint not null,
  comment_id   bigint,
  reporter     text,
  reason       text,
  source       text default 'user',
  status       text default 'pending',
  reviewed_by  text,
  reviewed_at  text
);

-- 8) 用户反馈 / bug 上报（type: 'bug' | 'suggestion' | 'other'；status: 'new' | 'handled'）
create table if not exists public.feedback (
  id          bigint generated always as identity primary key,
  type        text default 'other',
  content     text not null,
  username    text default '匿名用户',
  app_version text default '',
  status      text default 'new',
  created_at  timestamptz default now()
);

-- ============================================================================
-- 行级安全（RLS）
-- MVP 阶段用宽松策略（任何人可读写），方便联调；上线前务必接入 Supabase Auth 并收紧。
-- ⚠️ 安全提示：宽松策略意味着任何拿到 anon key 的人都能改数据，仅用于内测/演示。
-- ============================================================================
alter table public.posts            enable row level security;
alter table public.users            enable row level security;
alter table public.user_meta        enable row level security;
alter table public.friends          enable row level security;
alter table public.friend_requests  enable row level security;
alter table public.messages         enable row level security;
alter table public.reports          enable row level security;
alter table public.feedback         enable row level security;

drop policy if exists "allow all" on public.posts;
drop policy if exists "allow all" on public.users;
drop policy if exists "allow all" on public.user_meta;
drop policy if exists "allow all" on public.friends;
drop policy if exists "allow all" on public.friend_requests;
drop policy if exists "allow all" on public.messages;
drop policy if exists "allow all" on public.reports;

create policy "allow all" on public.posts           for all using (true) with check (true);
create policy "allow all" on public.users           for all using (true) with check (true);
create policy "allow all" on public.user_meta       for all using (true) with check (true);
create policy "allow all" on public.friends         for all using (true) with check (true);
create policy "allow all" on public.friend_requests for all using (true) with check (true);
create policy "allow all" on public.messages        for all using (true) with check (true);
create policy "allow all" on public.reports         for all using (true) with check (true);
create policy "allow all" on public.feedback        for all using (true) with check (true);

-- ============================================================================
-- 存储桶：图片 / 头像（公开读，写入由 anon key 放行）
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

drop policy if exists "media public read"  on storage.objects;
drop policy if exists "media anon write"   on storage.objects;
drop policy if exists "media anon update"  on storage.objects;
drop policy if exists "media anon delete"  on storage.objects;

create policy "media public read"  on storage.objects for select using (bucket_id = 'media');
create policy "media anon write"   on storage.objects for insert with check (bucket_id = 'media');
create policy "media anon update"  on storage.objects for update using (bucket_id = 'media') with check (bucket_id = 'media');
create policy "media anon delete"  on storage.objects for delete using (bucket_id = 'media');

-- ============================================================================
-- 种子账号（首次执行即可；重复执行有 ON CONFLICT 保护，不会重复插入）
-- 账号清单：
--   小ye    管理员(admin)   密码 breeze
--   MS100   普通用户(user)  密码 12345678
-- password_hash 由 App 端 _hash()（djb2 变体，16 进制）生成，切勿手改。
-- 若需删除旧测试账号并重建，见同目录 accounts.sql。
-- ============================================================================
insert into public.users (username, role, password_hash, avatar_emoji, avatar_color)
values
  ('小ye',  'admin', '74c09be2', '🌙', '#3B6FE0'),
  ('MS100', 'user',  '37eef629', '🎓', '#F25C7E')
on conflict (username) do nothing;

insert into public.user_meta (username, liked, collected, history)
values
  ('小ye',  '{}', '{}', '{}'),
  ('MS100', '{}', '{}', '{}')
on conflict (username) do nothing;
