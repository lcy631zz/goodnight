-- ============================================================================
-- goodnight · 账户重置（在 Supabase 控制台 SQL Editor 执行）
-- 作用：删除原有测试账号 + 演示社交数据，并创建两个账号：
--   小ye    管理员(admin)   密码 breeze
--   MS100   普通用户(user)  密码 12345678
-- password_hash 由 App 端 _hash()（djb2 变体，16 进制）生成，切勿手改。
-- 说明：可重复执行，幂等安全（旧账号在则删，新账号冲突则跳过）。
-- 前提：请先执行过 schema.sql（已建好表与 RLS 策略）。
-- ============================================================================

-- 1) 清掉演示社交数据（它们引用了将被删除的测试账号）
delete from public.messages;
delete from public.friend_requests;
delete from public.friends;

-- 2) 删除原有测试账号（user_meta 设了 on delete cascade，会一并删除）
delete from public.users
where username in ('夜猫子', '小安', '阿杰', '林夕', '陈默');

-- 3) 创建两个账号
insert into public.users (username, role, password_hash, avatar_emoji, avatar_color)
values
  ('小ye',  'admin', '74c09be2', '🌙', '#3B6FE0'),
  ('MS100', 'user',  '37eef629', '🎓', '#F25C7E')
-- 用 do update 而不是 do nothing：即使账号已存在（例如曾被手改成明文密码），
-- 重跑本脚本也会把 role / password_hash / 头像修正回来。
on conflict (username) do update
  set role          = excluded.role,
      password_hash = excluded.password_hash,
      avatar_emoji  = excluded.avatar_emoji,
      avatar_color  = excluded.avatar_color;

insert into public.user_meta (username, liked, collected, history)
values
  ('小ye',  '{}', '{}', '{}'),
  ('MS100', '{}', '{}', '{}')
on conflict (username) do nothing;
