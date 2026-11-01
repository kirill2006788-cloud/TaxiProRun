import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Push водителя: FCM + локальный показ уведомления в foreground.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const firebaseEnabledDefine = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: true,
  );
  static const _channelId = 'koroli_driver_orders';
  static const _channelName = 'Новые заказы';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _ready = false;
  bool _firebaseReady = false;
  bool _permissionRequested = false;
  String? _cachedToken;
  Map<String, dynamic>? _pendingTap;

  bool get usesFirebase => _firebaseReady;
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  Map<String, dynamic>? takePendingTap() {
    final value = _pendingTap;
    _pendingTap = null;
    return value;
  }

  static bool shouldUseFirebase() => firebaseEnabledDefine;

  Future<String?> getTokenForApi() async {
    final cached = _cachedToken;
    if (cached != null && cached.isNotEmpty) return cached;
    if (!_firebaseReady) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return null;
      _rememberRemoteToken(token);
      return _cachedToken;
    } catch (error) {
      debugPrint('Driver PushService: cannot obtain FCM token: $error');
      return null;
    }
  }

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _handleLocalNotificationResponse(launchResponse);
    }
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Уведомления о новых заказах',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('order_alert'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(const [0, 220, 100, 220]),
      ),
    );

    if (firebaseEnabledDefine) {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      await _initFirebaseMessaging();
    }
    _ready = true;
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        unawaited(handleRemotePayload(
          title: notification?.title ?? 'КОРОЛИ ДОРОГ',
          body: notification?.body ?? '',
          data: message.data,
        ));
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _publishTap(message.data),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _publishTap(initial.data);
      }

      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        _rememberRemoteToken(token);
      }
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        _rememberRemoteToken(token);
        _tokenRefreshController.add(token.trim());
      });
      _firebaseReady = true;
    } catch (error) {
      _firebaseReady = false;
      debugPrint(
        'Driver PushService: Firebase unavailable, local only: $error',
      );
    }
  }

  void _rememberRemoteToken(String token) {
    final normalized = token.trim();
    if (normalized.isNotEmpty) _cachedToken = normalized;
  }

  Future<bool> requestPermission() async {
    _permissionRequested = true;
    if (_firebaseReady) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: true,
        );
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (_) {}
    }
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> showLocal({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    if (!_ready) await init();
    if (Platform.isAndroid && !_permissionRequested) {
      await requestPermission();
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Уведомления о новых заказах',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('order_alert'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(const [0, 220, 100, 220]),
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> notifyOrderNew({
    required String fromAddress,
    required String toAddress,
    double? price,
    String? orderId,
  }) async {
    final pricePart = price != null ? ' · ${price.round()} ₽' : '';
    await showLocal(
      title: 'Новый заказ$pricePart',
      body: '$fromAddress → $toAddress',
      id: 2001,
      payload: jsonEncode({
        'type': 'order:new',
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
      }),
    );
  }

  Future<void> handleRemotePayload({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final type = data?['type']?.toString();
    if (type == 'order:new' || data?['orderId'] != null) {
      await notifyOrderNew(
        fromAddress: data?['fromAddress']?.toString() ?? title,
        toAddress: data?['toAddress']?.toString() ?? body,
        price: num.tryParse(data?['price']?.toString() ?? '')?.toDouble(),
        orderId: data?['orderId']?.toString(),
      );
      return;
    }
    await showLocal(title: title, body: body);
  }

  String get platformLabel {
    if (kIsWeb) return 'web';
    try {
      return Platform.isIOS ? 'ios' : 'android';
    } catch (_) {
      return 'android';
    }
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.trim().isEmpty) {
      _publishTap(const {'type': 'orders'});
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _publishTap(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {}
    _publishTap(const {'type': 'orders'});
  }

  void _publishTap(Map<String, dynamic> data) {
    if (_notificationTapController.hasListener) {
      _notificationTapController.add(data);
    } else {
      _pendingTap = Map<String, dynamic>.from(data);
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _tokenRefreshController.close();
    await _notificationTapController.close();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payload is rendered by the OS; do not log order addresses.
}
