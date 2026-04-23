/// Kiểu lặp lại: Không, Hàng ngày, Tuần, Tháng, Năm
enum RepeatType {
  none,     // 0 - Không lặp
  daily,    // 1 - Hàng ngày
  weekly,   // 2 - Hàng tuần
  monthly,  // 3 - Hàng tháng
  yearly;   // 4 - Hàng năm

  int get value => index;

  static RepeatType fromValue(int value) {
    if (value < 0 || value > 4) {
      return RepeatType.none;
    }
    return RepeatType.values[value];
  }

  String get displayName {
    switch (this) {
      case RepeatType.none:
        return 'No repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.yearly:
        return 'Yearly';
    }
  }
}

