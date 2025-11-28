// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/destination_provider.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/add_edit/add_edit_screen.dart';
import 'ui/screens/map/map_screen.dart';

import 'data/models/destination.dart';
import 'ui/widgets/radial_menu.dart';

import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (context) {
        final provider = DestinationProvider();
        provider.loadDestinations();
        return provider;
      },
      child: const MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Wisata Lokal',

      // 1. Terapkan GlobalKey ke Root MaterialApp
      navigatorKey: navigatorKey,

      theme: AppTheme.lightTheme,

      // 2. Tentukan Halaman Awal
      initialRoute: HomeScreen.routeName,

      // 1. Wrapper untuk menginjeksi CardTheme
      builder: (context, child) {
        // Ambil tema dasar yang sudah ada
        final baseTheme = Theme.of(context);

        // Lakukan copyWith pada CardTheme yang sudah ada
        final modifiedTheme = baseTheme.copyWith(
          cardTheme: baseTheme.cardTheme.copyWith(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: AppTheme.cardWhite, // Gunakan cardWhite dari AppTheme
          ),
        );

        // Kembalikan Theme baru
        return Theme(
          data: modifiedTheme,
          child: child!, // Child adalah Navigator/onGenerateRoute
        );
      },

      // 3. Definisikan routes menggunakan onGenerateRoute (Wajib)
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case HomeScreen.routeName:
            // Kita membungkus HomeScreen dengan Scaffold agar RadialMenu bisa terlihat
            return MaterialPageRoute(
              builder: (context) => RootScaffoldWrapper(
                appBar: AppBar(
                  title: const Text('Destinasi Wisata Lokal'),
                  backgroundColor: Colors.teal,
                  automaticallyImplyLeading: false,
                ),
                child: const HomeScreen(),
              ),
            );
          case MapScreen.routeName:
            return MaterialPageRoute(
              builder: (context) => RootScaffoldWrapper(
                appBar: AppBar(
                  title: const Text('Peta Global Destinasi'),
                  backgroundColor: Colors.teal,
                ),
                child: const MapScreen(),
              ),
            );
          case AddEditScreen.routeName:
            final args = settings.arguments;
            final destinationToEdit = args is Destination ? args : null;
            return MaterialPageRoute(
              builder: (context) => RootScaffoldWrapper(
                appBar: AppBar(title: const Text('Tambah Destinasi Baru')),
                child: AddEditScreen(destinationToEdit: destinationToEdit),
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}

// Widget Wrapper untuk Scaffold Global dan Radial Menu
class RootScaffoldWrapper extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  const RootScaffoldWrapper({super.key, required this.child, this.appBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      // Halaman utama (Home, Map, AddEdit)
      body: child,

      // Radial Menu diletakkan di FloatingActionButton
      floatingActionButton: const RadialMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
