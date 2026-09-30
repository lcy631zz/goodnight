import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home.dart';
import 'screens/profile.dart';
import 'screens/publish.dart';
import 'screens/login.dart';
import 'screens/review.dart';
import 'screens/messages.dart';
import 'db.dart';
import 'lang.dart';
import 'config/supabase_config.dart';
import 'update_service.dart';
import 'widgets/update_dialog.dart';
import 'auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await Lang.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'goodnight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3B6FE0),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1F2330),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0; // 索引见 _buildStack
  bool _canReview = false; // 管理员或审核员，可见"审核"标签
  int _unread = 0;
  final _homeKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    authUserNotifier.addListener(_onAuthChanged);
    DB.canReview().then((v) => setState(() => _canReview = v));
    _refreshUnread();
    // 启动后自动检查更新（首次构建完成后再弹窗，避免抢在首屏之前）
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  /// 登录/登出后实时刷新底部导航（未读角标、审核标签可见性）。
  /// 注意：审核标签出现/消失会改变各页在 IndexedStack 里的索引，
  /// 必须把当前选中的「语义页」重新对齐到新索引，否则管理员登录后会
  /// 从「我的」误跳到「审核」（小ye 就是管理员，正好踩这个坑）。
  void _onAuthChanged() {
    final prevTab = _tab;
    DB.canReview().then((v) {
      if (!mounted) return;
      var tab = prevTab;
      if (v != _canReview) {
        if (v) {
          // 由「无审核」切到「有审核」：原「我的」(2) 后移到 3。
          if (prevTab == 2) tab = 3;
        } else {
          // 由「有审核」切到「无审核」：原「我的」(3) 前移到 2；原「审核」(2) 落到「消息」(1)。
          if (prevTab == 3) tab = 2;
          if (prevTab == 2) tab = 1;
        }
      }
      if (mounted) {
        setState(() {
          _canReview = v;
          _tab = tab;
        });
      }
    });
    _refreshUnread();
  }

  @override
  void dispose() {
    authUserNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// 拉取远程版本信息，需要更新则弹出小红书风格更新页。
  Future<void> _checkUpdate() async {
    if (!mounted) return;
    final info = await fetchLatestVersion();
    if (!mounted || info == null) return;
    final res = checkUpdate(info);
    if (res.needUpdate && mounted) {
      await showUpdateDialog(context, res);
    }
  }

  /// 标签顺序：0 首页, 1 消息, (2 审核 管理员或审核员), 末位 我的
  /// 给每个页面固定 Key：IndexedStack 用 Key 而非位置来匹配，
  /// 这样管理员登录后插入「审核」页时，ProfileScreen 的状态不会被重建丢失。
  List<Widget> _buildStack() {
    final list = <Widget>[
      HomeScreen(key: _homeKey, onPublish: _openPublish),
      const MessagesScreen(key: Key('messages')),
    ];
    if (_canReview) {
      list.add(const ReviewScreen(key: Key('review')));
    }
    list.add(const ProfileScreen(key: Key('profile')));
    return list;
  }

  int get _profileIndex => _canReview ? 3 : 2;
  int get _messagesIndex => 1;
  int get _reviewIndex => _canReview ? 2 : -1;

  Future<void> _refreshUnread() async {
    final me = await DB.getCurrentUser();
    if (me == null) {
      if (mounted) setState(() => _unread = 0);
      return;
    }
    final n = await DB.unreadTotal(me);
    if (mounted) setState(() => _unread = n);
  }

  Future<void> _goto(int i) async {
    // 先立刻切页，不等网络——否则每次点标签都要等一次 Supabase 往返，非常卡。
    if (mounted) setState(() => _tab = i);
    // 角色/未读数在后台刷新，回来后再安静地更新 UI。
    final can = await DB.canReview();
    if (mounted && can != _canReview) setState(() => _canReview = can);
    _refreshUnread();
  }

  Future<void> _openPublish() async {
    final me = await DB.getCurrentUser();
    if (me == null) {
      final logged = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (logged != true) return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PublishScreen()),
    );
    if (result == true) _homeKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final children = _buildStack();
    return Scaffold(
      body: IndexedStack(
        index: _tab < children.length ? _tab : 0,
        children: children,
      ),
      bottomNavigationBar: BottomAppBar(
        height: 64,
        child: Row(
          children: [
            _navCell(_navItem(Icons.home_outlined, t('首页'), _tab == 0, () => _goto(0))),
            _navCell(_navItem(Icons.chat_bubble_outline, t('消息'), _tab == _messagesIndex,
                () => _goto(_messagesIndex), badge: _unread)),
            _navCell(_plusItem()),
            if (_canReview)
              _navCell(_navItem(Icons.verified_user, t('审核'), _tab == _reviewIndex,
                  () => _goto(_reviewIndex))),
            _navCell(_navItem(Icons.person_outline, t('我的'),
                _tab == _profileIndex, () => _goto(_profileIndex))),
          ],
        ),
      ),
    );
  }

  Widget _navCell(Widget child) => Expanded(child: Center(child: child));

  Widget _navItem(IconData icon, String label, bool on, VoidCallback onTap,
      {int badge = 0}) {
    final color = on ? const Color(0xFF3B6FE0) : const Color(0xFF8A90A2);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF25C7E), shape: BoxShape.circle),
                child: Text('$badge',
                    style: const TextStyle(fontSize: 9, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _plusItem() {
    return GestureDetector(
      onTap: _openPublish,
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3B6FE0),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B6FE0).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}
