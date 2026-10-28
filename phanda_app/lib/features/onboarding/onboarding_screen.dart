import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/profile.dart';
import '../../data/models/subject.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _subjects = <String>{};
  int _step = 0;
  int _form = 4;
  int _examYear = DateTime.now().year + 1;
  StudentRole _role = StudentRole.student;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subjects.addAll(subjectsForForm(4).take(4).map((subject) => subject.id));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  void _selectForm(int form) {
    setState(() {
      _form = form;
      final available = subjectsForForm(form).map((subject) => subject.id).toSet();
      _subjects.removeWhere((id) => !available.contains(id));
      if (_subjects.isEmpty) {
        _subjects.addAll(subjectsForForm(form).take(4).map((subject) => subject.id));
      }
      if (_examYear < DateTime.now().year) {
        _examYear = DateTime.now().year + 1;
      }
    });
  }

  void _next() {
    if (_step == 1 && _nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Tell us what to call you.');
      return;
    }
    setState(() {
      _nameError = null;
      _step = (_step + 1).clamp(0, 2);
    });
  }

  Future<void> _finish({bool preview = false}) async {
    if (_saving) return;
    if (!preview && _nameController.text.trim().isEmpty) {
      setState(() {
        _step = 1;
        _nameError = 'Tell us what to call you.';
      });
      return;
    }

    setState(() => _saving = true);
    final state = AppScope.read(context);
    await state.completeOnboarding(
      name: preview ? 'Chisomo Banda' : _nameController.text,
      school: preview ? 'Bwaila Secondary School' : _schoolController.text,
      form: preview ? 4 : _form,
      examYear: preview ? DateTime.now().year + 1 : _examYear,
      role: preview ? StudentRole.student : _role,
      subjectIds: preview
          ? subjectsForForm(4).take(5).map((subject) => subject.id).toList()
          : _subjects.toList(),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                if (_step > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _step -= 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Back',
                        ),
                        const Spacer(),
                        Text(
                          'Step $_step of 2',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_step) {
                      0 => _WelcomeStep(onStart: () => setState(() => _step = 1)),
                      1 => _buildDetails(theme),
                      _ => _buildSubjects(theme),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(ThemeData theme) {
    final years = <int>[
      for (var year = DateTime.now().year; year <= DateTime.now().year + 6; year++) year,
    ];

    return SingleChildScrollView(
      key: const ValueKey('details'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Let’s set up your shelf', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Your answers stay on this phone. They decide which papers and notes '
            'appear first — you can change them later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            decoration: InputDecoration(
              labelText: 'What should we call you?',
              hintText: 'e.g. Chisomo Banda',
              errorText: _nameError,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _schoolController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'School (optional)',
              hintText: 'e.g. Bwaila Secondary School',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: 22),
          Text('Which form are you in?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final form in <int>[1, 2, 3, 4])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ChoiceCard(
                      selected: _form == form,
                      title: 'Form $form',
                      caption: form <= 2 ? 'JCE' : 'MSCE',
                      onTap: () => _selectForm(form),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exam year', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'When you sit ${Subject.qualificationForForm(_form)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButton<int>(
                value: _examYear,
                borderRadius: BorderRadius.circular(12),
                items: [
                  for (final year in years)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _examYear = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('I am a…', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SegmentedButton<StudentRole>(
            segments: const [
              ButtonSegment(
                value: StudentRole.student,
                label: Text('Student'),
                icon: Icon(Icons.school_outlined, size: 18),
              ),
              ButtonSegment(
                value: StudentRole.teacher,
                label: Text('Teacher'),
                icon: Icon(Icons.co_present_outlined, size: 18),
              ),
            ],
            selected: <StudentRole>{_role},
            onSelectionChanged: (selection) => setState(() => _role = selection.first),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _next, child: const Text('Continue')),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => _finish(preview: true),
              child: const Text('Preview with sample data'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjects(ThemeData theme) {
    final available = subjectsForForm(_form);

    return Column(
      key: const ValueKey('subjects'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick your subjects', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'We will put these first in your library and recommendations. '
                  'Choose at least two.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final subject in available)
                      FilterChip(
                        selected: _subjects.contains(subject.id),
                        showCheckmark: false,
                        avatar: Text(subject.emoji, style: const TextStyle(fontSize: 14)),
                        label: Text(subject.name),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _subjects.add(subject.id);
                            } else if (_subjects.length > 1) {
                              _subjects.remove(subject.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                AppCard(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.offline_bolt_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Kuphanda works without internet. Only the two starter '
                          'guides include a PDF — attach official papers from your '
                          'phone as you get them.',
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 16),
          child: Column(
            children: [
              FilledButton(
                onPressed: _saving ? null : () => _finish(),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Start reading · ${_subjects.length} subjects'),
              ),
              const SizedBox(height: 8),
              Text(
                'You can add more subjects whenever you like.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const BrandMark(size: 64),
          const SizedBox(height: 28),
          Text(
            'Your school library,\nin your pocket.',
            style: theme.textTheme.displaySmall?.copyWith(fontSize: 36),
          ),
          const SizedBox(height: 12),
          Text(
            'Browse past papers, notes and study guides for Forms 1–4. Subscribe '
            'for full access, then keep what you need offline.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          const _Feature(
            icon: Icons.lock_open_rounded,
            title: 'Free and premium papers',
            body: 'Free papers stay open. Subscribe or buy a single paper to unlock the rest with PayChangu.',
          ),
          const SizedBox(height: 16),
          const _Feature(
            icon: Icons.download_for_offline_outlined,
            title: 'Offline when you need it',
            body: 'Download the documents you are entitled to and keep reading when the signal drops.',
          ),
          const SizedBox(height: 16),
          const _Feature(
            icon: Icons.insights_outlined,
            title: 'Progress that means something',
            body: 'Pages read and minutes studied, not a tick box — for you and your teacher.',
          ),
          const SizedBox(height: 36),
          FilledButton(onPressed: onStart, child: const Text('Get started')),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Mobile money payments · Powered by PayChangu',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.green),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
