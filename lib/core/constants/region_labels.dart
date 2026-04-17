import 'enums.dart';

/// Display labels for Region enum values.
const regionLabels = <Region, String>{
  Region.tw: '台灣',
  Region.kr: '韓國',
  Region.hk: '香港',
  Region.cn: '中國',
  Region.jp: '日本',
  Region.us: '美國',
  Region.uk: '英國',
  Region.fr: '法國',
  Region.it: '義大利',
  Region.pl: '波蘭',
  Region.be: '比利時',
  Region.other: '其他',
};

/// Display labels for ReleaseType enum values.
const releaseTypeLabels = <ReleaseType, String>{
  ReleaseType.theatrical: '院線版',
  ReleaseType.reissue: '重映版',
  ReleaseType.special: '特別版',
  ReleaseType.limited: '限定版',
  ReleaseType.other: '其他',
};

/// Display labels for SizeType enum values.
const sizeTypeLabels = <SizeType, String>{
  SizeType.b1: 'B1',
  SizeType.b2: 'B2',
  SizeType.a3: 'A3',
  SizeType.a4: 'A4',
  SizeType.mini: 'Mini',
  SizeType.custom: '自訂',
  SizeType.other: '其他',
};

/// Display labels for ChannelCategory enum values.
const channelCategoryLabels = <ChannelCategory, String>{
  ChannelCategory.cinema: '影城',
  ChannelCategory.distributor: '片商',
  ChannelCategory.lottery: '抽獎',
  ChannelCategory.exhibition: '展覽',
  ChannelCategory.retail: '零售',
  ChannelCategory.other: '其他',
};

/// Display labels for SubmissionStatus.
const submissionStatusLabels = <SubmissionStatus, String>{
  SubmissionStatus.pending: '審核中',
  SubmissionStatus.approved: '已通過',
  SubmissionStatus.rejected: '未通過',
  SubmissionStatus.duplicate: '重複',
};
