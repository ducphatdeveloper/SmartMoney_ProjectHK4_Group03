package fpt.aptech.server.utils.date;

import fpt.aptech.server.enums.date.DateRange;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.TemporalAdjusters;
import java.time.temporal.WeekFields;
import java.util.Locale;

/**
 * Lớp tiện ích xử lý ngày tháng dùng chung cho toàn bộ dự án SmartMoney.
 * Toàn bộ dùng Java 8+ built-in, không cần thư viện ngoài.
 * Tuần bắt đầu từ Thứ Hai (chuẩn Việt Nam).
 */
public final class DateUtils {

    private DateUtils() {} // Ngăn không cho ai khởi tạo lớp tiện ích này

    // Hằng số dùng chung để đảm bảo nhất quán
    private static final WeekFields WEEK_FIELDS = WeekFields.of(Locale.FRANCE); // Tuần bắt đầu từ Thứ Hai
    private static final Locale VI_LOCALE = new Locale("vi", "VN");

    // =========================================================================
    // PHẦN 0: RESOLVER (BỘ NÃO TRUNG TÂM)
    // =========================================================================

    /**
     * "Dịch" một khoảng thời gian tương đối (enum) hoặc tuyệt đối (2 biến)
     * thành một mảng [startDate, endDate]. Đây là trái tim của việc xử lý
     * thời gian cho các API báo cáo.
     *
     * @param startDate Ngày bắt đầu (ưu tiên thấp hơn range)
     * @param endDate   Ngày kết thúc (ưu tiên thấp hơn range)
     * @param range     Khoảng thời gian tương đối (VD: THIS_MONTH). Có độ ưu tiên cao nhất.
     * @return Một mảng LocalDateTime gồm 2 phần tử: [0] là startDate, [1] là endDate.
     * @throws IllegalArgumentException nếu không thể xác định được khoảng thời gian.
     */
    public static LocalDateTime[] resolveDateRange(LocalDateTime startDate, LocalDateTime endDate, DateRange range) {
        // Ưu tiên số 1: Xử lý theo 'range' nếu có
        if (range != null) {
            switch (range) {
                case THIS_WEEK:     return getThisWeek();
                case LAST_WEEK:     return getLastWeek();
                case THIS_MONTH:    return getThisMonth();
                case LAST_MONTH:    return getLastMonth();
                case THIS_QUARTER:  return getThisQuarter();
                case LAST_QUARTER:  return getLastQuarter();
                case THIS_YEAR:     return getThisYear();
                case LAST_YEAR:     return getLastYear();
                case FUTURE:        return getFuture(); // Xử lý Tương lai chung
                case CUSTOM:        break; // Nếu là CUSTOM, sẽ rơi xuống logic check startDate/endDate bên dưới
                default:            break; // Các trường hợp khác cũng vậy
            }
        }

        // Ưu tiên số 2: Xử lý theo 'startDate' và 'endDate'
        // Logic này được thực thi khi range=CUSTOM hoặc range=null
        if (startDate != null && endDate != null) {
            return new LocalDateTime[]{startDate, endDate};
        }

        // Nếu không có thông tin nào hợp lệ, báo lỗi
        throw new IllegalArgumentException("API yêu cầu phải có 'range' hoặc cả 'startDate' và 'endDate'.");
    }

    // =========================================================================
    // PHẦN 1: MỐC THỜI GIAN TRONG NGÀY
    // =========================================================================

    /** Lấy thời điểm bắt đầu của một ngày bất kỳ (VD: 2026-03-15 -> 2026-03-15T00:00:00) */
    public static LocalDateTime getStartOfDay(LocalDate date) {
        return date.atStartOfDay();
    }

    /** Lấy thời điểm kết thúc của một ngày bất kỳ (VD: 2026-03-15 -> 2026-03-15T23:59:59.999...) */
    public static LocalDateTime getEndOfDay(LocalDate date) {
        return date.atTime(LocalTime.MAX);
    }

    /** Lấy thời điểm bắt đầu của ngày hôm nay */
    public static LocalDateTime getStartOfToday() {
        return getStartOfDay(LocalDate.now());
    }

    /** Lấy thời điểm kết thúc của ngày hôm nay */
    public static LocalDateTime getEndOfToday() {
        return getEndOfDay(LocalDate.now());
    }

