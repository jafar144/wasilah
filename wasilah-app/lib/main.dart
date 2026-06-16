import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';

void main() => runApp(const WasilahApp());

const _seed = Color(0xFF00695C);

class WasilahApp extends StatelessWidget {
  const WasilahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Wasilah',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.notoSansTextTheme(base.textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HomeScreen(),
    );
  }
}
