import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/haptics.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/neko_tour.dart';

/// Pantalla de configuración — notificaciones, versión y cerrar sesión.
class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  late final _firebase = ref.read(firebaseServiceProvider);
  late final NotificationService _service = ref.read(
    notificationServiceProvider,
  );

  Map<String, String> _mealTimes = {};

  bool _loading = true;
  bool _saving = false;
  String _appVersion = '1.0.0';
  bool _smartEnabled = true;
  bool _notificationsGranted = true;
  bool _permissionRequestable = true;

  @override
  void initState() {
    super.initState();
    _loadSavedTimes();
    _loadVersion();
    _loadSmartFlag();
    _loadNotificationPermission();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  Future<void> _loadSmartFlag() async {
    final enabled = await _service.isSmartNotificationsEnabled();
    if (!mounted) return;
    setState(() => _smartEnabled = enabled);
  }

  Future<void> _toggleSmart(bool value) async {
    setState(() => _smartEnabled = value);
    try {
      await _service.setSmartNotificationsEnabled(value);
    } catch (e) {
      debugPrint('Config: error actualizando notificaciones inteligentes: $e');
      if (!mounted) return;
      setState(() => _smartEnabled = !value);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifErrorUpdateConfig),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadSavedTimes() async {
    final times = await _service.getSavedMealTimes();
    if (!mounted) return;
    setState(() {
      _mealTimes = times;
      _loading = false;
    });
  }

  Future<void> _loadNotificationPermission() async {
    final granted = await _service.areNotificationsEnabled();
    final permanentlyDenied =
        await _service.isNotificationPermissionPermanentlyDenied();
    if (!mounted) return;
    setState(() {
      _notificationsGranted = granted;
      _permissionRequestable = !granted && !permanentlyDenied;
    });
  }

  /// Pide el permiso de nuevo; si el sistema ya no permite preguntar, abre
  /// los ajustes para activarlo a mano.
  Future<void> _askNotificationPermission() async {
    Haptics.select();
    final granted = await _service.requestNotificationPermission();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _notificationsGranted = granted);
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifPermissionGranted),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final permanentlyDenied =
        await _service.isNotificationPermissionPermanentlyDenied();
    if (!mounted) return;
    if (permanentlyDenied) {
      await _service.openNotificationSettings();
    } else {
      setState(() => _permissionRequestable = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifPermissionStillDenied),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openNotificationSettings() async {
    Haptics.select();
    await _service.openNotificationSettings();
  }

  Future<void> _pickTime(String key, int currentHour, int currentMinute) async {
    final nk = context.nk;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // La app usa siempre AppTheme.darkTheme como tema base: en modo
            // claro el diálogo tendría fondo claro con texto del colorScheme
            // oscuro (invisible). Forzamos el colorScheme completo por modo.
            colorScheme: nk.mode == NekoThemeMode.dark
                ? ColorScheme.dark(
                    primary: nk.amber,
                    onPrimary: const Color(0xFF1A1206),
                    surface: nk.surface,
                    onSurface: nk.text,
                  )
                : ColorScheme.light(
                    primary: nk.amber,
                    onPrimary: Colors.white,
                    surface: nk.surface,
                    onSurface: nk.text,
                  ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: nk.cardBg,
              hourMinuteColor: nk.cat.withValues(alpha: 0.12),
              hourMinuteTextColor: nk.text,
              dialHandColor: nk.cat,
              dialBackgroundColor: nk.surfaceHigh,
              dialTextColor: nk.text,
              entryModeIconColor: nk.cat,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _mealTimes[key] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveMealTimes() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    // 1) Persistir en Firestore (una sola escritura).
    try {
      await _service.saveMealTimes(_mealTimes);
    } catch (e) {
      debugPrint('Config: error guardando horarios en Firestore: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifErrorSaveSchedules),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) setState(() => _saving = false);
      return;
    }

    // 2) Programar las notificaciones. Si falla, los horarios YA quedaron
    //    guardados; solo avisamos que no se activaron.
    var schedulingFailed = false;
    try {
      await _service.scheduleMealReminders(_mealTimes);
    } catch (e) {
      schedulingFailed = true;
      debugPrint(
        'Config: horarios guardados, pero falló programar notificaciones: $e',
      );
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          schedulingFailed
              ? l10n.notifSavedNotActivated
              : l10n.notifSavedActivated,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: nk.bg,
      appBar: AppBar(
        title: Text(
          l10n.profileSettings,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: nk.text,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: nk.text),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: nk.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AmberAtmosphere(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: nk.cat))
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildThemeSection(),
                    const SizedBox(height: 16),
                    _buildLanguageSection(),
                    const SizedBox(height: 16),
                    if (!_notificationsGranted) ...[
                      _buildPermissionSection(),
                      const SizedBox(height: 16),
                    ],
                    _buildNotificationsSection(),
                    const SizedBox(height: 16),
                    _buildSmartNotificationsSection(),
                    const SizedBox(height: 16),
                    _buildVersionSection(),
                    const SizedBox(height: 16),
                    _buildLogoutSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sección de tema (claro / oscuro)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildThemeSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final isDark = context.themeMode == NekoThemeMode.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: nk.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 14,
                  color: nk.amber,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.notifThemeHeader,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: nk.textFaint,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _themeOption(
                  icon: Icons.dark_mode_rounded,
                  label: l10n.notifThemeDark,
                  selected: isDark,
                  onTap: () =>
                      ThemeProvider.setThemeMode(context, NekoThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _themeOption(
                  icon: Icons.light_mode_rounded,
                  label: l10n.notifThemeLight,
                  selected: !isDark,
                  onTap: () =>
                      ThemeProvider.setThemeMode(context, NekoThemeMode.light),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final nk = context.nk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? nk.amber.withValues(alpha: 0.14) : nk.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? nk.amber.withValues(alpha: 0.4) : nk.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? nk.amber : nk.textDim),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? nk.amber : nk.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sección de permiso de notificaciones
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPermissionSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.cat.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: nk.cat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 14,
                  color: nk.cat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.notifPermissionTitle,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: nk.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.notifPermissionBody,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              height: 1.4,
              color: nk.textDim,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _permissionRequestable
                  ? _askNotificationPermission
                  : _openNotificationSettings,
              icon: Icon(
                _permissionRequestable
                    ? Icons.notifications_active_rounded
                    : Icons.settings_rounded,
                size: 16,
              ),
              label: Text(
                _permissionRequestable
                    ? l10n.notifPermissionRequest
                    : l10n.notifPermissionOpenSettings,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: nk.cat,
                foregroundColor: nk.mode == NekoThemeMode.dark
                    ? const Color(0xFF1A1206)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sección de idioma (Español / Inglés / Sistema)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLanguageSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final userLocale = ref.watch(localeProvider);
    final isSystem = userLocale == null;
    final isEs = userLocale?.languageCode == 'es';
    final isEn = userLocale?.languageCode == 'en';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: nk.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.translate_rounded,
                  size: 14,
                  color: nk.amber,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.settingsLanguageHeader,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: nk.textFaint,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _languageOption(
                  label: l10n.settingsLanguageSystem,
                  selected: isSystem,
                  onTap: () {
                    Haptics.select();
                    ref.read(localeProvider.notifier).setLanguage('system');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _languageOption(
                  label: l10n.settingsLanguageSpanish,
                  selected: isEs,
                  onTap: () {
                    Haptics.select();
                    ref.read(localeProvider.notifier).setLanguage('es');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _languageOption(
                  label: l10n.settingsLanguageEnglish,
                  selected: isEn,
                  onTap: () {
                    Haptics.select();
                    ref.read(localeProvider.notifier).setLanguage('en');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _languageOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final nk = context.nk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? nk.amber.withValues(alpha: 0.14) : nk.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? nk.amber.withValues(alpha: 0.4) : nk.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? nk.amber : nk.textDim,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sección de recordatorios
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNotificationsSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: nk.cat.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 14,
                  color: nk.cat,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.notifMealReminders,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: nk.textFaint,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.notifMealTimeHint,
            style: TextStyle(fontSize: 12, color: nk.textDim),
          ),
          const SizedBox(height: 12),
          _mealTimeRow(
            'desayuno',
            l10n.notifBreakfast,
            Icons.wb_sunny_rounded,
            const Color(0xFFFFB74D),
          ),
          _mealTimeRow(
            'almuerzo',
            l10n.notifLunch,
            Icons.restaurant_rounded,
            const Color(0xFF4CAF50),
          ),
          _mealTimeRow(
            'merienda',
            l10n.notifSnack,
            Icons.cookie_rounded,
            const Color(0xFF7BD88F),
          ),
          _mealTimeRow(
            'cena',
            l10n.notifDinner,
            Icons.nightlight_round,
            const Color(0xFF7E57C2),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _saveMealTimes,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: nk.cat,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_saving ? l10n.notifSaving : l10n.notifSaveSchedules),
              style: OutlinedButton.styleFrom(
                foregroundColor: nk.cat,
                side: BorderSide(color: nk.cat.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealTimeRow(String key, String label, IconData icon, Color color) {
    final nk = context.nk;
    final time = _mealTimes[key] ?? '08:00';
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    // En claro los colores pastel de comida pierden contraste (1.8–2.6:1):
    // el texto/ícono usa variantes oscuras (AA sobre blanco) y el pill
    // conserva el tinte del color original.
    final fg = nk.mode == NekoThemeMode.dark ? color : _mealColorLight(color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                color: nk.text,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _pickTime(key, hour, minute),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '$hour:${minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Variantes oscuras de los colores de comida para modo claro (AA sobre
  /// blanco). En dark se usan los pasteles originales (brillan sobre carbón).
  Color _mealColorLight(Color c) {
    if (c == const Color(0xFFFFB74D)) {
      return const Color(0xFFB45309); // desayuno
    }
    if (c == const Color(0xFF4CAF50)) {
      return const Color(0xFF2E7D32); // almuerzo
    }
    if (c == const Color(0xFF7BD88F)) {
      return const Color(0xFF276749); // merienda
    }
    if (c == const Color(0xFF7E57C2)) return const Color(0xFF5E35B1); // cena
    return c;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Notificaciones inteligentes (contextuales)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSmartNotificationsSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: nk.cat.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology_alt_rounded,
                  size: 14,
                  color: nk.cat,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.notifSmartHeader,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: nk.textFaint,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _smartEnabled,
            onChanged: _loading ? null : _toggleSmart,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: nk.cat,
            title: Text(
              l10n.notifSmartTitle,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: nk.text,
              ),
            ),
            subtitle: Text(
              l10n.notifSmartSubtitle,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 12,
                height: 1.4,
                color: nk.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Versión + Cerrar sesión
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVersionSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: nk.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        children: [
          _settingTile(
            icon: Icons.notifications_active_outlined,
            label: l10n.notifTestNotification,
            description: l10n.notifTestNotificationDesc,
            onTap: _testNotification,
          ),
          _settingTile(
            icon: Icons.info_outline_rounded,
            label: l10n.notifAbout,
            description: l10n.notifVersion(_appVersion),
            onTap: _showAboutDialog,
          ),
          _settingTile(
            icon: Icons.replay_rounded,
            label: l10n.notifResetTours,
            description: l10n.notifResetToursDesc,
            onTap: _resetTours,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: nk.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        children: [
          _settingTile(
            icon: Icons.logout_rounded,
            label: l10n.notifLogout,
            description: l10n.notifLogoutDesc,
            onTap: _confirmAndLogout,
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    final nk = context.nk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: nk.cat.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: nk.cat),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: nk.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12,
                      color: nk.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: nk.textFaint),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nk.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          l10n.notifAbout,
          style: TextStyle(color: nk.text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.notifAboutTagline,
              textAlign: TextAlign.center,
              style: TextStyle(color: nk.textDim, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: nk.cat.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Text(
                l10n.notifVersion(_appVersion),
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: nk.cat,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.notifClose, style: TextStyle(color: nk.textFaint)),
          ),
        ],
      ),
    );
  }

  /// Debug: programa una notificación en 10 segundos para verificar permisos,
  /// canal y que el banner emergente (heads-up) se muestre correctamente.
  Future<void> _testNotification() async {
    Haptics.select();
    try {
      await _service.sendTestNotification(seconds: 10);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifTestSnackOk),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifTestSnackError('$e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Debug: borra los flags de "tour ya visto" para que Mochi vuelva a
  /// mostrar los tutoriales contextuales (Despensa y Diario) desde cero.
  Future<void> _resetTours() async {
    await NekoTour.resetAll();
    if (!mounted) return;
    Haptics.success();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notifResetToursSnack),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nk.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          l10n.notifLogout,
          style: TextStyle(color: nk.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.notifLogoutConfirmBody,
          style: TextStyle(color: nk.textDim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: nk.textFaint),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.notifLogoutConfirm,
              style: TextStyle(color: nk.ok, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _service.cancelAll();
    await _firebase.logout();
  }
}
