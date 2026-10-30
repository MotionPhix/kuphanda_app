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
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  var busy = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SheetBody(
        title: 'Sign in',
        subtitle: 'Use the email and password for the account you want.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => Navigator.pop(sheetContext),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (email.text.trim().isEmpty || password.text.isEmpty) {
                        setSheetState(() => error = 'Enter the email and password.');
                        return;
                      }

                      setSheetState(() {
                        busy = true;
                        error = null;
                      });

                      try {
                        await state.signIn(
                          email: email.text.trim(),
                          password: password.text,
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) {
                          showSnack(context, 'Signed in as ${state.accountEmail ?? email.text.trim()}.');
                        }
                      } on ApiException catch (failure) {
                        setSheetState(() {
                          busy = false;
                          error = failure.message;
                        });
                      } catch (failure) {
                        setSheetState(() {
                          busy = false;
                          error = 'Could not sign in: $failure';
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign in'),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              onSubmitted: (_) => FocusScope.of(sheetContext).unfocus(),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            // Google stays available: it is how a learner signs in without an
            // email account at all.
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        final token = await GoogleSignInService().idToken();
                        await state.signInWithGoogle(token);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) showSnack(context, 'Signed in with Google.');
                      } catch (failure) {
                        setSheetState(() => error = 'Could not sign in with Google: $failure');
                      }
                    },
              icon: const Icon(Icons.account_circle_outlined, size: 18),
              label: const Text('Use Google instead'),
            ),
          ],
        ),
      ),
    ),
  );

  email.dispose();
  password.dispose();
}
