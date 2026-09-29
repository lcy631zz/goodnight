-- ============================================================================
-- goodnight · 修复：两个测试账号登不进去
--
-- 【问题】
--   数据库里 小ye 和 MS100 的 password_hash 存的是 **明文**
--   （小ye = 'breeze'，MS100 = '123456'）。
--   但 App 登录时会先把输入做 _hash()（djb2 变体、16 进制），再拿哈希去和
--   password_hash 比对。明文永远不等于哈希，所以这两个账号 100% 登不进去。
--   （其他演示账号存的是 7dd1705a，格式正常，那个是 '123456' 的哈希。）
--
-- 【修复】把 password_hash 改回正确哈希（由 App 的 _hash() 生成）：
--   '74c09be2' = hash('breeze')
--   '37eef629' = hash('12345678')
--
-- 【用法】复制本文件全部内容，粘贴到 Supabase 控制台 → SQL Editor → Run。
--   可重复执行，幂等安全。
-- ============================================================================

update public.users set password_hash = '74c09be2' where username = '小ye';
update public.users set password_hash = '37eef629' where username = 'MS100';

-- 核对：执行后应分别显示 74c09be2 与 37eef629
select username, role, password_hash
from public.users
where username in ('小ye', 'MS100');
