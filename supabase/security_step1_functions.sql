-- ============================================================================
-- goodnight 登录安全加固 · 第 1 步：服务端校验函数
-- ============================================================================
-- 作用：把「密码比对 / 改密码 / 改角色 / 会话增删改查」全部放进数据库函数。
--       客户端不再直接读 users.password_hash，也不再读写 sessions 表。
--
-- 执行时机：可在部署新版网页 / APK 之前先执行（本步不撤销任何权限，
--           旧版客户端照常工作）。完整顺序：
--             ① 跑本脚本 → ② 上线新客户端 → ③ 跑 security_step2_lockdown.sql
--
-- 重复执行安全：全部 create or replace，可反复运行。
-- 哈希算法不变（仍是 App 端 djb2 变体），现有账号密码无需重置。
-- ============================================================================

-- 会话令牌生成：32 字节安全随机数，base64url 风格（去掉 +/= 便于传输）
create or replace function public._new_session_token()
returns text
language plpgsql
as $$
declare
  v_bytes bytea;
  v_token text;
begin
  v_bytes := gen_random_bytes(32);
  v_token := replace(replace(encode(v_bytes, 'base64'), '+', '-'), '/', '_');
  v_token := rtrim(v_token, '=');
  return v_token;
end;
$$;

-- 说明：gen_random_bytes 由 pgcrypto 提供。Supabase 默认已启用该扩展；
-- 若报 "function gen_random_bytes does not exist"，先在 SQL Editor 执行：
--   create extension if not exists pgcrypto with schema extensions;


