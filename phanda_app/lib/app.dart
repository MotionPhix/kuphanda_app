import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'state/app_state.dart';

/// Provides the single [AppState] to the widget tree and rebuilds dependents
/// whenever it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context');
    return scope!.notifier!;
  }

  /// Read without subscribing — for callbacks and initState.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context');
    return scope!.notifier!;
  }
}

class KuphandaApp extends StatelessWidget {
  const KuphandaApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final profile = state.profile;
          return MaterialApp(
            title: 'Kuphanda',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: profile.theme.themeMode,
            scrollBehavior: const _AppScrollBehavior(),
            home: profile.onboardingComplete
                ? const AppShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
