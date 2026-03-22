/// Các khoảng thời gian tương đối: tuần này, tháng này, năm nay, v.v.
enum DateRange {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisQuarter,
  lastQuarter,
  thisYear,
  lastYear,
  future,
  custom;

  static DateRange fromString(String value) {
    final map = {
      'THIS_WEEK': DateRange.thisWeek,
      'LAST_WEEK': DateRange.lastWeek,
      'THIS_MONTH': DateRange.thisMonth,
      'LAST_MONTH': DateRange.lastMonth,
      'THIS_QUARTER': DateRange.thisQuarter,
      'LAST_QUARTER': DateRange.lastQuarter,
      'THIS_YEAR': DateRange.thisYear,
      'LAST_YEAR': DateRange.lastYear,
      'FUTURE': DateRange.future,
      'CUSTOM': DateRange.custom,
    };
    return map[value] ?? DateRange.custom;
  }

  String get apiValue {
    final map = {
      DateRange.thisWeek: 'THIS_WEEK',
      DateRange.lastWeek: 'LAST_WEEK',
      DateRange.thisMonth: 'THIS_MONTH',
      DateRange.lastMonth: 'LAST_MONTH',
      DateRange.thisQuarter: 'THIS_QUARTER',
      DateRange.lastQuarter: 'LAST_QUARTER',
      DateRange.thisYear: 'THIS_YEAR',
      DateRange.lastYear: 'LAST_YEAR',
      DateRange.future: 'FUTURE',
      DateRange.custom: 'CUSTOM',
    };
    return map[this] ?? 'CUSTOM';
  }

  String get displayName {
    switch (this) {
      case DateRange.thisWeek:
        return 'Tuần này';
      case DateRange.lastWeek:
        return 'Tuần trước';
      case DateRange.thisMonth:
        return 'Tháng này';
      case DateRange.lastMonth:
        return 'Tháng trước';
      case DateRange.thisQuarter:
        return 'Quý này';
      case DateRange.lastQuarter:
        return 'Quý trước';
      case DateRange.thisYear:
        return 'Năm nay';
      case DateRange.lastYear:
        return 'Năm trước';
      case DateRange.future:
        return 'Tương lai';
      case DateRange.custom:
        return 'Tùy chỉnh';
    }
  }
}

