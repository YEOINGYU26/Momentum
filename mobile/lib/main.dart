import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'core/app_colors.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/price_provider.dart';
import 'providers/balance_provider.dart';
import 'providers/job_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/chart_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/chart/chart_screen.dart';
import 'screens/auto_trade/auto_trade_screen.dart';
import 'screens/balance/balance_screen.dart';
import 'screens/menu/menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => PriceProvider()),
        ChangeNotifierProvider(create: (_) => BalanceProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => ChartProvider()),
      ],
      child: const TradingApp(),
    ),
  );
}

class TradingApp extends StatelessWidget {
  const TradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.dark,
          surface: AppColors.bg,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        cardTheme: CardThemeData(
          color: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── MainScaffold ──────────────────────────────────────────────────────────────

class MainScaffold extends StatefulWidget {
  static final _key = GlobalKey<_MainScaffoldState>();

  MainScaffold({Key? key}) : super(key: key ?? _key);

  /// Switch to the Chart tab (index 1) from anywhere.
  static void goToChart() {
    _key.currentState?._goToTab(1);
  }

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onGoToChart: () => _goToTab(1)),
      const ChartScreen(),
      const AutoTradeScreen(),
      const BalanceScreen(),
      const MenuScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.green.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.green),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart, color: AppColors.green),
            label: '차트',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt, color: AppColors.green),
            label: '자동매매',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.green),
            label: '잔고',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu, color: AppColors.green),
            label: '메뉴',
          ),
        ],
      ),
    );
  }
}
