import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/phone.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../state/app_state.dart';

/// Signing in with a number and a code sent over WhatsApp.
///
/// Deliberately a second way in, not the only one: WhatsApp needs a smartphone,
/// a data connection and an approved business number, and a learner whose phone
/// is dead at 7am still has a school email. The email form and Google stay where
/// they are; this sheet is what the "Continue with phone" button opens.
///
/// One sheet covers the three cases because they differ by a single sentence and
/// one field, not by flow:
///   login  — number on an account, code proves it;
///   signup — number not on any account, name + code create one;
///   link   — a signed-in learner adds a number to their own account.
Future<bool> showPhoneSignInSheet(
  BuildContext context,
  AppState state, {
  bool linkOnly = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _PhoneSheet(
        state: state,
        messenger: messenger,
        linkOnly: linkOnly,
      ),
    ),
  );

  return done ?? false;
}

class _PhoneSheet extends StatefulWidget {
  const _PhoneSheet({
    required this.state,
    required this.messenger,
    required this.linkOnly,
  });

  final AppState state;
  final ScaffoldMessengerState? messenger;
  final bool linkOnly;

  @override
  State<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<_PhoneSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();

  String? _error;
  bool _busy = false;

  /// True once a code has been sent: the sheet is showing the code step.
  OtpStart? _sent;

  /// Set when the number has no account yet, so step two asks for a name and
  /// creates one instead of failing with "no account".
  bool _creating = false;

  int _secondsLeft = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _say(String message) {
    final messenger = widget.messenger;
    if (messenger == null || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _purpose {
    if (widget.linkOnly) return 'link';
    return _creating ? 'signup' : 'login';
  }

  void _startCountdown(int seconds) {
    _ticker?.cancel();
    setState(() => _secondsLeft = seconds);
    if (seconds <= 0) return;

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft = seconds - timer.tick.clamp(0, seconds));
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    final typed = _phone.text.trim();
    if (typed.isEmpty) {
      setState(() => _error = 'Type the number you use on WhatsApp.');
      return;
    }

    // Refuse a landline or a half-typed number here, so the learner is not
    // waiting on a message that could never arrive.
    final e164 = PhoneNumber.normalise(typed);
    if (e164 == null) {
      setState(
        () => _error = 'That does not look like a mobile number. '
            'Use 099 123 4567, or +265 991 234 567.',
      );
      return;
    }

    if (_creating && _name.text.trim().isEmpty) {
      setState(() => _error = 'Add your name so your teacher can find you.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final sent = await widget.state.startPhoneCode(
        phone: e164,
        purpose: _purpose,
      );

      if (!mounted) return;

      if (!sent.exists && !_creating && !widget.linkOnly) {
        // The number is not on an account. Say so and offer to create one,
        // rather than leaving the person on a code step with no code coming.
        setState(() {
          _busy = false;
          _creating = true;
          _error = 'No account uses that number yet. '
              'Add your name and we will create one.';
        });
        return;
      }

      setState(() {
        _busy = false;
        _sent = sent;
        _error = null;
      });
      _startCountdown(sent.resendAfter);
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
        _error = 'Could not send the code: $failure';
      });
    }
  }

  Future<void> _verify() async {
    final sent = _sent;
    if (sent == null || sent.challenge == null) return;

    final digits = _code.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) {
      setState(() => _error = 'Type the code from the WhatsApp message.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (widget.linkOnly) {
        await widget.state.verifyPhoneLink(
          challenge: sent.challenge!,
          code: digits,
        );
      } else if (_creating) {
        await widget.state.registerWithPhoneCode(
          challenge: sent.challenge!,
          code: digits,
          name: _name.text,
        );
      } else {
        await widget.state.signInWithPhoneCode(
          challenge: sent.challenge!,
          code: digits,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);

      _say(
        widget.linkOnly
            ? 'Number verified. You can sign in with it next time.'
            : _creating
                ? 'Account created. Welcome.'
                : 'Signed in.',
      );
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
        _error = 'Could not check the code: $failure';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sent = _sent;

    return SheetBody(
      title: sent == null
          ? (widget.linkOnly ? 'Add a number' : 'Sign in with WhatsApp')
          : 'Enter the code',
      subtitle: sent == null
          ? (widget.linkOnly
              ? 'We will send a code to this number. Next time you can sign in '
                  'with it instead of a password.'
              : 'We will send a six-digit code to your WhatsApp. No password to '
                  'remember.')
          : 'Sent to ${sent.masked ?? PhoneNumber.pretty(sent.phone)}.',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy
                ? null
                : () {
                    if (sent != null && !widget.linkOnly) {
                      // Back to the number, not out of the sheet: mistyped
                      // digits are the common case, and reopening the sheet
                      // loses both fields.
                      _ticker?.cancel();
                      setState(() {
                        _sent = null;
                        _code.clear();
                        _error = null;
                        _secondsLeft = 0;
                      });
                      return;
                    }
                    Navigator.pop(context);
                  },
            child: Text(sent != null && !widget.linkOnly ? 'Change number' : 'Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : (sent == null ? _send : _verify),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    sent == null
                        ? 'Send code'
                        : _creating
                            ? 'Create account'
                            : 'Verify',
                  ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sent == null) ...<Widget>[
            if (!widget.linkOnly && _creating) ...<Widget>[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                LengthLimitingTextInputFormatter(17),
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '099 123 4567',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                helperText: 'A number that has WhatsApp, including the 0.',
              ),
              onSubmitted: (_) => _send(),
            ),
            if (!widget.linkOnly) ...<Widget>[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _creating = !_creating;
                          _error = null;
                        }),
                child: Text(
                  _creating
                      ? 'I already have an account'
                      : 'New here? Create an account',
                ),
              ),
            ],
          ] else ...<Widget>[
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(hintText: '000000'),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy || _secondsLeft > 0 ? null : _send,
                child: Text(
                  _secondsLeft > 0
                      ? 'Send a new code in ${_secondsLeft}s'
                      : 'Send a new code',
                ),
              ),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, height: 1.4),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            // The consent sentence, where it has to be: on the screen where the
            // number is given and the code is asked for. Meta requires opt-in
            // for messages a business starts, and a sign-in code is one. The
            // server records the moment the code comes back.
            _creating || widget.linkOnly
                ? 'By continuing you agree to receive sign-in codes from '
                    'Kuphanda on WhatsApp at this number. Nothing else is sent, '
                    'and the number is never shown to other learners.'
                : 'Your number is only used to sign you in. It is never shown to '
                    'other learners.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
