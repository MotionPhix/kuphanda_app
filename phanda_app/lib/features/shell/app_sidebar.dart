import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/navigation.dart';
import '../../core/widgets/common.dart';
import '../notifications/notifications_screen.dart';
import 'app_sidebar_account.dart';

/// The persistent left navigation on tablets and desktops.
///
/// A bare [NavigationRail] left the window looking like a phone held sideways:
/// five loose icons under the wordmark with nothing else in the column. This is
/// the shape a desktop app is expected to have — one primary action at the top,
/// destinations grouped under quiet section labels, and the signed-in account
/// pinned to the bottom with its own menu.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.index,
    required this.onSelect,
    this.collapsed = false,
  });

  /// Index into [_destinations].
  final int index;
  final ValueChanged<int> onSelect;

  /// Icon-only rail for the medium (tablet, split-screen) width.
  final bool collapsed;

  static const double expandedWidth = 252;
  static const double collapsedWidth = 76;

  static const _destinations = <SidebarDestination>[
    SidebarDestination('Home', Icons.home_outlined, Icons.home_rounded),
    SidebarDestination(
      'Library',
      Icons.local_library_outlined,
      Icons.local_library_rounded,
    ),
    SidebarDestination(
      'Files',
      Icons.folder_copy_outlined,
      Icons.folder_copy_rounded,
    ),
    SidebarDestination('Classes', Icons.groups_outlined, Icons.groups_rounded),
    SidebarDestination(
      'Progress',
      Icons.insights_outlined,
      Icons.insights_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final name = state.profile.name.trim().isNotEmpty
        ? state.profile.name.trim()
        : (state.accountName ?? 'Your account');
    // School accounts sign in with a code, not an email, so the second line
    // falls back to the school rather than leaving a blank row under the name.
    final storedEmail = (state.accountEmail ?? '').trim();
    final email = storedEmail.isNotEmpty
        ? storedEmail
        : (state.profile.school.trim().isNotEmpty
              ? state.profile.school.trim()
              : 'Signed in');

    return Container(
      width: collapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            collapsed ? 10 : 14,
            14,
            collapsed ? 10 : 14,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brand(context, collapsed),
              const SizedBox(height: 18),
              _primaryAction(context, collapsed),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (!collapsed) ...[
                      const _SectionLabel('Study'),
                      const SizedBox(height: 6),
                    ],
                    for (var i = 0; i < _destinations.length; i++)
                      _NavItem(
                        destination: _destinations[i],
                        selected: i == index,
                        collapsed: collapsed,
                        onTap: () => onSelect(i),
                      ),
                    const SizedBox(height: 18),
                    if (!collapsed) ...[
                      const _SectionLabel('Account'),
                      const SizedBox(height: 6),
                    ],
                    _NavItem(
                      destination: const SidebarDestination(
                        'Profile',
                        Icons.person_outline_rounded,
                        Icons.person_rounded,
                      ),
                      selected: false,
                      collapsed: collapsed,
                      onTap: () => openProfile(context),
                    ),
                    _NavItem(
                      destination: const SidebarDestination(
                        'Subscription',
                        Icons.credit_card_outlined,
                        Icons.credit_card_rounded,
                      ),
                      selected: false,
                      collapsed: collapsed,
                      onTap: () => openSubscription(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.7)),
              const SizedBox(height: 6),
              if (collapsed)
                Center(
                  child: Tooltip(
                    message: '$name\n$email',
                    child: InkWell(
                      onTap: () => openProfile(context),
                      borderRadius: BorderRadius.circular(20),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primary.withValues(alpha: 0.12),
                        child: Text(
                          state.profile.initials,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                AccountChip(
                  name: name,
                  email: email,
                  initials: state.profile.initials,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand(BuildContext context, bool collapsed) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Two lines, the way a desktop product signs its window: the name carries
    // the weight, the line under it says what the product is.
    final wordmark = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Kuphanda',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            fontSize: 15.5,
          ),
        ),
        Text(
          'School library',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return collapsed
        ? const Center(child: BrandMark(size: 36))
        : Row(
            children: [
              const BrandMark(size: 36),
              const SizedBox(width: 10),
              Expanded(child: wordmark),
            ],
          );
  }

  /// The one thing a learner opens the app to do, plus the inbox beside it.
  Widget _primaryAction(BuildContext context, bool collapsed) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final search = collapsed
        ? Tooltip(
            message: 'Find a paper',
            child: IconButton.filled(
              onPressed: () => onSelect(1),
              icon: const Icon(Icons.search_rounded, size: 20),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          )
        : Expanded(
            child: FilledButton.icon(
              onPressed: () => onSelect(1),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Find a paper'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );

    final inbox = Tooltip(
      message: 'Updates',
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        ),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: collapsed ? 44 : 42,
          height: collapsed ? 44 : 42,
          margin: EdgeInsets.only(top: collapsed ? 8 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (collapsed) {
      return Column(children: [search, inbox]);
    }

    return Row(children: [search, const SizedBox(width: 8), inbox]);
  }
}

class SidebarDestination {
  const SidebarDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final SidebarDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;

    final body = Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.11)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: 19,
            color: foreground,
          ),
          if (!collapsed) ...[
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        hoverColor: scheme.primary.withValues(alpha: 0.06),
        child: body,
      ),
    );

    if (!collapsed) return tappable;
    return Tooltip(message: destination.label, child: tappable);
  }
}
