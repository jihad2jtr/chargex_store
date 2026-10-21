import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/app_catalog_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/margin_provider.dart';
import 'providers/manual_services_provider.dart';
import 'providers/agent_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_main_screen.dart';
import 'core/services/fcm_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  await FcmService.instance.initialize(navKey: rootNavigatorKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => AppCatalogProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => MarginProvider()),
        ChangeNotifierProvider(create: (_) => ManualServicesProvider()),
        ChangeNotifierProvider(create: (_) => AgentProvider()),
      ],
      child: const ChargeXApp(),
    ),
  );
}

class ChargeXApp extends StatelessWidget {
  const ChargeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChargeX Digital Recharge Hub',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        // Arabic RTL directionality
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  void _checkAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.initAuth();
    if (auth.isAuthenticated) {
      FcmService.instance.syncTokenWithBackend();
    }
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.bolt, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppColors.secondary),
              const SizedBox(height: 16),
              const Text(
                'ChargeX',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    // All authenticated roles (Client, Agent, Supervisor, Admin) land on UserMainScreen
    // Elevated roles switch to their respective dashboards via the dedicated top-bar control button
    return const UserMainScreen();
  }
}
