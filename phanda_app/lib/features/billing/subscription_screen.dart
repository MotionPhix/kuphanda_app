import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../data/models/document.dart';
import '../../state/app_state.dart';

/// Sign-in and the paid-access surface.
///
/// Free documents are readable without an account. Anything premium requires a
/// subscription (or a single-document purchase), and this screen is the only
/// place that starts a PayChangu checkout.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.documentId});

  /// When set, the screen offers a one-off purchase for this document.
  final String? documentId;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      if (state.isSignedIn) state.loadBilling();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!state.isSignedIn)
            _authCard(theme, state)
          else ...[
            _statusCard(theme, state),
            const SizedBox(height: 18),
            if (widget.documentId != null) ...[
              _documentPurchaseCard(theme, state),
              const SizedBox(height: 18),
            ],
            Text('Choose a plan', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Prices are in Malawi kwacha. Pay with mobile money or a card on PayChangu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (state.plans.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final plan in state.plans) ...[
                _PlanCard(
                  plan: plan,
                  active: state.billing?.subscription?.tier == plan.tier,
                  onBuy: _busy ? null : () => _buyPlan(state, plan),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 12),
            Text(
              'School licences are not sold in the app. If your school has a licence, '
              'sign in with the account your teacher gave you and the same content is unlocked.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _authCard(ThemeData theme, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sign in to the library', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Free documents stay open to everyone. Sign in to subscribe, buy a single '
          'document, or download readings for offline use.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        if (_registering) ...[
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : () => _submit(state),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_registering ? 'Create account' : 'Sign in'),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _registering = !_registering;
              _error = null;
            }),
            child: Text(_registering ? 'I already have an account' : 'Create an account'),
          ),
        ),
      ],
    );
  }

  Widget _statusCard(ThemeData theme, AppState state) {
    final billing = state.billing;
    final subscription = billing?.subscription;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.greenDeep, AppColors.green],
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.sun, size: 18),
              const SizedBox(width: 6),
              Text(
                state.hasPaidAccess ? 'ACTIVE ACCESS' : 'FREE ACCOUNT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subscription?.plan ?? 'Free',
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            subscription?.endsAt != null
                ? 'Renews or expires ${formatDate(subscription!.endsAt!)}'
                : 'Browse free papers and guides. Upgrade to unlock the rest.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.accountEmail ?? '',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          if (subscription != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Pill(
                  label: 'Tier: ${state.entitlementTier.label}',
                  color: AppColors.sun,
                  compact: true,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _confirmSignOut(state),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _confirmSignOut(state),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Sign out'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _documentPurchaseCard(ThemeData theme, AppState state) {
    final document = state.documentById(widget.documentId!);
    if (document == null) return const SizedBox.shrink();

    final price = state.priceFor(document.id);
    final unlocked = !state.isLocked(document);

    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? 'You have access to this document.'
                      : price > 0
                          ? 'Buy just this document for MWK ${price.toString()}'
                          : 'This document is included in a subscription.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!unlocked && price > 0)
            FilledButton(
              onPressed: _busy ? null : () => _buyDocument(state, document),
              child: const Text('Buy'),
            ),
        ],
      ),
    );
  }

  Future<void> _submit(AppState state) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await state.registerAccount(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await state.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      await state.loadBilling();
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not sign in: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyPlan(AppState state, RemotePlan plan) async {
    await _checkout(
      state,
      () => state.startPlanCheckout(plan),
      'Subscribe · ${plan.name}',
    );
  }

  Future<void> _buyDocument(AppState state, Document document) async {
    await _checkout(
      state,
      () => state.startDocumentCheckout(document.id),
      'Buy document',
    );
  }

  Future<void> _checkout(
    AppState state,
    Future<CheckoutSession> Function() start,
    String label,
  ) async {
    setState(() => _busy = true);
    try {
      final session = await start();
      final uri = Uri.tryParse(session.checkoutUrl);
      if (uri == null) throw const ApiException('The checkout link was invalid.');

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _error = 'Could not open the PayChangu checkout page.');
        return;
      }

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PaymentWaiter(
          state: state,
          txRef: session.txRef,
          label: label,
        ),
      );
      if (mounted) await state.loadBilling();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Checkout failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSignOut(AppState state) async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'Downloaded files stay on this phone until their subscription ends. '
          'Sign in again to sync them.',
      confirmLabel: 'Sign out',
    );
    if (confirmed) {
      await state.signOut();
      if (mounted) setState(() {});
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.active, required this.onBuy});

  final RemotePlan plan;
  final bool active;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      borderColor: active ? theme.colorScheme.primary : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plan.name, style: theme.textTheme.titleSmall),
                    if (active) ...[
                      const SizedBox(width: 8),
                      const Pill(label: 'Current', color: AppColors.green, compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${plan.durationDays} day${plan.durationDays == 1 ? '' : 's'} · '
                  '${plan.tier.label} content',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (plan.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan.description!,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'MWK ${plan.priceMwk}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: active ? null : onBuy,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                child: Text(active ? 'Active' : 'Buy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentWaiter extends StatefulWidget {
  const _PaymentWaiter({required this.state, required this.txRef, required this.label});

  final AppState state;
  final String txRef;
  final String label;

  @override
  State<_PaymentWaiter> createState() => _PaymentWaiterState();
}

class _PaymentWaiterState extends State<_PaymentWaiter> {
  Timer? _timer;
  bool _checking = false;
  String? _error;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      if (!silent) _error = null;
    });
    try {
      final status = await widget.state.verifyPayment(widget.txRef);
      if (!mounted) return;
      setState(() => _status = status.status);
      if (status.isComplete) {
        _timer?.cancel();
        Navigator.of(context).pop();
        showSnack(context, 'Payment confirmed. Your access is unlocked.');
      } else if (!silent) {
        setState(() => _error = 'PayChangu has not confirmed the payment yet.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetBody(
        title: 'Complete your payment',
        subtitle: widget.label,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _checking ? null : () => _check(),
              child: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('I have paid'),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A PayChangu page opened in your browser. Finish there, then return here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: ${widget.txRef}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: $_status',
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This screen checks every five seconds. If you close it, use Subscription '
              'in your profile to refresh.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
