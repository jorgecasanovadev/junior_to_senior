import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';

/// Small coloured badge for junior / mid / senior.
class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {this.dense = false, super.key});

  final SeniorityLevel level;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.levelColor(level.index);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          color: color,
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class DifficultyChip extends StatelessWidget {
  const DifficultyChip(this.difficulty, {super.key});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty) {
      Difficulty.easy => const Color(0xFF2E7D32),
      Difficulty.medium => const Color(0xFFE65100),
      Difficulty.hard => const Color(0xFFC62828),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= difficulty.index
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          difficulty.label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Markdown body with the app's typography and readable code blocks.
class ContentMarkdown extends StatelessWidget {
  const ContentMarkdown(this.data, {this.selectable = true, super.key});

  final String data;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        listBullet: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      ),
    );
  }
}

/// A labelled number, used in the header strips.
class StatPill extends StatelessWidget {
  const StatPill({
    required this.label,
    required this.value,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Consistent empty state, so every tab fails the same way.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Uniform error view; surfaces the real message because in a content-driven
/// app the usual cause is a malformed JSON entry someone just contributed.
class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Algo se rompió',
      message: '$error',
      action: onRetry == null
          ? null
          : FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
    );
  }
}
