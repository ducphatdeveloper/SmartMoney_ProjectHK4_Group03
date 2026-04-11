package fpt.aptech.server.mapper.planned;

import fpt.aptech.server.dto.planned.PlannedTransactionResponse;
import fpt.aptech.server.entity.PlannedTransaction;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.utils.plannedtransaction.RepeatDayBitmask;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Locale;

@Component
@RequiredArgsConstructor // ✅ Sử dụng Lombok để inject TransactionRepository
public class PlannedTransactionMapper {

    // Dependencies
    private final TransactionRepository transactionRepository; // ✅ Inject để kiểm tra giao dịch

    // Format ngày tiếng Việt: "Thứ Ba, 14 tháng 4 2026"
    private static final DateTimeFormatter VN_DATE_FORMATTER =
            DateTimeFormatter.ofPattern("EEEE, dd 'tháng' M yyyy", Locale.of("vi", "VN"));

    public PlannedTransactionResponse toDto(PlannedTransaction p) {
        LocalDate today = LocalDate.now();

        // ══════════════════════════════════════════════════════════════════
        // TÍNH TOÁN CÁC TRƯỜNG TRẠNG THÁI CHO UI
        // ══════════════════════════════════════════════════════════════════

        // --- Bước 1: Khởi tạo các biến ---
        String displayStatus;
        String statusLabel;
        Integer remainingCount = null; // Sẽ tính sau nếu có thể

        // --- Bước 2: Kiểm tra xem kỳ hiện tại đã được trả chưa ---
        // Bills: có lastExecutedAt = đã trả TRỪ KHI nextDueDate đến hạn
        // Recurring: cần kiểm tra transaction thực tế
        boolean hasPaidForCurrentCycle;
        if (p.getPlanType() == 1) {
            // Bills: có lastExecutedAt nhưng nextDueDate đã đến hạn → cần trả lại
            if (p.getLastExecutedAt() != null && !p.getNextDueDate().isBefore(today)) {
                // Đã trả và chưa đến hạn kỳ tiếp theo
                hasPaidForCurrentCycle = true;
            } else {
                // Chưa trả HOẶC đã đến hạn kỳ tiếp theo → cần trả lại
                hasPaidForCurrentCycle = false;
            }
        } else {
            // Recurring: kiểm tra transaction thực tế
            LocalDate cycleDateToCheck = determineCycleDateToCheck(p, today);
            hasPaidForCurrentCycle = hasTransactionForCycle(p, cycleDateToCheck);
        }

        // --- Bước 3: Xác định `displayStatus` theo thứ tự ưu tiên ---
        if (p.getEndDate() != null && p.getEndDate().isBefore(today)) {
            displayStatus = "EXPIRED";
        } else if (!p.getActive()) {
            displayStatus = "INACTIVE";
        } else if (p.getPlanType() == 1 && hasPaidForCurrentCycle) {
            displayStatus = "PAID";
        } else if (p.getPlanType() == 1 && p.getNextDueDate().isBefore(today)) {
            // Bills: nextDueDate quá hạn = OVERDUE
            displayStatus = "OVERDUE";
        } else if (p.getPlanType() != 1 && p.getNextDueDate().isBefore(today) && !hasPaidForCurrentCycle) {
            // Recurring: nextDueDate quá hạn và chưa trả = OVERDUE
            displayStatus = "OVERDUE";
        } else {
            displayStatus = "ACTIVE";
        }

        // --- Bước 4: Xác định `statusLabel` và `remainingCount` ---
        if ("EXPIRED".equals(displayStatus)) {
            statusLabel = "Đã hết hạn ngày " + p.getEndDate().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
        } else if ("OVERDUE".equals(displayStatus)) {
            long daysOver = ChronoUnit.DAYS.between(p.getNextDueDate(), today);
            statusLabel = "Quá hạn " + daysOver + " ngày";
        } else if (p.getEndDate() != null) {
            statusLabel = "Lặp lại đến " + p.getEndDate().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
            // Tính remainingCount dựa trên endDate và beginDate (ước tính)
            remainingCount = calculateRemainingCount(p);
        } else {
            statusLabel = "Lặp lại vô thời hạn";
        }

        // --- Bước 5: Format nextDueDateLabel ---
        // Ẩn nextDueDateLabel khi không còn lần lặp nào nữa:
        //   (a) displayStatus = EXPIRED  → endDate đã qua hôm nay
        //   (b) remainingCount = 0       → tính toán không còn lần nào
        //   (c) nextDueDate > endDate    → lần kế tiếp vượt hạn dừng
        String nextDueDateLabel = null;
        if (p.getNextDueDate() != null) {
            boolean noMoreRepetitions = "EXPIRED".equals(displayStatus)
                    || (remainingCount != null && remainingCount == 0)
                    || (p.getEndDate() != null && p.getNextDueDate().isAfter(p.getEndDate()));
            if (!noMoreRepetitions) {
                nextDueDateLabel = p.getNextDueDate().format(VN_DATE_FORMATTER);
            }
        }


        // ══════════════════════════════════════════════════════════════════
        // BUILD RESPONSE DTO
        // ══════════════════════════════════════════════════════════════════
        return PlannedTransactionResponse.builder()
                .id(p.getId())
                .walletId(p.getWallet().getId())
                .walletName(p.getWallet().getWalletName())
                .walletIcon(p.getWallet().getGoalImageUrl())
                .categoryId(p.getCategory().getId())
                .categoryName(p.getCategory().getCtgName())
                .categoryIcon(p.getCategory().getCtgIconUrl())
                .categoryType(p.getCategory().getCtgType())
                .debtId(p.getDebt() != null ? p.getDebt().getId() : null)
                .debtPersonName(p.getDebt() != null ? p.getDebt().getPersonName() : null)
                .note(p.getNote())
                .amount(p.getAmount())
                .planType(p.getPlanType())
                .repeatType(p.getRepeatType())
                .repeatInterval(p.getRepeatInterval())
                .repeatOnDayVal(p.getRepeatOnDayVal())
                .beginDate(p.getBeginDate())
                .nextDueDate(p.getNextDueDate())
                .lastExecutedAt(p.getLastExecutedAt())
                .endDate(p.getEndDate())
                .active(p.getActive())
                .createdAt(p.getCreatedAt())
                .repeatDescription(buildRepeatDescription(p))

                // Các trường trạng thái đã tính toán
                .displayStatus(displayStatus)
                .statusLabel(statusLabel)
                .remainingCount(remainingCount)
                .nextDueDateLabel(nextDueDateLabel)
                .build();
    }

