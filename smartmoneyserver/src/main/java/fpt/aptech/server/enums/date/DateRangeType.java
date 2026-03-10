package fpt.aptech.server.enums.date;

/**
 * Phân loại một khoảng thời gian là quá khứ, hiện tại, tương lai, hoặc tùy chỉnh.
 * <p>
 * Dùng trong {@code DateRangeDTO} để giúp Frontend quyết định cách hiển thị
 * và xử lý logic một cách đồng bộ.
 */
public enum DateRangeType {
    PAST,       // Khoảng thời gian trong quá khứ (VD: "Tháng trước")
    CURRENT,    // Khoảng thời gian hiện tại (VD: "Tháng này")
    FUTURE,     // Khoảng thời gian trong tương lai (VD: "Tháng sau")

    /**
     * Trường hợp đặc biệt do Frontend tự tạo ra sau khi người dùng
     * chọn một khoảng ngày tùy ý trên lịch. Giúp đồng bộ hóa việc
     * hiển thị trên thanh trượt thời gian.
     */
    CUSTOM;
}