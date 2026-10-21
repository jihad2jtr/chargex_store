import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../../firebase_options.dart';
import '../network/api_client.dart';
import '../../providers/admin_provider.dart';
import '../../providers/manual_services_provider.dart';
import '../../providers/app_catalog_provider.dart';
import '../../providers/wallet_provider.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final ApiClient _api = ApiClient();
  bool _isInitialized = false;
  String? _currentToken;
  GlobalKey<NavigatorState>? navigatorKey;

  String? get currentToken => _currentToken;
  bool get isInitialized => _isInitialized;

  /// Initialize Firebase and FCM listeners
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    navigatorKey = navKey;

    try {
      // 1. Initialize Firebase App
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Set Background Message Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Request Notification Permissions (Android 13+ & iOS)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 4. Foreground notification presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Get Initial Device Token
      // ignore: deprecated_member_use
      _currentToken = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] Device Token: $_currentToken');

      // 6. Token refresh listener
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        debugPrint('[FCM] Token refreshed: $newToken');
        syncTokenWithBackend(newToken);
      });

      // 7. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground message received: ${message.notification?.title}');
        _handleForegroundMessage(message);
        _notifyAppDataChange(message.data);
      });

      // 8. Message clicked when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification opened app: ${message.data}');
        _notifyAppDataChange(message.data);
        _handleNotificationNavigation(message.data);
      });

      // 9. Check terminated message that opened app
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from terminated state by notification');
        _notifyAppDataChange(initialMessage.data);
        _handleNotificationNavigation(initialMessage.data);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[FCM] Initialization warning / fallback: $e');
    }
  }

  /// Sync device FCM token with backend
  Future<void> syncTokenWithBackend([String? token]) async {
    final tokenToSync = token ?? _currentToken;
    if (tokenToSync == null || tokenToSync.isEmpty) return;

    try {
      await _api.post('/notifications/fcm-token', body: {
        'token': tokenToSync,
        'platform': defaultTargetPlatform.name,
      });
      debugPrint('[FCM] Token synced with backend successfully');
    } catch (e) {
      debugPrint('[FCM] Failed to sync token with backend: $e');
    }
  }

  /// Remove device token from backend on logout
  Future<void> removeTokenFromBackend() async {
    if (_currentToken == null) return;
    try {
      await _api.delete('/notifications/fcm-token', body: {
        'token': _currentToken,
      });
      debugPrint('[FCM] Token removed from backend');
    } catch (_) {}
  }

  /// Show in-app banner for foreground notifications
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final title = notification.title ?? 'إشعار جديد';
    final body = notification.body ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF034B52), // Deep Petrol Teal
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF00BCD4), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'عرض',
          textColor: const Color(0xFF00BCD4),
          onPressed: () {
            _handleNotificationNavigation(message.data);
          },
        ),
      ),
    );
  }

  /// Deep link navigation when notification is tapped
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final orderId = data['orderId']?.toString();
    final type = data['type']?.toString();
    debugPrint('[FCM] Navigating to: type=$type, orderId=$orderId');
  }

  /// Automatically refresh application data providers when FCM push arrives
  void _notifyAppDataChange(Map<String, dynamic> data) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    try {
      // 1. Refresh customer orders & notification badge
      try {
        final catalog = Provider.of<AppCatalogProvider>(context, listen: false);
        catalog.fetchNotifications();
        catalog.fetchMyOrders();
      } catch (_) {}

      // 2. Refresh admin orders & top-up requests
      try {
        final admin = Provider.of<AdminProvider>(context, listen: false);
        admin.fetchAdminOrders(silent: true);
        admin.fetchManualTopupRequests();
      } catch (_) {}

      // 3. Refresh supervisor manual orders
      try {
        final supervisor = Provider.of<ManualServicesProvider>(context, listen: false);
        supervisor.fetchSupervisorOrders(null, true);
      } catch (_) {}

      // 4. Refresh wallet balance
      try {
        final wallet = Provider.of<WalletProvider>(context, listen: false);
        wallet.fetchBalance();
      } catch (_) {}
      
      debugPrint('[FCM] Application providers refreshed successfully');
    } catch (e) {
      debugPrint('[FCM] Data auto-refresh warning: $e');
    }
  }
}
