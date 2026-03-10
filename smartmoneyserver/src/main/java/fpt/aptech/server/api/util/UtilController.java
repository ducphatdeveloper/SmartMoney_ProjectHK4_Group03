package fpt.aptech.server.api.util;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.utils.DateRangeDTO;
import fpt.aptech.server.enums.date.DateRangeMode;
import fpt.aptech.server.enums.date.DateRangeType;
import fpt.aptech.server.utils.date.DateUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/utils")
@RequiredArgsConstructor
public class UtilController {

    /**
     * API sản xuất danh sách khoảng thời gian để Frontend vẽ thanh trượt ngang.
     *
     * <p><b>Cách dùng:</b> Frontend gọi API này một lần khi người dùng đổi chế độ xem,
     * sau đó dùng {@code startDate}/{@code endDate} từ DTO được chọn để gọi các API
     * giao dịch và báo cáo.</p>
     *
     * <p><b>Ví dụ kết quả theo từng mode:</b></p>
     * <ul>
     *   <li>DAILY:     [..., "02/03", "03/03", "Hôm qua", "Hôm nay", "Tương lai"]</li>
     *   <li>WEEKLY:    [..., "17/02/2026 - 23/02/2026", "Tuần trước", "Tuần này", "Tương lai"]</li>
     *   <li>MONTHLY:   [..., "Tháng 1/2026", "Tháng 2/2026", "Tháng trước", "Tháng này", "Tương lai"]</li>
     *   <li>QUARTERLY: [..., "Quý 3/2025", "Quý 4/2025", "Quý 1/2026", "Quý 2/2026", "Tương lai"]</li>
     *   <li>YEARLY:    [..., "2023", "2024", "Năm trước", "Năm nay", "Tương lai"]</li>
     * </ul>
     *
     * @param mode      Chế độ xem: DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY
     * @param pastUnits Số đơn vị quá khứ cần tạo (mặc định 24)
     * @param futureUnits Số đơn vị tương lai (mặc định 1, luôn gộp thành 1 tab "Tương lai")
     */
    @GetMapping("/date-ranges")
    public ResponseEntity<ApiResponse<List<DateRangeDTO>>> getDateRanges(
            @RequestParam("mode") DateRangeMode mode,
            @RequestParam(value = "past", defaultValue = "24") int pastUnits,
            @RequestParam(value = "future", defaultValue = "1") int futureUnits) {

        List<DateRangeDTO> ranges = new ArrayList<>();
        LocalDate today = LocalDate.now();

        // 1. Tạo các khoảng thời gian trong quá khứ.
        //    Dùng add(0, ...) để thêm vào ĐẦU list, đảm bảo thứ tự từ xa → gần.
        //    VD: lặp i=24 trước (xa nhất), i=1 sau (gần nhất → sẽ đứng đầu list)
        for (int i = 1; i <= pastUnits; i++) {
            LocalDate targetDate = getPastDate(today, mode, i);
            ranges.add(0, createDateRangeDTO(targetDate, mode, DateRangeType.PAST));
        }

        // 2. Tạo khoảng thời gian hiện tại (Hôm nay / Tuần này / Tháng này...)
        ranges.add(createDateRangeDTO(today, mode, DateRangeType.CURRENT));

        // 3. Tạo đúng 1 tab "Tương lai" ở cuối thanh trượt.
        //    Không phân biệt ngày/tuần/tháng cụ thể — Frontend chỉ cần 1 điểm neo tương lai.
        if (futureUnits > 0) {
            LocalDate futureDate = getFutureDate(today, mode, 1);
            ranges.add(createDateRangeDTO(futureDate, mode, DateRangeType.FUTURE));
        }

        return ResponseEntity.ok(ApiResponse.success(ranges));
    }

    /**
     * Tính ngày đại diện cho một đơn vị trong quá khứ.
     * VD: QUARTERLY, units=2 → lùi 6 tháng → rơi vào Q4 2025 (nếu hôm nay là Q2 2026)
     */
    private LocalDate getPastDate(LocalDate today, DateRangeMode mode, int units) {
        switch (mode) {
            case DAILY:     return today.minusDays(units);
            case WEEKLY:    return today.minusWeeks(units);
            case MONTHLY:   return today.minusMonths(units);
            case QUARTERLY: return today.minusMonths(units * 3L); // 1 quý = 3 tháng
            case YEARLY:    return today.minusYears(units);
            default:        throw new IllegalArgumentException("Chế độ không hợp lệ: " + mode);
        }
    }

    /**
     * Tính ngày đại diện cho một đơn vị trong tương lai.
     */
    private LocalDate getFutureDate(LocalDate today, DateRangeMode mode, int units) {
        switch (mode) {
            case DAILY:     return today.plusDays(units);
            case WEEKLY:    return today.plusWeeks(units);
            case MONTHLY:   return today.plusMonths(units);
            case QUARTERLY: return today.plusMonths(units * 3L);
            case YEARLY:    return today.plusYears(units);
            default:        throw new IllegalArgumentException("Chế độ không hợp lệ: " + mode);
        }
    }

