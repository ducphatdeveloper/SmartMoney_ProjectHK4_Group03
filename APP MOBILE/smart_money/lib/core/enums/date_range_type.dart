/// Phân loại một khoảng thời gian: quá khứ, hiện tại, tương lai, hoặc tùy chỉnh
enum DateRangeType {
  past,
  current,
  future,
  custom;

  static DateRangeType fromString(String value) {
    return DateRangeType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => DateRangeType.current,
    );
  }

  String get displayName {
    switch (this) {
      case DateRangeType.past:
        return 'Past';
      case DateRangeType.current:
        return 'Current';
      case DateRangeType.future:
        return 'Future';
      case DateRangeType.custom:
        return 'Custom';
    }
  }
}

