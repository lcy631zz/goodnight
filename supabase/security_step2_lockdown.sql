-- ============================================================================
-- goodnight 登录安全加固 · 第 2 步：收紧敏感列权限
-- ============================================================================
-- ⚠️ 执行前必须确认：新版网页 / APK 已经上线并被同学刷新到！
--    因为本脚本会撤销 anon 直接读写 password_hash / role 的权限，
--    旧版客户端还在使用旧方式，会登录失败。
--
-- 前置条件：security_step1_functions.sql 已执行成功（3 个函数存在）。
-- 本脚本可重复执行（幂等）。
--
-- 加固后效果：
--   ✅ 任何人无法再通过 anon key 读取 users.password_hash（拖库失效）
--   ✅ 任何人无法再直接改 role（普通用户自己提权失效）
--   ✅ 任何人无法再直接改 password_hash（改别人密码失效）
--   ✅ 登录 / 改密码 / 改角色 全部走第 1 步的服务端函数
--   ✅ 编辑资料、发帖子、传图片等原有功能不受影响
-- ============================================================================

-- ---------- 核心原理 ----------
-- PostgreSQL 里「表级 GRANT」会覆盖「列级 REVOKE」，所以不能只写
--   revoke select (password_hash) on public.users from anon;   -- 这样没用
-- 正确做法：先撤销表级权限，再按列白名单重新授予。

-- ============================================================================
-- 1) SELECT：撤销表级，重建列白名单（不含 password_hash）
-- ============================================================================
revoke select on public.users from anon;

grant select (
  username,
  role,
  avatar_emoji,
  avatar_color,
  avatar_url,
  bio,
  region,
  gender,
  grade,
  major,
  user_id
) on public.users to anon;

-- ============================================================================
-- 2) UPDATE：撤销表级，只开放「个人资料」相关列
--    不含 password_hash、不含 role
-- ============================================================================
revoke update on public.users from anon;

grant update (
  avatar_emoji,
  avatar_color,
  avatar_url,
  bio,
  region,
  gender,
  grade,
  major
) on public.users to anon;

-- ============================================================================
-- 3) INSERT：保留
--    校内账号上传工具 supabase/upload_accounts.html 用 anon key 直接 insert 账号，
--    这里不动，否则那个工具会失效。insert 不能读取已有数据，不构成拖库风险。
--    如需进一步收紧，可把建号改成服务端函数后再 revoke insert。
-- ============================================================================

-- ============================================================================
-- 4) DELETE：保留（当前 App 无删除账号功能；如需最严可下掉）
-- ============================================================================

-- ============================================================================
-- 5) sessions 表：撤销 anon 的全部直接读写 ★ 提权闭环的关键 ★
--    会话令牌现在只由第 1 步的服务端函数签发、校验、删除。
--    anon 若还能直接写 sessions，就能伪造一条 admin 会话绕过角色校验。
--    撤销后 App 的登录/校验/登出/改角色全部走函数，功能不受影响。
-- ============================================================================
revoke all on public.sessions from anon;

-- ============================================================================
-- 6) 验收查询：执行后把结果截图发我核对
--    期望：password_hash 那一行 has_select = false、has_update = false
--          role 那一行 has_select = true、has_update = false
--          bio  那一行 has_select = true、has_update = true
-- ============================================================================
-- select
--   column_name,
--   coalesce(
--     (select count(*) > 0 from information_schema.column_privileges cp
--       where cp.table_schema = 'public' and cp.table_name = 'users'
--         and cp.column_name = c.column_name and cp.grantee = 'anon'
--         and cp.privilege_type = 'SELECT'), false) as has_select,
--   coalesce(
--     (select count(*) > 0 from information_schema.column_privileges cp
--       where cp.table_schema = 'public' and cp.table_name = 'users'
--         and cp.column_name = c.column_name and cp.grantee = 'anon'
--         and cp.privilege_type = 'UPDATE'), false) as has_update
-- from information_schema.columns c
-- where c.table_schema = 'public' and c.table_name = 'users'
-- order by ordinal_position;