    /**
     * "Nhà máy" tạo ra một DateRangeDTO hoàn chỉnh từ một ngày đại diện và chế độ xem.
     *
     * <p><b>Quy tắc tạo label:</b></p>
     * <ul>
     *   <li>FUTURE     → luôn là "Tương lai" (gộp mọi ngày tương lai thành 1 tab)</li>
     *   <li>DAILY      → "Hôm nay", "Hôm qua", hoặc "dd/MM"</li>
     *   <li>WEEKLY     → "Tuần này", "Tuần trước", hoặc "dd/MM/yyyy - dd/MM/yyyy"</li>
     *   <li>MONTHLY    → "Tháng này", "Tháng trước", hoặc "Tháng M/YYYY"</li>
     *   <li>QUARTERLY  → luôn dạng "Quý x/YYYY" (không có label đặc biệt "Quý này/trước"
     *                    vì 1 năm có 4 quý, người dùng cần thấy số quý cụ thể để không nhầm)</li>
     *   <li>YEARLY     → "Năm nay", "Năm trước", hoặc "YYYY"</li>
     * </ul>
     */
    private DateRangeDTO createDateRangeDTO(LocalDate date, DateRangeMode mode, DateRangeType type) {
        LocalDateTime[] dates;
        String label;

        if (type == DateRangeType.FUTURE) {
            // Tab tương lai luôn gộp thành 1 — không cần label cụ thể
            label = "Tương lai";
            // Logic đặc biệt cho FUTURE: endDate là vô tận (2099-12-31)
            dates = new LocalDateTime[]{
                DateUtils.getStartOfDay(date), // Bắt đầu từ ngày mai (hoặc ngày tương lai được truyền vào)
                DateUtils.getEndOfDay(LocalDate.of(2099, 12, 31)) // Kết thúc ở tương lai xa
            };
            return new DateRangeDTO(label, dates[0], dates[1], type);
        } else {
            switch (mode) {
                case DAILY:
                    if (type == DateRangeType.CURRENT)                          label = "Hôm nay";
                    else if (date.equals(LocalDate.now().minusDays(1)))         label = "Hôm qua";
                    else                                                         label = date.format(DateTimeFormatter.ofPattern("dd/MM"));
                    break;

                case WEEKLY:
                    if (type == DateRangeType.CURRENT)                          label = "Tuần này";
                    else if (DateUtils.getStartOfWeek(date).equals(
                             DateUtils.getStartOfWeek(LocalDate.now().minusWeeks(1)))) label = "Tuần trước";
                    else {
                        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy");
                        String start = DateUtils.getStartOfWeek(date).format(formatter);
                        String end = DateUtils.getEndOfWeek(date).format(formatter);
                        label = start + " - " + end;
                    }
                    break;

                case MONTHLY:
                    if (type == DateRangeType.CURRENT)                          label = "Tháng này";
                    else if (date.withDayOfMonth(1).equals(
                             LocalDate.now().withDayOfMonth(1).minusMonths(1))) label = "Tháng trước";
                    else                                                         label = DateUtils.formatMonthYear(date);
                    break;

                case QUARTERLY:
                    // Luôn hiển thị "Quý 1/2026", "Quý 2/2026"... để người dùng biết chính xác đang ở quý nào.
                    // Không dùng label "Quý này/Quý trước" vì 1 năm có 4 quý — dễ gây nhầm lẫn.
                    label = DateUtils.formatQuarterYear(date);
                    break;

                case YEARLY:
                    if (type == DateRangeType.CURRENT)                          label = "Năm nay";
                    else if (date.getYear() == LocalDate.now().getYear() - 1)   label = "Năm trước";
                    else                                                         label = String.valueOf(date.getYear());
                    break;

                default:
                    throw new IllegalArgumentException("Chế độ không hợp lệ: " + mode);
            }
        }

        // Tính startDate và endDate tương ứng với ngày đại diện và mode (cho các trường hợp không phải FUTURE)
        switch (mode) {
            case DAILY:     dates = new LocalDateTime[]{DateUtils.getStartOfDay(date), DateUtils.getEndOfDay(date)}; break;
            case WEEKLY:    dates = DateUtils.getSpecificWeek(date); break;
            case MONTHLY:   dates = DateUtils.getSpecificMonth(date.getMonthValue(), date.getYear()); break;
            case QUARTERLY: dates = DateUtils.getSpecificQuarter((date.getMonthValue() - 1) / 3 + 1, date.getYear()); break;
            case YEARLY:    dates = DateUtils.getSpecificYear(date.getYear()); break;
            default:        throw new IllegalArgumentException("Chế độ không hợp lệ: " + mode);
        }

        return new DateRangeDTO(label, dates[0], dates[1], type);
    }
}