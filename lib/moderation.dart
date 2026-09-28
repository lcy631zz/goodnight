/// 本地“快速机器人审核”。
///
/// 设计原则（用户要求，审核要宽松）：
///   - 只拦截【中度及以上】违反公序良俗的内容；
///   - 【轻度荤玩笑】、【轻度脏话】、口语化吐槽 一律放行，不在这张表里。
///   - 介于"轻度"与"中度"之间的【边界词】命中“不确定”档：仍放行，但标记为
///     待审核（进管理员审核队列），由人工二次确认。

enum ModStatus { ok, uncertain, blocked }

class ModerationResult {
  final ModStatus status;
  final String? reason;
  const ModerationResult({required this.status, this.reason});
}

class Moderator {
  /// 仅拦截“中度及以上”违规：明确的严重色情交易、毒品、暴力恐怖、仇恨歧视、严重违法交易、煽动自残。
  /// 注意：轻度脏话、轻度荤段子 故意不列入，避免误伤正常交流。
  static const List<String> _block = [
    // 严重色情 / 淫秽交易
    '裸聊', '援交', '卖身', '代孕', '色情直播', '成人影片', '黄片', '卖淫',
    // 毒品
    '贩毒', '吸毒', '冰毒', '海洛因', '可卡因', '大麻交易', '制毒',
    // 暴力 / 恐怖
    '杀人', '枪杀', '持刀伤人', '恐怖袭击', '爆炸物', '纵火',
    // 仇恨 / 歧视（严重）
    '种族灭绝', '纳粹',
    // 严重违法交易
    '走私军火', '假币', '洗钱', '博彩平台', '境外赌博', '贩卖枪支',
    // 煽动自残
    '教唆自杀',
  ];

  /// 边界词：可能被理解为“轻度荤/脏”也可能偏“中度”，命中即标记不确定（送审）。
  /// 这些词本身不在 _block 中，所以不会直接拦截，只是人工复核一下。
  static const List<String> _uncertain = [
    '约炮', '一夜情', '操你', '草你', '尼玛', '滚蛋', '废物', '煞笔', '傻逼',
    '婊子', '鸡巴', '屌', '乳', '胸推', '裸', '福利姬', '色情',
  ];

  /// 对一段文本做审核。
  static ModerationResult check(String text) {
    final t = text.toLowerCase();
    for (final w in _block) {
      if (t.contains(w.toLowerCase())) {
        return ModerationResult(
          status: ModStatus.blocked,
          reason: '内容疑似包含中度及以上违规信息，未通过快速审核',
        );
      }
    }
    for (final w in _uncertain) {
      if (t.contains(w.toLowerCase())) {
        return const ModerationResult(
          status: ModStatus.uncertain,
          reason: '内容触发边界词，已放行但标记为待人工复核',
        );
      }
    }
    return const ModerationResult(status: ModStatus.ok);
  }

  /// 合并标题+正文一起审。
  static ModerationResult checkPost({String title = '', String body = ''}) {
    final r = check(title);
    if (r.status != ModStatus.ok) return r;
    return check(body);
  }
}
