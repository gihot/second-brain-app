class VaultStatus {
  final int totalNotes;
  final int inboxCount;
  final DateTime? lastSync;
  final bool isServerReachable;

  const VaultStatus({
    this.totalNotes = 0,
    this.inboxCount = 0,
    this.lastSync,
    this.isServerReachable = false,
  });

  String get lastSyncText {
    if (lastSync == null) return '--';
    final diff = DateTime.now().difference(lastSync!);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'vor ${diff.inHours}h';
    return 'vor ${diff.inDays}d';
  }

  VaultStatus copyWith({
    int? totalNotes,
    int? inboxCount,
    DateTime? lastSync,
    bool? isServerReachable,
  }) {
    return VaultStatus(
      totalNotes: totalNotes ?? this.totalNotes,
      inboxCount: inboxCount ?? this.inboxCount,
      lastSync: lastSync ?? this.lastSync,
      isServerReachable: isServerReachable ?? this.isServerReachable,
    );
  }
}
