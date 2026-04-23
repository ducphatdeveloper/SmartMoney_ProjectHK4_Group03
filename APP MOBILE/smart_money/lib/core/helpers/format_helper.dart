// core/helpers/format_helper.dart
// Mirror chính xác CurrencyUtils.java và DateUtils.java của Spring Boot
// Đảm bảo Flutter hiển thị đúng format với backend
import 'package:intl/intl.dart';

class FormatHelper {

  // =============================================
  // PHẦN 1: FORMAT TIỀN TỆ
  // Mirror CurrencyUtils.java
  // =============================================

  // Format đầy đủ với ký hiệu ₫
  // VD: 1500000 → "1.500.000 ₫"
  // Mirror: CurrencyUtils.formatVND()
  static String formatVND(num? amount) {
    if (amount == null) return "0 ₫";
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} ₫';
  }

  // Format số thuần không có ký hiệu (dùng cho input field)
  // VD: 1500000 → "1.500.000"
  // Mirror: CurrencyUtils.formatNumber()
  static String formatNumber(num? amount) {
    if (amount == null) return "0";
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(amount);
  }

  // Format ngắn gọn cho chart label, badge, notification
  // VD: 500000 → "500k" | 1500000 → "1.5tr" | 1500000000 → "1.5tỷ"
  // Mirror: CurrencyUtils.formatShort()
  static String formatShort(num? amount) {
    if (amount == null) return "0";
    final value = amount.toDouble();

    if (value >= 1_000_000_000) {
      final ty = value / 1_000_000_000;
      return '${_formatDecimal(ty)}tỷ';
    }
    if (value >= 1_000_000) {
      final tr = value / 1_000_000;
      return '${_formatDecimal(tr)}tr';
    }
    if (value >= 1_000) {
      final k = value / 1_000;
      return '${_formatDecimal(k)}k';
    }
    return value.toInt().toString();
  }

  // Format theo currency code của user (VND, USD...)
  // Dùng khi cần hiển thị theo currency của từng user
  static String formatByCurrency(num? amount, String? currencyCode) {
    if (amount == null) return "0";
    switch (currencyCode?.toUpperCase()) {
      case 'USD':
        return '\$${NumberFormat('#,##0.00', 'en_US').format(amount)}';
      case 'EUR':
        return '€${NumberFormat('#,##0.00', 'en_EU').format(amount)}';
      case 'VND':
      default:
        return formatVND(amount);
    }
  }

  // =============================================
  // PHẦN 2: FORMAT NGÀY THÁNG
  // Mirror DateUtils.java
  // =============================================

  // Format ngày thân thiện kiểu app thu chi
  // VD: "Today", "Yesterday", "Friday, 14/03"
  // Mirror: DateUtils.formatDisplayDate()
  static String formatDisplayDate(DateTime date) {
    final today    = DateTime.now();
    final todayDate    = DateTime(today.year, today.month, today.day);
    final targetDate   = DateTime(date.year, date.month, date.day);
    final yesterday    = todayDate.subtract(const Duration(days: 1));

    if (targetDate == todayDate)   return "Today";
    if (targetDate == yesterday)   return "Yesterday";

    // Friday, 14/03 — dùng intl cho tiếng Anh
    return DateFormat('EEEE, dd/MM', 'en_US').format(date);
  }

  // Format tháng/năm cho label báo cáo
  // VD: "Tháng 2/2026"
  // Mirror: DateUtils.formatMonthYear()
  static String formatMonthYear(DateTime date) {
    return "Month ${date.month}/${date.year}";
  }

  // Format quý/năm cho label báo cáo
  // VD: "Quý 1/2026"
  // Mirror: DateUtils.formatQuarterYear()
  static String formatQuarterYear(DateTime date) {
    final quarter = ((date.month - 1) ~/ 3) + 1;
    return "Quarter $quarter/${date.year}";
  }

  // Format tuần/năm cho label báo cáo
  // VD: "Tuần 11/2026"
  // Mirror: DateUtils.formatWeekYear()
  static String formatWeekYear(DateTime date) {
    // Tính số tuần theo chuẩn ISO (tuần bắt đầu từ Thứ Hai)
    final week = _isoWeekNumber(date);
    return "Week $week/${date.year}";
  }

  // Format ngày đơn giản dạng dd/MM/yyyy
  // VD: "21/03/2026"
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Format ngày giờ đầy đủ
  // VD: "21/03/2026 05:23"
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  // Parse ISO string từ Spring Boot về DateTime
  // Spring Boot trả về: "2026-03-21T05:23:24.2119158"
  static DateTime? parseFromApi(String? dateString) {
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  // =============================================
  // PHẦN 3: BITMASK NGÀY LẶP LẠI
  // Mirror RepeatDayBitmask.java
  // Dùng cho planned transaction (hóa đơn định kỳ)
  // =============================================

  static const int sunday    = 1;   // 2^0
  static const int monday    = 2;   // 2^1
  static const int tuesday   = 4;   // 2^2
  static const int wednesday = 8;   // 2^3
  static const int thursday  = 16;  // 2^4
  static const int friday    = 32;  // 2^5
  static const int saturday  = 64;  // 2^6

  // Kiểm tra bitmask có chứa ngày không
  // Mirror: RepeatDayBitmask.hasDay()
  static bool hasDay(int bitmask, int day) => (bitmask & day) != 0;

  // Thêm ngày vào bitmask
  // Mirror: RepeatDayBitmask.addDay()
  static int addDay(int bitmask, int day) => bitmask | day;

  // Xóa ngày khỏi bitmask
  // Mirror: RepeatDayBitmask.removeDay()
  static int removeDay(int bitmask, int day) => bitmask & ~day;

  // Lấy danh sách tên ngày từ bitmask — dùng để hiện UI
  // VD: 34 (MONDAY + FRIDAY) → ["Thứ Hai", "Thứ Sáu"]
  static List<String> getDayNames(int bitmask) {
    final days = <String>[];
    if (hasDay(bitmask, monday))    days.add("Monday");
    if (hasDay(bitmask, tuesday))   days.add("Tuesday");
    if (hasDay(bitmask, wednesday)) days.add("Wednesday");
    if (hasDay(bitmask, thursday))  days.add("Thursday");
    if (hasDay(bitmask, friday))    days.add("Friday");
    if (hasDay(bitmask, saturday))  days.add("Saturday");
    if (hasDay(bitmask, sunday))    days.add("Sunday");
    return days;
  }

  // =============================================
  // PHẦN 4: HELPER NỘI BỘ
  // =============================================

  // Mirror: CurrencyUtils.formatDecimal()
  // 1.0 → "1" | 1.5 → "1.5"
  static String _formatDecimal(double value) {
    if (value == value.truncate()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  // Tính số tuần ISO (tuần bắt đầu từ Thứ Hai)
  // Mirror: WeekFields.of(Locale.FRANCE) trong Java
  static int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 1)
        .add(Duration(days: (4 - DateTime(thursday.year, 1, 1).weekday + 7) % 7));
    return ((thursday.difference(firstThursday).inDays) ~/ 7) + 1;
  }
}

//  Tóm tắt
// ```
// core/constants/date_enums.dart  → enum cho API query params
// core/helpers/format_helper.dart → mirror CurrencyUtils + DateUtils + RepeatDayBitmask
//
// Team dùng:
// FormatHelper.formatVND(amount)         → "1.500.000 ₫"
// FormatHelper.formatShort(amount)       → "1.5tr"
// FormatHelper.formatDisplayDate(date)   → "Hôm nay" / "Thứ Sáu, 14/03"
// FormatHelper.formatMonthYear(date)     → "Tháng 3/2026"
// FormatHelper.getDayNames(bitmask)      → ["Thứ Hai", "Thứ Sáu"]
// FormatHelper.parseFromApi(dateString)  → DateTime