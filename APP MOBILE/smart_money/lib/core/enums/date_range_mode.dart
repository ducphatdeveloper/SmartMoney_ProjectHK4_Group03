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
        return 'Theo ngày';
      case DateRangeMode.weekly:
        return 'Theo tuần';
      case DateRangeMode.monthly:
        return 'Theo tháng';
      case DateRangeMode.quarterly:
        return 'Theo quý';
      case DateRangeMode.yearly:
        return 'Theo năm';
    }
  }
}

