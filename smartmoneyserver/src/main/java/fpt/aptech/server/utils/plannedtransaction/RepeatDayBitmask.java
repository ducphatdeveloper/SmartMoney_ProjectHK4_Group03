package fpt.aptech.server.utils.plannedtransaction;

/**
 * Lớp tiện ích để xử lý bitmask cho các ngày trong tuần.
 * Dùng cho trường tPlannedTransactions.repeat_on_day_val
 */
public final class RepeatDayBitmask {

    // Ngăn không cho ai khởi tạo lớp tiện ích này
    private RepeatDayBitmask() {}

    public static final int SUNDAY    = 1;  // 2^0
    public static final int MONDAY    = 2;  // 2^1
    public static final int TUESDAY   = 4;  // 2^2
    public static final int WEDNESDAY = 8;  // 2^3
    public static final int THURSDAY  = 16; // 2^4
    public static final int FRIDAY    = 32; // 2^5
    public static final int SATURDAY  = 64; // 2^6

    /**
     * Kiểm tra xem một bitmask có chứa một ngày cụ thể không.
     * @param bitmask Giá trị từ database (VD: 34)
     * @param day     Hằng số ngày cần check (VD: MONDAY)
     * @return true nếu ngày đó được chọn
     */
    public static boolean hasDay(int bitmask, int day) {
        return (bitmask & day) != 0;
    }

    /**
     * Thêm một ngày vào bitmask.
     * @param bitmask Bitmask hiện tại
     * @param day     Ngày cần thêm
     * @return Bitmask mới
     */
    public static int addDay(int bitmask, int day) {
        return bitmask | day;
    }

    /**
     * Xóa một ngày khỏi bitmask.
     * @param bitmask Bitmask hiện tại
     * @param day     Ngày cần xóa
     * @return Bitmask mới
     */
    public static int removeDay(int bitmask, int day) {
        return bitmask & ~day;
    }
}