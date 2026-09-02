import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import '../data/outfits.dart';
import '../l10n/app_localizations.dart';
import '../models/pet_state.dart';
import '../services/firebase_service.dart';
import '../services/pet_service.dart';
import '../widgets/atmosphere_background.dart';
import '../widgets/neko_cat_mascot.dart';

/// Vestidor: grid 2×N de outfits. Long-press abre el lore del gato sarcástico.
/// La fila inferior muestra stats mini (hambre + humor + nivel).
///
/// Los outfits bloqueados por racha/nivel muestran el progreso actual
/// (p. ej. "Racha 3/7 días") y se desbloquean solos al alcanzar el logro.
class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  late final PetRepository _pet = ref.read(petServiceProvider);
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);

  StreamSubscription<PetState>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  PetState? _state;
  bool _loading = true;
  String _busyId = '';

  /// Racha actual del usuario (para el progreso de outfits por racha).
  int _streak = 0;

  String? get _uid => _firebase.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid == null) {
      _loading = false;
      return;
    }
    _sub = _pet.watchPetState(uid).listen((state) {
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    });
    // Racha en vivo para pintar el progreso de los outfits bloqueados.
    _profileSub = _firebase.db.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      if (!mounted) return;
      setState(() {
        _streak = ((doc.data()?['currentStreak'] as num?) ?? 0).toInt();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _unlock(Outfit outfit) async {
    final uid = _uid;
    if (uid == null || !outfit.isFree) return;
    setState(() => _busyId = outfit.id);
    try {
      await _pet.unlockOutfit(uid, outfit.id);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.wardrobeUnlockedSnack(outfit.nombre)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnack(AppLocalizations.of(context).wardrobeUnlockFailed);
      }
    } finally {
      if (mounted) setState(() => _busyId = '');
    }
  }

  Future<void> _equip(Outfit outfit) async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _busyId = outfit.id);
    try {
      await _pet.equipOutfit(uid, outfit.id);
    } catch (_) {
      if (mounted) {
        _showSnack(AppLocalizations.of(context).wardrobeEquipLocked);
      }
    } finally {
      if (mounted) setState(() => _busyId = '');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.petWardrobeTooltip), centerTitle: false),
      body: AtmosphereBackground(
        child: SafeArea(
          child: _loading || _state == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.cat),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.l,
                        AppSpacing.s,
                        AppSpacing.l,
                        AppSpacing.s,
                      ),
                      child: _buildHint(),
                    ),
                    Expanded(child: _buildGrid()),
                    _buildMiniStats(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.wardrobeHint,
      style: const TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 10,
        color: AppColors.textDim,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.l,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.m,
        crossAxisSpacing: AppSpacing.m,
        childAspectRatio: 0.78,
      ),
      itemCount: Outfits.all.length,
      itemBuilder: (context, index) {
        return _buildSlot(Outfits.all[index]);
      },
    );
  }

  // ── Slot del grid ────────────────────────────────────────────────────

  Widget _buildSlot(Outfit outfit) {
    final state = _state;
    final l10n = AppLocalizations.of(context);
    final owned = state?.ownedOutfits.contains(outfit.id) ?? false;
    final equipped = state?.currentOutfit == outfit.id;
    final locked = !outfit.isFree && !owned;

    return GestureDetector(
      onLongPress: () => _showOutfitSheet(outfit),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: equipped
                ? AppColors.cat.withValues(alpha: 0.65)
                : locked
                ? AppColors.textDim.withValues(alpha: 0.12)
                : AppColors.textDim.withValues(alpha: 0.22),
            width: equipped ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: locked ? 0.3 : 1.0,
                    child: _buildPreview(outfit),
                  ),
                  if (locked) ...[
                    Container(color: Colors.black.withValues(alpha: 0.35)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: AppColors.textMuted,
                          size: 30,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.wardrobeLocked,
                          style: const TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (equipped)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cat,
                          borderRadius: BorderRadius.circular(AppRadii.stamp),
                        ),
                        child: Text(
                          l10n.wardrobeEquipped,
                          style: const TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF1A0F00),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Text(
                outfit.nombre,
                style: const TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s,
                0,
                AppSpacing.s,
                AppSpacing.m,
              ),
              child: _buildAction(
                outfit,
                owned: owned,
                equipped: equipped,
                locked: locked,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(Outfit outfit) {
    if (outfit.assetPath != null) {
      return NekoCatMascot(
        mood: CatMood.idle,
        size: 88,
        showLabel: false,
        outfitOverlayPath: outfit.assetPath,
      );
    }
    // Sin asset: ícono representativo del outfit.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textDim.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(outfit.icon, color: AppColors.cat, size: 30),
        ),
      ],
    );
  }

  Widget _buildAction(
    Outfit outfit, {
    required bool owned,
    required bool equipped,
    required bool locked,
  }) {
    final l10n = AppLocalizations.of(context);
    if (locked) {
      return Text(
        _unlockProgress(outfit),
        style: const TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          color: AppColors.textMuted,
        ),
        textAlign: TextAlign.center,
      );
    }
    if (equipped) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: AppColors.cat),
          const SizedBox(width: 4),
          Text(
            l10n.wardrobeInUse,
            style: const TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.cat,
            ),
          ),
        ],
      );
    }
    if (!owned) {
      return SizedBox(
        width: double.infinity,
        height: 32,
        child: FilledButton(
          onPressed: _busyId == outfit.id ? null : () => _unlock(outfit),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
          ),
          child: _busyId == outfit.id
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  l10n.wardrobeUnlockFree,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 32,
      child: OutlinedButton(
        onPressed: _busyId == outfit.id ? null : () => _equip(outfit),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.cat.withValues(alpha: 0.5)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
        ),
        child: Text(
          l10n.wardrobeEquip,
          style: const TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  /// Progreso del outfit bloqueado según su requisito de racha o nivel.
  /// 'Próximamente' y sin requisito numérico → se muestra la condición tal cual.
  String _unlockProgress(Outfit outfit) {
    final l10n = AppLocalizations.of(context);
    final req = outfit.unlockRequirement();
    if (req == null) return outfit.condition;

    final (kind, value) = req;
    switch (kind) {
      case OutfitUnlock.streak:
        final current = _streak < value ? _streak : value;
        return l10n.wardrobeProgressStreak(current, value);
      case OutfitUnlock.level:
        final lvl = (_state?.level ?? 1) < value ? (_state?.level ?? 1) : value;
        return l10n.wardrobeProgressLevel(lvl, value);
      case OutfitUnlock.free:
        return l10n.wardrobeFree;
      case OutfitUnlock.comingSoon:
        return outfit.condition;
    }
  }

  // ── Stats mini (fila inferior) ───────────────────────────────────────

  Widget _buildMiniStats() {
    final state = _state;
    if (state == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final hunger = state.currentHunger;
    final hungerColor = hunger >= 70 ? AppColors.depleted : AppColors.cat;
    final moodColor = _moodColor(state.currentMood);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(top: BorderSide(color: AppColors.textDim, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniStat(
              icon: Icons.restaurant_rounded,
              label: l10n.petHunger,
              value: '${hunger.round()}%',
              color: hungerColor,
            ),
          ),
          Expanded(
            child: _miniStat(
              icon: Icons.face_rounded,
              label: l10n.wardrobeMood,
              value: PetMoods.label(state.currentMood).toUpperCase(),
              color: moodColor,
            ),
          ),
          Expanded(
            child: _miniStat(
              icon: Icons.bolt_rounded,
              label: l10n.petLevel,
              value: l10n.petLevelValue(state.level),
              color: AppColors.inStock,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case PetMoods.happy:
        return const Color(0xFF4CAF50);
      case PetMoods.full:
        return const Color(0xFFFF9800);
      case PetMoods.angry:
        return const Color(0xFFFF5252);
      default:
        return AppColors.cat;
    }
  }

  // ── Bottom sheet con lore del gato ───────────────────────────────────

  void _showOutfitSheet(Outfit outfit) {
    final state = _state;
    final owned = state?.ownedOutfits.contains(outfit.id) ?? false;
    final equipped = state?.currentOutfit == outfit.id;
    final locked = !outfit.isFree && !owned;
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.fab)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Center(child: _buildPreviewLarge(outfit, locked: locked)),
                const SizedBox(height: AppSpacing.m),
                Text(
                  outfit.nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  outfit.descripcion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadii.stamp),
                    ),
                    child: Text(
                      locked
                          ? '🔒 ${outfit.condition}'
                          : (owned
                                ? l10n.wardrobeInYourWardrobe
                                : l10n.wardrobeFree),
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: locked ? AppColors.textMuted : AppColors.cat,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                if (locked)
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.textDim),
                      ),
                      child: Text(l10n.wardrobeNotYet),
                    ),
                  )
                else if (equipped)
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.cat,
                        foregroundColor: const Color(0xFF1A0F00),
                      ),
                      child: Text(
                        l10n.wardrobeEquipped,
                        style: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  )
                else if (!owned)
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _unlock(outfit);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      child: Text(
                        l10n.wardrobeUnlockFree,
                        style: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _equip(outfit);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.cat,
                        foregroundColor: const Color(0xFF1A0F00),
                      ),
                      child: Text(
                        l10n.wardrobeEquip,
                        style: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewLarge(Outfit outfit, {required bool locked}) {
    return Opacity(
      opacity: locked ? 0.35 : 1.0,
      child: outfit.assetPath != null
          ? NekoCatMascot(
              mood: CatMood.idle,
              size: 120,
              showLabel: false,
              outfitOverlayPath: outfit.assetPath,
            )
          : Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textDim.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(outfit.icon, color: AppColors.cat, size: 44),
            ),
    );
  }
}
