// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/cards/view/cards_view.dart';
import 'package:osvan_app/screen/dashboard/controller/dashboard_controller.dart';
import 'package:osvan_app/screen/dashboard/view/dashboard_view.dart';
import 'package:osvan_app/screen/settings/view/settings_view.dart';
import 'package:share_plus/share_plus.dart';

/// Luxury Dark constants (single mode)
const kDarkBg = Color(0xFF070B14);
const kDarkSurface = Color(0xFF0F172A); // rule: big card color
const kDarkSurface2 = Color(0xFF0B1220);

/// Luxury Ice-Blue accent
const kIceBlue = Color(0xFF60A5FA);

class MainNavView extends StatefulWidget {
  const MainNavView({super.key});

  @override
  State<MainNavView> createState() => _MainNavViewState();
}

class _MainNavViewState extends State<MainNavView>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  late final DashboardController _dc =
      Get.put(DashboardController(), permanent: true);

  final List<Widget> _pages = const [
    DashboardView(),
    CardsView(),
    SettingsView(),
  ];

  final _items = const [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.credit_card_outlined, label: 'Cards'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dc.loadUser());
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();

    final now = DateTime.now();
    if (_selectedIndex == 0 && index == 0) {
      if (_lastTap != null &&
          now.difference(_lastTap!) < const Duration(milliseconds: 350)) {
        // optional: scroll-to-top hook later
      }
      _lastTap = now;
    } else {
      _lastTap = now;
    }

    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Single mode: force premium dark theme for the whole shell
    final dark = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kDarkBg,
      colorScheme: const ColorScheme.dark(
        primary: kIceBlue,
        secondary: kIceBlue,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );

    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: kDarkBg,

        // Background glow (same language as Dashboard)
        extendBody: true,
        body: Stack(
          children: [
            const _LuxuryShellBackground(),

            // Actual UI
            Column(
              children: [
                // Glass AppBar (custom)
                _GlassTopBar(
                  selectedIndex: _selectedIndex,
                  dc: _dc,
                ),

                // Pages
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: _pages),
                ),
              ],
            ),
          ],
        ),

        // Bottom Navigation (luxury glass pill)
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kDarkSurface.withOpacity(0.84),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        offset: const Offset(0, 10),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: _AnimatedPillNavBar(
                    items: _items,
                    index: _selectedIndex,
                    onTap: _onTabTapped,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTopBar extends StatelessWidget {
  final int selectedIndex;
  final DashboardController dc;

  const _GlassTopBar({
    required this.selectedIndex,
    required this.dc,
  });

  @override
  Widget build(BuildContext context) {
    final title = selectedIndex == 0
        ? 'Manage your money with Osvan'
        : selectedIndex == 1
            ? 'Your virtual cards'
            : 'Account & preferences';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: kDarkSurface.withOpacity(0.78),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                // Brand dot + name
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kIceBlue.withOpacity(0.14),
                    border: Border.all(color: kIceBlue.withOpacity(0.18)),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kIceBlue,
                      boxShadow: [
                        BoxShadow(
                          color: kIceBlue.withOpacity(0.35),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Greeting
                Expanded(
                  child: Obx(() {
                    final u = dc.user.value;

                    String pickName() {
                      if (u == null) return 'there';
                      final display = (u.displayName).trim();
                      if (display.isNotEmpty) return display;

                      final first = (u.firstName).trim();
                      if (first.isNotEmpty) return first;

                      final user = (u.username).trim();
                      if (user.isNotEmpty) return user;

                      final email = (u.email).trim();
                      if (email.isNotEmpty) return email.split('@').first;

                      return 'there';
                    }

                    final name = pickName();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }),
                ),

                // Actions (match your old behavior)
                if (selectedIndex == 0) ...[
                  _TopIcon(
                    tooltip: 'Share Osvan',
                    icon: Icons.share_outlined,
                    onTap: () {
                      Share.share(
                        'Check out the Osvan App – A better way to manage your money.\nhttps://osvan.africa',
                        subject: 'Join Osvan!',
                      );
                    },
                  ),
                  _TopIcon(
                    tooltip: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                    onTap: () => Get.toNamed('/notifications'),
                  ),
                ] else if (selectedIndex == 1) ...[
                  _TopIcon(
                    tooltip: 'Add Card',
                    icon: Icons.add_card_outlined,
                    onTap: () => Get.toNamed('/cards/new'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _TopIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.92), size: 20),
        ),
      ),
    );
  }
}

class _LuxuryShellBackground extends StatelessWidget {
  const _LuxuryShellBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kDarkBg, kDarkSurface2, kDarkBg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: kIceBlue, size: 260, opacity: 0.10),
          ),
          Positioned(
            top: 160,
            right: -120,
            child: _GlowBlob(color: osvanGreen, size: 260, opacity: 0.07),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child:
                _GlowBlob(color: Colors.purpleAccent, size: 320, opacity: 0.07),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withOpacity(opacity),
          ),
        ),
      ),
    );
  }
}

/// A compact, pill-style navbar with a smooth ICE-BLUE active indicator
class _AnimatedPillNavBar extends StatelessWidget {
  final List<({IconData icon, String label})> items;
  final int index;
  final ValueChanged<int> onTap;

  const _AnimatedPillNavBar({
    required this.items,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withOpacity(0.72);

    return Row(
      children: List.generate(items.length, (i) {
        final sel = i == index;

        return Expanded(
          child: Semantics(
            button: true,
            selected: sel,
            label: items[i].label,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? kIceBlue : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: sel
                        ? kIceBlue.withOpacity(0.35)
                        : Colors.white.withOpacity(0.06),
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: kIceBlue.withOpacity(0.35),
                            offset: const Offset(0, 8),
                            blurRadius: 18,
                          ),
                        ]
                      : [],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 22,
                        color: sel ? Colors.white : inactiveColor,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 170),
                        curve: Curves.easeOut,
                        child: SizedBox(width: sel ? 8 : 0),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: sel ? 1 : 0,
                        child: sel
                            ? Text(
                                items[i].label,
                                overflow: TextOverflow.fade,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
