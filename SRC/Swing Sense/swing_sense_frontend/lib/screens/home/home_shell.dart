import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../explore/explore_screen.dart';
import '../goals/goals_screen.dart';
import '../profile/profile_screen.dart';
import '../session/session_setup_screen.dart';
import 'feed_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    FeedScreen(),
    ExploreScreen(),
    SizedBox.shrink(),
    GoalsScreen(),
    ProfileScreen(),
  ];

  void _openSessionSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SessionSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          if (i == 2) {
            _openSessionSetup();
            return;
          }
          setState(() => _index = i);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Feed'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Explorar'),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(gradient: AppColors.greenGradient, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.black),
            ),
            label: 'Treinar',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), activeIcon: Icon(Icons.flag), label: 'Metas'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
