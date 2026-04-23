/// Chế độ xem thời gian: theo ngày, tuần, tháng, quý, năm
enum DateRangeMode {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly;

  String get displayName {
    switch (this) {
      case DateRangeMode.daily:
        return 'Daily';
      case DateRangeMode.weekly:
        return 'Weekly';
      case DateRangeMode.monthly:
        return 'Monthly';
      case DateRangeMode.quarterly:
        return 'Quarterly';
      case DateRangeMode.yearly:
        return 'Yearly';
    }
  }
}

