import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine_model.dart';

class MedicineNotificationService {
  MedicineNotificationService._internal();

  static final MedicineNotificationService instance = MedicineNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> Function(String householdId, String medicineId)? _onOpenMedicine;
  bool _initialized = false;
  String? _queuedPayload;

  Future<void> initialize({
    required Future<void> Function(String householdId, String medicineId) onOpenMedicine,
  }) async {
    _onOpenMedicine = onOpenMedicine;

    if (_initialized) {
      await _consumeQueuedPayload();
      return;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    await _requestPermissions();
    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _queuedPayload = launchDetails?.notificationResponse?.payload;
    }

    await _consumeQueuedPayload();
  }

  Future<void> scheduleForMedicine({
    required String householdId,
    required MedicineModel medicine,
  }) async {
    if (!_initialized) {
      return;
    }

    await cancelMedicineNotifications(medicine.id);

    final endDate = medicine.endDate?.toDate();
    if (endDate != null && endDate.isBefore(DateTime.now())) {
      return;
    }

    for (var i = 0; i < medicine.reminderTimes.length; i++) {
      final scheduledTime = _nextScheduleTime(
        reminderTime: medicine.reminderTimes[i],
        startDate: medicine.startDate.toDate(),
      );
      if (scheduledTime == null) {
        continue;
      }

      await _plugin.zonedSchedule(
        _notificationId(medicine.id, i),
        'Medicine Reminder',
        'Time to take ${medicine.name} - ${medicine.dosage}',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_reminders',
            'Medicine Reminders',
            channelDescription: 'Daily medicine reminder alerts for Nestkin',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode({
          'type': 'medicine',
          'householdId': householdId,
          'medicineId': medicine.id,
        }),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> syncSchedules({
    required String householdId,
    required List<MedicineModel> medicines,
  }) async {
    if (!_initialized) {
      return;
    }

    for (final medicine in medicines) {
      final endDate = medicine.endDate?.toDate();
      if (endDate != null && endDate.isBefore(DateTime.now())) {
        await cancelMedicineNotifications(medicine.id);
        continue;
      }

      await scheduleForMedicine(
        householdId: householdId,
        medicine: medicine,
      );
    }
  }

  Future<void> cancelMedicineNotifications(String medicineId) async {
    if (!_initialized) {
      return;
    }

    for (var i = 0; i < 12; i++) {
      await _plugin.cancel(_notificationId(medicineId, i));
    }
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _consumeQueuedPayload() async {
    if (_queuedPayload == null) {
      return;
    }

    final payload = _queuedPayload;
    _queuedPayload = null;
    await _handlePayload(payload);
  }

  Future<void> _handlePayload(String? payload) async {
    if (payload == null || payload.isEmpty) {
      return;
    }

    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final type = decoded['type'];
    final householdId = decoded['householdId'];
    final medicineId = decoded['medicineId'];
    if (type != 'medicine' || householdId is! String || medicineId is! String) {
      return;
    }

    final callback = _onOpenMedicine;
    if (callback == null) {
      _queuedPayload = payload;
      return;
    }

    await callback(householdId, medicineId);
  }

  tz.TZDateTime? _nextScheduleTime({
    required String reminderTime,
    required DateTime startDate,
  }) {
    final parts = reminderTime.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    final localStart = tz.TZDateTime(
      tz.local,
      startDate.year,
      startDate.month,
      startDate.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(localStart)) {
      scheduled = localStart;
    } else if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  int _notificationId(String medicineId, int slot) {
    final normalized = medicineId.codeUnits.fold<int>(0, (sum, item) => sum + item);
    return (normalized % 100000) * 100 + slot;
  }
}