    // =========================================================================
    // PHẦN 2: TUẦN
    // =========================================================================

    /** Lấy ngày Thứ Hai đầu tuần của một ngày bất kỳ */
    public static LocalDateTime getStartOfWeek(LocalDate date) {
        return date.with(WEEK_FIELDS.dayOfWeek(), 1).atStartOfDay();
    }

    /** Lấy ngày Chủ Nhật cuối tuần của một ngày bất kỳ */
    public static LocalDateTime getEndOfWeek(LocalDate date) {
        return date.with(WEEK_FIELDS.dayOfWeek(), 7).atTime(LocalTime.MAX);
    }

    /** Lấy khoảng thời gian [Thứ Hai, Chủ Nhật] của tuần này */
    public static LocalDateTime[] getThisWeek() {
        LocalDate today = LocalDate.now();
        return new LocalDateTime[]{getStartOfWeek(today), getEndOfWeek(today)};
    }

    /** Lấy khoảng thời gian [Thứ Hai, Chủ Nhật] của tuần trước */
    public static LocalDateTime[] getLastWeek() {
        LocalDate lastWeek = LocalDate.now().minusWeeks(1);
        return new LocalDateTime[]{getStartOfWeek(lastWeek), getEndOfWeek(lastWeek)};
    }

    /** Lấy khoảng thời gian [Thứ Hai, Chủ Nhật] của tuần chứa một ngày bất kỳ */
    public static LocalDateTime[] getSpecificWeek(LocalDate date) {
        return new LocalDateTime[]{getStartOfWeek(date), getEndOfWeek(date)};
    }

    // =========================================================================
    // PHẦN 3: THÁNG
    // =========================================================================

    /** Lấy ngày đầu tiên của tháng chứa một ngày bất kỳ */
    public static LocalDateTime getStartOfMonth(LocalDate date) {
        return date.withDayOfMonth(1).atStartOfDay();
    }

    /** Lấy ngày cuối cùng của tháng chứa một ngày bất kỳ */
    public static LocalDateTime getEndOfMonth(LocalDate date) {
        return date.with(TemporalAdjusters.lastDayOfMonth()).atTime(LocalTime.MAX);
    }

    /** Lấy khoảng thời gian của tháng này */
    public static LocalDateTime[] getThisMonth() {
        LocalDate today = LocalDate.now();
        return new LocalDateTime[]{getStartOfMonth(today), getEndOfMonth(today)};
    }

    /** Lấy khoảng thời gian của tháng trước */
    public static LocalDateTime[] getLastMonth() {
        LocalDate lastMonth = LocalDate.now().minusMonths(1);
        return new LocalDateTime[]{getStartOfMonth(lastMonth), getEndOfMonth(lastMonth)};
    }

    /** Lấy khoảng thời gian của một tháng cụ thể trong năm */
    public static LocalDateTime[] getSpecificMonth(int month, int year) {
        LocalDate date = LocalDate.of(year, month, 1);
        return new LocalDateTime[]{getStartOfMonth(date), getEndOfMonth(date)};
    }

    // =========================================================================
    // PHẦN 4: QUÝ
    // =========================================================================

    /** Lấy ngày đầu tiên của quý chứa một ngày bất kỳ */
    public static LocalDateTime getStartOfQuarter(LocalDate date) {
        int currentQuarter = (date.getMonthValue() - 1) / 3 + 1;
        LocalDate firstDay = LocalDate.of(date.getYear(), (currentQuarter - 1) * 3 + 1, 1);
        return firstDay.atStartOfDay();
    }

    /** Lấy ngày cuối cùng của quý chứa một ngày bất kỳ */
    public static LocalDateTime getEndOfQuarter(LocalDate date) {
        int currentQuarter = (date.getMonthValue() - 1) / 3 + 1;
        LocalDate lastDay = LocalDate.of(date.getYear(), currentQuarter * 3, 1)
                .with(TemporalAdjusters.lastDayOfMonth());
        return lastDay.atTime(LocalTime.MAX);
    }

    /** Lấy khoảng thời gian của quý này */
    public static LocalDateTime[] getThisQuarter() {
        LocalDate today = LocalDate.now();
        return new LocalDateTime[]{getStartOfQuarter(today), getEndOfQuarter(today)};
    }