    public List<PlannedTransactionResponse> toDtoList(List<PlannedTransaction> list) {
        return list.stream().map(this::toDto).toList();
    }

    /**
     * [HELPER] Tính số lần lặp lại còn lại dựa trên endDate và nextDueDate.
     * Logic: Tính số lần từ nextDueDate đến endDate, thay vì dựa trên lastExecutedAt
     */
    private Integer calculateRemainingCount(PlannedTransaction p) {
        if (p.getEndDate() == null || p.getBeginDate() == null) return null;
        
        LocalDate today = LocalDate.now();
        
        // Nếu endDate đã qua rồi → không còn lần nào
        if (p.getEndDate().isBefore(today)) {
            return 0;
        }
        
        // Nếu không có nextDueDate → fallback về beginDate
        LocalDate fromDate = p.getNextDueDate() != null ? p.getNextDueDate() : p.getBeginDate();
        
        // Nếu fromDate đã qua endDate → không còn lần nào
        if (fromDate.isAfter(p.getEndDate())) {
            return 0;
        }
        
        int interval = p.getRepeatInterval() != null ? p.getRepeatInterval() : 1;
        
        // Tính số lần còn lại từ fromDate đến endDate
        return switch (p.getRepeatType()) {
            case 1 -> (int) ChronoUnit.DAYS.between(fromDate, p.getEndDate()) / interval + 1;
            case 2 -> (int) ChronoUnit.WEEKS.between(fromDate, p.getEndDate()) / interval + 1;
            case 3 -> (int) ChronoUnit.MONTHS.between(fromDate, p.getEndDate()) / interval + 1;
            case 4 -> (int) ChronoUnit.YEARS.between(fromDate, p.getEndDate()) / interval + 1;
            default -> 0;
        };
    }

    /**
     * [HELPER] Xác định ngày cần kiểm tra transaction cho trạng thái PAID.
     * Logic: Nếu nextDueDate > today → kiểm tra kỳ trước đó (đã thanh toán)
     *        Nếu nextDueDate <= today → kiểm tra nextDueDate (kỳ hiện tại)
     */
    private LocalDate determineCycleDateToCheck(PlannedTransaction p, LocalDate today) {
        if (p.getNextDueDate() == null) {
            return p.getBeginDate(); // Fallback
        }
        
        // Nếu nextDueDate là ngày tương lai → cần kiểm tra kỳ trước đó đã được trả chưa
        if (p.getNextDueDate().isAfter(today)) {
            // QUAN TRỌNG: Nếu có lastExecutedAt → kiểm tra ngày đó
            if (p.getLastExecutedAt() != null) {
                return p.getLastExecutedAt();
            }
            // Nếu không có lastExecutedAt → tính ngày trước đó
            return calculatePreviousDueDate(p, p.getNextDueDate());
        }
        
        // Nếu nextDueDate là hôm nay hoặc quá khứ → kiểm tra chính nextDueDate
        return p.getNextDueDate();
    }

