/// SyncQueueItem represents a local mutation queued for background synchronization.
class SyncQueueItem {
  final String id;
  final String entity;
  final String operation; // "create" | "update" | "delete"
  final Map<String, dynamic> payload;
  int retryCount;
  final DateTime createdAt;
  DateTime? lastAttemptAt;
  String status;
  // "pending" | "syncing" | "failed" | "auth_required" | "deferred"
  //   deferred = a required dependency (e.g. unresolved server profile id) is
  //   not available yet; the item is kept intact and does NOT consume the
  //   retry budget.
  String? errorMessage;

  // --- P2-F8: per-item processing claim -------------------------------------
  // A sync processor (foreground SyncService or the WorkManager background
  // isolate) stamps its opaque [claimToken] + [claimedAt] on an item before it
  // dispatches the network call. A second processor that sees a *fresh* claim
  // owned by someone else skips the item, so the same mutation is never sent
  // twice. A claim older than the sync lease is treated as abandoned (crashed
  // holder) and may be re-claimed — the queue can never permanently deadlock.
  String? claimToken;
  DateTime? claimedAt;

  SyncQueueItem({
    required this.id,
    required this.entity,
    required this.operation,
    required this.payload,
    this.retryCount = 0,
    DateTime? createdAt,
    this.lastAttemptAt,
    this.status = 'pending',
    this.errorMessage,
    this.claimToken,
    this.claimedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity': entity,
      'operation': operation,
      'payload': payload,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      if (lastAttemptAt != null)
        'lastAttemptAt': lastAttemptAt!.toIso8601String(),
      'status': status,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (claimToken != null) 'claimToken': claimToken,
      if (claimedAt != null) 'claimedAt': claimedAt!.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as String,
      entity: map['entity'] as String,
      operation: map['operation'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      retryCount: map['retryCount'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.tryParse(map['lastAttemptAt'] as String)
          : null,
      status: map['status'] as String? ?? 'pending',
      errorMessage: map['errorMessage'] as String?,
      claimToken: map['claimToken'] as String?,
      claimedAt: map['claimedAt'] != null
          ? DateTime.tryParse(map['claimedAt'].toString())
          : null,
    );
  }

  /// Returns a copy with selected fields overridden. Used by the queue
  /// coalescer (P2-F4) to fold a newer mutation onto an existing queue entry
  /// without changing its stable Hive key or original [createdAt].
  SyncQueueItem copyWith({
    String? id,
    String? entity,
    String? operation,
    Map<String, dynamic>? payload,
    int? retryCount,
    DateTime? createdAt,
    Object? lastAttemptAt = _sentinel,
    String? status,
    Object? errorMessage = _sentinel,
    Object? claimToken = _sentinel,
    Object? claimedAt = _sentinel,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt == _sentinel
          ? this.lastAttemptAt
          : lastAttemptAt as DateTime?,
      status: status ?? this.status,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      claimToken: claimToken == _sentinel
          ? this.claimToken
          : claimToken as String?,
      claimedAt: claimedAt == _sentinel
          ? this.claimedAt
          : claimedAt as DateTime?,
    );
  }

  static const Object _sentinel = Object();
}
