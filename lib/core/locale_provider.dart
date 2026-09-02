import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLanguagePrefKey = 'app_language_code';

/// Estado y controlador del idioma de NekoFit.
///
/// `null` representa el idioma del sistema (por defecto).
/// `Locale('es')` fuerza español.
/// `Locale('en')` fuerza inglés.
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _loadSavedLocale();
  }

  /// Código de idioma guardado: 'system', 'es' o 'en'.
  String get currentCode {
    if (state == null) return 'system';
    return state!.languageCode;
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_kLanguagePrefKey);

      if (savedCode == 'es') {
        state = const Locale('es');
        return;
      } else if (savedCode == 'en') {
        state = const Locale('en');
        return;
      }

      // Si no está en SharedPreferences, intentar cargar de Firestore si hay usuario
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final remoteCode = doc.data()?['language'] as String?;
        if (remoteCode == 'es') {
          state = const Locale('es');
          await prefs.setString(_kLanguagePrefKey, 'es');
        } else if (remoteCode == 'en') {
          state = const Locale('en');
          await prefs.setString(_kLanguagePrefKey, 'en');
        }
      }
    } catch (_) {}
  }

  /// Cambia el idioma de la aplicación y persiste la selección.
  /// [code]: 'system' (o null), 'es', 'en'.
  Future<void> setLanguage(String? code) async {
    if (code == null || code == 'system') {
      if (state == null) return;
      state = null;
    } else if (code == 'es') {
      if (state?.languageCode == 'es') return;
      state = const Locale('es');
    } else if (code == 'en') {
      if (state?.languageCode == 'en') return;
      state = const Locale('en');
    } else {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (code == null || code == 'system') {
        await prefs.remove(_kLanguagePrefKey);
      } else {
        await prefs.setString(_kLanguagePrefKey, code);
      }
    } catch (_) {}

    // Persistir en Firestore de fondo si hay sesión iniciada
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'language': code ?? 'system',
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}

/// Provider global reactivo del Locale actual.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});
