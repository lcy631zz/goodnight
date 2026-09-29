import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'backend.dart';
import 'auth_state.dart';

/// 推荐排序的中间结果（帖子和推荐理由）。
class _Scored {
  final Post post;
  final double score;
  final String author;
  final String reason;
  _Scored(this.post, this.score, this.author, this.reason);
}

/// Supabase 后端持久化层（实现 [Backend] 接口，替代原本地 JSON 文件）。
///
/// 设计要点：
/// - 本类实现 [Backend] 抽象接口，因此页面层无需关心底层实现。
/// - 帖子/评论/点赞/好友/私信等数据存于 Supabase 数据库；图片与头像存于 media 存储桶（返回 URL）。
/// - “当前登录用户”是本机会话，用 shared_preferences 记录（不做跨设备登录态）。
/// - 演示种子数据请在 Supabase SQL Editor 执行 supabase/schema.sql（含登录密码 123456 的账号）。
///
/// ⚠️ 安全提示：本 MVP 使用宽松 RLS（任何人可读写），仅用于内测/联调。
///    正式上线前务必接入 Supabase Auth 并收紧策略，且不要在客户端存储明文/弱哈希密码。
class SupabaseBackend implements Backend {
  SupabaseClient get _sb => Supabase.instance.client;

  // ---------- 本机会话（当前登录用户名） ----------
  Future<String?> _sessionUser() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('current_user');
  }

  Future<void> _setSessionUser(String? u) async {
    final sp = await SharedPreferences.getInstance();
    if (u == null) {
      await sp.remove('current_user');
    } else {
      await sp.setString('current_user', u);
    }
  }

  // ---------- 行 → 模型 映射 ----------
  Post _rowToPost(Map<String, dynamic> r) {
    final comments = r['comments'] is List ? r['comments'] as List : const [];
    final images = (r['images'] is List ? r['images'] as List : const [])
        .map((e) => e.toString())
        .toList();
    return Post.fromMap({
      'id': r['id'],
      'board': r['board'],
      'title': r['title'],
      'body': r['body'] ?? '',
      'imageCaption': r['image_caption'],
      'color': r['color'],
      'author': r['author'],
      'views': r['views'] ?? 0,
      'likes': r['likes'] ?? 0,
      'liked': 0,
      'collected': 0,
      'collects': r['collects'] ?? 0,
      'shares': r['shares'] ?? 0,
      'time': r['time'] ?? '刚刚',
      'comments': jsonEncode(comments),
        'uncertain': (r['uncertain'] == true) ? 1 : 0,
        'hidden': (r['hidden'] == true) ? 1 : 0,
        'sold': (r['sold'] == true) ? 1 : 0,
        'images': images,
    });
  }

  Map<String, dynamic> _postToRow(Post p) => {
        'board': p.board,
        'title': p.title,
        'body': p.body,
        'image_caption': p.imageCaption,
        'color': p.color,
        'author': p.author,
        'views': p.views,
        'likes': p.likes,
        'collects': p.collects,
        'shares': p.shares,
        'comments': p.comments.map((c) => c.toJson()).toList(),
        'uncertain': p.uncertain,
        'hidden': p.hidden,
        'sold': p.sold,
        'images': p.images,
        'time': p.time,
      };

  User _rowToUser(Map<String, dynamic> r) => User(
        username: r['username'],
        role: r['role'] ?? 'user',
        password: r['password_hash'] ?? '',
        avatarEmoji: r['avatar_emoji'] ?? '',
        avatarColor: r['avatar_color'] ?? '#3B6FE0',
        avatarPath: r['avatar_url'],
        bio: r['bio'],
        region: r['region'],
        gender: r['gender'],
        grade: r['grade'],
        major: r['major'],
      );

  Report _rowToReport(Map<String, dynamic> r) => Report(
        id: r['id'],
        type: r['type'],
        targetId: r['target_id'],
        commentId: r['comment_id'],
        reporter: r['reporter'],
        reason: r['reason'],
        source: r['source'] ?? 'user',
        status: r['status'] ?? 'pending',
        reviewedBy: r['reviewed_by'],
        reviewedAt: r['reviewed_at'],
      );

  Message _rowToMessage(Map<String, dynamic> r) => Message(
        id: r['id'],
        from: r['sender'],
        to: r['receiver'],
        text: r['text'],
        imagePath: r['image_url'],
        sticker: r['sticker'],
        time: r['time'] ?? '',
        read: r['read'] == true,
        recalled: r['recalled'] == true,
      );

  FriendRequest _rowToRequest(Map<String, dynamic> r) => FriendRequest(
        id: r['id'],
        from: r['requester'],
        to: r['addressee'],
        status: r['status'] ?? 'pending',
        time: r['time'] ?? '',
      );

  // ---------- 帖子 ----------
  @override
  Future<List<Post>> allPosts() async {
    final res = await _sb
        .from('posts')
        .select()
        .neq('hidden', true)
        .neq('sold', true)
        .order('id', ascending: false);
    return (res as List)
        .map((e) => _rowToPost(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Post?> postById(int id, {bool includeHidden = false}) async {
    var q = _sb.from('posts').select().eq('id', id);
    if (!includeHidden) q = q.neq('hidden', true);
    final res = await q.maybeSingle();
    return res == null ? null : _rowToPost(res as Map<String, dynamic>);
  }

  @override
  Future<List<Post>> postsByIds(List<int> ids) async {
    final all = await allPosts();
    final map = {for (final p in all) p.id!: p};
    return [for (final id in ids) if (map.containsKey(id)) map[id]!];
  }

  @override
  Future<int> insertPost(Post p) async {
    final row = _postToRow(p);
    final res = await _sb.from('posts').insert(row).select('id').single();
    p.id = res['id'] as int;
    return p.id!;
  }

  @override
  Future<void> updatePost(Post p) async {
    await _sb.from('posts').update(_postToRow(p)).eq('id', p.id!);
  }

  @override
  Future<void> hidePost(int id) async {
    final p = await postById(id, includeHidden: true);
    if (p != null) {
      p.hidden = true;
      await updatePost(p);
    }
  }

  @override
  Future<void> setPostSold(int id, bool sold) async {
    await _sb.from('posts').update({'sold': sold}).eq('id', id);
  }

  @override
  Future<List<Post>> postsByAuthor(String author) async {
    final res = await _sb
        .from('posts')
        .select()
        .eq('author', author)
        .neq('hidden', true)
        .order('id', ascending: false);
    return (res as List)
        .map((e) => _rowToPost(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> removeComment(int postId, int commentId) async {
    final p = await postById(postId, includeHidden: true);
    if (p == null) return;
    _dropComment(p.comments, commentId);
    await updatePost(p);
  }

  bool _dropComment(List<Comment> list, int cid) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].id == cid) {
        list.removeAt(i);
        return true;
      }
      if (_dropComment(list[i].replies, cid)) return true;
    }
    return false;
  }

  @override
  Future<void> decorate(Post p) async {
    final u = await getCurrentUser();
    if (u == null) {
      p.liked = false;
      p.collected = false;
      return;
    }
    final liked = await likedIds();
    final coll = await collectedIds();
    p.liked = liked.contains(p.id);
    p.collected = coll.contains(p.id);
  }

  // ---------- 首页推荐算法（类小红书/抖音） ----------
  int _countReplies(Comment c) =>
      c.replies.fold(0, (n, r) => n + 1 + _countReplies(r));
  int _countMine(List<Comment> list, String me) => list.fold(
      0, (n, c) => n + (c.name == me ? 1 : 0) + _countMine(c.replies, me));

  /// 返回带推荐理由的推荐流；board 传非『推荐』值则在该板块内做推荐筛选。
  @override
  Future<List<({Post post, String reason})>> recommendFeed(
      {String? me, String? board}) async {
    final meUser = me ?? await getCurrentUser();
    final all = await allPosts();
    final likeSet = (meUser != null ? await likedIds() : <int>[]).toSet();
    final collSet = (meUser != null ? await collectedIds() : <int>[]).toSet();
    final boardAff = <String, double>{};
    final authorAff = <String, double>{};
    for (final p in all) {
      double w = 0;
      if (likeSet.contains(p.id)) w += 2;
      if (collSet.contains(p.id)) w += 3;
      if (w > 0) {
        boardAff[p.board] = (boardAff[p.board] ?? 0) + w;
        authorAff[p.author] = (authorAff[p.author] ?? 0) + w;
      }
      if (meUser != null) {
        final cnt = _countMine(p.comments, meUser).toDouble();
        if (cnt > 0) {
          boardAff[p.board] = (boardAff[p.board] ?? 0) + cnt;
          authorAff[p.author] = (authorAff[p.author] ?? 0) + cnt;
        }
      }
    }
    final maxId = all.fold<int>(0, (m, p) => p.id != null && p.id! > m ? p.id! : m);
    final scored = all.map((p) {
      final ageH = ((maxId - (p.id ?? 0)) * 3).toDouble(); // 用 id 近似新鲜度（越新越大）
      final recency = 1 / (1 + ageH / 24);
      final comments = p.comments.fold<int>(0, (n, c) => n + 1 + _countReplies(c));
      final heat = log(1 + p.likes + 3 * comments + 2 * p.collects + p.shares) / ln10 / 2;
      final visual = p.images.isNotEmpty ? 1.15 : 1.0;
      final interest =
          (1 + 0.25 * (boardAff[p.board] ?? 0)) * (1 + 0.4 * (authorAff[p.author] ?? 0));
      final score = (0.5 * recency + 0.5 * heat) * visual * interest;
      String reason;
      if (interest > 1.0 &&
          ((boardAff[p.board] ?? 0) + (authorAff[p.author] ?? 0)) >= 3) {
        reason = '猜你喜欢';
      } else if (heat >= recency && heat > 0.5) {
        reason = '热门';
      } else if (recency > 0.6) {
        reason = '最新';
      } else {
        reason = '推荐';
      }
      return _Scored(p, score, p.author, reason);
    }).toList();
    scored.sort((a, b) => b.score.compareTo(a.score));
    // 多样性重排：同作者不连发、单作者上限 2 条
    final result = <_Scored>[];
    final perAuthor = <String, int>{};
    const cap = 2;
    String? lastAuthor;
    final remain = scored.toList();
    while (remain.isNotEmpty) {
      int pick = -1;
      for (int i = 0; i < remain.length; i++) {
        if (remain[i].author != lastAuthor &&
            (perAuthor[remain[i].author] ?? 0) < cap) {
          pick = i;
          break;
        }
      }
      if (pick == -1) {
        for (int i = 0; i < remain.length; i++) {
          if ((perAuthor[remain[i].author] ?? 0) < cap) {
            pick = i;
            break;
          }
        }
      }
      if (pick == -1) break;
      final s = remain.removeAt(pick);
      result.add(s);
      perAuthor[s.author] = (perAuthor[s.author] ?? 0) + 1;
      lastAuthor = s.author;
    }
    var entries = result
        .map((s) => (post: s.post, reason: s.reason))
        .toList();
    if (board != null && board != '推荐') {
      entries = entries.where((e) => e.post.board == board).toList();
    }
    return entries;
  }

  /// 便捷方法：只取帖子列表。
  @override
  Future<List<Post>> recommendPosts({String? me, String? board}) async =>
      (await recommendFeed(me: me, board: board)).map((e) => e.post).toList();

  // ---------- 账号 / 登录 ----------
  @override
  Future<String?> getCurrentUser() async => _sessionUser();

  @override
  Future<User?> currentUserModel() async {
    final u = await getCurrentUser();
    if (u == null) return null;
    return getUser(u);
  }

  @override
  Future<User?> getUser(String username) async {
    final res = await _sb
        .from('users')
        .select()
        .eq('username', username)
        .maybeSingle();
    if (res == null) return null;
    return _rowToUser(res as Map<String, dynamic>);
  }

  @override
  Future<List<User>> allUsers() async {
    final res = await _sb.from('users').select();
    return (res as List)
        .map((e) => _rowToUser(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> isAdmin() async {
    final u = await currentUserModel();
    return u?.role == 'admin';
  }

  @override
  Future<bool> login(String username, String password) async {
    final res = await _sb
        .from('users')
        .select()
        .eq('username', username)
        .eq('password_hash', _hash(password))
        .maybeSingle();
    if (res == null) return false;
    await _setSessionUser(username);
    authUserNotifier.value = username; // 广播登录事件，刷新所有依赖登录态的界面
    await _ensureAdmin(username);
    return true;
  }

  /// 若系统里还没有任何管理员，则把当前注册账号提升为管理员。
  Future<void> _ensureAdmin(String username) async {
    final res =
        await _sb.from('users').select('username').eq('role', 'admin').limit(1);
    if ((res as List).isNotEmpty) return;
    await _sb.from('users').update({'role': 'admin'}).eq('username', username);
  }

  @override
  Future<void> logout() async {
    await _setSessionUser(null);
    authUserNotifier.value = null; // 广播登出事件，刷新所有依赖登录态的界面
  }

  @override
  Future<bool> changePassword(
      String username, String oldPw, String newPw) async {
    final u = await getUser(username);
    if (u == null) return false;
    if (u.password != _hash(oldPw)) return false;
    await _sb
        .from('users')
        .update({'password_hash': _hash(newPw)})
        .eq('username', username);
    return true;
  }

  @override
  Future<void> updateUser(User u) async {
    await _sb.from('users').update({
      'role': u.role,
      'password_hash': u.password,
      'avatar_emoji': u.avatarEmoji,
      'avatar_color': u.avatarColor,
      'avatar_url': u.avatarPath,
      'bio': u.bio,
      'region': u.region,
      'gender': u.gender,
      'grade': u.grade,
      'major': u.major,
    }).eq('username', u.username);
  }

  @override
  Future<void> setRole(String username, String role) async {
    await _sb.from('users').update({'role': role}).eq('username', username);
  }

  // ---------- 举报 / 审核 ----------
  @override
  Future<void> addReport(Report r) async {
    await _sb.from('reports').insert({
      'type': r.type,
      'target_id': r.targetId,
      'comment_id': r.commentId,
      'reporter': r.reporter,
      'reason': r.reason,
      'source': r.source,
      'status': r.status,
    });
  }

  @override
  Future<List<Report>> pendingReports() async {
    final res = await _sb.from('reports').select().eq('status', 'pending');
    return (res as List)
        .map((e) => _rowToReport(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> resolveReport(
      int reportId, bool approve, String reviewer) async {
    final raw =
        await _sb.from('reports').select().eq('id', reportId).single();
    final r = _rowToReport(raw as Map<String, dynamic>);
    r.status = approve ? 'approved' : 'rejected';
    r.reviewedBy = reviewer;
    r.reviewedAt = DateTime.now().toIso8601String();
    await _sb.from('reports').update({
      'status': r.status,
      'reviewed_by': r.reviewedBy,
      'reviewed_at': r.reviewedAt,
    }).eq('id', reportId);
    if (!approve) {
      if (r.type == 'post') {
        await hidePost(r.targetId);
      } else if (r.type == 'comment' && r.commentId != null) {
        await removeComment(r.targetId, r.commentId!);
      }
    }
  }

  // ---------- 反馈 ----------
  AppFeedback _rowToFeedback(Map<String, dynamic> r) => AppFeedback(
        id: r['id'],
        type: r['type'] ?? 'other',
        content: r['content'] ?? '',
        username: r['username'] ?? '匿名用户',
        appVersion: r['app_version'] ?? '',
        status: r['status'] ?? 'new',
        createdAt: r['created_at'],
      );

  @override
  Future<void> submitFeedback(AppFeedback f) async {
    await _sb.from('feedback').insert(f.toRow());
  }

  @override
  Future<List<AppFeedback>> allFeedback() async {
    final res = await _sb
        .from('feedback')
        .select()
        .order('id', ascending: false);
    return (res as List)
        .map((e) => _rowToFeedback(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> resolveFeedback(int id, bool handled) async {
    await _sb
        .from('feedback')
        .update({'status': handled ? 'handled' : 'new'})
        .eq('id', id);
  }

  // ---------- 好友 / 私信 ----------
  @override
  Future<List<String>> friendsOf(String user) async {
    final res =
        await _sb.from('friends').select('friend').eq('username', user);
    return (res as List).map((e) => (e['friend'] as String)).toList();
  }

  @override
  Future<bool> isFriend(String a, String b) async =>
      (await friendsOf(a)).contains(b);

  @override
  Future<void> addFriend(String a, String b) async {
    await _sb.from('friends').insert([
      {'username': a, 'friend': b},
      {'username': b, 'friend': a},
    ]);
  }

  @override
  Future<bool> sendFriendRequest(String from, String to) async {
    if (from == to) return false;
    if (await isFriend(from, to)) return false;
    final existing = await _sb
        .from('friend_requests')
        .select()
        .eq('requester', from)
        .eq('addressee', to)
        .eq('status', 'pending');
    if ((existing as List).isNotEmpty) return false;
    await _sb.from('friend_requests').insert({
      'requester': from,
      'addressee': to,
      'status': 'pending',
      'time': _hm(DateTime.now()),
    });
    return true;
  }

  @override
  Future<List<FriendRequest>> incomingRequests(String user) async {
    final res = await _sb
        .from('friend_requests')
        .select()
        .eq('addressee', user)
        .eq('status', 'pending');
    return (res as List)
        .map((e) => _rowToRequest(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FriendRequest>> outgoingRequests(String user) async {
    final res = await _sb
        .from('friend_requests')
        .select()
        .eq('requester', user)
        .eq('status', 'pending');
    return (res as List)
        .map((e) => _rowToRequest(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> respondRequest(int id, bool accept) async {
    final raw =
        await _sb.from('friend_requests').select().eq('id', id).single();
    final r = _rowToRequest(raw as Map<String, dynamic>);
    r.status = accept ? 'accepted' : 'rejected';
    await _sb
        .from('friend_requests')
        .update({'status': r.status})
        .eq('id', id);
    if (accept) await addFriend(r.from, r.to);
  }

  @override
  Future<List<Message>> messagesBetween(String a, String b) async {
    final res = await _sb
        .from('messages')
        .select()
        .or(
            'and(sender.eq.$a,receiver.eq.$b),and(sender.eq.$b,receiver.eq.$a)')
        .order('id', ascending: true);
    return (res as List)
        .map((e) => _rowToMessage(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> conversations(String user) async {
    final res = await _sb
        .from('messages')
        .select()
        .or('sender.eq.$user,receiver.eq.$user');
    final all = (res as List)
        .map((e) => _rowToMessage(e as Map<String, dynamic>))
        .toList();
    final peers = <String>{};
    for (final m in all) {
      if (m.from == user) peers.add(m.to);
      if (m.to == user) peers.add(m.from);
    }
    final result = <Map<String, dynamic>>[];
    for (final peer in peers) {
      final msgs = all
          .where((m) =>
              (m.from == user && m.to == peer) ||
              (m.from == peer && m.to == user))
          .toList()
        ..sort((x, y) => (x.id ?? 0).compareTo(y.id ?? 0));
      if (msgs.isEmpty) continue;
      final last = msgs.last;
      final unread =
          msgs.where((m) => m.to == user && !m.read && !m.recalled).length;
      result.add({'peer': peer, 'last': last, 'unread': unread});
    }
    result.sort((a, b) => ((b['last'] as Message).id ?? 0)
        .compareTo((a['last'] as Message).id ?? 0));
    return result;
  }

  @override
  Future<int> sendMessage(Message m) async {
    final res = await _sb.from('messages').insert({
      'sender': m.from,
      'receiver': m.to,
      'text': m.text,
      'image_url': m.imagePath,
      'sticker': m.sticker,
      'time': m.time,
      'read': m.read,
      'recalled': m.recalled,
    }).select('id').single();
    return res['id'] as int;
  }

  @override
  Future<void> markRead(String me, String peer) async {
    await _sb
        .from('messages')
        .update({'read': true})
        .eq('sender', peer)
        .eq('receiver', me);
  }

  @override
  Future<int> unreadTotal(String user) async {
    final res = await _sb
        .from('messages')
        .select('id')
        .eq('receiver', user)
        .eq('read', false)
        .eq('recalled', false);
    return (res as List).length;
  }

  // ---------- 个人收藏（点赞 / 收藏 / 历史） ----------
  Future<Map<String, dynamic>> _profile(String user) async {
    var res =
        await _sb.from('user_meta').select().eq('username', user).maybeSingle();
    if (res == null) {
      await _sb.from('user_meta').insert({
        'username': user,
        'liked': [],
        'collected': [],
        'history': [],
      });
      res = {
        'username': user,
        'liked': [],
        'collected': [],
        'history': [],
      };
    }
    return res as Map<String, dynamic>;
  }

  @override
  Future<List<int>> likedIds() async {
    final u = await getCurrentUser();
    if (u == null) return [];
    final p = await _profile(u);
    return ((p['liked'] as List? ?? []).map((e) => (e as num).toInt())).toList();
  }

  @override
  Future<List<int>> collectedIds() async {
    final u = await getCurrentUser();
    if (u == null) return [];
    final p = await _profile(u);
    return ((p['collected'] as List? ?? []).map((e) => (e as num).toInt()))
        .toList();
  }

  @override
  Future<List<int>> historyIds() async {
    final u = await getCurrentUser();
    if (u == null) return [];
    final p = await _profile(u);
    return ((p['history'] as List? ?? []).map((e) => (e as num).toInt()))
        .toList();
  }

  @override
  Future<void> toggleLike(int id, bool liked) async {
    final u = await getCurrentUser();
    if (u == null) return;
    final p = await _profile(u);
    final l =
        List<int>.from((p['liked'] as List? ?? []).map((e) => (e as num).toInt()));
    if (liked) {
      if (!l.contains(id)) l.add(id);
    } else {
      l.remove(id);
    }
    await _sb.from('user_meta').update({'liked': l}).eq('username', u);
  }

  @override
  Future<void> toggleCollect(int id, bool collected) async {
    final u = await getCurrentUser();
    if (u == null) return;
    final p = await _profile(u);
    final c = List<int>.from(
        (p['collected'] as List? ?? []).map((e) => (e as num).toInt()));
    if (collected) {
      if (!c.contains(id)) c.add(id);
    } else {
      c.remove(id);
    }
    await _sb.from('user_meta').update({'collected': c}).eq('username', u);
  }

  @override
  Future<void> addHistory(int id) async {
    final u = await getCurrentUser();
    if (u == null) return;
    final p = await _profile(u);
    final h = List<int>.from(
        (p['history'] as List? ?? []).map((e) => (e as num).toInt()));
    h.remove(id);
    h.insert(0, id);
    if (h.length > 200) h.removeRange(200, h.length);
    await _sb.from('user_meta').update({'history': h}).eq('username', u);
  }

  // ---------- 工具 ----------
  /// 本地弱哈希（非加密，仅避免明文）。⚠️ 上线前应改为 Supabase Auth，切勿客户端哈希密码。
  String _hash(String s) {
    int h = 5381;
    for (int i = 0; i < s.length; i++) {
      h = ((h << 5) + h + s.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return h.toRadixString(16);
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
