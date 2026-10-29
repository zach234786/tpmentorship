import 'dart:convert';
// chat notification payloads are json so a display name can never
// corrupt them
import 'package:flutter/foundation.dart' show kIsWeb;
// detect whether the app is running on the web
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// the local notifications plugin
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
// scheduled notifications need timezone aware dates

// what a chat notification carries so tapping it can reopen the right
// conversation. kept as json rather than "uid|name" because a display
// name containing the separator would corrupt the payload
class ChatNotificationPayload {
  const ChatNotificationPayload({
    required this.senderUid,
    required this.senderName,
  });

  final String senderUid;
  final String senderName;

  String encode() => jsonEncode({'uid': senderUid, 'name': senderName});

  // null for anything that isn't one of ours - session reminders carry no
  // payload at all, and a malformed one must not blow up the tap handler
  static ChatNotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final uid = decoded['uid'];
      final name = decoded['name'];
      if (uid is! String || uid.isEmpty || name is! String) return null;
      return ChatNotificationPayload(senderUid: uid, senderName: name);
    } catch (_) {
      // not valid json - not ours
      return null;
    }
  }
}

class NotificationService {
// additional feature: local notifications
// schedules a reminder 15 minutes before each booked session
//
// notifications only exist on mobile - every method quietly does nothing
// on web (kIsWeb check) so the web build still runs without errors

  NotificationService._();
  // private constructor so no one else can create instances

  static final NotificationService instance = NotificationService._();
  // one shared instance for the whole app (singleton pattern),
  // because the underlying plugin must only be initialised once

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  // true once init() has finished, so we never schedule before setup

  // called when a chat notification is tapped. set by main.dart rather
  // than wired up here so this service never has to import a screen or
  // the navigator. init() runs before runApp, so this is still null at
  // registration time - the handler reads it at tap time instead
  void Function(String senderUid, String senderName)? onChatTap;

  // sets up the plugin - called once in main() before the app starts
  Future<void> init() async {
    if (kIsWeb) return;
    // no local notifications on web

    tz_data.initializeTimeZones();
    // load the timezone database
    tz.setLocalLocation(tz.getLocation('Asia/Singapore'));
    // the app is for TP students so Singapore time is always correct

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // use the app icon as the notification icon
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _ready = true;
  }

  // pops the Android 13+ system permission dialog - called only once the
  // user has actually opted in (onboarding toggle, or later in Settings),
  // never unconditionally at app launch
  Future<void> requestPermission() async {
    if (kIsWeb || !_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // routes a tapped notification back to the chat it came from. session
  // reminders carry no payload, so they decode to null and are ignored
  void _onNotificationTap(NotificationResponse response) {
    final payload = ChatNotificationPayload.decode(response.payload);
    if (payload == null) return;
    onChatTap?.call(payload.senderUid, payload.senderName);
  }

  // every notification needs a number id - turn a firestore document id
  // into a stable positive number so the same session (or conversation)
  // always maps to the same notification (lets us replace or cancel it
  // later)
  int _idFor(String documentId) => documentId.hashCode & 0x7fffffff;

  // schedules the reminder 15 minutes before the session starts
  // calling it again for the same session replaces the old reminder
  // (used when rescheduling)
  Future<void> scheduleSessionReminder({
    required String sessionId,
    required String title,
    required String mentorName,
    required DateTime sessionTime,
    required bool notificationsEnabled,
  }) async {
    if (!notificationsEnabled) return;
    // this account has turned notifications off - nothing to schedule
    if (kIsWeb || !_ready) return;
    // web, or init failed - skip quietly

    final reminderTime = sessionTime.subtract(const Duration(minutes: 15));
    if (reminderTime.isBefore(DateTime.now())) return;
    // the reminder moment already passed, nothing to schedule

    await _plugin.zonedSchedule(
      id: _idFor(sessionId),
      title: 'Upcoming session: $title',
      body: 'Your session with $mentorName starts in 15 minutes!',
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      // convert to a timezone aware date as the plugin requires
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'session_reminders',
          'Session Reminders',
          channelDescription: 'Reminders before booked mentoring sessions',
          importance: Importance.high,
          priority: Priority.high,
          // high importance = pops up on screen with sound
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // inexact = fires around the right time without needing the special
      // exact-alarm permission from Android 12+
    );
  }

  // removes the reminder for a session (used when cancelling)
  Future<void> cancelSessionReminder(String sessionId) async {
    if (kIsWeb || !_ready) return;
    await _plugin.cancel(id: _idFor(sessionId));
  }

  // fires immediately when someone else's message arrives. the id is
  // derived from the conversation, so a second message from the same
  // person replaces their notification instead of stacking a new one
  //
  // only reachable while the app process is alive - see ChatNotifier
  Future<void> showMessageNotification({
    required String conversationId,
    required String senderUid,
    required String senderName,
    required String text,
  }) async {
    if (kIsWeb || !_ready) return;
    await _plugin.show(
      id: _idFor(conversationId),
      title: senderName,
      body: text,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Chat Messages',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.high,
          priority: Priority.high,
          // its own channel, separate from session reminders, so the two
          // can be muted independently in android settings
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: ChatNotificationPayload(
        senderUid: senderUid,
        senderName: senderName,
      ).encode(),
    );
  }

  // a notification can outlive the app in the tray. if one launched us,
  // this returns its payload so the app can route to that chat - without
  // it, tapping a notification after the process died opens the app and
  // then does nothing
  Future<ChatNotificationPayload?> launchPayload() async {
    if (kIsWeb || !_ready) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return ChatNotificationPayload.decode(
      details?.notificationResponse?.payload,
    );
  }

  // fires a notification immediately - used to demo the feature live
  // without waiting for a real session to come up
  Future<void> showTestNotification() async {
    if (kIsWeb || !_ready) return;
    await _plugin.show(
      id: 0,
      title: 'TP Mentorship',
      body:
          'Notifications are working! Session reminders will look like this.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'session_reminders',
          'Session Reminders',
          channelDescription: 'Reminders before booked mentoring sessions',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
