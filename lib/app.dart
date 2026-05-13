import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/core/theme/app_theme.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:ssh_client/ui/pages/home_page.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);

    return MaterialApp(
      title: 'SSH Client',
      debugShowCheckedModeBanner: false,
      theme: themeType.lightTheme,
      darkTheme: themeType.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
