import 'package:flutter/material.dart';

import 'document.dart';
import 'subject.dart';

enum StudentRole {
  student('Student', 'I am studying for my exams'),
  teacher('Teacher', 'I teach classes and set reading');

  const StudentRole(this.label, this.description);

  final String label;
  final String description;
}

enum LibraryPlan {
  free('Free', 0, 'Browse free documents'),
  school('School licence', 4, 'Provided by your school');

  const LibraryPlan(this.label, this.rank, this.description);

  final String label;
  final int rank;
  final String description;

  /// A plan covers a document when its rank reaches the document's tier.
  bool covers(AccessTier tier) => rank >= tier.rank;
}

enum AppThemePreference {
  system('Auto', Icons.brightness_auto_outlined),
  light('Light', Icons.light_mode_outlined),
  dark('Dark', Icons.dark_mode_outlined);

  const AppThemePreference(this.label, this.icon);

  final String label;
  final IconData icon;

  ThemeMode get themeMode => switch (this) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };
}

/// The local learner profile. Kuphanda required an account for everything;
/// this app is intentionally offline-first, so the profile is device-local and
/// there is no login wall between a student and a past paper.
class Profile {
  const Profile({
    this.name = '',
    this.school = '',
    this.form = 4,
    this.examYear = 2027,
    this.role = StudentRole.student,
    this.subjectIds = const <String>[],
    this.plan = LibraryPlan.free,
    this.weeklyGoalMinutes = 300,
    this.theme = AppThemePreference.system,
    this.onboardingComplete = false,
  });

  final String name;
  final String school;
  final int form;
  final int examYear;
  final StudentRole role;
  final List<String> subjectIds;
  final LibraryPlan plan;
  final int weeklyGoalMinutes;
  final AppThemePreference theme;
  final bool onboardingComplete;

  String get examTarget => Subject.qualificationForForm(form);

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'learner';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'K';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  List<Subject> get subjects {
    final ids = subjectIds.isEmpty ? subjectsForForm(form).map((s) => s.id) : subjectIds;
    return ids.map(subjectById).toList(growable: false);
  }

  Profile copyWith({
    String? name,
    String? school,
    int? form,
    int? examYear,
    StudentRole? role,
    List<String>? subjectIds,
    LibraryPlan? plan,
    int? weeklyGoalMinutes,
    AppThemePreference? theme,
    bool? onboardingComplete,
  }) {
    return Profile(
      name: name ?? this.name,
      school: school ?? this.school,
      form: form ?? this.form,
      examYear: examYear ?? this.examYear,
      role: role ?? this.role,
      subjectIds: subjectIds ?? this.subjectIds,
      plan: plan ?? this.plan,
      weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
      theme: theme ?? this.theme,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'school': school,
        'form': form,
        'examYear': examYear,
        'role': role.name,
        'subjectIds': subjectIds,
        'plan': plan.name,
        'weeklyGoalMinutes': weeklyGoalMinutes,
        'theme': theme.name,
        'onboardingComplete': onboardingComplete,
      };

  static Profile fromJson(Map<String, Object?> json) {
    return Profile(
      name: (json['name'] as String?) ?? '',
      school: (json['school'] as String?) ?? '',
      form: (json['form'] as num?)?.toInt() ?? 4,
      examYear: (json['examYear'] as num?)?.toInt() ?? DateTime.now().year + 1,
      role: StudentRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => StudentRole.student,
      ),
      subjectIds: (json['subjectIds'] as List<Object?>?)
              ?.map((id) => id.toString())
              .toList() ??
          const <String>[],
      plan: LibraryPlan.values.firstWhere(
        (plan) => plan.name == json['plan'],
        orElse: () => LibraryPlan.school,
      ),
      weeklyGoalMinutes: (json['weeklyGoalMinutes'] as num?)?.toInt() ?? 300,
      theme: AppThemePreference.values.firstWhere(
        (theme) => theme.name == json['theme'],
        orElse: () => AppThemePreference.system,
      ),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    );
  }
}

