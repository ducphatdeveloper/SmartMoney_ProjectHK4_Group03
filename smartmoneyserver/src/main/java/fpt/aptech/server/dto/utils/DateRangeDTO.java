package fpt.aptech.server.dto.utils;

import fpt.aptech.server.enums.date.DateRangeType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * DTO chứa thông tin về một khoảng thời gian để hiển thị trên thanh trượt.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DateRangeDTO {
    /**
     * Nhãn hiển thị cho người dùng.
     * VD: "Tháng 5/2026", "Hôm nay", "Q2 2026"
     */
    private String label;

    /**
     * Thời điểm bắt đầu của khoảng thời gian.
     */
    private LocalDateTime startDate;

    /**
     * Thời điểm kết thúc của khoảng thời gian.
     */
    private LocalDateTime endDate;

    /**
     * Phân loại khoảng thời gian này là quá khứ, hiện tại hay tương lai.
     */
    private DateRangeType type;
}