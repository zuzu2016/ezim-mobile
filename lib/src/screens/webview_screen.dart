import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

/// WebView screen that loads authenticated Blade pages using wv_token.
///
/// Features:
/// - Fetches a short-lived wv_token before loading any URL
/// - Injects JS to force desktop viewport on table-heavy pages
/// - Exposes FlutterBridge JS channel for Blade->Flutter communication
/// - Detects HTTP 401 responses and forces logout
class WebViewScreen extends StatefulWidget {
  final String path;
  final VoidCallback? onUnreadCountChanged;

  const WebViewScreen({
    super.key,
    required this.path,
    this.onUnreadCountChanged,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    if (token == null) {
      setState(() => _error = 'Not authenticated');
      return;
    }

    try {
      final url = await _apiService.getWebViewUrl(
        token: token,
        path: widget.path,
      );

      if (!mounted) return;

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..enableZoom(true)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _injectDesktopViewport();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description} (${error.errorCode})');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Block navigation to login/logout pages
            if (request.url.contains('/login') ||
                request.url.contains('/logout')) {
              auth.handleUnauthorized();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
            // Detect 401 responses and force logout
            if (error.response?.statusCode == 401) {
              debugPrint('WebView received 401, forcing logout');
              auth.handleUnauthorized();
            }
          },
        ))
        // FlutterBridge: Blade pages can call Flutter via JS
        ..addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: (JavaScriptMessage message) {
            _handleJsCallback(message.message);
          },
        )
        ..loadRequest(Uri.parse(url));

      if (mounted) {
        setState(() {
          _controller = controller;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load page: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Handle messages from Blade pages via FlutterBridge JS channel.
  void _handleJsCallback(String message) {
    try {
      final data = Map<String, String>.from(
        _parseJsPayload(message),
      );

      final action = data['action'];

      switch (action) {
        case 'markNotificationRead':
          final id = data['id'];
          if (id != null) {
            final auth = context.read<AuthProvider>();
            if (auth.token != null) {
              _apiService.markNotificationRead(
                token: auth.token!,
                notificationId: int.parse(id),
              );
              auth.decrementUnreadCount();
              widget.onUnreadCountChanged?.call();
            }
          }
          break;

        case 'logout':
          context.read<AuthProvider>().handleUnauthorized();
          break;

        default:
          debugPrint('Unknown FlutterBridge action: $action');
      }
    } catch (e) {
      debugPrint('FlutterBridge parse error: $e');
    }
  }

  Map<String, dynamic> _parseJsPayload(String raw) {
    try {
      return Map<String, dynamic>.from(
        Map<String, dynamic>.from(
          const JsonDecoder().convert(raw) as Map,
        ),
      );
    } catch (_) {
      return {'action': raw};
    }
  }

  /// Inject JS to force desktop viewport on pages containing <table>.
  void _injectDesktopViewport() {
    const js = '''
      (function() {
        var tables = document.querySelectorAll('table');
        if (tables.length > 0) {
          var meta = document.querySelector('meta[name="viewport"]');
          if (meta) {
            meta.setAttribute('content', 'width=1280');
          } else {
            var m = document.createElement('meta');
            m.name = 'viewport';
            m.content = 'width=1280';
            document.head.appendChild(m);
          }
        }
      })();
    ''';
    _controller?.runJavaScript(js);
  }

  void _reload() {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    _initWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Failed to load page',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_controller != null)
              WebViewWidget(controller: _controller!),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class JsonDecoder {
  const JsonDecoder();
  dynamic convert(String json) => null;
}
