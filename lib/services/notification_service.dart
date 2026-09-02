import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

/// Servicio de notificaciones locales.
///
/// Dos familias de notificaciones, cada una con su canal y rango de IDs:
///
///   Recordatorios de comida (canal `nekofit_meals`, IDs 10-14)
///     → repetitivos diarios a la hora configurada por el usuario.
///
///   Notificaciones inteligentes (canal `nekofit_context`, IDs 20-23)
///     → one-shot diarias que se recalculan cada vez que la app está en
///     primer plano o el usuario registra una comida:
///       - 18:00 "Te faltan X kcal hoy"        (si vas bajo de tu meta)
///       - 19:00 "X lleva N días sin comer"    (racha rota)
///       - 20:00 "X lleva N días — ¿repongo?"  (predictivo de despensa)
///       - 21:00 "Hoy llevas +Xg de proteína"  (logro comparativo)
///
/// Como las notificaciones locales no pueden consultar Firestore al
/// dispararse, el contenido se calcula en el momento de programarlas y se
/// refresca en cada interacción significativa (abrir la app, guardar comida,
/// cambiar ajustes). Es el patrón "compute-then-schedule" para MVP.
class NotificationService {
  NotificationService();
  static final NotificationService instance = NotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── IDs de notificación (rangos separados para nunca pisarse) ─────────────
  static const int _idDesayuno = 10;
  static const int _idAlmuerzo = 11;
  static const int _idMerienda = 12;
  static const int _idCena = 13;
  static const int _idOtherMeal = 14;

  static const int _idKcalProgress = 20;
  static const int _idStreakBreak = 21;
  static const int _idPantryRestock = 22;
  static const int _idProteinWin = 23;

  static const List<int> _mealReminderIds = [
    _idDesayuno,
    _idAlmuerzo,
    _idMerienda,
    _idCena,
    _idOtherMeal,
  ];
  static const List<int> _contextualIds = [
    _idKcalProgress,
    _idStreakBreak,
    _idPantryRestock,
    _idProteinWin,
  ];

