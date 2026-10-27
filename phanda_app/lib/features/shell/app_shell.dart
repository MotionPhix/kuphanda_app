import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../classes/classes_screen.dart';
import '../documents/my_documents_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../progress/progress_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home_rounded),
    _Destination('Library', Icons.local_library_outlined, Icons.local_library_rounded),
    _Destination('Documents', Icons.folder_copy_outlined, Icons.folder_copy_rounded),
    _Destination('Classes', Icons.groups_outlined, Icons.groups_rounded),
    _Destination('Progress', Icons.insights_outlined, Icons.insights_rounded),
  ];

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final state = AppScope.of(context);

    final screens = <Widget>[
      HomeScreen(
        onNavigate: _goTo,
        onOpenProfile: () => openProfile(context),
      ),
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
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: size == ScreenSize.expanded,
              minExtendedWidth: 208,
              selectedIndex: _index,
              onDestinationSelected: _goTo,
              groupAlignment: -0.86,
              leading: Padding(
                padding: EdgeInsets.fromLTRB(size == ScreenSize.expanded ? 20 : 0, 12, 0, 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 40),
                    if (size == ScreenSize.expanded) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Kuphanda',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      onPressed: () => openProfile(context),
                      tooltip: 'Profile',
                      icon: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.green.withValues(alpha: 0.12),
                        child: Text(
                          state.profile.initials,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.green,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
