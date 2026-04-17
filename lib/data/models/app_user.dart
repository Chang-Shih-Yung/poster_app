class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.submissionCount = 0,
    // V2 fields
    this.isPublic = true,
    this.bio,
  });

  factory AppUser.fromRow(Map<String, dynamic> row) {
    return AppUser(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? '',
      avatarUrl: row['avatar_url'] as String?,
      role: row['role'] as String? ?? 'user',
      submissionCount: (row['submission_count'] as int?) ?? 0,
      isPublic: (row['is_public'] as bool?) ?? true,
      bio: row['bio'] as String?,
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final int submissionCount;
  final bool isPublic;
  final String? bio;

  bool get isAdmin => role == 'admin' || role == 'owner';
}
