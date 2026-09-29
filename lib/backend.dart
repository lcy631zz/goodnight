import 'models.dart';

/// 后端抽象接口：定义 goodnight 全部数据访问契约。
///
/// 页面层只依赖本接口（通过 [DB] 静态门面调用），
/// 不关心底层是 Supabase 还是将来的国内自建后端。
///
/// 迁移到国内后端时，只需新增一个实现 [Backend] 的类，
/// 并把 db.dart 中 `_backend` 的实例化一行换掉即可，页面零改动。
abstract class Backend {
  // ---------- 帖子 ----------
  Future<List<Post>> allPosts();
  Future<Post?> postById(int id, {bool includeHidden = false});
  Future<List<Post>> postsByIds(List<int> ids);
  Future<int> insertPost(Post p);
  Future<void> updatePost(Post p);
  Future<void> hidePost(int id);
  Future<void> setPostSold(int id, bool sold);
  Future<List<Post>> postsByAuthor(String author);
  Future<void> removeComment(int postId, int commentId);
  Future<void> decorate(Post p);
  Future<List<({Post post, String reason})>> recommendFeed({String? me, String? board});
  Future<List<Post>> recommendPosts({String? me, String? board});

  // ---------- 账号 / 登录 ----------
  Future<String?> getCurrentUser();
  Future<User?> currentUserModel();
  Future<User?> getUser(String username);
  Future<List<User>> allUsers();
  Future<bool> isAdmin();
  Future<bool> login(String username, String password);
  Future<void> logout();
  Future<bool> changePassword(String username, String oldPw, String newPw);
  Future<void> updateUser(User u);
  Future<void> setRole(String username, String role);

  // ---------- 举报 / 审核 ----------
  Future<void> addReport(Report r);
  Future<List<Report>> pendingReports();
  Future<void> resolveReport(int reportId, bool approve, String reviewer);

  // ---------- 反馈 ----------
  Future<void> submitFeedback(AppFeedback f);
  Future<List<AppFeedback>> allFeedback();
  Future<void> resolveFeedback(int id, bool handled);

  // ---------- 好友 / 私信 ----------
  Future<List<String>> friendsOf(String user);
  Future<bool> isFriend(String a, String b);
  Future<void> addFriend(String a, String b);
  Future<bool> sendFriendRequest(String from, String to);
  Future<List<FriendRequest>> incomingRequests(String user);
  Future<List<FriendRequest>> outgoingRequests(String user);
  Future<void> respondRequest(int id, bool accept);
  Future<List<Message>> messagesBetween(String a, String b);
  Future<List<Map<String, dynamic>>> conversations(String user);
  Future<int> sendMessage(Message m);
  Future<void> markRead(String me, String peer);
  Future<int> unreadTotal(String user);

  // ---------- 个人收藏（点赞 / 收藏 / 历史） ----------
  Future<List<int>> likedIds();
  Future<List<int>> collectedIds();
  Future<List<int>> historyIds();
  Future<void> toggleLike(int id, bool liked);
  Future<void> toggleCollect(int id, bool collected);
  Future<void> addHistory(int id);
}
