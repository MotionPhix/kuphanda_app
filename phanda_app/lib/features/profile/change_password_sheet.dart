import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../state/app_state.dart';

/// Changing the password from a phone that is already signed in.
///
/// The alternative was the emailed reset link, which is a strange thing to ask
/// of someone holding an open session — and it signs every device out, this one
/// included.
Future<void> showChangePasswordSheet(
  BuildContext context,
  AppState state,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      // The sheet's box stays put when the keyboard opens, so the form reserves
      // the inset or the fields land behind the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _ChangePasswordSheet(state: state, messenger: messenger),
    ),
  );
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.state, required this.messenger});

  final AppState state;
  final ScaffoldMessengerState? messenger;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  // Controllers live with the sheet: disposing them as soon as the route
  // returns would leave the fields using a dead controller mid-animation.
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter the password you use now.');
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _error = 'The new password needs eight characters or more.');
      return;
    }
    if (_next.text != _repeat.text) {
      setState(() => _error = 'The two new passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.state.changePassword(
        currentPassword: _current.text,
        password: _next.text,
      );
      if (mounted) Navigator.pop(context);
      final messenger = widget.messenger;
      if (messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Password changed. Other devices are signed out.')),
        );
      }
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
        _error = 'Could not change the password: $failure';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SheetBody(
      title: 'Change password',
      subtitle: 'For ${widget.state.accountEmail ?? 'this account'}.',
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
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Current password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repeat,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _save(),
            decoration: const InputDecoration(
              labelText: 'Repeat the new password',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Your other phones and computers will be signed out. This one stays '
            'signed in.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
