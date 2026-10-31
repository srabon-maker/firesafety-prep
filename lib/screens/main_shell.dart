import 'package:flutter/material.dart';

import 'home_page.dart';
import 'community_page.dart';
import 'notes_page.dart';
import 'profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  final pages = const [
    HomePage(),
    CommunityPage(),
    NotesPage(),
    ProfilePage(),
  ];

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
          onDestinationSelected: (i) {
            setState(() => index = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'হোম',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'কমিউনিটি',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'নোট',
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
