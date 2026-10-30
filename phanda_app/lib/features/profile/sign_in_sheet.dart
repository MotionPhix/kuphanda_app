import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../data/auth/google_sign_in_service.dart';
import '../../state/app_state.dart';

/// Signing in on a phone that already has a profile — a teacher on a school
/// handset, or someone checking a second account.
///
/// The app could only reach Google before, which is one identity per device and
/// no way to be anyone else. Email and password are the account the school
/// issues, and the pair the teacher needs to set reading.
Future<void> showSignInSheet(BuildContext context, AppState state) async {
  // Captured before the sheet opens: the page that asked for it can be gone by
  // the time the sign-in lands, and the message still has somewhere to go.
  final messenger = ScaffoldMessenger.maybeOf(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      // The sheet's box stays where it is when the keyboard opens, so the form
      // has to reserve the inset itself or the fields land behind the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _SignInSheet(state: state, messenger: messenger),
    ),
  );
}

/// The sheet's own state object, so the text controllers are disposed when the
/// sheet is actually gone.
///
/// Creating them beside the `showModalBottomSheet` call and disposing after it
/// returns was disposing them while the sheet was still animating out: the
/// fields went on using a dead controller, and the framework answered with a
/// failed assertion instead of a closed sheet.
class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.state, required this.messenger});

  final AppState state;
  final ScaffoldMessengerState? messenger;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _say(String message) {
    final messenger = widget.messenger;
    if (messenger == null || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter the email and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.state.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.pop(context);
      _say('Signed in as ${widget.state.accountEmail ?? _email.text.trim()}.');
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not sign in: $failure';
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final token = await GoogleSignInService().idToken();
      await widget.state.signInWithGoogle(token);
      if (mounted) Navigator.pop(context);
      _say('Signed in with Google.');
    } catch (failure) {
      if (!mounted) return;
      setState(() => _error = 'Could not sign in with Google: $failure');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SheetBody(
      title: 'Sign in',
      subtitle: 'Use the email and password for the account you want.',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : _signIn,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sign in'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _email,
            // No autofocus: it throws the keyboard up over a four-field form
            // and hands the screen to Android's autofill chooser before the
            // learner has read the sheet.
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          // Google stays available: it is how a learner signs in without an
          // email account at all.
          TextButton.icon(
            onPressed: _busy ? null : _signInWithGoogle,
            icon: const Icon(Icons.account_circle_outlined, size: 18),
            label: const Text('Use Google instead'),
          ),
        ],
      ),
    );
  }
}
