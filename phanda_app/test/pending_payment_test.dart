import 'package:flutter_test/flutter_test.dart';
import 'package:kuphanda/data/api/api_client.dart';
import 'package:kuphanda/data/api/api_models.dart';
import 'package:kuphanda/data/api/token_store.dart';
import 'package:kuphanda/data/models/document.dart';
import 'package:kuphanda/data/models/profile.dart';
import 'package:kuphanda/data/store/document_files.dart';
import 'package:kuphanda/data/store/snapshot.dart';
import 'package:kuphanda/data/store/state_store.dart';
import 'package:kuphanda/state/app_state.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'https://library.test/api/v1', token: 'token');

  bool complete = false;

  @override
  Future<List<RemotePlan>> fetchPlans() async => const [
        RemotePlan(
          id: 1,
          slug: 'week',
          name: 'Weekly pass',
          tier: AccessTier.weekly,
          priceMwk: 1500,
          durationDays: 7,
        ),
      ];

  @override
  Future<BillingStatus> fetchBillingStatus() async =>
      const BillingStatus(
        tier: AccessTier.free,
        plan: 'free',
        purchases: <String>{},
      );

  @override
  Future<List<PaymentRecord>> fetchPayments() async => const [];

  @override
  Future<List<RemoteDocument>> fetchDocuments({int perPage = 100}) async => const [];

  @override
  Future<List<RemoteOfflineItem>> fetchOffline() async => const [];

  @override
  Future<CheckoutSession> checkoutPlan(int planId) async => const CheckoutSession(
        txRef: 'SUB-TEST',
        checkoutUrl: 'https://checkout.paychangu.test/SUB-TEST',
        amountMwk: 1500,
        kind: 'subscription',
      );

  @override
  Future<PaymentStatus> paymentStatus(String txRef) async => PaymentStatus(
        txRef: txRef,
        status: complete ? 'active' : 'pending',
        kind: 'subscription',
      );
}

void main() {
  test('pending payment survives a snapshot round trip', () {
    final snapshot = AppSnapshot(
      pendingPaymentTxRef: 'SUB-123',
      pendingPaymentKind: 'subscription',
      pendingPaymentAt: DateTime.utc(2026, 10, 27, 12),
    );

    final restored = AppSnapshot.decode(snapshot.encode());

    expect(restored.pendingPaymentTxRef, 'SUB-123');
    expect(restored.pendingPaymentKind, 'subscription');
    expect(restored.pendingPaymentAt, DateTime.utc(2026, 10, 27, 12));
  });

  test('checkout is remembered, kept while pending, and cleared when confirmed', () async {
    final store = MemoryStateStore(
      AppSnapshot(profile: const Profile(onboardingComplete: true)),
    );
    final api = _FakeApi();
    final state = AppState(
      store: store,
      files: FakeDocumentFiles(),
      api: api,
      tokenStore: MemoryTokenStore('token'),
    );
    await state.initialize();

    expect(state.isSignedIn, isTrue);

    final session = await state.startPlanCheckout(
      const RemotePlan(
        id: 1,
        slug: 'week',
        name: 'Weekly pass',
        tier: AccessTier.weekly,
        priceMwk: 1500,
        durationDays: 7,
      ),
    );

    expect(state.hasPendingPayment, isTrue);
    expect(state.pendingPaymentTxRef, session.txRef);
    expect((await store.read())?.pendingPaymentTxRef, session.txRef);

    final stillPending = await state.resumePendingPayment();
    expect(stillPending?.isComplete, isFalse);
    expect(state.hasPendingPayment, isTrue);

    api.complete = true;
    final confirmed = await state.resumePendingPayment();

    expect(confirmed?.isComplete, isTrue);
    expect(state.hasPendingPayment, isFalse);
    expect((await store.read())?.pendingPaymentTxRef, isNull);
  });
}
