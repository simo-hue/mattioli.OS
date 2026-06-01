import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/shell/presentation/desktop_shell.dart';
import 'package:flutter/material.dart';

class EvolveDesktopApp extends StatelessWidget {
  const EvolveDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evolve Desktop',
      debugShowCheckedModeBanner: false,
      theme: EvolveTheme.dark(),
      home: const DesktopShell(),
    );
  }
}
