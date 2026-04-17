// V2 enums — must match Postgres enum definitions exactly.

enum Region {
  tw('TW'),
  kr('KR'),
  hk('HK'),
  cn('CN'),
  jp('JP'),
  us('US'),
  uk('UK'),
  fr('FR'),
  it('IT'),
  pl('PL'),
  be('BE'),
  other('OTHER');

  const Region(this.value);
  final String value;

  static Region fromString(String? s) =>
      Region.values.firstWhere((e) => e.value == s, orElse: () => Region.other);
}

enum ReleaseType {
  theatrical('theatrical'),
  reissue('reissue'),
  special('special'),
  limited('limited'),
  other('other');

  const ReleaseType(this.value);
  final String value;

  static ReleaseType fromString(String? s) => ReleaseType.values
      .firstWhere((e) => e.value == s, orElse: () => ReleaseType.other);
}

enum SizeType {
  b1('B1'),
  b2('B2'),
  a3('A3'),
  a4('A4'),
  mini('mini'),
  custom('custom'),
  other('other');

  const SizeType(this.value);
  final String value;

  static SizeType fromString(String? s) =>
      SizeType.values.firstWhere((e) => e.value == s, orElse: () => SizeType.other);
}

enum ChannelCategory {
  cinema('cinema'),
  distributor('distributor'),
  lottery('lottery'),
  exhibition('exhibition'),
  retail('retail'),
  other('other');

  const ChannelCategory(this.value);
  final String value;

  static ChannelCategory fromString(String? s) => ChannelCategory.values
      .firstWhere((e) => e.value == s, orElse: () => ChannelCategory.other);
}

enum SubmissionStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  duplicate('duplicate');

  const SubmissionStatus(this.value);
  final String value;

  static SubmissionStatus fromString(String? s) => SubmissionStatus.values
      .firstWhere((e) => e.value == s, orElse: () => SubmissionStatus.pending);
}
