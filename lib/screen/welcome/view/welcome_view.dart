// ignore_for_file: deprecated_member_use

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  int _currentIndex = 0;

  final List<Map<String, String>> slides = [
    {
      'image': 'assets/images/fintech1.png',
      'text':
          'Built for the way Africa sends and receives. Whether it’s mobile money or bank transfer, you’re covered.',
    },
    {
      'image': 'assets/images/fintech2.png',
      'text':
          'Drive what moves the future. Import top-quality vehicles directly from trusted Chinese manufacturers.',
    },
    {
      'image': 'assets/images/fintech3.png',
      'text':
          'Trust built into every deal. Digital shields protect your money and goods from fraud.',
    },
  ];

  void onGetStartedPressed() {
    Get.toNamed(AppRoutes.login);
  }

  void onLanguagePressed() {
    Get.snackbar(
      "Coming Soon",
      "Language selector not implemented yet",
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CarouselSlider.builder(
            itemCount: slides.length,
            itemBuilder: (context, index, realIndex) {
              final slide = slides[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(slide['image']!, fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(0.4)),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        slide['text']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
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
              onPageChanged: (index, reason) {
                setState(() => _currentIndex = index);
              },
            ),
          ),

          // Language Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.language, color: Colors.white),
                  onPressed: onLanguagePressed,
                ),
              ),
            ),
          ),

          // Dots Indicator
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: slides.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == entry.key
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }).toList(),
            ),
          ),

          // Get Started Button
          Positioned(
            bottom: 40,
            left: 32,
            right: 32,
            child: ElevatedButton(
              onPressed: onGetStartedPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), // Osvan green
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
