// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/destination_provider.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/add_edit/add_edit_screen.dart';
import 'ui/screens/map/map_screen.dart';

import 'data/models/destination.dart';
import 'ui/widgets/radial_menu.dart'; // Wajib diimport untuk GlobalKey

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

      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // 2. Tentukan Halaman Awal
      initialRoute: HomeScreen.routeName,
      // 3. Definisikan routes menggunakan onGenerateRoute (Wajib)
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case HomeScreen.routeName:
            // Kita membungkus HomeScreen dengan Scaffold agar RadialMenu bisa terlihat
            return MaterialPageRoute(
              builder: (context) =>
                  const RootScaffoldWrapper(child: HomeScreen()),
            );
          case MapScreen.routeName:
            return MaterialPageRoute(
              builder: (context) =>
                  const RootScaffoldWrapper(child: MapScreen()),
            );
          case AddEditScreen.routeName:
            final args = settings.arguments;
            final destinationToEdit = args is Destination ? args : null;
            return MaterialPageRoute(
              builder: (context) => RootScaffoldWrapper(
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
  const RootScaffoldWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Halaman utama (Home, Map, AddEdit)
      body: child,

      // Radial Menu diletakkan di FloatingActionButton
      floatingActionButton: const RadialMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
