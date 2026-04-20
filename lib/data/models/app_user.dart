/// User-selectable gender (optional, includes prefer-not-say).
enum Gender {
  male('male', '男'),
  female('female', '女'),
  nonBinary('non_binary', '非二元'),
  preferNotSay('prefer_not_say', '不公開');

  const Gender(this.value, this.labelZh);
  final String value;
  final String labelZh;

  static Gender? fromString(String? raw) {
    if (raw == null) return null;
    for (final g in values) {
      if (g.value == raw) return g;
    }
    return null;
  }
}

/// One named link on a user profile (e.g. {label: "IG", url: "..."}).
class ProfileLink {
  const ProfileLink({required this.label, required this.url});
  factory ProfileLink.fromJson(Map<String, dynamic> j) =>
      ProfileLink(label: j['label'] as String, url: j['url'] as String);
  Map<String, dynamic> toJson() => {'label': label, 'url': url};

  final String label;
  final String url;
}

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
    // Profile editor fields (EPIC profile editor)
    this.gender,
    this.links = const [],
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
      gender: Gender.fromString(row['gender'] as String?),
      links: ((row['links'] as List?) ?? const [])
          .map((e) => ProfileLink.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final int submissionCount;
  final bool isPublic;
  final String? bio;
  final Gender? gender;
  final List<ProfileLink> links;

  bool get isAdmin => role == 'admin' || role == 'owner';
}
