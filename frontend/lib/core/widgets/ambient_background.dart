import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.fog, AppColors.cloud, Color(0xFFF1E7DA)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            right: -40,
            child: _AmbientOrb(size: 320, color: Color(0x264E7BFF)),
          ),
          const Positioned(
            top: 120,
            left: -70,
            child: _AmbientOrb(size: 220, color: Color(0x221C7A72)),
          ),
          const Positioned(
            bottom: -140,
            left: 60,
            child: _AmbientOrb(size: 320, color: Color(0x26E06D43)),
          ),
          const Positioned(
            bottom: 120,
            right: 70,
            child: _AmbientOrb(size: 180, color: Color(0x1FE8DED0)),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}
