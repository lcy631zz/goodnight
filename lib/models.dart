import 'dart:convert';

/// 全局唯一 id 生成（本地够用，无需服务端）。
int genId() => DateTime.now().microsecondsSinceEpoch;

class Comment {
  final int id;
  final String name;
  final String text;
  final List<Comment> replies;
  final bool uncertain; // 机器人判定为"不确定"内容（仍放行，但进审核队列）
  final String? imagePath; // 本地导入图片
  final String? sticker; // 表情包

  Comment({
    int? id,
    required this.name,
    required this.text,
    this.replies = const [],
    this.uncertain = false,
    this.imagePath,
    this.sticker,
  }) : id = id ?? genId();

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String,
        text: (j['text'] as String?) ?? '',
        uncertain: (j['uncertain'] as int? ?? 0) == 1,
        imagePath: j['imagePath'] as String?,
        sticker: j['sticker'] as String?,
        replies: (j['replies'] as List? ?? [])
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'text': text,
        'uncertain': uncertain ? 1 : 0,
        'imagePath': imagePath,
        'sticker': sticker,
        'replies': replies.map((e) => e.toJson()).toList(),
      };

  static List<Comment> listFromJson(String json) {
    if (json.isEmpty) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Comment> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
}

class Post {
  int? id;
  final String board;
  final String title;
  final String body;
  final String imageCaption;
  final String color; // hex string e.g. #3B6FE0
  final String author;
  final int views;
  int likes;
  bool liked;
  bool collected;
  final int collects; // 收藏数（用于推荐热度）
  final int shares; // 转发数
  final String time;
  List<Comment> comments;
  final bool uncertain; // 机器人判定为"不确定"内容
  bool hidden; // 审核被删除
  List<String> images; // 本地导入的图片路径（最多 9 张）

