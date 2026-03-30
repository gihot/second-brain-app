class VaultStatus {
  final int totalNotes;
  final int inboxCount;
  final int connectedCount;
  final DateTime? lastSync;
  final bool isServerReachable;

  const VaultStatus({
    this.totalNotes = 0,
    this.inboxCount = 0,
    this.connectedCount = 0,
    this.lastSync,
    this.isServerReachable = false,
  });

  String get lastSyncText {
    if (lastSync == null) return '--';
    final diff = DateTime.now().difference(lastSync!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  VaultStatus copyWith({
    int? totalNotes,
    int? inboxCount,
    int? connectedCount,
    DateTime? lastSync,
    bool? isServerReachable,
  }) {
    return VaultStatus(
      totalNotes: totalNotes ?? this.totalNotes,
      inboxCount: inboxCount ?? this.inboxCount,
      connectedCount: connectedCount ?? this.connectedCount,
      lastSync: lastSync ?? this.lastSync,
      isServerReachable: isServerReachable ?? this.isServerReachable,
    );
  }
}
