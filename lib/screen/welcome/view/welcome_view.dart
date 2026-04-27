// lib/screen/auth/welcome_view.dart
// Premium WelcomeView — high-tech, modern, unique (glass CTA, gradient, animated indicators)
// ✅ Keeps CarouselSlider
// ✅ Premium overlays, glow, better typography, glass CTA
// ✅ Adds "Skip" + language placeholder bottom sheet
// ✅ No breaking logic: still navigates to AppRoutes.login
//
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/colors.dart';
import '../../../routes/app_routes.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  int _currentIndex = 0;

  // ✅ correct controller type
  final CarouselSliderController _carousel = CarouselSliderController();

  final List<_WelcomeSlide> slides = const [
    _WelcomeSlide(
      image: 'assets/images/fintech1.png',
      title: 'Send & receive\nwith confidence',
      text:
          'Built for the way Africa moves money. Mobile money or bank transfer—fast, secure, and smooth.',
      accent: Color(0xFF60A5FA), // blue glow
    ),
    _WelcomeSlide(
      image: 'assets/images/fintech2.png',
      title: 'Import vehicles\nwithout stress',
      text:
          'Drive what moves the future. Access trusted suppliers and transparent steps—no guesswork.',
      accent: Color(0xFFF59E0B), // gold glow
    ),
    _WelcomeSlide(
      image: 'assets/images/fintech3.png',
      title: 'Protection\nbuilt-in',
      text:
          'Trust is part of every deal. Digital shields reduce fraud risk and help you stay in control.',
      accent: Color(0xFF10B981), // green glow
    ),
  ];

  void onGetStartedPressed() => Get.toNamed(AppRoutes.login);

  void onLanguagePressed() {
    _showComingSoonSheet(
      title: "Language",
      body: "Language selection will be available soon.",
    );
  }

  void onSkipPressed() => onGetStartedPressed();

  void _showComingSoonSheet({required String title, required String body}) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF0F172A) : Colors.white)
                      .withOpacity(isDark ? 0.78 : 0.95),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.10),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: osvanGreen.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.info_outline,
                              color: osvanGreen.withOpacity(0.95)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: th.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.close_rounded),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: th.textTheme.bodyMedium?.copyWith(
                        color:
                            th.textTheme.bodyMedium?.color?.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: osvanGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Okay",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          CarouselSlider.builder(
            carouselController: _carousel,
            itemCount: slides.length,
            itemBuilder: (context, index, realIndex) {
              final s = slides[index];

              final dx =
                  ((realIndex - index).abs() * 10).clamp(0, 16).toDouble();

              return Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(dx, 0),
                    child: Image.asset(
                      s.image,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.55),
                          Colors.black.withOpacity(0.40),
                          Colors.black.withOpacity(0.72),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: _GlowBlob(
                      color: s.accent.withOpacity(0.28),
                      size: 280,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: _GlowBlob(
                      color: osvanGreen.withOpacity(0.18),
                      size: 320,
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(height: h * 0.12),
                          Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: th.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.06,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Text(
                              s.text,
                              textAlign: TextAlign.center,
                              style: th.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withOpacity(0.88),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            options: CarouselOptions(
              height: MediaQuery.of(context).size.height,
              viewportFraction: 1,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              autoPlayAnimationDuration: const Duration(milliseconds: 900),
              autoPlayCurve: Curves.easeOutCubic,
              onPageChanged: (index, reason) =>
                  setState(() => _currentIndex = index),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _GlassPillButton(
                    icon: Icons.language_rounded,
                    label: "Language",
                    onTap: onLanguagePressed,
                  ),
                  const Spacer(),
                  _GlassTextButton(
                    label: "Skip",
                    onTap: onSkipPressed,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PremiumDots(
                    count: slides.length,
                    active: _currentIndex,
                    onDotTap: (i) => _carousel.animateToPage(i),
                  ),
                  const SizedBox(height: 14),
                  _BottomGlassCTA(
                    title: "Get started",
                    subtitle: "Create an account or sign in to continue",
                    buttonText: "Continue",
                    onPressed: onGetStartedPressed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSlide {
  final String image;
  final String title;
  final String text;
  final Color accent;
  const _WelcomeSlide({
    required this.image,
    required this.title,
    required this.text,
    required this.accent,
  });
}

class _PremiumDots extends StatelessWidget {
  final int count;
  final int active;
  final ValueChanged<int> onDotTap;

  const _PremiumDots({
    required this.count,
    required this.active,
    required this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return GestureDetector(
          onTap: () => onDotTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: isActive ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        blurRadius: 14,
                        color: Colors.white.withOpacity(0.25),
                      )
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _BottomGlassCTA extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _BottomGlassCTA({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.62),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                offset: const Offset(0, 14),
                color: Colors.black.withOpacity(0.35),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: th.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: th.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.78),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: osvanGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(0.10),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GlassTextButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(0.10),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 70,
              spreadRadius: 18,
              color: color.withOpacity(0.55),
            ),
          ],
        ),
      ),
    );
  }
}
