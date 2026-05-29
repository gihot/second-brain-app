/// J5 (Plan v2): Single Source of Truth für den Auth-Zustand.
///
/// Vorher lag der Token in `ApiService._token` UND der User in
/// `AuthProvider._user` — zwei Felder, zwei Sync-Punkte, eine eigene
/// Bug-Klasse (Token in einem Slot ohne Spiegelung im anderen).
///
/// Jetzt: AuthProvider besitzt genau eine [AuthSession]. ApiService kennt
/// den Token nicht selbst, sondern ruft einen `tokenProvider`-Callback,
/// der `session?.token` zurückgibt. Es gibt physisch nur eine Quelle.
class AuthSession {
  final String id;
  final String email;
  final String token;

  /// ISO-8601, wenn der Account in der 30-Tage-Lösch-Frist steht
  /// (Wave 4.2). Sonst null.
  final String? pendingDeletionAt;

  const AuthSession({
    required this.id,
    required this.email,
    required this.token,
    this.pendingDeletionAt,
  });

  /// Baut eine Session aus einer `/auth/me`- oder Login-User-Map plus
  /// dem Token. Returns null wenn essenzielle Felder fehlen.
  static AuthSession? fromUserMap(Map<String, dynamic>? user, String token) {
    if (user == null) return null;
    final id = user['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return AuthSession(
      id: id,
      email: (user['email'] as String?) ?? '',
      token: token,
      pendingDeletionAt: user['pending_deletion_at'] as String?,
    );
  }

  AuthSession copyWith({
    String? email,
    String? token,
    String? pendingDeletionAt,
    bool clearPendingDeletion = false,
  }) {
    return AuthSession(
      id: id,
      email: email ?? this.email,
      token: token ?? this.token,
      pendingDeletionAt: clearPendingDeletion
          ? null
          : (pendingDeletionAt ?? this.pendingDeletionAt),
    );
  }
}