  // Horarios de las notificaciones inteligentes (se sobreescriben en cada
  // recálculo; no son configurables todavía).
  static const int _kcalHour = 18;
  static const int _streakHour = 19;
  static const int _pantryHour = 20;
  static const int _proteinHour = 21;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('NotificationService: no se pudo resolver timezone: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Solicitar permiso de notificaciones (Android 13+ / iOS)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Recordatorios de comida (meals)
  // ═══════════════════════════════════════════════════════════════════════════

  // Horarios de comidas por defecto
  static const Map<String, String> _defaultMealTimes = {
    'desayuno': '08:00',
    'almuerzo': '13:00',
    'merienda': '17:00',
    'cena': '20:00',
  };

  // Programar recordatorios diarios en los horarios indicados
  Future<void> scheduleMealReminders(Map<String, String>? customTimes) async {
    if (!_initialized) return;

    // Cancelar solo recordatorios de comida (nunca los inteligentes).
    await _cancelMealReminders();

    final times = customTimes ?? _defaultMealTimes;

    final uid = FirebaseService.instance.currentUser?.uid;
    String catName = 'Mochi';
    if (uid != null) {
      try {
        final doc = await FirebaseService.instance.db.collection('users').doc(uid).get();
        final raw = doc.data()?['catName'] as String?;
        if (raw != null && raw.trim().isNotEmpty) catName = raw.trim();
      } catch (_) {}
    }

    for (final entry in times.entries) {
      final mealName = entry.key;
      final time = entry.value;

      if (time.isEmpty) continue;

      final parts = time.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final scheduledDate = _nextAt(DateTime.now(), hour, minute);

      try {
        await _scheduleNotification(
          id: _mealId(mealName),
          title: '$catName tiene hambre',
          body: 'Hora de registrar tu $mealName para mantener tu diario al día.',
          scheduledDate: scheduledDate,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        // Un horario fallido no debe cancelar el resto ni romper el guardado.
        debugPrint('NotificationService: no se pudo programar $mealName ($time): $e');
      }
    }
  }

  // Cancelar todos los recordatorios (comida + contextuales).
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _cancelMealReminders();
    await cancelContextualNotifications();
  }

  Future<void> _cancelMealReminders() async {
    for (final id in _mealReminderIds) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  // ID único por comida
  int _mealId(String meal) {
    switch (meal) {
      case 'desayuno':
        return _idDesayuno;
      case 'almuerzo':
        return _idAlmuerzo;
      case 'merienda':
        return _idMerienda;
      case 'cena':
        return _idCena;
      default:
        return _idOtherMeal;
    }
  }

  // Obtener horarios guardados del usuario
  Future<Map<String, String>> getSavedMealTimes() async {
    final uid = FirebaseService.instance.currentUser?.uid;
    if (uid == null) return _defaultMealTimes;

    final doc = await FirebaseService.instance.db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return _defaultMealTimes;

    final mealTimes = data['mealNotificationTimes'] as Map<String, dynamic>?;
    if (mealTimes == null) return _defaultMealTimes;

    return {
      'desayuno': (mealTimes['desayuno'] ?? '08:00').toString(),
      'almuerzo': (mealTimes['almuerzo'] ?? '13:00').toString(),
      'merienda': (mealTimes['merienda'] ?? '17:00').toString(),
      'cena': (mealTimes['cena'] ?? '20:00').toString(),
    };
  }

  // Guardar horarios del usuario
  Future<void> saveMealTimes(Map<String, String> times) async {
    final uid = FirebaseService.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseService.instance.db.collection('users').doc(uid).set({
      'mealNotificationTimes': times,
    }, SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Notificaciones inteligentes (contextuales)
  // ═══════════════════════════════════════════════════════════════════════════

  /// ¿Están habilitadas las notificaciones inteligentes? (por defecto sí).
  Future<bool> isSmartNotificationsEnabled() async {
    final uid = FirebaseService.instance.currentUser?.uid;
    if (uid == null) return true;
    try {
      final doc =
          await FirebaseService.instance.db.collection('users').doc(uid).get();
      return (doc.data()?['smartNotificationsEnabled'] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Activa/desactiva las notificaciones inteligentes y re-programa o cancela
  /// según el nuevo valor.
  Future<void> setSmartNotificationsEnabled(bool value) async {
    final uid = FirebaseService.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseService.instance.db.collection('users').doc(uid).update({
      'smartNotificationsEnabled': value,
    });

    if (value) {
      await scheduleContextualNotifications();
    } else {
      await cancelContextualNotifications();
    }
  }

  Future<void> cancelContextualNotifications() async {
    if (!_initialized) return;
    for (final id in _contextualIds) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  /// Recalcula el contexto del usuario y programa las notificaciones
  /// inteligentes de HOY (si aún no pasó su hora). El contenido se vuelve a
  /// calcular en cada llamada, así que debe invocarse al abrir la app, al
  /// registrar una comida y al cambiar los ajustes.
  ///
  /// Best-effort: cualquier error se silencia para no bloquear la UI.
  Future<void> scheduleContextualNotifications() async {
    if (!_initialized) return;
    final uid = FirebaseService.instance.currentUser?.uid;
    if (uid == null) return;

    // Limpiar lo anterior antes de reprogramar.
    await cancelContextualNotifications();

    try {
      final db = FirebaseService.instance.db;
      final userRef = db.collection('users').doc(uid);
      final data = (await userRef.get()).data();
      if (data == null) return;

      // Preferencia de notificaciones inteligentes (por defecto activadas).
      final smartEnabled = (data['smartNotificationsEnabled'] as bool?) ?? true;
      if (!smartEnabled) return;

      final catName = (data['catName'] as String?)?.trim().isNotEmpty == true
          ? data['catName'] as String
          : 'Mochi';

      final macroGoals = data['macroGoals'] as Map<String, dynamic>?;
      final calGoal = (macroGoals?['calories'] as num?)?.toDouble() ?? 2000.0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Consumo de hoy y de ayer (una query por día).
      final todayMeals = await _mealsInRange(userRef, today, tomorrow);
      final yesterdayMeals = await _mealsInRange(
          userRef, today.subtract(const Duration(days: 1)), today);

      final todayKcal = todayMeals.$1;
      final todayProtein = todayMeals.$2;
      final yesterdayProtein = yesterdayMeals.$2;

      // 1) 18:00 — Te faltan kcal hoy.
      final remaining = calGoal - todayKcal;
      if (remaining >= 200) {
        await _scheduleContextualToday(
          id: _idKcalProgress,
          hour: _kcalHour,
          title: '$catName te lleva la cuenta',
          body: 'Te faltan ${remaining.round()} kcal hoy. '
              'Un snack bien elegido y cierras el día en tu meta.',
        );
      }

      // 2) 19:00 — Racha rota.
      final lastLogged = data['lastLoggedDate'];
      if (lastLogged != null) {
        DateTime? lastDate;
        if (lastLogged is Timestamp) {
          lastDate = lastLogged.toDate();
        } else {
          lastDate = DateTime.tryParse(lastLogged.toString());
        }
        if (lastDate != null) {
          final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
          final daysWithout = today.difference(lastDay).inDays;
          if (daysWithout >= 3) {
            await _scheduleContextualToday(
              id: _idStreakBreak,
              hour: _streakHour,
              title: '$catName te extraña',
              body: '$catName lleva $daysWithout días sin comida registrada. '
                  'Su plato está triste y su despensa lo nota.',
            );
          }
        }
      }

      // 3) 20:00 — Predictivo de despensa (RF-9).
      final pantrySnap = await userRef.collection('pantry').get();
      String? restockName;
      var restockDays = 0;
      for (final d in pantrySnap.docs) {
        final p = d.data();
        if (p['isAvailable'] == false) continue;
        final rep = p['lastReplenished'];
        DateTime? repDate;
        if (rep is Timestamp) {
          repDate = rep.toDate();
        } else {
          repDate = DateTime.tryParse(rep?.toString() ?? '');
        }
        if (repDate == null) continue;
        final days = today
            .difference(DateTime(repDate.year, repDate.month, repDate.day))
            .inDays;
        if (days >= 7 && days > restockDays) {
          restockDays = days;
          restockName = p['name']?.toString();
        }
      }
      if (restockName != null && restockName.isNotEmpty) {
        await _scheduleContextualToday(
          id: _idPantryRestock,
          hour: _pantryHour,
          title: 'Tu konbini te avisa',
          body: '$restockName lleva $restockDays días en la despensa. '
              '¿Reponemos antes de que se acabe?',
        );
      }

      // 4) 21:00 — Logro de proteína vs ayer.
      final proteinDelta = todayProtein - yesterdayProtein;
      if (proteinDelta >= 10 && yesterdayProtein > 0) {
        await _scheduleContextualToday(
          id: _idProteinWin,
          hour: _proteinHour,
          title: 'Modo proteína activado',
          body: 'Hoy llevas ${proteinDelta.round()}g más de proteína que ayer. '
              'Así se construye. 💪',
        );
      }
    } catch (e) {
      // Best-effort: las notificaciones contextuales nunca deben romper la UI.
      debugPrint('NotificationService: scheduleContextualNotifications: $e');
    }
  }

  /// Suma kcal y proteína de las comidas de un rango de fechas.
  /// Usa una query por rango sobre `createdAt` (índice simple automático).
  /// Devuelve (kcal, proteínas).
  Future<(double, double)> _mealsInRange(
      DocumentReference<Map<String, dynamic>> userRef,
      DateTime start,
      DateTime end) async {
    double kcal = 0;
    double protein = 0;
    try {
      final snap = await userRef
          .collection('meals')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .get();
      for (final d in snap.docs) {
        final m = d.data();
        kcal += (m['calories'] as num?)?.toDouble() ?? 0;
        protein += (m['proteins'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}
    return (kcal, protein);
  }

  /// Programa una notificación inteligente.
  /// Si la hora de hoy ya pasó, se programa automáticamente para mañana a esa hora
  /// (o se recalculará al abrir la app).
  Future<void> _scheduleContextualToday({
    required int id,
    required int hour,
    required String title,
    required String body,
  }) async {
    final when = _nextAt(DateTime.now(), hour, 0);

    await _scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      channelId: 'nekofit_context',
      channelName: 'Notificaciones Inteligentes',
      channelDescription: 'Consejos contextuales de tu mascota',
      importance: Importance.max,
      priority: Priority.high,
      matchDateTimeComponents: null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers de scheduling y Modo Debug
  // ═══════════════════════════════════════════════════════════════════════════

  /// Programa una notificación de prueba en [seconds] segundos para verificar
  /// permisos, canal y visibilidad en pantalla (banner heads-up).
  Future<void> sendTestNotification({int seconds = 10}) async {
    if (!_initialized) await init();

    tz.Location local;
    try {
      local = tz.local;
    } catch (_) {
      local = tz.UTC;
    }

    final scheduledDate =
        tz.TZDateTime.now(local).add(Duration(seconds: seconds));

    await _scheduleNotification(
      id: 999,
      title: '🐾 ¡Mochi dice miau!',
      body: 'Notificación de prueba ($seconds s). El canal y los permisos funcionan perfecto.',
      scheduledDate: scheduledDate,
      channelId: 'nekofit_debug',
      channelName: 'Notificaciones de Prueba',
      channelDescription: 'Canal de prueba para verificar notificaciones',
      importance: Importance.max,
      priority: Priority.high,
      matchDateTimeComponents: null,
    );
  }

  /// Próxima ocurrencia de [hour]:[minute] en la zona local.
  tz.TZDateTime _nextAt(DateTime now, int hour, int minute) {
    tz.Location local;
    try {
      local = tz.local;
    } catch (_) {
      local = tz.UTC;
    }
    var date = tz.TZDateTime(local, now.year, now.month, now.day, hour, minute);
    if (date.isBefore(tz.TZDateTime.from(now, local))) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String channelId = 'nekofit_meals',
    String channelName = 'Recordatorios de Comida',
    String channelDescription = 'Recordatorios para registrar tu comida del día',
    Importance importance = Importance.max,
    Priority priority = Priority.high,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }
}
