import '../../data/models/daily_archive.dart';
import '../../data/models/document.dart';

class OfflineQueueItem<T> {
  final String id;
  final T payload;
  final DateTime queuedAt;
  final String type; // 'scan' ou 'daily_archive'

  OfflineQueueItem({
    required this.id,
    required this.payload,
    required this.queuedAt,
    required this.type,
  });
}

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  bool _isOnline = true;
  final List<OfflineQueueItem<DocumentItem>> _pendingScans = [];
  final List<OfflineQueueItem<DailyArchiveItem>> _pendingDailyArchives = [];

  bool get isOnline => _isOnline;
  int get pendingCount => _pendingScans.length + _pendingDailyArchives.length;
  List<OfflineQueueItem<DocumentItem>> get pendingScans => List.unmodifiable(_pendingScans);
  List<OfflineQueueItem<DailyArchiveItem>> get pendingDailyArchives => List.unmodifiable(_pendingDailyArchives);

  void setOnlineStatus(bool online, {Function(int syncedCount)? onSyncCompleted}) {
    _isOnline = online;
    if (_isOnline && pendingCount > 0) {
      final count = syncPendingItems();
      onSyncCompleted?.call(count);
    }
  }

  void enqueueScan(DocumentItem doc) {
    _pendingScans.add(
      OfflineQueueItem(
        id: 'off_scan_${DateTime.now().millisecondsSinceEpoch}',
        payload: doc,
        queuedAt: DateTime.now(),
        type: 'scan',
      ),
    );
  }

  void enqueueDailyArchive(DailyArchiveItem archive) {
    _pendingDailyArchives.add(
      OfflineQueueItem(
        id: 'off_arch_${DateTime.now().millisecondsSinceEpoch}',
        payload: archive,
        queuedAt: DateTime.now(),
        type: 'daily_archive',
      ),
    );
  }

  int syncPendingItems() {
    final totalSynced = pendingCount;
    _pendingScans.clear();
    _pendingDailyArchives.clear();
    return totalSynced;
  }
}
