// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/cards/view/cards_view.dart';
import 'package:osvan_app/screen/dashboard/view/dashboard_view.dart';
import 'package:osvan_app/screen/settings/view/settings_view.dart';
import 'package:share_plus/share_plus.dart';

class MainNavView extends StatefulWidget {
  const MainNavView({super.key});

  @override
  State<MainNavView> createState() => _MainNavViewState();
}

class _MainNavViewState extends State<MainNavView> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardView(),
    const CardsView(),
    const SettingsView(),
  ];

  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.credit_card,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hello Joseph!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Get.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Theme.of(
          context,
        ).cardColor, // Updated to match card color
        elevation: 0,
        iconTheme: IconThemeData(
          color: Get.isDarkMode ? Colors.white : Colors.black,
        ),
        actions: _selectedIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    Share.share(
                      'Check out the Osvan App – A better way to manage your money.\nhttps://osvan.africa',
                      subject: 'Join Osvan Fintech!',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {
                    Get.toNamed('/notifications');
                  },
                ),
              ]
            : [],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: osvanGreen, // ✅ use static Osvan green everywhere //
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() => _selectedIndex = index);
              },
              backgroundColor: Colors.transparent,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white54,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
              items: _icons
                  .map(
                    (icon) =>
                        BottomNavigationBarItem(icon: Icon(icon), label: ''),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
