// core/constants/date_enums.dart
// Mirror đúng các enum từ Spring Boot
// Dùng khi gọi API: ?mode=MONTHLY hoặc ?range=THIS_MONTH

// Mirror DateRangeMode.java
// Dùng cho API /api/utils/date-ranges?mode=MONTHLY
enum DateRangeMode {
  daily,      // DAILY
  weekly,     // WEEKLY
  monthly,    // MONTHLY
  quarterly,  // QUARTERLY
  yearly;     // YEARLY

  // Chuyển thành String để gắn vào URL query param
  String toApiString() => name.toUpperCase();
}

// Mirror DateRange.java
// Dùng cho API ?range=THIS_MONTH
enum DateRange {
  thisWeek,     // THIS_WEEK
  lastWeek,     // LAST_WEEK
  thisMonth,    // THIS_MONTH
  lastMonth,    // LAST_MONTH
  thisQuarter,  // THIS_QUARTER
  lastQuarter,  // LAST_QUARTER
  thisYear,     // THIS_YEAR
  lastYear,     // LAST_YEAR
  future,       // FUTURE
  custom;       // CUSTOM

  String toApiString() {
    switch (this) {
      case DateRange.thisWeek:    return 'THIS_WEEK';
      case DateRange.lastWeek:    return 'LAST_WEEK';
      case DateRange.thisMonth:   return 'THIS_MONTH';
      case DateRange.lastMonth:   return 'LAST_MONTH';
      case DateRange.thisQuarter: return 'THIS_QUARTER';
      case DateRange.lastQuarter: return 'LAST_QUARTER';
      case DateRange.thisYear:    return 'THIS_YEAR';
      case DateRange.lastYear:    return 'LAST_YEAR';
      case DateRange.future:      return 'FUTURE';
      case DateRange.custom:      return 'CUSTOM';
    }
  }
}

// Mirror DateRangeType.java
// Trả về từ API date-ranges để Flutter biết tab nào là hiện tại/quá khứ/tương lai
enum DateRangeType {
  past,     // PAST
  current,  // CURRENT
  future,   // FUTURE
  custom;   // CUSTOM

  static DateRangeType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PAST':    return DateRangeType.past;
      case 'CURRENT': return DateRangeType.current;
      case 'FUTURE':  return DateRangeType.future;
      case 'CUSTOM':  return DateRangeType.custom;
      default:        return DateRangeType.past;
    }
  }
}