  Post({
    this.id,
    required this.board,
    required this.title,
    this.body = '',
    required this.imageCaption,
    required this.color,
    required this.author,
    this.views = 0,
    this.likes = 0,
    this.liked = false,
    this.collected = false,
    this.collects = 0,
    this.shares = 0,
    this.time = '刚刚',
    this.comments = const [],
    this.uncertain = false,
    this.hidden = false,
    this.images = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'board': board,
        'title': title,
        'body': body,
        'imageCaption': imageCaption,
        'color': color,
        'author': author,
        'views': views,
        'likes': likes,
        'liked': liked ? 1 : 0,
        'collected': collected ? 1 : 0,
        'collects': collects,
        'shares': shares,
        'time': time,
        'comments': Comment.listToJson(comments),
        'uncertain': uncertain ? 1 : 0,
        'hidden': hidden ? 1 : 0,
        'images': images,
      };

  factory Post.fromMap(Map<String, dynamic> m) => Post(
        id: m['id'] as int?,
        board: m['board'] as String,
        title: m['title'] as String,
        body: m['body'] as String? ?? '',
        imageCaption: m['imageCaption'] as String,
        color: m['color'] as String,
        author: m['author'] as String,
        views: m['views'] as int? ?? 0,
        likes: m['likes'] as int? ?? 0,
        liked: (m['liked'] as int? ?? 0) == 1,
        collected: (m['collected'] as int? ?? 0) == 1,
        collects: m['collects'] as int? ?? 0,
        shares: m['shares'] as int? ?? 0,
        time: m['time'] as String? ?? '刚刚',
        comments: Comment.listFromJson(m['comments'] as String? ?? ''),
        uncertain: (m['uncertain'] as int? ?? 0) == 1,
        hidden: (m['hidden'] as int? ?? 0) == 1,
        images: (m['images'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}

/// 用户（本地账号）。role: 'admin' | 'user'。
/// 性别/级/专业来自学生信息（上服务器后由管理员导入），应用内只读、不编辑。
class User {
  final String username;
  final String role;
  final String password; // 已哈希
  String avatarEmoji; // 头像 emoji，空则显示首字母
  String avatarColor; // 头像底色 hex
  String? avatarPath; // 本地导入头像的图片路径（优先于 emoji）
  String? bio; // 简介
  String? region; // 自选地区
  String? gender; // 性别（来自学生信息，只读）
  String? grade; // 级（如 2026级，来自学生信息）
  String? major; // 专业（来自学生信息）

  User({
    required this.username,
    this.role = 'user',
    required this.password,
    this.avatarEmoji = '',
    this.avatarColor = '#3B6FE0',
    this.avatarPath,
    this.bio,
    this.region,
    this.gender,
    this.grade,
    this.major,
  });

  String get roleLabel => role == 'admin'
      ? '管理员'
      : (role == 'reviewer' ? '审核' : '普通用户');
  bool get canReview => role == 'admin' || role == 'reviewer';

  factory User.fromJson(Map<String, dynamic> j) => User(
        username: j['username'] as String,
        role: j['role'] as String? ?? 'user',
        password: j['password'] as String,
        avatarEmoji: j['avatarEmoji'] as String? ?? '',
        avatarColor: j['avatarColor'] as String? ?? '#3B6FE0',
        avatarPath: j['avatarPath'] as String?,
        bio: j['bio'] as String?,
        region: j['region'] as String?,
        gender: j['gender'] as String?,
        grade: j['grade'] as String?,
        major: j['major'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'role': role,
        'password': password,
        'avatarEmoji': avatarEmoji,
        'avatarColor': avatarColor,
        'avatarPath': avatarPath,
        'bio': bio,
        'region': region,
        'gender': gender,
        'grade': grade,
        'major': major,
      };
}

/// 举报 / 审核记录（用户举报 or 机器人不确定都进这里；以后上服务器多审核员共享同一队列）
class Report {
  final int id;
  final String type; // 'post' | 'comment'
  final int targetId; // 帖子 id
  final int? commentId; // 评论 id（type=comment 时）
  final String reporter; // 举报人（机器人记 'bot'）
  final String? reason; // 举报理由
  final String source; // 'user' | 'bot'
  String status; // 'pending' | 'approved' | 'rejected'
  String? reviewedBy;
  String? reviewedAt;

  Report({
    int? id,
    required this.type,
    required this.targetId,
    this.commentId,
    required this.reporter,
    this.reason,
    this.source = 'user',
    this.status = 'pending',
    this.reviewedBy,
    this.reviewedAt,
  }) : id = id ?? genId();

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as int? ?? 0,
        type: j['type'] as String,
        targetId: j['targetId'] as int,
        commentId: j['commentId'] as int?,
        reporter: j['reporter'] as String,
        reason: j['reason'] as String?,
        source: j['source'] as String? ?? 'user',
        status: j['status'] as String? ?? 'pending',
        reviewedBy: j['reviewedBy'] as String?,
        reviewedAt: j['reviewedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'targetId': targetId,
        'commentId': commentId,
        'reporter': reporter,
        'reason': reason,
        'source': source,
        'status': status,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt,
      };
}

/// 私信消息。type: 'text' | 'image' | 'sticker'。
/// 本地单设备演示：所有学生账号已预置，可在不同账号间互发；跨设备同步待上服务器。
class Message {
  final int id;
  final String from;
  final String to;
  final String? text;
  final String? imagePath; // 本地导入图片路径
  final String? sticker; // 表情包（用 emoji 充当，待上服务器可换图片资源）
  final String time;
  final bool read;
  final bool recalled; // 撤回

  Message({
    int? id,
    required this.from,
    required this.to,
    this.text,
    this.imagePath,
    this.sticker,
    required this.time,
    this.read = false,
    this.recalled = false,
  }) : id = id ?? genId();

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as int?,
        from: j['from'] as String,
        to: j['to'] as String,
        text: j['text'] as String?,
        imagePath: j['imagePath'] as String?,
        sticker: j['sticker'] as String?,
        time: j['time'] as String? ?? '',
        read: (j['read'] as int? ?? 0) == 1,
        recalled: (j['recalled'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'text': text,
        'imagePath': imagePath,
        'sticker': sticker,
        'time': time,
        'read': read ? 1 : 0,
        'recalled': recalled ? 1 : 0,
      };
}

/// 好友请求。status: 'pending' | 'accepted' | 'rejected'。
class FriendRequest {
  final int id;
  final String from;
  final String to;
  String status;
  final String time;

  FriendRequest({
    int? id,
    required this.from,
    required this.to,
    this.status = 'pending',
    required this.time,
  }) : id = id ?? genId();

  factory FriendRequest.fromJson(Map<String, dynamic> j) => FriendRequest(
        id: j['id'] as int?,
        from: j['from'] as String,
        to: j['to'] as String,
        status: j['status'] as String? ?? 'pending',
        time: j['time'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'status': status,
        'time': time,
      };
}

/// 用户反馈 / bug 上报。type: 'bug' | 'suggestion' | 'other'；status: 'new' | 'handled'。
/// 类名特意用 AppFeedback，避免与 Flutter 自带的 Feedback（触觉反馈）冲突。
class AppFeedback {
  final int? id;
  final String type;
  final String content;
  final String username; // 提交人；未登录为 '匿名用户'
  final String appVersion;
  final String status; // 'new' | 'handled'
  final String? createdAt;

  AppFeedback({
    this.id,
    required this.type,
    required this.content,
    required this.username,
    required this.appVersion,
    this.status = 'new',
    this.createdAt,
  });

  factory AppFeedback.fromJson(Map<String, dynamic> j) => AppFeedback(
        id: j['id'] as int?,
        type: j['type'] as String? ?? 'other',
        content: j['content'] as String? ?? '',
        username: j['username'] as String? ?? '匿名用户',
        appVersion: j['app_version'] as String? ?? '',
        status: j['status'] as String? ?? 'new',
        createdAt: j['created_at'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'type': type,
        'content': content,
        'username': username,
        'app_version': appVersion,
        'status': status,
      };
}
