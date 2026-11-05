import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_models.dart';
import '../../data/models/document.dart';
import '../../features/profile/sign_in_sheet.dart';
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      if (!state.isSignedIn) return;
      state.loadBilling();
      state.resumePendingPayment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      // A price list and two paragraphs of small print are unreadable when a
      // desktop window stretches them to 1400 dp, so the page is centred in a
      // reading column the way every other pushed screen is.
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsivePage(
            maxWidth: kReadingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.isSignedIn)
                  _authCard(theme, state)
                else ...[
                  if (state.hasPendingPayment) ...[
                    _pendingBanner(theme, state),
                    const SizedBox(height: 14),
                  ],
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
                  if (state.plans.isEmpty && state.billingError != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Could not load the plans',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // The server's own words when it gave any: "Server
                            // Error" tells a learner nothing, a refused
                            // connection at least tells them to check signal.
                            state.billingError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () => state.loadBilling(),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else if (state.billingLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.plans.isEmpty)
                    // Loaded, no error, and still nothing to buy: the server has
                    // no published plans. A spinner here was the reported bug —
                    // it turned for ever because "empty" and "loading" were the
                    // same state.
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No plans are on sale yet',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The library has not published its prices yet. Your account still works, and free documents open as usual.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () => state.loadBilling(),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payment history',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh receipts',
                        onPressed: () => state.loadBilling(),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    ],
                  ),
                  if (state.payments.isEmpty)
                    Text(
                      'No payments yet. Receipts for subscriptions and single-document '
                      'purchases appear here once PayChangu confirms them.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    )
                  else
                    for (final record in state.payments) ...[
                      _PaymentRow(
                        record: record,
                        onTap: () => _showReceipt(record),
                      ),
                      const SizedBox(height: 8),
                    ],
                  const SizedBox(height: 16),
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
          ),
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
        // One door, the same one the onboarding gate uses: email, Google, or a
        // new account. A second copy of the form here would drift from it.
        FilledButton(
          onPressed: _busy ? null : () => _openSignIn(state),
          child: const Text('Sign in or create an account'),
        ),
        const SizedBox(height: 10),
        Text(
          'Your receipt and downloads follow the account to any phone.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Signing in from here lands on this screen, not the library: the plans and
  /// any pending payment are what the learner came for.
  Future<void> _openSignIn(AppState state) async {
    await showSignInSheet(context, state);
    if (!mounted || !AppScope.read(context).isSignedIn) return;
    await state.loadBilling();
    await state.resumePendingPayment();
  }

  Widget _pendingBanner(ThemeData theme, AppState state) {
    return AppCard(
      color: AppColors.sun.withValues(alpha: 0.1),
      borderColor: AppColors.sun.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: Color(0xFF7A5200),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment pending',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF7A5200),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'We are waiting for PayChangu to confirm '
            '${state.pendingPaymentKind == 'document' ? 'your document purchase' : 'your subscription'}. '
            'Reference ${state.pendingPaymentTxRef}.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _checkPending(state),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                child: const Text('Check now'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : () => state.clearPendingPayment(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _checkPending(AppState state) async {
    setState(() => _busy = true);
    try {
      final status = await state.resumePendingPayment();
      if (!mounted) return;
      if (status?.isComplete == true) {
        showSnack(context, 'Payment confirmed. Your access is unlocked.');
      } else {
        showSnack(
          context,
          status == null
              ? 'Could not reach the library. Try again in a moment.'
              : 'PayChangu has not confirmed the payment yet.',
          error: status == null,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              const Icon(
                Icons.verified_rounded,
                color: AppColors.sun,
                size: 18,
              ),
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
                      ? 'Buy just this document for ${formatMwk(price)}'
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
      if (uri == null) {
        throw const ApiException('The checkout link was invalid.');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showSnack(
          context,
          'Could not open the PayChangu checkout page.',
          error: true,
        );
        return;
      }

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            _PaymentWaiter(state: state, txRef: session.txRef, label: label),
      );
      if (mounted) await state.loadBilling();
    } on ApiException catch (error) {
      if (mounted) showSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showSnack(context, 'Checkout failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showReceipt(PaymentRecord record) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SheetBody(
          title: 'Receipt',
          subtitle: record.title,
          actions: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: record.txRef));
                  if (sheetContext.mounted) {
                    showSnack(sheetContext, 'Reference copied.');
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy reference'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Close'),
              ),
            ),
          ],
          child: Column(
            children: [
              _ReceiptLine(label: 'Reference', value: record.txRef),
              _ReceiptLine(
                label: 'Type',
                value: record.isSubscription
                    ? 'Subscription'
                    : 'Single document',
              ),
              _ReceiptLine(label: 'Amount', value: formatMwk(record.amountMwk)),
              _ReceiptLine(label: 'Status', value: record.status),
              if (record.paidAt != null)
                _ReceiptLine(label: 'Paid', value: formatDate(record.paidAt!)),
              if (record.endsAt != null)
                _ReceiptLine(
                  label: record.isSubscription ? 'Access until' : 'Expires',
                  value: formatDate(record.endsAt!),
                ),
              if (record.createdAt != null)
                _ReceiptLine(
                  label: 'Started',
                  value: formatDate(record.createdAt!),
                ),
              const SizedBox(height: 10),
              Text(
                'Keep this reference if you need to raise a payment query with your '
                'school or PayChangu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(AppState state) async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'Downloaded files stay on this phone until their subscription ends. '
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
  const _PlanCard({
    required this.plan,
    required this.active,
    required this.onBuy,
  });

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
                    // The name plus the "Current" pill needs 112px more than the
                    // card has at 1.3x, so the name yields first.
                    Flexible(
                      child: Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      const Pill(
                        label: 'Current',
                        color: AppColors.green,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${plan.durationDays} day${plan.durationDays == 1 ? '' : 's'} · '
                  '${_planTierLabel(plan.tier)}',
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
                formatMwk(plan.priceMwk),
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
  const _PaymentWaiter({
    required this.state,
    required this.txRef,
    required this.label,
  });

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
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _check(silent: true),
    );
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
            Text('Status: $_status', style: theme.textTheme.bodySmall),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
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

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.record, required this.onTap});

  final PaymentRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (record.status) {
      'active' || 'paid' => AppColors.green,
      'pending' => AppColors.sun,
      'expired' || 'cancelled' => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            record.isSubscription
                ? Icons.card_membership_outlined
                : Icons.menu_book_outlined,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  record.paidAt != null
                      ? formatDate(record.paidAt!)
                      : record.createdAt != null
                      ? formatDate(record.createdAt!)
                      : record.txRef,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMwk(record.amountMwk),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                record.status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _planTierLabel(AccessTier tier) => switch (tier) {
  AccessTier.daily => 'Daily access',
  AccessTier.weekly => 'Weekly access',
  AccessTier.monthly => 'Monthly access',
  AccessTier.school => 'School licence',
  AccessTier.free => 'Free access',
};
