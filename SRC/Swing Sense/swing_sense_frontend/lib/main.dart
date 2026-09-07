import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'state/auth_provider.dart';
import 'state/feed_provider.dart';
import 'state/goals_provider.dart';

void main() {
  runApp(const SwingSenseApp());
}

class SwingSenseApp extends StatelessWidget {
  const SwingSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => GoalsProvider()),
      ],
      child: MaterialApp(
        title: 'Swing Sense',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
