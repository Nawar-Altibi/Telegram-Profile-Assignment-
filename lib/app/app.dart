import 'package:flutter/material.dart';

import '../core/constants/theme/app_theme.dart';
import '../features/shell/presentation/screens/app_shell.dart';

/// Root widget: applies the dark Telegram theme and opens the [AppShell].
class TelegramProfileApp extends StatelessWidget {
  const TelegramProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram Profile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
