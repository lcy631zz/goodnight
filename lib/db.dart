import 'models.dart';
import 'backend.dart';
import 'supabase_backend.dart';

/// 静态门面（Facade）：页面层统一通过 `DB.xxx()` 调用后端能力。
///
/// 所有调用都委托给一个实现了 [Backend] 接口的后端实例。
/// 当前默认实现是 [SupabaseBackend]（海外 Supabase，免备案）。
///
/// 将来迁移到国内后端时，只需：
///   1. 新建一个实现 [Backend] 的类（例如 domestic_backend.dart 里的 DomesticBackend）；
///   2. 把下面这一行的 `SupabaseBackend()` 换成 `DomesticBackend()`；
/// 页面层与 db.dart 的调用处均无需改动。
class DB {
  static final Backend _backend = SupabaseBackend();

  // ---------- 帖子 ----------
  static Future<List<Post>> allPosts() => _backend.allPosts();
  static Future<Post?> postById(int id, {bool includeHidden = false}) =>
      _backend.postById(id, includeHidden: includeHidden);
  static Future<List<Post>> postsByIds(List<int> ids) => _backend.postsByIds(ids);
  static Future<int> insertPost(Post p) => _backend.insertPost(p);
  static Future<void> updatePost(Post p) => _backend.updatePost(p);
  static Future<void> hidePost(int id) => _backend.hidePost(id);
  static Future<void> deletePost(int id) => _backend.deletePost(id);
  static Future<void> setPostSold(int id, bool sold) =>
      _backend.setPostSold(id, sold);
  static Future<List<Post>> postsByAuthor(String author) =>
      _backend.postsByAuthor(author);
  static Future<void> removeComment(int postId, int commentId) =>
      _backend.removeComment(postId, commentId);
  static Future<void> decorate(Post p) => _backend.decorate(p);
  static Future<List<({Post post, String reason})>> recommendFeed(
          {String? me, String? board}) =>
      _backend.recommendFeed(me: me, board: board);
  static Future<List<Post>> recommendPosts({String? me, String? board}) =>
      _backend.recommendPosts(me: me, board: board);

  // ---------- 账号 / 登录 ----------
  static Future<String?> getCurrentUser() => _backend.getCurrentUser();
  static Future<User?> currentUserModel() => _backend.currentUserModel();
  static Future<User?> getUser(String username) => _backend.getUser(username);
  static Future<List<User>> allUsers() => _backend.allUsers();
  static Future<bool> isAdmin() => _backend.isAdmin();
  static Future<bool> login(String username, String password) =>
      _backend.login(username, password);
  static Future<void> logout() => _backend.logout();
  static Future<bool> changePassword(String username, String oldPw, String newPw) =>
      _backend.changePassword(username, oldPw, newPw);
  static Future<void> updateUser(User u) => _backend.updateUser(u);
  static Future<void> setRole(String username, String role) =>
      _backend.setRole(username, role);
  static Future<bool> canReview() async {
    final u = await _backend.currentUserModel();
    return u != null && (u.role == 'admin' || u.role == 'reviewer');
  }

  // ---------- 举报 / 审核 ----------
  static Future<void> addReport(Report r) => _backend.addReport(r);
  static Future<List<Report>> pendingReports() => _backend.pendingReports();
  static Future<void> resolveReport(int reportId, bool approve, String reviewer) =>
      _backend.resolveReport(reportId, approve, reviewer);

  // ---------- 反馈 ----------
  static Future<void> submitFeedback(AppFeedback f) =>
      _backend.submitFeedback(f);
  static Future<List<AppFeedback>> allFeedback() => _backend.allFeedback();
  static Future<void> resolveFeedback(int id, bool handled) =>
      _backend.resolveFeedback(id, handled);

  // ---------- 好友 / 私信 ----------
  static Future<List<String>> friendsOf(String user) => _backend.friendsOf(user);
  static Future<bool> isFriend(String a, String b) => _backend.isFriend(a, b);
  static Future<void> addFriend(String a, String b) => _backend.addFriend(a, b);
  static Future<bool> sendFriendRequest(String from, String to) =>
      _backend.sendFriendRequest(from, to);
  static Future<List<FriendRequest>> incomingRequests(String user) =>
      _backend.incomingRequests(user);
  static Future<List<FriendRequest>> outgoingRequests(String user) =>
      _backend.outgoingRequests(user);
  static Future<void> respondRequest(int id, bool accept) =>
      _backend.respondRequest(id, accept);
  static Future<List<Message>> messagesBetween(String a, String b) =>
      _backend.messagesBetween(a, b);
  static Future<List<Map<String, dynamic>>> conversations(String user) =>
      _backend.conversations(user);
  static Future<int> sendMessage(Message m) => _backend.sendMessage(m);
  static Future<void> markRead(String me, String peer) =>
      _backend.markRead(me, peer);
  static Future<int> unreadTotal(String user) => _backend.unreadTotal(user);

  // ---------- 个人收藏（点赞 / 收藏 / 历史） ----------
  static Future<List<int>> likedIds() => _backend.likedIds();
  static Future<List<int>> collectedIds() => _backend.collectedIds();
  static Future<List<int>> historyIds() => _backend.historyIds();
  static Future<void> toggleLike(int id, bool liked) =>
      _backend.toggleLike(id, liked);
  static Future<void> toggleCollect(int id, bool collected) =>
      _backend.toggleCollect(id, collected);
  static Future<void> addHistory(int id) => _backend.addHistory(id);
}
