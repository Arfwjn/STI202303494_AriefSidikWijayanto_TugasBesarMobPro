// lib/ui/widgets/radial_menu.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../../core/theme.dart';
import '../screens/home/home_screen.dart';
import '../screens/add_edit/add_edit_screen.dart';
import '../screens/map/map_screen.dart';

class RadialMenu extends StatefulWidget {
  const RadialMenu({super.key});

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Background overlay when menu is open
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return IgnorePointer(
              ignoring: !_controller.isCompleted,
              child: AnimatedOpacity(
                duration: AppAnimations.fast,
                opacity: _controller.value * 0.3,
                child: Container(color: Colors.black),
              ),
            );
          },
        ),

        // Menu Buttons
        _buildMenuButton(
          angle: 3 * pi / 4,
          icon: Icons.home_rounded,
          label: 'Home',
          routeName: HomeScreen.routeName,
          color: AppTheme.primaryBlue,
        ),
        _buildMenuButton(
          angle: pi / 2,
          icon: Icons.add_location_alt_rounded,
          label: 'Tambah',
          routeName: AddEditScreen.routeName,
          color: AppTheme.accentOrange,
        ),
        _buildMenuButton(
          angle: pi / 4,
          icon: Icons.map_rounded,
          label: 'Peta',
          routeName: MapScreen.routeName,
          color: AppTheme.secondaryPurple,
        ),

        // Center FAB
        _buildCenterButton(),
      ],
    );
  }

  Widget _buildMenuButton({
    required double angle,
    required IconData icon,
    required String label,
    required String routeName,
    required Color color,
  }) {
    const double radius = 110;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double x = radius * cos(angle) * _scaleAnimation.value;
        final double y = radius * sin(angle) * _scaleAnimation.value;

        return Transform.translate(
          offset: Offset(x, -y),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pushNamed(routeName);
                    _controller.reverse();
                  },
                  child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () {
        if (_controller.isDismissed) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * pi / 4,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: _controller.value > 0.5
                    ? const LinearGradient(
                        colors: [Colors.red, Colors.redAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (_controller.value > 0.5
                                ? Colors.red
                                : AppTheme.primaryBlue)
                            .withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                _controller.value > 0.5 ? Icons.close : Icons.apps_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}