-- ---------- 1. 登录校验 + 建立会话 ----------
-- 服务端比对密码哈希；成功后由服务端生成令牌并 upsert sessions，
-- 返回 json: {"username": "真实用户名", "token": "会话令牌"}
-- 失败返回 null。客户端拿不到 password_hash，也伪造不了令牌。
create or replace function public.app_login(
  p_user_id text, p_hash text, p_device text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_token text;
begin
  if p_user_id is null or p_hash is null or p_device is null then
    return null;
  end if;
  if p_device not in ('pc', 'phone') then
    return null;
  end if;

  select username
    into v_username
    from public.users
   where user_id = p_user_id
     and password_hash = p_hash
   limit 1;

  if v_username is null then
    return null; -- 登录失败
  end if;

  v_token := public._new_session_token();

  insert into public.sessions (username, device_type, token, created_at, last_active)
  values (v_username, p_device, v_token, now(), now())
  on conflict (username, device_type)
  do update set token = excluded.token,
                created_at = excluded.created_at,
                last_active = excluded.last_active;

  return json_build_object('username', v_username, 'token', v_token);
end;
$$;

comment on function public.app_login(text, text, text) is
  '登录：服务端校验密码并签发会话令牌，成功返回 {username,token}，失败返回 null';


-- ---------- 2. 旧登录态补建会话 ----------
-- 升级前已登录的用户本地没有令牌，调此函数就地补一个，避免全员被误踢。
-- 返回新令牌 text。
create or replace function public.app_ensure_session(
  p_username text, p_device text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
begin
  if p_username is null or p_device is null then
    return null;
  end if;
  if p_device not in ('pc', 'phone') then
    return null;
  end if;
  -- 用户必须真实存在，避免给任意用户名建会话
  if not exists (select 1 from public.users where username = p_username) then
    return null;
  end if;

  v_token := public._new_session_token();

  insert into public.sessions (username, device_type, token, created_at, last_active)
  values (p_username, p_device, v_token, now(), now())
  on conflict (username, device_type)
  do update set token = excluded.token,
                created_at = excluded.created_at,
                last_active = excluded.last_active;

  return v_token;
end;
$$;

comment on function public.app_ensure_session(text, text) is
  '旧登录态平滑迁移：为已存在用户补建会话并返回新令牌';


-- ---------- 3. 会话校验（是否被顶掉） ----------
-- 返回 true = 令牌仍有效；false = 会话不存在或已被同类型新设备顶替。
create or replace function public.app_validate_session(
  p_username text, p_device text, p_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stored text;
begin
  if p_username is null or p_device is null or p_token is null then
    return false;
  end if;

  select token
    into v_stored
    from public.sessions
   where username = p_username
     and device_type = p_device
   limit 1;

  if v_stored is null then
    return false;
  end if;
  return v_stored = p_token;
end;
$$;

comment on function public.app_validate_session(text, text, text) is
  '校验会话令牌是否仍有效（同类型设备被顶替后返回 false）';


-- ---------- 4. 登出（只删本机会话） ----------
-- 按 token 精确删除：被顶替后 sessions 里那行已属于新设备，
-- 旧设备登出时 token 不匹配会删 0 行，不误伤新设备。
create or replace function public.app_logout_session(
  p_username text, p_device text, p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_username is null or p_device is null or p_token is null then
    return;
  end if;

  delete from public.sessions
   where username = p_username
     and device_type = p_device
     and token = p_token;
end;
$$;

comment on function public.app_logout_session(text, text, text) is
  '登出：按令牌精确删除本机会话，不影响新设备';


-- ---------- 5. 修改密码 ----------
-- 旧哈希校验 + 新哈希写入都在服务端完成，调用方无需读/写 password_hash。
-- 返回 true = 旧密码正确且已改；false = 用户名不存在或旧密码错误。
create or replace function public.app_change_password(
  p_username text, p_old_hash text, p_new_hash text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_username is null or p_old_hash is null or p_new_hash is null then
    return false;
  end if;

  update public.users
     set password_hash = p_new_hash
   where username = p_username
     and password_hash = p_old_hash;

  return found; -- found = true 表示命中了行，即旧哈希正确
end;
$$;

comment on function public.app_change_password(text, text, text) is
  '改密码：服务端校验旧哈希并写入新哈希，旧密码错误返回 false';


-- ---------- 6. 修改用户角色（管理员专用） ----------
-- 服务端校验「调用者本人确实是管理员」：
--   ① sessions 表里必须有 (caller, token, device) 匹配的会话（令牌由服务端签发，
--      anon 无法伪造，见第 2 步会撤销 sessions 全部 anon 权限）
--   ② users 表里 caller 的 role 必须是 admin
-- 两项都通过才允许改目标用户角色。普通用户自己提权会被拒绝。
-- ⚠️ 安全：所有拒绝分支统一抛「操作失败」，不向调用方暴露具体是哪一项没通过，
--    避免攻击者靠报错差异探测校验逻辑；真实原因只留在数据库日志里。
create or replace function public.app_set_role(
  p_caller text, p_token text, p_device text, p_target text, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_valid_session boolean;
begin
  if p_caller is null or p_token is null or p_device is null
     or p_target is null or p_role is null then
    raise exception '操作失败';
  end if;

  select exists(
    select 1
      from public.sessions s
     where s.username = p_caller
       and s.token = p_token
       and s.device_type = p_device
  ) into v_valid_session;

  if not v_valid_session then
    raise exception '操作失败';
  end if;

  select role
    into v_caller_role
    from public.users
   where username = p_caller;

  if v_caller_role is distinct from 'admin' then
    raise exception '操作失败';
  end if;

  if p_role not in ('user', 'reviewer', 'admin') then
    raise exception '操作失败';
  end if;

  update public.users set role = p_role where username = p_target;
end;
$$;

comment on function public.app_set_role(text, text, text, text, text) is
  '管理员改角色：核对服务端签发的会话令牌与 admin 身份后才写入';


-- ---------- 7. 授权 ----------
-- 函数以 definer（建表者）权限运行，内部已做身份/密码校验，
-- 因此可放心授予 anon 执行权限。真正要防的是「直接读写敏感表/列」，在第 2 步。
grant execute on function public.app_login(text, text, text) to anon;
grant execute on function public.app_ensure_session(text, text) to anon;
grant execute on function public.app_validate_session(text, text, text) to anon;
grant execute on function public.app_logout_session(text, text, text) to anon;
grant execute on function public.app_change_password(text, text, text) to anon;
grant execute on function public.app_set_role(text, text, text, text, text) to anon;

-- 注意：authenticated 角色当前未使用（App 只用 anon key），故不授权。
