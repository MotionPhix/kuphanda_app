import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/profile.dart';
import '../../data/models/subject.dart';
import '../../state/app_state.dart';
import 'sign_in_sheet.dart';
import '../billing/subscription_screen.dart';
import '../staff/staff_library_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final profile = state.profile;
    final stats = state.stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        // The list runs to the edge of the phone, so its last card has to clear
        // the navigation bar itself: without this the About paragraphs sat under
        // the system bar and could not be read. viewPadding rather than padding,
        // because the inset belongs to the device and must not come and go with
        // the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          ResponsivePage(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        profile.initials,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name.isEmpty ? 'Your profile' : profile.name,
                            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
                          ),
                          if (profile.school.isNotEmpty)
                            Text(
                              profile.school,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // The exam target is implied by the form number:
                              // spelling both out pushed the pill past the
                              // column and off the screen.
                              Pill(
                                label: 'Form ${profile.form} · ${profile.examYear}',
                                compact: true,
                              ),
                              Pill(
                                label: profile.role.label,
                                color: AppColors.sun,
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => showEditProfile(context, state),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Streak',
                        value: plural(stats.currentStreak, 'day'),
                        icon: Icons.local_fire_department_outlined,
                        tint: const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'This week',
                        value: formatMinutes(stats.weekMinutes),
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Account', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileItem(
                        icon: state.isSignedIn
                            ? Icons.verified_user_outlined
                            : Icons.person_outline_rounded,
                        title: state.isSignedIn ? 'Signed in' : 'Not signed in',
                        // Signing out used to be a one-way door: the library
                        // stays usable offline, but nothing offered a way back
                        // to Google. The row is that way back.
                        subtitle: state.isSignedIn
                            ? '${state.accountName ?? profile.name} · ${state.accountEmail ?? ''}'
                            : 'Tap to sign in and sync your progress',
                        onTap: state.isSignedIn
                            ? () => _confirmSignOut(context, state)
                            : () => showSignInSheet(context, state),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('Your library', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileItem(
                        icon: Icons.card_membership_outlined,
                        title: 'Subscription & access',
                        subtitle: state.isSignedIn
                            ? '${state.entitlementTier.label} · ${state.accountEmail ?? ''}'
                            : 'Sign in to subscribe or buy documents',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        ),
                      ),
                      if (state.isStaff) ...[
                        const Divider(height: 1),
                        _ProfileItem(
                          icon: Icons.upload_file_outlined,
                          title: 'Staff tools',
                          subtitle: 'Publish versions and withdraw documents',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const StaffLibraryScreen(),
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 1),
                      _ProfileItem(
                        icon: Icons.menu_book_outlined,
                        title: 'Subjects',
                        subtitle: profile.subjects.map((subject) => subject.shortName).join(', '),
                        onTap: () => showEditProfile(context, state),
                      ),
                      const Divider(height: 1),
                      _ProfileItem(
                        icon: Icons.flag_outlined,
                        title: 'Exam year',
                        subtitle: '${profile.examTarget} in ${profile.examYear}',
                        onTap: () => showEditProfile(context, state),
                      ),
                      const Divider(height: 1),
                      _ProfileItem(
                        icon: Icons.timer_outlined,
                        title: 'Weekly study goal',
                        subtitle: formatMinutes(profile.weeklyGoalMinutes),
                        onTap: () => showEditProfile(context, state),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('Preferences', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appearance', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      SegmentedButton<AppThemePreference>(
                        showSelectedIcon: false,
                        segments: [
                          for (final preference in AppThemePreference.values)
                            ButtonSegment(
                              value: preference,
                              icon: Icon(preference.icon, size: 16),
                              label: Text(preference.label),
                            ),
                        ],
                        selected: <AppThemePreference>{profile.theme},
                        onSelectionChanged: (selection) =>
                            state.setTheme(selection.first),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your role is set during setup. Students join classes; teachers '
                        'create them.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('Data on this phone', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ProfileItem(
                        icon: Icons.sd_storage_outlined,
                        title: 'Storage used',
                        subtitle:
                            '${state.importedFileCount} ${state.importedFileCount == 1 ? 'file' : 'files'} · ${formatBytes(state.storageBytes)}',
                        onTap: null,
                      ),
                      const Divider(height: 1),
                      _ProfileItem(
                        icon: Icons.restart_alt_rounded,
                        title: 'Reset app data',
                        subtitle: 'Remove downloads, progress, notes and classes',
                        destructive: true,
                        onTap: () async {
                          final confirmed = await confirmAction(
                            context,
                            title: 'Reset Kuphanda?',
                            message: 'This deletes every imported PDF, your reading progress, '
                                'bookmarks, notes and classes from this phone. The bundled '
                                'catalogue stays.',
                            confirmLabel: 'Reset everything',
                          );
                          if (confirmed) {
                            await state.resetEverything();
                            if (context.mounted) showSnack(context, 'App reset.');
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('About', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const BrandMark(size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kuphanda', style: theme.textTheme.titleSmall),
                                Text(
                                  'Version 1.0.0 · online library',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Kuphanda is a subscription reading platform for Malawian secondary '
                        'schools, covering Forms 1–4 and the JCE and MSCE examinations. '
                        'Browse online, subscribe with PayChangu, and download entitled '
                        'documents for offline reading.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'The catalogue and its PDFs are supplied by the library team. Files '
                        'you import stay on this phone and are not uploaded. Past papers and '
                        'textbooks remain the property of MANEB and their publishers.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, AppState state) async {
  final sure = await confirmAction(
    context,
    title: 'Sign out?',
    // What signing out actually does: the downloads stay, the reading itself —
    // progress, classes, notes — belongs to the account and is cleared, so the
    // next person to pick up the phone starts from nothing.
    message: 'Downloaded papers stay on this phone, but the reading progress, '
        'classes and notes on it are cleared. You can sign in again from here '
        'whenever you want.',
    confirmLabel: 'Sign out',
    destructive: true,
  );
  if (sure != true || !context.mounted) return;

  await state.signOut();
  if (context.mounted) showSnack(context, 'Signed out. Your papers are still here.');
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        size: 20,
        color: destructive ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: destructive ? theme.colorScheme.error : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, size: 18),
    );
  }
}

Future<void> showEditProfile(BuildContext context, AppState state) async {
  final profile = state.profile;
  final firstController = TextEditingController(
    text: profile.firstName == 'learner' ? '' : profile.firstName,
  );
  final lastController = TextEditingController(text: profile.lastName);
  final schoolController = TextEditingController(text: profile.school);
  var form = profile.form;
  var examYear = profile.examYear;
  var weeklyGoal = profile.weeklyGoalMinutes;
  final subjects = <String>{...profile.subjectIds};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final available = subjectsForForm(form);
          return SheetBody(
            title: 'Edit profile',
            maxHeightFactor: 0.92,
            actions: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () async {
                    final cleaned = subjects
                        .where((id) => available.any((subject) => subject.id == id))
                        .toList();
                    await state.updateProfile(
                      profile.copyWith(
                        givenName: firstController.text.trim(),
                        familyName: lastController.text.trim(),
                        name: [
                          firstController.text.trim(),
                          lastController.text.trim(),
                        ].where((part) => part.isNotEmpty).join(' '),
                        school: schoolController.text.trim(),
                        form: form,
                        examYear: examYear,
                        subjectIds: cleaned.isEmpty
                            ? available.take(4).map((subject) => subject.id).toList()
                            : cleaned,
                        weeklyGoalMinutes: weeklyGoal,
                      ),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'First name'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lastController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: schoolController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'School'),
                ),
                const SizedBox(height: 16),
                Text('Form', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in <int>[1, 2, 3, 4])
                      ChoiceChip(
                        label: Text('Form $option'),
                        selected: form == option,
                        onSelected: (_) => setSheetState(() {
                          form = option;
                          subjects.removeWhere(
                            (id) => !subjectsForForm(form).any((subject) => subject.id == id),
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('Exam year', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    DropdownButton<int>(
                      value: examYear,
                      items: [
                        for (var year = DateTime.now().year;
                            year <= DateTime.now().year + 6;
                            year++)
                          DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (value) {
                        if (value != null) setSheetState(() => examYear = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text('Subjects', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in available)
                      FilterChip(
                        label: Text(subject.shortName),
                        selected: subjects.contains(subject.id),
                        onSelected: (selected) => setSheetState(() {
                          if (selected) {
                            subjects.add(subject.id);
                          } else if (subjects.length > 1) {
                            subjects.remove(subject.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Weekly goal · ${formatMinutes(weeklyGoal)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: weeklyGoal.toDouble(),
                  min: 60,
                  max: 900,
                  divisions: 28,
                  label: formatMinutes(weeklyGoal),
                  onChanged: (value) => setSheetState(() => weeklyGoal = value.round()),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  firstController.dispose();
  lastController.dispose();
  schoolController.dispose();
}
