import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import 'webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final auth = context.read<AuthProvider>();

    // Register FCM token with backend
    if (auth.token != null) {
      try {
        final fcmToken = await NotificationService.getFcmToken();
        if (fcmToken != null) {
          await _apiService.saveFcmToken(
            token: auth.token!,
            fcmToken: fcmToken,
            platform: 'android',
          );
        }
      } catch (e) {
        debugPrint('FCM token save error (non-critical): $e');
      }

      // Fetch and update unread badge
      try {
        await auth.refreshUnreadCount();
        await NotificationService.updateBadge(auth.unreadCount);
      } catch (e) {
        debugPrint('Unread count error (non-critical): $e');
      }
    }

    // Setup notification deep-link handler
    NotificationService.onNotificationTapped = (String url) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        final path = url.startsWith('/') ? url : '/$url';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WebViewScreen(
              path: path,
              onUnreadCountChanged: _refreshBadge,
            ),
          ),
        );
      }
    };

    // Refresh badge when push received
    NotificationService.onPushReceived = () {
      _refreshBadge();
    };
  }

  Future<void> _refreshBadge() async {
    final auth = context.read<AuthProvider>();
    await auth.refreshUnreadCount();
    await NotificationService.updateBadge(auth.unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.token == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return WebViewScreen(
          path: auth.getDashboardPath(),
          onUnreadCountChanged: _refreshBadge,
        );
      },
    );
  }
}
