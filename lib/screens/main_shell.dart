
import 'package:flutter/material.dart';

import '../services/auth_guard.dart';
import 'home_page.dart';
import 'community_page.dart';
import 'profile_page.dart';
import 'marketplace_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  late final List<Widget> pages = [
    const HomePage(),
    const MarketplacePage(),
    const CommunityPage(),
    ProfilePage(
      onLogout: _goToHome,
    ),
  ];

  void _goToHome() {
    if (!mounted) return;

    setState(() {
      index = 0;
    });
  }

  Future<void> _onDestinationSelected(int i) async {
    // Home ও Marketplace সবার জন্য উন্মুক্ত
    if (i == 0 || i == 1) {
      setState(() => index = i);
      return;
    }

    // অন্য পেজে প্রবেশের আগে Login যাচাই
    final authenticated =
        await AuthGuard.ensureAuthenticated(context);

    if (!mounted || !authenticated) return;

    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          height: 70,
          selectedIndex: index,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFFFE0D8),
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'হোম',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'মার্কেট',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'কমিউনিটি',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'প্রোফাইল',
            ),
          ],
        ),
      );
}
