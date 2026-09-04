import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/providers/auth_provider.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/services/notification_service.dart';
import 'src/config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error (non-critical): $e');
  }

  try {
    await NotificationService.init();
    await NotificationService.setupBackgroundHandler();
  } catch (e) {
    debugPrint('Notification init error (non-critical): $e');
  }

  runApp(const EzimApp());
}

class EzimApp extends StatelessWidget {
  const EzimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
      ],
      child: MaterialApp(
        title: 'EZIM',
        theme: EzimTheme.lightTheme,
        darkTheme: EzimTheme.darkTheme,
        home: const _AppHome(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _AppHome extends StatefulWidget {
  const _AppHome({super.key});

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.setupForegroundHandler(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        auth.refreshUnreadCount();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
