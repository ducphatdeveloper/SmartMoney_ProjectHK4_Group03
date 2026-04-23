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
        return 'This Week';
      case DateRange.lastWeek:
        return 'Last Week';
      case DateRange.thisMonth:
        return 'This Month';
      case DateRange.lastMonth:
        return 'Last Month';
      case DateRange.thisQuarter:
        return 'This Quarter';
      case DateRange.lastQuarter:
        return 'Last Quarter';
      case DateRange.thisYear:
        return 'This Year';
      case DateRange.lastYear:
        return 'Last Year';
      case DateRange.future:
        return 'Future';
      case DateRange.custom:
        return 'Custom';
    }
  }
}

