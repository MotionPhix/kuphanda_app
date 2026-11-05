import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/models/profile.dart';
import '../classes/classes_screen.dart';
import '../documents/my_documents_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../progress/progress_screen.dart';
import '../teacher/teacher_home_screen.dart';
import 'app_sidebar.dart';

/// One destination in the shell: the screen, its label and the group it sits in.
class _Destination {
  const _Destination(
    this.label,
    this.section,
    this.icon,
    this.selectedIcon,
    this.screen,
  );

  final String label;
  final String section;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goTo(int index) {
    if (index == _index || index < 0) return;
    setState(() => _index = index);
  }

  /// Learners and teachers open the same app to do different jobs. The learner
  /// reads; the teacher runs classes. Their shells lead with that, and neither
  /// is shown the other's screens.
  List<_Destination> _destinationsFor(Profile profile) {
    final isTeacher = profile.role == StudentRole.teacher;

    if (isTeacher) {
      return [
        _Destination(
          'Home',
          'Teaching',
          Icons.home_outlined,
          Icons.home_rounded,
          TeacherHomeScreen(onNavigate: _goTo),
        ),
        _Destination(
          'Classes',
          'Teaching',
          Icons.groups_outlined,
          Icons.groups_rounded,
          const ClassesScreen(),
        ),
        _Destination(
          'Library',
          'Library',
          Icons.local_library_outlined,
          Icons.local_library_rounded,
          const LibraryScreen(),
        ),
        _Destination(
          'Files',
          'Library',
          Icons.folder_copy_outlined,
          Icons.folder_copy_rounded,
          const MyDocumentsScreen(),
        ),
      ];
    }

    return [
      _Destination(
        'Home',
        'Study',
        Icons.home_outlined,
        Icons.home_rounded,
        HomeScreen(
          onNavigate: _goTo,
          onOpenProfile: () => openProfile(context),
        ),
      ),
      _Destination(
        'Library',
        'Study',
        Icons.local_library_outlined,
        Icons.local_library_rounded,
        const LibraryScreen(),
      ),
      _Destination(
        'Files',
        'Study',
        Icons.folder_copy_outlined,
        Icons.folder_copy_rounded,
        const MyDocumentsScreen(),
      ),
      _Destination(
        'Classes',
        'Study',
        Icons.groups_outlined,
        Icons.groups_rounded,
        const ClassesScreen(),
      ),
      _Destination(
        'Progress',
        'Study',
        Icons.insights_outlined,
        Icons.insights_rounded,
        ProgressScreen(onOpenProfile: () => openProfile(context)),
      ),
    ];
  }

  List<SidebarSection> _sectionsFor(List<_Destination> destinations) {
    final grouped = <String, List<SidebarDestination>>{};
    for (var i = 0; i < destinations.length; i++) {
      final destination = destinations[i];
      grouped
          .putIfAbsent(destination.section, () => [])
          .add(
            SidebarDestination(
              destination.label,
              destination.icon,
              destination.selectedIcon,
              index: i,
            ),
          );
    }
    return [
      for (final entry in grouped.entries)
        SidebarSection(entry.key, entry.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final profile = AppScope.of(context).profile;
    final destinations = _destinationsFor(profile);

    // A role change — or signing in as the other side of the classroom — must
    // not leave the shell pointing past the end of a shorter list.
    final index = _index.clamp(0, destinations.length - 1);

    final content = IndexedStack(
      index: index,
      children: [for (final destination in destinations) destination.screen],
    );

    if (size == ScreenSize.compact) {
      return Scaffold(
        body: SafeArea(bottom: false, child: content),
        // The five destinations share 72dp each. At 1.3x text "Progress" broke
        // across two lines and spilled out of the bar, so the chrome is clamped
        // while the content keeps the reader's full text size.
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _goTo,
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        ),
      );
    }

    // Tablet and desktop: one grouped sidebar instead of a stretched phone rail.
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AppSidebar(
              index: index,
              onSelect: _goTo,
              collapsed: size != ScreenSize.expanded,
              sections: _sectionsFor(destinations),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
