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
        return 'Quá khứ';
      case DateRangeType.current:
        return 'Hiện tại';
      case DateRangeType.future:
        return 'Tương lai';
      case DateRangeType.custom:
        return 'Tùy chỉnh';
    }
  }
}

