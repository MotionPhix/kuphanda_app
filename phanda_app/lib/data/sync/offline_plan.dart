import '../api/api_models.dart';
import '../models/document.dart';

enum OfflineActionType { download, update, remove }

/// One piece of work the sync has to perform. Kept separate from the network
/// so the decision can be unit-tested without a server.
class OfflineAction {
  const OfflineAction({
    required this.type,
    required this.documentId,
    this.version,
    this.downloadUrl,
    this.file,
  });

  final OfflineActionType type;
  final String documentId;
  final int? version;
  final String? downloadUrl;
  final RemoteFile? file;

  bool get isDownload => type == OfflineActionType.download || type == OfflineActionType.update;
}

/// Compares the server's current marks with the files on this device.
///
/// - A marked document with no server download is new → download.
/// - A stored version older than the server version → update.
/// - A stored server file whose mark disappeared (another device removed it)
///   → remove.
/// - Bundled or imported files are never removed by sync; only files that
///   carry [DocumentAsset.remote] belong to the server set.
List<OfflineAction> planOfflineSync({
  required List<RemoteOfflineItem> remote,
  required Map<String, DocumentAsset> local,
}) {
  final actions = <OfflineAction>[];
  final remoteIds = <String>{};

  for (final item in remote) {
    remoteIds.add(item.documentId);
    final file = item.file;
    if (file == null) continue;

    final asset = local[item.documentId];
    final storedVersion = asset != null && asset.remote ? asset.version : null;

    // Expired subscription or a revoked purchase: the mark remains (so it
    // resumes if the learner renews) but the stored file must not stay readable.
    if (!item.isEntitled) {
      if (asset != null && asset.remote) {
        actions.add(OfflineAction(
          type: OfflineActionType.remove,
          documentId: item.documentId,
        ));
      }
      continue;
    }

    if (storedVersion == null || storedVersion < file.version) {
      actions.add(
        OfflineAction(
          type: storedVersion == null ? OfflineActionType.download : OfflineActionType.update,
          documentId: item.documentId,
          version: file.version,
          downloadUrl: item.downloadUrl,
          file: file,
        ),
      );
    }
  }

  for (final entry in local.entries) {
    if (entry.value.remote && !remoteIds.contains(entry.key)) {
      actions.add(OfflineAction(type: OfflineActionType.remove, documentId: entry.key));
    }
  }

  return actions;
}
