package fpt.aptech.server.utils.currency;

import java.math.BigDecimal;
import java.text.NumberFormat;
import java.util.Locale;

/**
 * Lớp tiện ích format tiền tệ dùng chung cho toàn bộ dự án SmartMoney.
 * Đảm bảo nhất quán khi hiển thị số tiền trên toàn bộ ứng dụng.
 */
public final class CurrencyUtils {

    private CurrencyUtils() {} // Ngăn khởi tạo

    private static final Locale VN_LOCALE = new Locale("vi", "VN");

    // =========================================================================
    // PHẦN 1: FORMAT ĐẦY ĐỦ
    // =========================================================================

    /**
     * Format số tiền đầy đủ với ký hiệu ₫.
     * VD: 1500000 → "1.500.000 ₫"
     */
    public static String formatVND(BigDecimal amount) {
        if (amount == null) return "0 ₫";
        NumberFormat formatter = NumberFormat.getNumberInstance(VN_LOCALE);
        formatter.setMaximumFractionDigits(0);
        return formatter.format(amount) + " ₫";
    }

    /**
     * Format số tiền đầy đủ không có ký hiệu ₫ (dùng cho API response).
     * VD: 1500000 → "1.500.000"
     */
    public static String formatNumber(BigDecimal amount) {
        if (amount == null) return "0";
        NumberFormat formatter = NumberFormat.getNumberInstance(VN_LOCALE);
        formatter.setMaximumFractionDigits(0);
        return formatter.format(amount);
    }

    // =========================================================================
    // PHẦN 2: FORMAT NGẮN GỌN (Dùng cho chart label, badge, notification)
    // =========================================================================

    /**
     * Format số tiền ngắn gọn.
     * VD:
     * - 500.000       → "500k"
     * - 1.500.000     → "1.5tr"
     * - 10.000.000    → "10tr"
     * - 1.500.000.000 → "1.5tỷ"
     */
    public static String formatShort(BigDecimal amount) {
        if (amount == null) return "0";

        double value = amount.doubleValue();

        if (value >= 1_000_000_000) {
            double ty = value / 1_000_000_000;
            return formatDecimal(ty) + "tỷ";
        }
        if (value >= 1_000_000) {
            double tr = value / 1_000_000;
            return formatDecimal(tr) + "tr";
        }
        if (value >= 1_000) {
            double k = value / 1_000;
            return formatDecimal(k) + "k";
        }
        return String.valueOf((long) value);
    }

    // =========================================================================
    // PHẦN 3: HELPER NỘI BỘ
    // =========================================================================

    /**
     * Format số thập phân: bỏ .0 nếu là số nguyên, giữ 1 chữ số nếu có phần thập phân.
     * VD: 1.0 → "1" | 1.5 → "1.5"
     */
    private static String formatDecimal(double value) {
        if (value == (long) value) {
            return String.valueOf((long) value);
        }
        return String.format("%.1f", value);
    }
}