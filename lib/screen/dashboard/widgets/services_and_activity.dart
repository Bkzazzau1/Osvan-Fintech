// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';

import '/controller/theme_controller.dart';

class ServicesAndActivity extends StatelessWidget {
  const ServicesAndActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(isDark),
        const SizedBox(height: 20),
        _servicesRow(context, isDark),
        const SizedBox(height: 24),
        _recentActivity(),
      ],
    );
  }

  Widget _header(bool isDark) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Services',
            style: TextStyle(
              color: isDark ? osvanWhite : osvanBlack,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('See All',
                style: TextStyle(color: osvanGrey, fontSize: 14)),
          ),
        ],
      );

  Widget _servicesRow(BuildContext context, bool isDark) {
    final bg = isDark ? osvanGreen.withOpacity(0.12) : Colors.white;
    final fg = isDark ? osvanGreen : osvanBlack;
    final borderColor = isDark ? Colors.transparent : Colors.grey.shade200;
    final cardWidth = (MediaQuery.of(context).size.width - 48) / 2;

    Widget card(String label, IconData icon, VoidCallback onTap) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                          color: Colors.black.withOpacity(0.04))
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 30, color: fg),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: fg)),
              ],
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        card('Osvan Assurance', Icons.lock, () => Get.toNamed('/osvan_secure')),
        card('Osvan Automart', Icons.local_shipping,
            () => Get.toNamed('/osvan_automart')),
      ],
    );
  }

  Widget _recentActivity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const ListTile(
            title: Text('Sent ₦1,000 to John'),
            subtitle: Text('Jul 12, 2025'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Get.toNamed('/transaction-history'),
              child: const Text('View All Transactions',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
}
