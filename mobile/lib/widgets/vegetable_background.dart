import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Decorative green background with scattered vegetable emoji, used behind
/// the auth screens (login / register / OTP) to give them a grocery-store
/// identity beyond a plain white page. Wraps [child] in a Scaffold-ready
/// Stack — pass this as a screen's `body`.
class VegetableBackground extends StatelessWidget {
  const VegetableBackground({super.key, required this.child});

  final Widget child;

  static const _emoji = [
    '🥦',
    '🥕',
    '🍅',
    '🥬',
    '🌽',
    '🍆',
    '🫑',
    '🧅',
    '🥔',
    '🍋',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Scattered translucent vegetable emoji, purely decorative.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.16,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final positions = <Widget>[];
                    for (var i = 0; i < _emoji.length; i++) {
                      final dx = (i * 37 % 100) / 100 * constraints.maxWidth;
                      final dy = (i * 53 % 100) / 100 * constraints.maxHeight;
                      positions.add(
                        Positioned(
                          left: dx,
                          top: dy,
                          child: Text(
                            _emoji[i],
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      );
                    }
                    return Stack(children: positions);
                  },
                ),
              ),
            ),
          ),
          // The actual screen content, on a rounded off-white card area so
          // form fields stay readable over the green backdrop.
          SafeArea(child: child),
        ],
      ),
    );
  }
}
