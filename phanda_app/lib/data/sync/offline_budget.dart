import '../models/document.dart';

/// Storage policy for documents kept on the device.
///
/// Until now "offline" meant "whatever fits on the phone": every download stayed
/// until the learner removed it or Android ran out of space. On a 32 GB handset that
/// is not a policy, it is an accident waiting for a full disk.
///
/// The rule is a fixed budget per device with eviction, never a refusal:
///
/// - A download that would overflow the budget drops the copies least recently read
///   until it fits. A learner who taps download gets the document; sorting out space
///   is the app's job, not theirs.
/// - A single document larger than the whole budget is the one case that cannot be
///   solved by evicting - it is reported instead of silently clearing everything.
/// - Recency is the later of "when it was saved" and "when it was last read", so a
///   paper downloaded months ago but opened yesterday survives a document saved
///   yesterday and never opened.
class OfflineBudget {
  const OfflineBudget._();

  /// 50 MB per device. Enough for several past papers at typical scan sizes; small
  /// enough to stay invisible on the cheap handsets this app is built for.
  static const int defaultBudgetBytes = 50 * 1024 * 1024;

  /// Which copies to drop so [incomingBytes] fits. Oldest touch first.
  ///
  /// Pure on purpose: the caller does the deleting, so the ordering can be tested
  /// without a file system.
  static List<DocumentAsset> chooseEvictions({
    required Iterable<DocumentAsset> assets,
    required int incomingBytes,
    required DateTime Function(DocumentAsset asset) lastTouched,
    int budget = defaultBudgetBytes,
  }) {
    if (incomingBytes > budget) {
      throw const OfflineBudgetExceeded(
        'This document is larger than the 50 MB kept on this device. Read it online, '
        'or free up space by removing a downloaded document.',
      );
    }

    final candidates = assets.toList(growable: false);

    var total = 0;
    for (final asset in candidates) {
      total += asset.sizeBytes;
    }

    if (total + incomingBytes <= budget) {
      return const <DocumentAsset>[];
    }

    final byAge = [...candidates]..sort((a, b) => lastTouched(a).compareTo(lastTouched(b)));

    final evicted = <DocumentAsset>[];

    for (final asset in byAge) {
      if (total + incomingBytes <= budget) break;
      evicted.add(asset);
      total -= asset.sizeBytes;
    }

    return evicted;
  }
}

class OfflineBudgetExceeded implements Exception {
  const OfflineBudgetExceeded(this.message);

  final String message;

  @override
  String toString() => message;
}
