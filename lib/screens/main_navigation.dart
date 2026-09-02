import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/neko_palette.dart';
import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/pet_state.dart';
import '../services/cat_alert_service.dart';
import 'home_dashboard.dart';
import 'pantry_screen.dart';
import 'diary_screen.dart';
import 'pet_screen.dart';
import 'profile_screen.dart';

/// Scope global para cambiar de pestaña de la `MainNavigation` desde cualquier
/// punto del árbol (p.ej. el drawer de la Despensa) sin hacer `push`.
///
/// Uso: `MainNavigationScope.of(context).changeTab(3);`
class MainNavigationScope extends InheritedNotifier<ValueNotifier<int>> {
  const MainNavigationScope({
    super.key,
    required ValueNotifier<int> notifier,
    required this.changeTab,
    required super.child,
  }) : super(notifier: notifier);

  /// Cambia la pestaña activa (swap del `selectedIndex` global).
  final ValueChanged<int> changeTab;

  /// Índice de la pestaña actualmente activa.
  int get currentIndex => notifier!.value;

  static MainNavigationScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MainNavigationScope>();
    assert(scope != null, 'MainNavigationScope no está en el árbol de widgets');
    return scope!;
  }
}

/// Navegación principal de la app — IndexedStack con BottomNavigationBar.
///
/// Índices:
///   0  → HomeDashboard  (resumen)
///   1  → PantryScreen   (despensa)
///   2  → DiaryScreen    (diario alimentario)
///   3  → PetScreen      (mascota)
///   4  → ProfileScreen  (perfil)
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  final ValueNotifier<int> _currentTab = ValueNotifier<int>(0);
  late final CatAlertService _catAlert = ref.read(catAlertServiceProvider);

  void _goTo(int index) {
    if (index == _currentTab.value) return;
    // Al entrar a la pestaña Mascota se leen las alertas del gato.
    if (index == 3) _catAlert.markRead();
    _currentTab.value = index;
  }

  @override
  void dispose() {
    _currentTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    // Badge del gato: se sincroniza con el estado reactivo de la mascota.
    // sustituye al antiguo `StreamSubscription` manual de PetService.
    ref.listen<AsyncValue<PetState>>(petStateProvider, (previous, next) {
      final hunger = next.value?.currentHunger ?? 0;
      _catAlert.setHighHunger(hunger >= 75);
    });
    return MainNavigationScope(
      notifier: _currentTab,
      changeTab: _goTo,
      child: ValueListenableBuilder<int>(
        valueListenable: _currentTab,
        builder: (context, index, _) {
          // Cada pestaña se envuelve con `Offstage(offstage: index != i)`:
          //   - Cuando la pestaña NO es la activa, su subárbol queda
          //     fuera del hit-test y del paint. El `Element` sigue vivo,
          //     así que el State y las animaciones se preservan.
          //   - Esto resuelve el crash `RenderBox.hitTest NEEDS-LAYOUT`
          //     en `_ScaffoldSlot.floatingActionButton` que ocurría
          //     porque el `Scaffold` interno de `PetScreen` recibía
          //     hit-test aunque su pestaña no fuera la activa.
          //
          // `Positioned.fill` garantiza que el hijo activo ocupe toda la
          // pantalla, igual que el `IndexedStack` original.
          return Scaffold(
            backgroundColor: nk.bg,
            extendBody: false,
            body: Stack(
              children: [
                Positioned.fill(
                  child: Offstage(
                    offstage: index != 0,
                    child: HomeDashboard(onNavigateTo: _goTo),
                  ),
                ),
                Positioned.fill(
                  child: Offstage(
                    offstage: index != 1,
                    child: const PantryScreen(),
                  ),
                ),
                Positioned.fill(
                  child: Offstage(
                    offstage: index != 2,
                    child: const DiaryScreen(),
                  ),
                ),
                Positioned.fill(
                  child: Offstage(
                    offstage: index != 3,
                    child: const PetScreen(),
                  ),
                ),
                Positioned.fill(
                  child: Offstage(
                    offstage: index != 4,
                    child: const ProfileScreen(),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _NekoBottomNav(
                    currentIndex: index,
                    onTap: _goTo,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: null,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Bar estilo NekoFit
// ─────────────────────────────────────────────────────────────────────────────
class _NekoBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NekoBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nk = context.nk;
    final l10n = AppLocalizations.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: nk.mode == NekoThemeMode.dark 
                  ? const Color(0xFF1A1A1A).withValues(alpha: 0.82) 
                  : const Color(0xFFF5F5F7).withValues(alpha: 0.82),
              border: Border.all(
                color: nk.mode == NekoThemeMode.dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 68,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: l10n.navHome,
                      index: 0,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                    _NavItem(
                      icon: Icons.inventory_2_rounded,
                      label: l10n.navPantry,
                      index: 1,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                    _NavItem(
                      icon: Icons.calendar_month_rounded,
                      label: l10n.navDiary,
                      index: 2,
                      currentIndex: currentIndex,
                      onTap: onTap,
                      fab: true,
                    ),
                    _NavItem(
                      icon: Icons.pets_rounded,
                      label: l10n.navPet,
                      index: 3,
                      currentIndex: currentIndex,
                      onTap: onTap,
                      badgeCount: ref.read(catAlertServiceProvider).unread,
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: l10n.navProfile,
                      index: 4,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Contador de alertas sin leer — si es > 0 muestra un dot rojo.
  final ValueListenable<int>? badgeCount;

  /// Renderiza el ítem como FAB central (gradiente ámbar, elevado).
  final bool fab;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount,
    this.fab = false,
  });

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final isDark = nk.mode == NekoThemeMode.dark;
    final isActive = index == currentIndex;

    // ── FAB central: rediseño creativo para el Diario (Calendario) ──
    if (fab) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          customBorder: const CircleBorder(),
          splashColor: nk.amber.withValues(alpha: 0.25),
          highlightColor: nk.amber.withValues(alpha: 0.10),
          child: Transform.translate(
            offset: const Offset(0, -12),
            child: AnimatedContainer(
              duration: AppSprings.elasticSpring.estimatedDuration,
              curve: Curves.easeOutBack,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isActive
                    ? (isDark ? context.nt.amberGradient : null)
                    : (isDark
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2A2620), Color(0xFF1A1612)],
                            )
                          : null),
                color: isActive
                    ? (isDark ? null : nk.amber)
                    : (isDark ? null : nk.surface),
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? nk.amber.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 26,
                color: isActive
                    ? (isDark ? context.nt.onAmber : Colors.white)
                    : nk.textFaint,
              ),
            ),
          ),
        ),
      );
    }

    // ── Ítem normal: pill + etiqueta ──
    Widget iconPill = AnimatedContainer(
      duration: AppSprings.defaultSpring.estimatedDuration,
      curve: Curves.easeOutCubic,
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        color: isActive ? nk.amber.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 20, color: isActive ? nk.amber : nk.textFaint),
    );

    // Badge rojo encima del ícono — solo se reconstruye al cambiar el conteo.
    if (badgeCount != null) {
      iconPill = ValueListenableBuilder<int>(
        valueListenable: badgeCount!,
        child: iconPill,
        builder: (context, count, child) => Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            if (count > 0)
              Positioned(right: -4, top: -4, child: _BadgeDot(count: count)),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(index),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        splashColor: nk.amber.withValues(alpha: 0.15),
        highlightColor: nk.amber.withValues(alpha: 0.05),
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconPill,
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 8.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.12,
                  color: isActive ? nk.amber : nk.textFaint,
                ),
                child: Text(label.toUpperCase()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dot rojo con conteo — "el gato tiene algo que decirte".
class _BadgeDot extends StatelessWidget {
  final int count;
  const _BadgeDot({required this.count});

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: nk.bg, width: 1.5),
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
