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
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/balance/balance_screen.dart';
import 'screens/jobs/jobs_screen.dart';
import 'screens/orders/orders_screen.dart';

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

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    BalanceScreen(),
    JobsScreen(),
    OrdersScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for sign-out and navigate to login
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
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.green.withValues(alpha: 0.15),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: '시세',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: '잔고',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_mode),
            label: '전략',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: '주문',
          ),
        ],
      ),
    );
  }
}
