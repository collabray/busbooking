import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';
import 'screens/manifest_screen.dart';
import 'screens/sync_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConductorApp());
}

class ConductorApp extends StatelessWidget {
  const ConductorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniBus Conductor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5A7B)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D5A7B),
          foregroundColor: Colors.white,
        ),
      ),
      home: const ConductorHomeScreen(),
    );
  }
}

class ConductorHomeScreen extends StatefulWidget {
  const ConductorHomeScreen({super.key});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen> {
  int _index = 0;
  final _screens = const [ScanScreen(), ManifestScreen(), SyncScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Manifest'),
          NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
        ],
      ),
    );
  }
}
