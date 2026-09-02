import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/neko_palette.dart';
import '../services/streak_service.dart';

/// Badge visual de racha con llama animada y multiplicador de XP.
///
/// Si [onTap] es null, al presionar abre automáticamente el modal interactivo
/// [StreakMultiplierModal] con el desglose de tiers y progreso.
class StreakFlameBadge extends StatefulWidget {
  final int streak;
  final VoidCallback? onTap;
  final bool showMultiplier;
  final bool isCompact;

  const StreakFlameBadge({
    super.key,
    required this.streak,
    this.onTap,
    this.showMultiplier = true,
    this.isCompact = false,
  });

  @override
  State<StreakFlameBadge> createState() => _StreakFlameBadgeState();
}

class _StreakFlameBadgeState extends State<StreakFlameBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _showModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StreakMultiplierModal(streak: widget.streak),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final info = StreakService.streakTier(widget.streak);
    final hasMultiplier = info.multiplier > 1.0;
    final hasActiveFlame = widget.streak >= 3;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final pulseVal = hasActiveFlame ? _pulse.value : 0.0;
        final glowOpacity = 0.12 + (pulseVal * 0.16);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap ?? () => _showModal(context),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isCompact ? 8 : 10,
                vertical: widget.isCompact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: hasActiveFlame
                    ? info.color.withValues(alpha: 0.14)
                    : nk.text.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasActiveFlame
                      ? info.color.withValues(alpha: 0.35 + (pulseVal * 0.3))
                      : nk.border,
                  width: hasActiveFlame ? 1.2 : 1.0,
                ),
                boxShadow: hasActiveFlame
                    ? [
                        BoxShadow(
                          color: info.color.withValues(alpha: glowOpacity),
                          blurRadius: 10 + (pulseVal * 6),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícono de llama / emoji con escala sutil
                  Transform.scale(
                    scale: hasActiveFlame ? (1.0 + (pulseVal * 0.12)) : 1.0,
                    child: Text(
                      widget.streak > 0 ? (hasActiveFlame ? '🔥' : '⚡') : '💤',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 13 : 15,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Días de racha
                  Text(
                    '${widget.streak}D',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: widget.isCompact ? 11 : 12,
                      fontWeight: FontWeight.w800,
                      color: hasActiveFlame ? info.color : nk.text,
                      letterSpacing: 0.2,
                    ),
                  ),
                  // Multiplicador de XP
                  if (widget.showMultiplier && hasMultiplier) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            info.color.withValues(alpha: 0.95),
                            info.glowColor.withValues(alpha: 0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${info.multiplier}x XP',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: widget.isCompact ? 8.5 : 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal interactivo con el sistema de multiplicadores y progreso
// ─────────────────────────────────────────────────────────────────────────────

class StreakMultiplierModal extends StatelessWidget {
  final int streak;

  const StreakMultiplierModal({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final nk = context.nk;
    final info = StreakService.streakTier(streak);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: nk.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: nk.textFaint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                  children: [
                    // Cabecera Hero con Llama
                    _buildHeroHeader(nk, info),
                    const SizedBox(height: 20),

                    // Progreso al siguiente tier
                    _buildProgressSection(nk, info),
                    const SizedBox(height: 24),

                    // Título de la sección de Tiers
                    Row(
                      children: [
                        Icon(Icons.military_tech_rounded, size: 16, color: nk.amber),
                        const SizedBox(width: 8),
                        Text(
                          'TIERS DE MULTIPLICADOR',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: nk.textFaint,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de Tiers
                    _TierRow(
                      tierStreak: 30,
                      label: 'Llama Mítica',
                      multiplier: 2.5,
                      flameEmoji: '👑🔥',
                      color: const Color(0xFFFFD700),
                      isUnlocked: streak >= 30,
                      isCurrent: streak >= 30,
                      nk: nk,
                    ),
                    _TierRow(
                      tierStreak: 14,
                      label: 'Llama Azul Épica',
                      multiplier: 2.0,
                      flameEmoji: '⚡🔥',
                      color: const Color(0xFF00E5FF),
                      isUnlocked: streak >= 14,
                      isCurrent: streak >= 14 && streak < 30,
                      nk: nk,
                    ),
                    _TierRow(
                      tierStreak: 7,
                      label: 'Llama Dorada',
                      multiplier: 1.5,
                      flameEmoji: '🔥🔥',
                      color: const Color(0xFFFF9800),
                      isUnlocked: streak >= 7,
                      isCurrent: streak >= 7 && streak < 14,
                      nk: nk,
                    ),
                    _TierRow(
                      tierStreak: 3,
                      label: 'Llama Ámbar',
                      multiplier: 1.2,
                      flameEmoji: '🔥',
                      color: const Color(0xFFF0B429),
                      isUnlocked: streak >= 3,
                      isCurrent: streak >= 3 && streak < 7,
                      nk: nk,
                    ),
                    _TierRow(
                      tierStreak: 1,
                      label: 'Chispa Inicial',
                      multiplier: 1.0,
                      flameEmoji: '✨',
                      color: const Color(0xFF8B8A82),
                      isUnlocked: streak >= 1,
                      isCurrent: streak < 3,
                      nk: nk,
                    ),
                    const SizedBox(height: 20),

                    // Explicación de valor gamificado
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: nk.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: nk.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💡', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cada comida que registres en tu diario alimenta a tu mascota y multiplica la XP que gana. ¡Mantén viva la llama!',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                color: nk.textDim,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(
    NekoColors nk,
    ({
      String tierName,
      Color color,
      Color glowColor,
      String flameEmoji,
      int? nextTierStreak,
      double multiplier,
      int minStreak,
    }) info,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: info.color.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                info.flameEmoji,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak ${streak == 1 ? "DÍA" : "DÍAS"} DE RACHA',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: nk.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    info.tierName.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: info.color,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Badge central de multiplicador activo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  info.color.withValues(alpha: 0.9),
                  (info.glowColor == Colors.transparent ? info.color : info.glowColor)
                      .withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: Colors.black),
                const SizedBox(width: 6),
                Text(
                  'Multiplicador activo: ${info.multiplier}x XP',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(
    NekoColors nk,
    ({
      String tierName,
      Color color,
      Color glowColor,
      String flameEmoji,
      int? nextTierStreak,
      double multiplier,
      int minStreak,
    }) info,
  ) {
    if (info.nextTierStreak == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Has alcanzado el rango máximo! Tienes la bonificación suprema de 2.5x XP.',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: nk.text,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final nextGoal = info.nextTierStreak!;
    final needed = math.max(1, nextGoal - streak);
    final progress = ((streak - info.minStreak) / (nextGoal - info.minStreak))
        .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nk.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Siguiente nivel de llama',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: nk.text,
                  ),
                ),
              ),
              Text(
                'Faltan $needed ${needed == 1 ? "día" : "días"}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: nk.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: nk.surfaceHigh,
              color: info.color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${info.minStreak}D',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: nk.textFaint),
              ),
              Text(
                '${nextGoal}D',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: nk.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final int tierStreak;
  final String label;
  final double multiplier;
  final String flameEmoji;
  final Color color;
  final bool isUnlocked;
  final bool isCurrent;
  final NekoColors nk;

  const _TierRow({
    required this.tierStreak,
    required this.label,
    required this.multiplier,
    required this.flameEmoji,
    required this.color,
    required this.isUnlocked,
    required this.isCurrent,
    required this.nk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withValues(alpha: 0.12)
            : (isUnlocked ? nk.surface : nk.surface.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? color
              : (isUnlocked ? nk.border : nk.border.withValues(alpha: 0.4)),
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Text(flameEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isUnlocked ? nk.text : nk.textFaint,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTUAL',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'A partir de $tierStreak ${tierStreak == 1 ? "día" : "días"} de racha',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    color: nk.textFaint,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? color.withValues(alpha: 0.18)
                  : nk.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${multiplier}x XP',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isUnlocked ? color : nk.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
