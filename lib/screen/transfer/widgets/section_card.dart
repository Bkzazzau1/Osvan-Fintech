// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final bool noPadding;

  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.noPadding = false, // ✅ DEFAULT (important)
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color cardColor =
        theme.cardTheme.color ?? theme.colorScheme.surface;
    final Color titleColor = theme.colorScheme.onSurface;
    final Color subColor = theme.colorScheme.onSurface.withOpacity(0.75);

    return Card(
      elevation: theme.cardTheme.elevation ?? 10,
      color: cardColor,
      shadowColor: theme.shadowColor
          .withOpacity((theme.cardTheme.elevation ?? 10) > 0 ? 0.12 : 0),
      shape: theme.cardTheme.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: noPadding ? EdgeInsets.zero : const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || subtitle != null) ...[
              Text(
                title ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: subColor),
                ),
              ],
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
