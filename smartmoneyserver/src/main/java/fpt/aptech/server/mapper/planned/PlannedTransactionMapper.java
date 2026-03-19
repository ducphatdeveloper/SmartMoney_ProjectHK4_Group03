package fpt.aptech.server.mapper.planned;

import fpt.aptech.server.dto.planned.PlannedTransactionResponse;
import fpt.aptech.server.entity.PlannedTransaction;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class PlannedTransactionMapper {

    public PlannedTransactionResponse toDto(PlannedTransaction p) {
        return PlannedTransactionResponse.builder()
                .id(p.getId())
                .walletId(p.getWallet().getId())
                .walletName(p.getWallet().getWalletName())
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
                .build();
    }

    public List<PlannedTransactionResponse> toDtoList(List<PlannedTransaction> list) {
        return list.stream().map(this::toDto).toList();
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

    // Chuyển bitmask → tên thứ: 42 (T2+T4+T6) → "T2, T4, T6"
    private String buildWeekDayLabel(Integer bitmask) {
        if (bitmask == null) return "";
        String[] labels = {"CN", "T2", "T3", "T4", "T5", "T6", "T7"};
        int[]    values = {  1,    2,    4,    8,   16,   32,   64};
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 7; i++) {
            if ((bitmask & values[i]) != 0) {
                if (!sb.isEmpty()) sb.append(", ");
                sb.append(labels[i]);
            }
        }
        return sb.toString();
    }
}