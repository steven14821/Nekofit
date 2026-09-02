import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/haptics.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../data/outfits.dart';
import '../l10n/app_localizations.dart';
import '../models/pantry_item.dart';
import '../models/pet_state.dart';
import '../services/firebase_service.dart';
import '../services/pet_service.dart';
import '../services/streak_service.dart';
import '../widgets/amber_atmosphere.dart';
import '../widgets/celebrations.dart';
import '../widgets/neko_cat_mascot.dart';
import '../widgets/neko_chat_sheet.dart';
import '../widgets/streak_flame_badge.dart';
import 'diary_screen.dart';
import 'wardrobe_screen.dart';

/// Pantalla de la mascota virtual: muestra hambre, humor, nivel y racha.
/// El botón principal "Dar de comer" navega al diario, que es donde se
/// alimentará a la mascota al guardar una comida real.
///
/// Cuando el gato sube de nivel se muestra una celebración a pantalla
/// completa (LevelUpCelebration) detectando el cambio en el stream de estado.
class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});

  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  late final PetRepository _pet = ref.read(petServiceProvider);
  late final FirebaseService _firebase = ref.read(firebaseServiceProvider);
  String _catName = 'Mochi';
  String _petType = 'gato';

  PetState? _state;
  List<PantryItem> _pantryItems = const [];

  StreamSubscription<PetState>? _petSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pantrySub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  // Celebración de subida de nivel detectada en vivo.
  int? _levelUpTo;
  int _levelUpSeq = 0;

  @override
  void initState() {
    super.initState();
    _listenForProfileChanges();
    _listenPetState();
    _listenPantry();
  }

  @override
  void dispose() {
    _petSub?.cancel();
    _pantrySub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  /// Escucha el estado de la mascota. Si el nivel sube respecto al último
  /// valor conocido, dispara la celebración.
  void _listenPetState() {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    _petSub = _pet.watchPetState(uid).listen((state) {
      if (!mounted) return;
      final prevLevel = _state?.level;
      final leveledUp = prevLevel != null && state.level > prevLevel;
      // Subida de nivel → feedback de logro (además de la celebración visual).
      if (leveledUp) Haptics.success();
      setState(() {
        _state = state;
        if (leveledUp) {
          _levelUpTo = state.level;
          _levelUpSeq++;
        }
      });
    });
  }

  void _listenPantry() {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    _pantrySub = _firebase.db
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            _pantryItems = snap.docs
                .map((d) => PantryItem.fromMap(d.data(), d.id))
                .toList();
          });
        });
  }

  /// Escucha el documento del usuario en tiempo real para que los cambios de
  /// nombre/tipo de mascota (hechos desde editar perfil) se reflejen al
  /// instante, sin necesidad de recargar la pantalla.
  void _listenForProfileChanges() {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    _profileSub = _firebase.db.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      if (!mounted || !doc.exists) return;
      final raw = doc.data()?['catName'] as String?;
      final petType = doc.data()?['petType'] as String?;
      setState(() {
        if (raw != null && raw.trim().isNotEmpty) _catName = raw.trim();
        if (petType != null && petType.isNotEmpty) _petType = petType;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final state = _state;
    if (state == null) {
      return Scaffold(
        backgroundColor: nk.bg,
        body: Center(child: CircularProgressIndicator(color: nk.amber)),
      );
    }

    return Stack(
      children: [
        _buildContent(context, state, _pantryItems),
        // Celebración de subida de nivel detectada en vivo.
        if (_levelUpTo != null)
          Positioned.fill(
            child: LevelUpCelebration(
              key: ValueKey('pet-levelup-$_levelUpSeq'),
              level: _levelUpTo!,
              xp: state.xp,
              catName: _catName,
              onFinished: () {
                if (mounted) setState(() => _levelUpTo = null);
              },
            ),
          ),
      ],
    );
  }

  /// Construye el contenido visual de la pantalla Mascota con su propio
  /// `Scaffold` (AppBar + FAB + body). El `Scaffold` interno es
  /// intencional: provee el FAB del chat y el AppBar de "Tu Mascota".
  ///
  /// Importante: este `Scaffold` está envuelto por `Offstage` en
  /// `MainNavigation` cuando la pestaña Mascota no está activa, lo que
  /// bloquea su hit-test y resuelve el crash `_ScaffoldSlot.floatingActionButton
  /// NEEDS-LAYOUT`.
  Widget _buildContent(
    BuildContext context,
    PetState state,
    List<PantryItem> pantryItems,
  ) {
    final outfit = Outfits.byId(state.currentOutfit);

    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: nk.bg,
      appBar: AppBar(
        title: Text(
          l10n.petTitle,
          style: _display(
            size: 20,
            weight: FontWeight.w700,
            color: nk.text,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: nk.textDim),
        actions: [
          IconButton(
            tooltip: l10n.petWardrobeTooltip,
            icon: Icon(Icons.checkroom_rounded, color: nk.textDim),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const WardrobeScreen()));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'pet-neko-chat-fab',
        onPressed: () => NekoChatSheet.show(context, pantryItems),
        backgroundColor: nk.amber,
        foregroundColor: nk.mode == NekoThemeMode.dark
            ? const Color(0xFF1A1206)
            : Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.chat_bubble_rounded),
      ),
      body: AmberAtmosphere(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroCard(state, outfit?.assetPath),
                const SizedBox(height: 16),
                _buildStatsGrid(state),
                const SizedBox(height: 16),
                _buildFeedButton(context),
                const SizedBox(height: 12),
                _buildWardrobeButton(context),
                const SizedBox(height: 20),
                _buildFootnote(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard(PetState state, String? outfitAsset) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final moodColor = _moodColor(state.currentMood, nk);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        gradient: nk.mode == NekoThemeMode.dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF23201A), Color(0xFF16151A)],
              )
            : null,
        color: nk.mode == NekoThemeMode.dark ? null : nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: moodColor.withValues(alpha: 0.35), width: 1),
        boxShadow: nk.mode == NekoThemeMode.dark
            ? const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ]
            : const [],
      ),
      child: Column(
        children: [
          NekoCatMascot(
            petState: state,
            outfitOverlayPath: outfitAsset,
            size: 150,
            showLabel: false,
            imagePath: petAssetPath(_petType),
          ),
          const SizedBox(height: 14),
          Text(
            _catName.toUpperCase(),
            style: _display(
              size: 30,
              weight: FontWeight.w700,
              color: nk.text,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: moodColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: moodColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              l10n.petMoodLabel(
                PetMoods.label(state.currentMood).toUpperCase(),
              ),
              style: _mono(
                size: 10.5,
                weight: FontWeight.w700,
                color: moodColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats grid ───────────────────────────────────────────────────────
  Widget _buildStatsGrid(PetState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hungerCard(state),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            Expanded(child: _levelCard(state)),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: _streakCard(state)),
          ],
        ),
      ],
    );
  }

  Widget _hungerCard(PetState state) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    final hunger = state.currentHunger;
    final pct = (hunger / 100.0).clamp(0.0, 1.0);
    final isCritical = hunger >= 70;
    final accent = isCritical ? nk.danger : nk.protein;
    final fillColor = isCritical ? nk.danger : nk.cat;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                l10n.petHunger,
                style: _mono(
                  size: 11,
                  weight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '${hunger.toStringAsFixed(0)}%',
                style: _mono(size: 18, weight: FontWeight.w700, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: nk.surfaceHigh,
              child: FractionallySizedBox(
                widthFactor: pct,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCritical
                ? l10n.petHungerCritical(_catName)
                : l10n.petHungerLow,
            style: _body(size: 12, color: nk.textDim),
          ),
        ],
      ),
    );
  }

  Widget _levelCard(PetState state) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nk.ok.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: nk.ok),
              const SizedBox(width: 6),
              Text(
                l10n.petLevel,
                style: _mono(
                  size: 11,
                  weight: FontWeight.w700,
                  color: nk.ok,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.petLevelValue(state.level),
            style: _display(size: 24, weight: FontWeight.w700, color: nk.text),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: nk.surfaceHigh,
              child: FractionallySizedBox(
                widthFactor: state.levelProgress,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: nk.ok,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('${state.xp}/100 XP', style: _mono(size: 10, color: nk.textDim)),
        ],
      ),
    );
  }

  Widget _streakCard(PetState state) {
    return FutureBuilder<int>(
      future: _streakDays(),
      builder: (context, snap) {
        final streak = snap.data ?? 0;
        final nk = context.nk;
        final l10n = AppLocalizations.of(context);
        final info = StreakService.streakTier(streak);
        final hasActiveFlame = streak >= 3;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => StreakMultiplierModal(streak: streak),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: hasActiveFlame
                    ? info.color.withValues(alpha: 0.10)
                    : nk.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasActiveFlame
                      ? info.color.withValues(alpha: 0.45)
                      : nk.warn.withValues(alpha: 0.28),
                  width: hasActiveFlame ? 1.4 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        streak > 0 ? (hasActiveFlame ? '🔥' : '⚡') : '💤',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.petStreak,
                        style: _mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: hasActiveFlame ? info.color : nk.warn,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const Spacer(),
                      // Chip multiplicador
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${info.multiplier}x XP',
                          style: _mono(
                            size: 9.5,
                            weight: FontWeight.w800,
                            color: hasActiveFlame ? info.color : nk.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$streak',
                        style: _display(
                          size: 24,
                          weight: FontWeight.w700,
                          color: hasActiveFlame ? info.color : nk.text,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.petStreakDays(streak),
                        style: _mono(
                          size: 11,
                          color: hasActiveFlame
                              ? info.color.withValues(alpha: 0.8)
                              : nk.textDim,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    info.tierName,
                    style: _mono(
                      size: 9.5,
                      color: hasActiveFlame
                          ? info.color.withValues(alpha: 0.7)
                          : nk.textDim,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<int> _streakDays() async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return 0;
    final doc = await _firebase.db.collection('users').doc(uid).get();
    return ((doc.data()?['currentStreak'] as num?) ?? 0).toInt();
  }

  // ── CTA ───────────────────────────────────────────────────────────────
  Widget _buildFeedButton(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          final fed = await Navigator.of(
            context,
          ).push<bool>(MaterialPageRoute(builder: (_) => const DiaryScreen()));
          if (fed != true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.petExpectingFood(_catName)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: nk.amber,
          foregroundColor: nk.mode == NekoThemeMode.dark
              ? const Color(0xFF1A1206)
              : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(
          Icons.restaurant_menu_rounded,
          color: nk.mode == NekoThemeMode.dark
              ? const Color(0xFF1A1206)
              : Colors.white,
        ),
        label: Text(
          l10n.petFeed,
          style: _mono(
            size: 13.5,
            weight: FontWeight.w700,
            color: nk.mode == NekoThemeMode.dark
                ? const Color(0xFF1A1206)
                : Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildWardrobeButton(BuildContext context) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WardrobeScreen()));
        },
        icon: const Icon(Icons.checkroom_rounded, size: 18),
        label: Text(l10n.petWardrobe),
        style: OutlinedButton.styleFrom(
          foregroundColor: nk.amber,
          side: BorderSide(color: nk.amber.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildFootnote(PetState state) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: nk.cat, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.petObserving(_catName, state.xpTotal),
          style: _mono(size: 10.5, color: nk.textFaint),
        ),
      ],
    );
  }

  Color _moodColor(String mood, NekoColors nk) {
    switch (mood) {
      case PetMoods.happy:
        return nk.ok;
      case PetMoods.full:
        return nk.warn;
      case PetMoods.angry:
        return nk.danger;
      default:
        return nk.cat;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tipografía Noche Ámbar (mismas fuentes que Home/Diario)
// ─────────────────────────────────────────────────────────────────────────────
TextStyle _display({
  double size = 14,
  FontWeight weight = FontWeight.w700,
  Color color = const Color(0xFFF4EFE6),
  double? letterSpacing,
  double? height,
}) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

TextStyle _mono({
  double size = 11,
  FontWeight weight = FontWeight.w500,
  Color color = const Color(0xFF6B6459),
  double letterSpacing = 0,
  double? height,
}) => GoogleFonts.jetBrainsMono(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

TextStyle _body({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = const Color(0xFFF4EFE6),
}) => GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color);
