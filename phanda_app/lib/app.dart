import 'dart:ui' show PointerDeviceKind;

import 'dart:async';

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

class KuphandaApp extends StatefulWidget {
  const KuphandaApp({super.key, required this.state});

  final AppState state;

  @override
  State<KuphandaApp> createState() => _KuphandaAppState();
}

class _KuphandaAppState extends State<KuphandaApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late bool _wasSignedIn = widget.state.isSignedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Crossing the sign-in line has to close whatever was pushed on the other
  /// side — Profile, a paper, a class — or signing out leaves the previous
  /// person's screen staring back at them. It pops back to the root rather than
  /// rebuilding the whole navigator: a rebuild would also throw away the
  /// onboarding step the learner is standing on the moment they sign in.
  void _onSessionChanged() {
    final signedIn = widget.state.isSignedIn;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Returning from the browser checkout: confirm a pending payment if one
      // is stored, without blocking the UI.
      unawaited(widget.state.resumePendingPayment());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final profile = state.profile;
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Kuphanda',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: profile.theme.themeMode,
            scrollBehavior: const _AppScrollBehavior(),
            // Two conditions, not one: a finished profile on a signed-out
            // phone would otherwise leave the library open to whoever picks
            // it up. Logging out ends the session and returns here.
            home: state.isSignedIn && profile.onboardingComplete
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
