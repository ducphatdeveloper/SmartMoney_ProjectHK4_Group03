package fpt.aptech.server.enums.date;

/**
 * Định nghĩa các khoảng thời gian tương đối mà API báo cáo hỗ trợ.
 * <p>
 * Dùng làm tham số `range` trong các API GET, giúp Frontend không cần
 * tự tính toán `startDate` và `endDate` phức tạp.
 */
public enum DateRange {
    // === TUẦN ===
    THIS_WEEK,      // Tuần này (từ Thứ Hai đến Chủ Nhật)
    LAST_WEEK,      // Tuần trước

    // === THÁNG ===
    THIS_MONTH,     // Tháng này
    LAST_MONTH,     // Tháng trước

    // === QUÝ ===
    THIS_QUARTER,   // Quý này
    LAST_QUARTER,   // Quý trước

    // === NĂM ===
    THIS_YEAR,      // Năm nay
    LAST_YEAR,      // Năm trước

    // === TƯƠNG LAI (Dùng chung cho tất cả) ===
    FUTURE,         // Tương lai (từ ngày mai trở đi vô tận)

    /**
     * Trường hợp đặc biệt: Người dùng tự chọn một khoảng ngày bất kỳ.
     * Khi API nhận được `range=CUSTOM`, nó sẽ sử dụng `startDate` và `endDate`
     * được gửi kèm để xác định khoảng thời gian.
     */
    CUSTOM;
}