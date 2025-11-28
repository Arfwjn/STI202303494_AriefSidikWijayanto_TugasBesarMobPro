// lib/ui/widgets/radial_menu.dart

import '../../../../main.dart'; // Akses navigatorKey
import 'package:flutter/material.dart';
import 'dart:math';

// Import Screens (untuk navigasi)
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Fungsi untuk membangun tombol Radial
  Widget _buildButton(double angle, IconData icon, String routeName) {
    final double radius = 100;
    final double x = radius * cos(angle);
    final double y = radius * sin(angle);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double effectiveX = x * _controller.value;
        final double effectiveY = y * _controller.value;
        return Transform.translate(
          offset: Offset(effectiveX, -effectiveY),
          child: GestureDetector(
            onTap: () {
              // 1. Tutup menu (tanpa menunggu, agar cepat)
              _controller.reverse();
              // 2. Eksekusi navigasi secara instan (Synchronous)
              if (navigatorKey.currentState != null) {
                navigatorKey.currentState!.popUntil((route) => route.isFirst);
                navigatorKey.currentState!.pushNamed(routeName);
              }
            },
            child: Container(
              // Menggantikan tampilan mini FAB
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sudut disesuaikan untuk tampil ke Kanan Atas, Atas, dan Kiri Atas
    const double angleMap = pi / 4;
    const double angleAdd = pi / 2;
    const double angleHome = 3 * pi / 4;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        _buildButton(angleMap, Icons.map, MapScreen.routeName),
        _buildButton(angleAdd, Icons.add_location_alt, AddEditScreen.routeName),
        _buildButton(angleHome, Icons.home, HomeScreen.routeName),
        // Tombol Tengah Utama (GANTI FAB menjadi GestureDetector)
        GestureDetector(
          onTap: () {
            _controller.isDismissed
                ? _controller.forward()
                : _controller.reverse();
          },
          child: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _controller,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
