import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Push-уведомления пассажира.
///
/// Настоящий FCM-токен возвращается только после успешной инициализации
/// Firebase. Фиктивные `local-*` токены намеренно не создаются: сервер не
/// должен хранить недоставляемые регистрации.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const firebaseEnabledDefine = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: true,
  );

  static const _channelId = 'koroli_dorog_orders';
  static const _channelName = 'Статус заказов';

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
  bool _enabled = true;
  String? _cachedToken;
  String? _lastNotifiedStatus;

  bool get isReady => _ready;
  bool get usesFirebase => _firebaseReady;
  bool get enabled => _enabled;
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  static bool shouldUseFirebase() => firebaseEnabledDefine;

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) resetStatusDedupe();
  }

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
      debugPrint('PushService: cannot obtain FCM token: $error');
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
      onDidReceiveNotificationResponse: (_) {},
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Уведомления о статусе поездки',
        importance: Importance.high,
      ),
    );

    if (shouldUseFirebase()) {
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
        (message) => _notificationTapController.add(message.data),
      );

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        scheduleMicrotask(() => _notificationTapController.add(initial.data));
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
        'PushService: Firebase unavailable, local notifications only: $error',
      );
    }
  }

  void _rememberRemoteToken(String token) {
    final normalized = token.trim();
    if (normalized.isNotEmpty) _cachedToken = normalized;
  }

  Future<bool> requestPermission() async {
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
      } catch (_) {
        // Android fallback below also covers devices without Google services.
      }
    }
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> showLocal({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!_enabled) return;
    if (!_ready) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Уведомления о статусе поездки',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  Future<void> notifyOrderStatus(String status) async {
    final normalized = status.toLowerCase().trim();
    if (!_enabled) return;
    if (!{
      'accepted',
      'enroute',
      'arrived',
      'waiting',
      'started',
      'completed',
      'canceled',
      'cancelled',
    }.contains(normalized)) {
      return;
    }
    if (_lastNotifiedStatus == normalized) return;
    _lastNotifiedStatus = normalized;

    final (title, body, id) = switch (normalized) {
      'accepted' => (
          'Водитель найден',
          'Водитель принял заказ и готовится к подаче',
          101,
        ),
      'enroute' => (
          'Водитель едет к вам',
          'Следите за машиной на карте',
          102,
        ),
      'arrived' || 'waiting' => (
          'Машина приехала',
          'Автомобиль ожидает в точке подачи',
          103,
        ),
      'started' => (
          'Поездка началась',
          'Желаем приятной дороги',
          104,
        ),
      'completed' => (
          'Поездка завершена',
          'Оцените поездку и водителя',
          105,
        ),
      'canceled' || 'cancelled' => (
          'Заказ отменён',
          'Откройте приложение, чтобы заказать другую машину',
          106,
        ),
      _ => ('КОРОЛИ ДОРОГ', 'Статус поездки обновлён', 100),
    };
    await showLocal(
      title: title,
      body: body,
      id: id,
    );
  }

  void resetStatusDedupe() => _lastNotifiedStatus = null;

  Future<void> handleRemotePayload({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final status = data?['status']?.toString();
    if (status != null) {
      await notifyOrderStatus(status);
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
  // The OS renders notification payloads in background. Do not log payloads:
  // order data can contain personal addresses.
}