    /**
     * [HELPER] Tính ngày đến hạn trước đó từ một ngày cho trước.
     * Dùng để kiểm tra xem kỳ trước đó đã được trả chưa.
     */
    private LocalDate calculatePreviousDueDate(PlannedTransaction p, LocalDate from) {
        int interval = p.getRepeatInterval() != null ? p.getRepeatInterval() : 1;

        return switch (p.getRepeatType()) {
            case 1 -> from.minusDays(interval);
            case 2 -> calculatePreviousWeekDay(p.getRepeatOnDayVal(), from, interval);
            case 3 -> from.minusMonths(interval);
            case 4 -> from.minusYears(interval);
            default -> from.minusMonths(1);
        };
    }

    /**
     * [HELPER] Tính ngày trong tuần trước đó theo bitmask.
     */
    private LocalDate calculatePreviousWeekDay(Integer bitmask, LocalDate from, int intervalWeeks) {
        if (bitmask == null || bitmask == 0) return from.minusWeeks(intervalWeeks);

        int[] javaToMask = {0,
                RepeatDayBitmask.MONDAY, RepeatDayBitmask.TUESDAY,
                RepeatDayBitmask.WEDNESDAY, RepeatDayBitmask.THURSDAY,
                RepeatDayBitmask.FRIDAY, RepeatDayBitmask.SATURDAY,
                RepeatDayBitmask.SUNDAY};

        // Tìm ngày hợp lệ gần nhất trong quá khứ (tối đa 6 ngày)
        for (int offset = 1; offset <= 6; offset++) {
            LocalDate candidate = from.minusDays(offset);
            if (candidate.getDayOfWeek() == DayOfWeek.MONDAY && offset > 1) break; // Đã sang tuần trước
            int mask = javaToMask[candidate.getDayOfWeek().getValue()];
            if ((bitmask & mask) != 0) return candidate;
        }

        // Fallback: trừ đi intervalWeeks tuần
        return from.minusWeeks(intervalWeeks);
    }

    /**
     * [HELPER] Kiểm tra xem có giao dịch nào được tạo cho một PlannedTransaction
     * trong một ngày cụ thể (đại diện cho một kỳ) hay không.
     * @param p PlannedTransaction cần kiểm tra
     * @param cycleDate Ngày của kỳ cần kiểm tra
     * @return true nếu đã có giao dịch, false nếu chưa
     */
    private boolean hasTransactionForCycle(PlannedTransaction p, LocalDate cycleDate) {
        if (cycleDate == null) return false;
        LocalDateTime startOfCycle = cycleDate.atStartOfDay();
        LocalDateTime endOfCycle = cycleDate.atTime(23, 59, 59);
        // Sử dụng phương thức query đã có sẵn trong TransactionRepository
        return transactionRepository.existsByPlannedTransactionIdAndAccountIdAndTransDateBetween(
                p.getId(),
                p.getAccount().getId(),
                startOfCycle,
                endOfCycle
        );
    }


    // ── Tạo mô tả lịch lặp để Flutter hiển thị (không lưu DB) ──────────
    // VD: "Lặp vào ngày 14, mỗi 2 tháng" | "Lặp mỗi T2, T4, T6 hàng tuần"
    private String buildRepeatDescription(PlannedTransaction p) {
        int interval = p.getRepeatInterval() != null ? p.getRepeatInterval() : 1;

        return switch (p.getRepeatType()) {
            case 1 -> interval == 1
                    ? "Lặp mỗi ngày"
                    : "Lặp mỗi " + interval + " ngày";

            case 2 -> {
                String days = buildWeekDayLabel(p.getRepeatOnDayVal());
                yield interval == 1
                        ? "Lặp mỗi " + days + " hàng tuần"
                        : "Lặp mỗi " + days + ", " + interval + " tuần/lần";
            }

            case 3 -> {
                int day = p.getBeginDate().getDayOfMonth();
                yield interval == 1
                        ? "Lặp vào ngày " + day + " hàng tháng"
                        : "Lặp vào ngày " + day + ", mỗi " + interval + " tháng";
            }

            case 4 -> interval == 1
                    ? "Lặp mỗi năm"
                    : "Lặp mỗi " + interval + " năm";

            default -> "";
        };
    }

    // ✅ Dùng RepeatDayBitmask util thay vì inline code
    // Chuyển bitmask → tên thứ: 34 (T2+T6) → "T2, T6"
    private String buildWeekDayLabel(Integer bitmask) {
        if (bitmask == null || bitmask == 0) return "";
        String[] labels = {"CN", "T2", "T3", "T4", "T5", "T6", "T7"};
        int[]    values = {
                RepeatDayBitmask.SUNDAY, RepeatDayBitmask.MONDAY,
                RepeatDayBitmask.TUESDAY, RepeatDayBitmask.WEDNESDAY,
                RepeatDayBitmask.THURSDAY, RepeatDayBitmask.FRIDAY,
                RepeatDayBitmask.SATURDAY
        };
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 7; i++) {
            if (RepeatDayBitmask.hasDay(bitmask, values[i])) {
                if (!sb.isEmpty()) sb.append(", ");
                sb.append(labels[i]);
            }
        }
        return sb.toString();
    }
}
