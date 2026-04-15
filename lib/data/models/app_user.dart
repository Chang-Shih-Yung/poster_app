class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.submissionCount = 0,
  });

  factory AppUser.fromRow(Map<String, dynamic> row) {
    return AppUser(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? '',
      avatarUrl: row['avatar_url'] as String?,
      role: row['role'] as String? ?? 'user',
      submissionCount: (row['submission_count'] as int?) ?? 0,
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final int submissionCount;

  bool get isAdmin => role == 'admin' || role == 'owner';
}
