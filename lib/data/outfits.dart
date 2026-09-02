import 'package:flutter/material.dart';

/// Tipo de requisito de desbloqueo de un outfit.
enum OutfitUnlock {
  /// Se desbloquea gratis desde el vestidor.
  free,

  /// Requiere racha de N días (`condition` = 'Racha de N días').
  streak,

  /// Requiere nivel N (`condition` = 'Nivel N').
  level,

  /// Aún no disponible ('Próximamente').
  comingSoon,
}

/// Catálogo de outfits (skins) disponibles para la mascota virtual.
///
/// Cualquier outfit con [assetPath] no nulo se renderiza como overlay en
/// `NekoCatMascot`. Los slots bloqueados usan [condition] para mostrar el
/// requisito de desbloqueo ('free' = se desbloquea gratis desde el vestidor).
/// Las condiciones de racha/nivel se desbloquean SOLAS al alcanzar el logro
/// (ver `Outfit.unlockRequirement` y `PetService.unlockEligibleOutfits`).
class Outfit {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icon;
  final String? assetPath;

  /// Requisito de desbloqueo. `'free'` = desbloqueable gratis.
  final String condition;

  const Outfit({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icon,
    required this.assetPath,
    required this.condition,
  });

  bool get isFree => condition == 'free';

  /// Devuelve el tipo de requisito y el valor numérico necesario para
  /// desbloquearlo automáticamente. `null` = no se desbloquea solo
  /// (p. ej. 'Próximamente').
  (OutfitUnlock, int)? unlockRequirement() {
    if (condition == 'free') return (OutfitUnlock.free, 0);
    final streakMatch = RegExp(r'^Racha de (\d+) días').firstMatch(condition);
    if (streakMatch != null) {
      return (OutfitUnlock.streak, int.tryParse(streakMatch.group(1) ?? '') ?? 0);
    }
    final levelMatch = RegExp(r'^Nivel (\d+)$').firstMatch(condition);
    if (levelMatch != null) {
      return (OutfitUnlock.level, int.tryParse(levelMatch.group(1) ?? '') ?? 0);
    }
    return null;
  }
}

class Outfits {
  Outfits._();

  /// Outfit por defecto: siempre poseído, sin overlay.
  static const String defaultOutfitId = 'default';

  static const List<Outfit> all = [
    Outfit(
      id: defaultOutfitId,
      nombre: 'Mochi Original',
      descripcion:
          'El gato sin filtro. Sin capa, sin gafas, sin vergüenza ajena.',
      icon: Icons.pets_rounded,
      assetPath: null,
      condition: 'free',
    ),
    Outfit(
      id: 'capa_heroe',
      nombre: 'Capa de Héroe',
      descripcion:
          'Una capa roja para volar por el supermercado. No te hace más fuerte, '
          'pero se ve bien en el espejo.',
      icon: Icons.flight_takeoff_rounded,
      assetPath: 'assets/images/outfit_capa_heroe.png',
      condition: 'free',
    ),
    Outfit(
      id: 'gafas_sol',
      nombre: 'Gafas de Sol',
      descripcion:
          'Para mirar macros con actitud. Dicen que el que las usa no duerme la '
          'siesta. Mentira.',
      icon: Icons.wb_sunny_rounded,
      assetPath: null,
      condition: 'Racha de 7 días',
    ),
    Outfit(
      id: 'disfraz_pesa',
      nombre: 'Sudadera de Gym',
      descripcion:
          'La línea fit del konbini. Transpirable, elegante y con olor a '
          'motivación (de tu motivación, no de la mía).',
      icon: Icons.fitness_center_rounded,
      assetPath: null,
      condition: 'Nivel 3',
    ),
    Outfit(
      id: 'corona',
      nombre: 'Corona Dorada',
      descripcion:
          'Solo para los que no se saltan la merienda. Brilla más que tu '
          'constancia en el gimnasio.',
      icon: Icons.emoji_events_rounded,
      assetPath: null,
      condition: 'Racha de 14 días',
    ),
    Outfit(
      id: 'buzo_pantera',
      nombre: 'Buzo Pantera',
      descripcion:
          'Sigiloso. Como tus snacks a medianoche. Nadie verá nada, y si lo '
          'ven, era el vecino.',
      icon: Icons.dark_mode_rounded,
      assetPath: null,
      condition: 'Nivel 5',
    ),
  ];

  static Outfit? byId(String? id) {
    if (id == null) return null;
    for (final o in all) {
      if (o.id == id) return o;
    }
    return null;
  }
}
