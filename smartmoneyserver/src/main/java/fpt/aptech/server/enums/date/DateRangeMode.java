package fpt.aptech.server.enums.date;

/**
 * Chế độ xem thời gian mà Frontend yêu cầu "nhà máy" sản xuất.
 * <p>
 * Dùng làm tham số `mode` cho API {@code /api/utils/date-ranges} để
 * quyết định xem nên tạo danh sách theo Ngày, Tuần, Tháng, Quý, hay Năm.
 */
public enum DateRangeMode {
    DAILY,      // Theo ngày
    WEEKLY,     // Theo tuần
    MONTHLY,    // Theo tháng
    QUARTERLY,  // Theo quý
    YEARLY;     // Theo năm
}