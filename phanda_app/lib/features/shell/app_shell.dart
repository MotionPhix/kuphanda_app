import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../classes/classes_screen.dart';
import '../documents/my_documents_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../progress/progress_screen.dart';
import 'app_sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);

    final screens = <Widget>[
      HomeScreen(onNavigate: _goTo, onOpenProfile: () => openProfile(context)),
      const LibraryScreen(),
      const MyDocumentsScreen(),
      const ClassesScreen(),
      ProgressScreen(onOpenProfile: () => openProfile(context)),
    ];

    final content = IndexedStack(index: _index, children: screens);

    if (size == ScreenSize.compact) {
      return Scaffold(
        body: SafeArea(bottom: false, child: content),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_library_outlined),
              selectedIcon: Icon(Icons.local_library_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_copy_outlined),
              selectedIcon: Icon(Icons.folder_copy_rounded),
              label: 'Files',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Classes',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Progress',
            ),
          ],
        ),
      );
    }

    // Tablet and desktop: one grouped sidebar instead of a stretched phone rail.
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AppSidebar(
              index: _index,
              onSelect: _goTo,
              collapsed: size != ScreenSize.expanded,
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