    /** Lấy khoảng thời gian của quý trước */
    public static LocalDateTime[] getLastQuarter() {
        LocalDate lastQuarter = LocalDate.now().minusMonths(3);
        return new LocalDateTime[]{getStartOfQuarter(lastQuarter), getEndOfQuarter(lastQuarter)};
    }

    /** Lấy khoảng thời gian của một quý cụ thể trong năm */
    public static LocalDateTime[] getSpecificQuarter(int quarter, int year) {
        LocalDate date = LocalDate.of(year, (quarter - 1) * 3 + 1, 1);
        return new LocalDateTime[]{getStartOfQuarter(date), getEndOfQuarter(date)};
    }

    // =========================================================================
    // PHẦN 5: NĂM
    // =========================================================================

    /** Lấy ngày đầu tiên của năm chứa một ngày bất kỳ */
    public static LocalDateTime getStartOfYear(LocalDate date) {
        return date.withDayOfYear(1).atStartOfDay();
    }

    /** Lấy ngày cuối cùng của năm chứa một ngày bất kỳ */
    public static LocalDateTime getEndOfYear(LocalDate date) {
        return date.with(TemporalAdjusters.lastDayOfYear()).atTime(LocalTime.MAX);
    }

    /** Lấy khoảng thời gian của năm nay */
    public static LocalDateTime[] getThisYear() {
        LocalDate today = LocalDate.now();
        return new LocalDateTime[]{getStartOfYear(today), getEndOfYear(today)};
    }

    /** Lấy khoảng thời gian của năm trước */
    public static LocalDateTime[] getLastYear() {
        LocalDate lastYear = LocalDate.now().minusYears(1);
        return new LocalDateTime[]{getStartOfYear(lastYear), getEndOfYear(lastYear)};
    }

    /** Lấy khoảng thời gian của một năm cụ thể */
    public static LocalDateTime[] getSpecificYear(int year) {
        LocalDate date = LocalDate.of(year, 1, 1);
        return new LocalDateTime[]{getStartOfYear(date), getEndOfYear(date)};
    }

    // =========================================================================
    // PHẦN 6: TƯƠNG LAI (Dùng chung)
    // =========================================================================

    /**
     * Lấy khoảng thời gian "Tương lai" (từ ngày mai đến vô tận).
     * Dùng chung cho tất cả các chế độ xem.
     */
    public static LocalDateTime[] getFuture() {
        LocalDate tomorrow = LocalDate.now().plusDays(1);
        LocalDate farFuture = LocalDate.of(2099, 12, 31); // Một ngày rất xa
        return new LocalDateTime[]{getStartOfDay(tomorrow), getEndOfDay(farFuture)};
    }

    // =========================================================================
    // PHẦN 7: FORMAT HIỂN THỊ
    // =========================================================================

    /**
     * Format ngày hiển thị thân thiện kiểu app thu chi.
     * VD: "Hôm nay", "Hôm qua", "Thứ Sáu, 14/03"
     */
    public static String formatDisplayDate(LocalDate date) {
        LocalDate today = LocalDate.now();
        if (date.equals(today)) return "Hôm nay";
        if (date.equals(today.minusDays(1))) return "Hôm qua";
        return date.format(DateTimeFormatter.ofPattern("EEEE, dd/MM/yyyy", VI_LOCALE));
    }

    /**
     * Format tháng/năm cho label báo cáo. VD: "Tháng 2/2026"
     */
    public static String formatMonthYear(LocalDate date) {
        return "Tháng " + date.getMonthValue() + "/" + date.getYear();
    }

    /**
     * Format quý/năm cho label báo cáo. VD: "Quý 1/2026"
     */
    public static String formatQuarterYear(LocalDate date) {
        int quarter = (date.getMonthValue() - 1) / 3 + 1;
        return "Quý " + quarter + "/" + date.getYear();
    }

    /**
     * Format tuần/năm cho label báo cáo. VD: "Tuần 11/2026"
     */
    public static String formatWeekYear(LocalDate date) {
        int week = date.get(WEEK_FIELDS.weekOfWeekBasedYear());
        return "Tuần " + week + "/" + date.getYear();
    }
}