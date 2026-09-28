/// Supabase 配置。
///
/// 在 Supabase 控制台（Project Settings → API）复制 Project URL 与 anon/public key，
/// 分别填到下面两行。然后去 Supabase SQL Editor 执行 supabase/schema.sql 建表。
///
/// ⚠️ anon key 是设计上可暴露在前端的（由 RLS 行级安全策略保护），
///    千万不要填 service_role key（那拥有绕过 RLS 的超级权限）。
const String supabaseUrl = 'https://osmctjyhdvwmeyljeeua.supabase.co';
const String supabaseAnonKey = 'sb_publishable_cOhO4R5J1TcYF_BOXwrfkg_43xpz1cP';
