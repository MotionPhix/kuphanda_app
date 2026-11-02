import 'package:flutter/material.dart';

import '../../app.dart';
import '../profile/sign_in_sheet.dart';
import '../../core/theme.dart';
import '../../data/api/api_models.dart';
import '../../data/auth/google_sign_in_service.dart';
import '../../core/widgets/common.dart';
import '../../data/models/profile.dart';
import '../../data/models/subject.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _schoolController = TextEditingController();
  final _subjects = <String>{};
  int _step = 0;
  int _form = 4;
  int _examYear = DateTime.now().year + 1;
  StudentRole _role = StudentRole.student;
  String? _nameError;
  bool _googleBusy = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subjects.addAll(subjectsForForm(4).take(4).map((subject) => subject.id));
  }

  /// Set once the learner types in the name fields, so their words are never
  /// overwritten by a profile that arrives a moment later.
  bool _detailsEdited = false;

  /// The gate is reached once per ended session, not on every rebuild.
  bool _jumpedToGate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Whoever signs in — the gate, Google, or a test driving the state — the
    // details step opens on their own name rather than an empty form. The
    // account's name can arrive a moment after the session does, so this keeps
    // offering until the form has been touched.
    final app = AppScope.of(context);
    if (app.isSignedIn && !_detailsEdited) _adoptAccount();

    // A session that ended mid-use needs the way back in, not the tour: open on
    // the gate, where the reason is written.
    if (!_jumpedToGate && !app.isSignedIn && app.sessionEndedReason != null) {
      _jumpedToGate = true;
      _step = 1;
    }
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _useGoogle() async {
    setState(() => _googleBusy = true);
    final state = AppScope.read(context);
    try {
      final token = await GoogleSignInService().idToken();
      await state.signInWithGoogle(token, sync: false);
      final profile = state.profile;
      _firstController.text = profile.firstName == 'learner' ? '' : profile.firstName;
      _lastController.text = profile.lastName;
      if (mounted) {
        setState(() => _nameError = null);
        showSnack(context, 'Google account connected. Check your name, then continue.');
      }
    } on ApiException catch (error) {
      if (mounted) showSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
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

  /// Fills the details step from the account that just signed in, so a learner
  /// sees their own name and school instead of an empty form. Anything they
  /// have already typed wins.
  void _adoptAccount() {
    final profile = AppScope.read(context).profile;
    final first = profile.firstName;
    if (_firstController.text.trim().isEmpty &&
        first.isNotEmpty &&
        first != 'learner') {
      _firstController.text = first;
    }
    if (_lastController.text.trim().isEmpty && profile.lastName.isNotEmpty) {
      _lastController.text = profile.lastName;
    }
    if (_schoolController.text.trim().isEmpty && profile.school.isNotEmpty) {
      _schoolController.text = profile.school;
    }
  }

  void _next() {
    if (!AppScope.read(context).isSignedIn) return;
    if (_step == 1 &&
        (_firstController.text.trim().isEmpty || _lastController.text.trim().isEmpty)) {
      setState(() => _nameError = 'Add both your first and last name.');
      return;
    }
    setState(() {
      _nameError = null;
      _step = (_step + 1).clamp(0, 2);
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    if (_firstController.text.trim().isEmpty ||
        _lastController.text.trim().isEmpty) {
      setState(() {
        _step = 1;
        _nameError = 'Add both your first and last name.';
      });
      return;
    }

    setState(() => _saving = true);
    final state = AppScope.read(context);
    await state.completeOnboarding(
      name: [_firstController.text.trim(), _lastController.text.trim()]
          .where((part) => part.isNotEmpty)
          .join(' '),
      givenName: _firstController.text,
      familyName: _lastController.text,
      school: _schoolController.text,
      form: _form,
      examYear: _examYear,
      role: _role,
      subjectIds: _subjects.toList(),
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
                    // Top-aligned, so the short sign-in step starts where the
                    // longer forms do instead of floating in the middle of the
                    // screen.
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: switch (_step) {
                      0 => _WelcomeStep(onStart: () => setState(() => _step = 1)),
                      // The step after Get started is the account, not the
                      // form: nothing the learner types here is worth keeping
                      // until there is someone to keep it for.
                      1 => AppScope.of(context).isSignedIn
                          ? _buildDetails(theme)
                          : _buildSignInGate(theme),
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

  /// The account comes before the details: a name typed into a phone nobody is
  /// signed in on cannot be attached to anyone, and a second phone would never
  /// find that learner again.
  Widget _buildSignInGate(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('gate'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in to continue', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Your papers, classes and progress belong to your account. Use the '
            'email your school gave you, or continue with Google.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // A session that ended without the learner asking is worth a line of
          // explanation: otherwise the app appears to have thrown them out.
          if (AppScope.of(context).sessionEndedReason != null) ...[
            const SizedBox(height: 16),
            AppCard(
              color: AppColors.sun.withValues(alpha: 0.12),
              borderColor: AppColors.sun.withValues(alpha: 0.4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppScope.of(context).sessionEndedReason!,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _googleBusy ? null : _signInWithEmail,
            child: const Text('Sign in with email'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _googleBusy ? null : _useGoogle,
            icon: _googleBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('G', style: TextStyle(fontWeight: FontWeight.w700)),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 20),
          Text(
            'Next you will add your name, school and form.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithEmail() async {
    await showSignInSheet(context, AppScope.read(context));
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
          Text('Who should we call you?', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Use the name you want your teachers and classmates to see. '
            'You can edit it later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // The account is already behind this form, so the line says whose
          // details these are rather than offering another way in.
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Signed in as ${AppScope.of(context).accountEmail ?? 'your account'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _firstController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    _detailsEdited = true;
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'First name',
                    hintText: 'Chisomo',
                    errorText: _nameError,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lastController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    _detailsEdited = true;
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    hintText: 'Banda',
                  ),
                ),
              ),
            ],
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
                          'A connection is needed to browse and subscribe. Documents you '
                          'download stay readable when you are offline.',
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
          // The SafeArea around the body has already reserved the system bar,
          // and this context sits above it, so reading paddingOf() here measured
          // the raw inset and reserved it a second time — a dead band of ~48 dp
          // under the button.
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
          // The payment line is a footnote, not part of the button: without a
          // gap of its own it sat against the button's lower edge.
          const SizedBox(height: 18),
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



