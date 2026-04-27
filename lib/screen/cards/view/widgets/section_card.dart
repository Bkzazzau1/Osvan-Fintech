// lib/widgets/section_card.dart
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final bg = (isDark ? const Color(0xFF0F172A) : Colors.white)
        .withOpacity(isDark ? 0.75 : 0.95);

    final border = (isDark ? Colors.white : Colors.black).withOpacity(0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null || subtitle != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title ?? '',
                              style: th.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: th.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: th.textTheme.bodySmall?.color
                                ?.withOpacity(isDark ? 0.72 : 0.70),
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          ),

          // subtle top highlight
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(isDark ? 0.05 : 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
