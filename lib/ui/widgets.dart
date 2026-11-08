import 'dart:math' as math;

import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'glass.dart';


class EtsBackground extends StatelessWidget {
  const EtsBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (EtsGlass.on) {
      return Stack(
        children: [
          const Positioned.fill(child: GlassWallpaper()),
          Positioned.fill(child: child),
        ],
      );
    }
    return ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);
  }
}

/// 标准 M3 “主色容器” Hero 卡：无渐变、无夸张阴影。
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.colors, this.padding = const EdgeInsets.all(28)});
  final Widget child;
  final List<Color>? colors;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: scheme.onPrimaryContainer),
      child: IconTheme.merge(data: IconThemeData(color: scheme.onPrimaryContainer), child: child),
    );
    if (EtsGlass.on) {
      return EtsGlass.surface(
        context: context,
        padding: padding,
        radius: 28,
        color: scheme.primaryContainer.withValues(alpha: 0.78),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        child: content,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: content,
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (EtsGlass.on) {
      return EtsGlass.surface(
        context: context,
        padding: padding,
        radius: 24,
        color: color ?? scheme.surface.withValues(alpha: 0.70),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        child: child,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Panel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, required this.max, this.size = 88, this.label});
  final double score;
  final double max;
  final double size;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = max <= 0 ? 0.0 : (score / max).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: size * 0.09,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
              color: progress >= 0.6 ? scheme.primary : scheme.error,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(score.toStringAsFixed(score >= 10 ? 0 : 1),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.26, height: 1)),
              if (label != null)
                Text(label!, style: TextStyle(fontSize: size * 0.11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 录音中的动态波形。
class RecordingWave extends StatefulWidget {
  const RecordingWave({super.key, this.active = true, this.bars = 26});
  final bool active;
  final int bars;
  @override
  State<RecordingWave> createState() => _RecordingWaveState();
}

class _RecordingWaveState extends State<RecordingWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.bars, (i) {
            final phase = (i / widget.bars) * math.pi * 2;
            final wave = (math.sin(_controller.value * math.pi * 2 + phase) + 1) / 2;
            final h = 8 + wave * 34 * (widget.active ? 1 : 0.25);
            return Container(
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.35 + wave * 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.subtitle, this.icon = Icons.inbox_rounded, this.action});
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(icon, size: 42, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      color: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('重试', style: TextStyle(color: scheme.onErrorContainer)),
            ),
        ],
      ),
    );
  }
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, this.label = '加载中…'});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          const SizedBox(width: 30, height: 30, child: M3ELoadingIndicator(size: 34)),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}


/// 品牌标记（桌面侧栏 / 移动顶栏共用）。
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44, this.showSubtitle = true});
  final double size;
  final bool showSubtitle;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.34),
            color: scheme.primary,
          ),
          child: Center(
            child: Text('E',
                style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('E听说', style: Theme.of(context).textTheme.titleLarge),
              Text('M3E · FLUTTER',
                  style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ],
    );
  }
}
