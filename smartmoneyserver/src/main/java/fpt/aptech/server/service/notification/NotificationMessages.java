package fpt.aptech.server.service.notification;

import fpt.aptech.server.utils.currency.CurrencyUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/**
 * Tập trung toàn bộ template thông báo của hệ thống.
 *
 * Mỗi module chỉ cần gọi static method tương ứng → nhận NotificationContent
 * → truyền vào NotificationService.createNotification().
 *
 * Không lưu gì vào DB ở đây — chỉ tạo title + content.
 *
 * ─── Cách dùng ─────────────────────────────────────────────────────────────
 *   NotificationContent msg = NotificationMessages.budgetWarning("Ăn uống", 85, spent, total);
 *   notificationService.createNotification(account, msg.title(), msg.content(),
 *           NotificationType.BUDGET, budgetId, null);
 * ────────────────────────────────────────────────────────────────────────────
 */
public final class NotificationMessages {

    private NotificationMessages() {} // Utility class — không cho khởi tạo

    private static final DateTimeFormatter VN_DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final Locale VI = new Locale("vi", "VN");

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 1 — TRANSACTION
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Giao dịch được ghi nhận thành công.
     * Dùng khi: TransactionService.createTransaction() hoàn thành.
     */
    public static NotificationContent transactionCreated(boolean isIncome,
                                                         BigDecimal amount,
                                                         String categoryName,
                                                         String walletName) {
        String type = isIncome ? "thu nhập" : "chi tiêu";
        String title = "Giao dịch mới";
        String content = String.format("Đã ghi nhận %s %s - %s vào ví %s",
                type, CurrencyUtils.formatVND(amount), categoryName, walletName);
        return new NotificationContent(title, content);
    }

    /**
     * Giao dịch lớn bất thường (vượt ngưỡng cảnh báo do user cài đặt).
     * Dùng khi: tạo transaction có amount > threshold.
     * (Để sẵn cho tương lai — khi thêm tính năng cài ngưỡng cảnh báo)
     */
    public static NotificationContent largeTransactionAlert(BigDecimal amount,
                                                            String categoryName) {
        String title = "Giao dịch lớn";
        String content = String.format("Phát hiện giao dịch lớn: %s cho %s. Hãy kiểm tra lại!",
                CurrencyUtils.formatVND(amount), categoryName);
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc nhở giao dịch theo lịch do user đặt.
     * Dùng khi: TransactionService.createTransaction() / updateTransaction()
     *           khi request.reminderDate() != null.
     *
     * Ví dụ output:
     *   Title  : "💰 Nhắc nhở: Khoản thu của bạn"
     *   Content: "Bạn đã thu 1.500.000 ₫ - Ăn uống ngày 11/04/2026 lúc 14:30 vào Ví chính.
     *             Ghi chú: Ăn trưa team. | Sự kiện: Sinh nhật bạn. | Hóa đơn định kỳ. | Khoản nợ: Anh Tuấn."
     *
     * @param isIncome       true = khoản thu (income), false = khoản chi (expense)
     * @param amount         số tiền của giao dịch
     * @param categoryName   tên danh mục (VD: "Ăn uống", "Lương")
     * @param sourceName     tên ví hoặc mục tiêu tiết kiệm đã chọn
     * @param transDate      thời điểm giao dịch — dùng để format "ngày dd/MM/yyyy lúc HH:mm"
     * @param note           ghi chú giao dịch (nullable — bỏ qua nếu null/blank)
     * @param eventName      tên sự kiện liên kết (nullable — bỏ qua nếu null)
     * @param plannedType    loại giao dịch định kỳ: 1=Hóa đơn, 2=Định kỳ tự động (nullable)
     * @param debtPersonName tên người liên quan trong sổ nợ (nullable — bỏ qua nếu null)
     */
    public static NotificationContent transactionReminder(boolean isIncome,
                                                          BigDecimal amount,
                                                          String categoryName,
                                                          String sourceName,
                                                          LocalDateTime transDate,
                                                          String note,
                                                          String eventName,
                                                          Integer plannedType,
                                                          String debtPersonName) {
        // Bước 1: Xác định nhãn loại giao dịch — "thu" hoặc "chi"
        String type = isIncome ? "thu" : "chi";

        // Bước 2: Xác định tiêu đề thông báo theo loại giao dịch
        //   isIncome = true  → khoản thu → icon 💰
        //   isIncome = false → khoản chi → icon 💸
        String title = isIncome
                ? "💰 Nhắc nhở: Khoản thu của bạn"
                : "💸 Nhắc nhở: Khoản chi của bạn";

        // Bước 3: Format ngày giờ đầy đủ từ transDate
        //   VD: transDate = 2026-04-11T14:30:00 → "ngày 11/04/2026 lúc 14:30"
        //   %02d: đảm bảo ngày/tháng/giờ/phút luôn 2 chữ số (VD: 7 → "07")
        String dateTimeLabel = String.format("ngày %02d/%02d/%d lúc %02d:%02d",
                transDate.getDayOfMonth(),   // ngày trong tháng (1-31)
                transDate.getMonthValue(),   // tháng (1-12)
                transDate.getYear(),         // năm 4 chữ số
                transDate.getHour(),         // giờ (0-23)
                transDate.getMinute()        // phút (0-59)
        );

        // Bước 4: Ghép nội dung thông báo chính
        //   Cấu trúc: "Bạn đã [thu/chi] [số tiền] - [danh mục] [ngày giờ] vào [nguồn tiền]."
        StringBuilder content = new StringBuilder(String.format(
                "Bạn đã %s %s - %s %s vào %s.",
                type,
                CurrencyUtils.formatVND(amount),
                categoryName,
                dateTimeLabel,
                sourceName
        ));

        // Bước 5: Nối các thông tin bổ sung (chỉ thêm nếu có giá trị)
        if (note != null && !note.isBlank()) {
            content.append(" Ghi chú: ").append(note.trim()).append(".");
        }
        if (eventName != null && !eventName.isBlank()) {
            content.append(" Sự kiện: ").append(eventName.trim()).append(".");
        }
        if (plannedType != null) {
            content.append(plannedType == 1 ? " Hóa đơn định kỳ." : " Giao dịch lặp lại tự động.");
        }
        if (debtPersonName != null && !debtPersonName.isBlank()) {
            content.append(" Khoản nợ: ").append(debtPersonName.trim()).append(".");
        }

        return new NotificationContent(title, content.toString());
    }

    /**
     * Overload không có thông tin bổ sung — dùng khi không có note/event/planned/debt.
     * Giữ backward-compatibility cho các call site cũ (5 tham số).
     */
    public static NotificationContent transactionReminder(boolean isIncome,
                                                          BigDecimal amount,
                                                          String categoryName,
                                                          String sourceName,
                                                          LocalDateTime transDate) {
        return transactionReminder(isIncome, amount, categoryName, sourceName, transDate,
                null, null, null, null);
    }

    /**
     * Giao dịch được khôi phục bởi Admin.
     */
    public static NotificationContent transactionRestored(BigDecimal amount) {
        String title = "Giao dịch được khôi phục ♻️";
        String content = String.format("Giao dịch trị giá %s đã được Admin khôi phục thành công. Vui lòng kiểm tra lại số dư ví.",
                CurrencyUtils.formatVND(amount));
        return new NotificationContent(title, content);
    }

    /**
     * Tất cả giao dịch đã xóa được khôi phục bởi Admin.
     */
    public static NotificationContent allTransactionsRestored() {
        String title = "Khôi phục dữ liệu thành công ♻️";
        String content = "Tất cả giao dịch đã bị xóa của bạn đã được Admin khôi phục lại trạng thái ban đầu.";
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 2 — SAVING GOAL
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Đạt mốc % mục tiêu (25%, 50%, 75%).
     * Dùng khi: depositToSavingGoal() khiến progressPercent vượt mốc.
     */
    public static NotificationContent savingMilestone(String goalName,
                                                      int percent,
                                                      BigDecimal remaining) {
        String title = "Mục tiêu tiến triển 🎯";
        String content = String.format("Bạn đã đạt %d%% mục tiêu \"%s\". Còn %s nữa là hoàn thành!",
                percent, goalName, CurrencyUtils.formatVND(remaining));
        return new NotificationContent(title, content);
    }

    /**
     * Mục tiêu hoàn thành 100%.
     * Dùng khi: depositToSavingGoal() → GoalStatus.COMPLETED.
     */
    public static NotificationContent savingCompleted(String goalName,
                                                      BigDecimal targetAmount) {
        String title = "Mục tiêu hoàn thành 🎉";
        String content = String.format("Chúc mừng! Bạn đã hoàn thành mục tiêu \"%s\" với %s.",
                goalName, CurrencyUtils.formatVND(targetAmount));
        return new NotificationContent(title, content);
    }

    /**
     * Mục tiêu sắp đến hạn (còn X ngày).
     * Dùng khi: SavingGoalScheduler quét goals sắp hết hạn (VD: còn 7 ngày).
     */
    public static NotificationContent savingNearDeadline(String goalName,
                                                         int daysLeft,
                                                         LocalDate endDate,
                                                         BigDecimal remaining) {
        String title = "Nhắc mục tiêu ⏰";
        String content = String.format(
                "Mục tiêu \"%s\" sắp đến hạn (%s). Còn %d ngày và %s nữa để hoàn thành!",
                goalName, endDate.format(VN_DATE), daysLeft, CurrencyUtils.formatVND(remaining));
        return new NotificationContent(title, content);
    }

    /**
     * Mục tiêu đã quá hạn.
     * Dùng khi: SavingGoalScheduler → GoalStatus.OVERDUE.
     */
    public static NotificationContent savingOverdue(String goalName,
                                                    BigDecimal remaining) {
        String title = "Mục tiêu quá hạn ⚠️";
        String content = String.format(
                "Mục tiêu tiết kiệm \"%s\" đã quá hạn nhưng vẫn còn thiếu %s. Bạn có muốn gia hạn?",
                goalName, CurrencyUtils.formatVND(remaining));
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 3 — BUDGET
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Đã chi >= 80% ngân sách (cảnh báo vàng).
     * Dùng khi: BudgetScheduler.checkAndNotify() → 80% <= percent < 100%.
     */
    public static NotificationContent budgetWarning(String budgetLabel,
                                                    int percent,
                                                    BigDecimal spent,
                                                    BigDecimal total) {
        String title = "Cảnh báo ngân sách 🔔";
        String content = String.format(
                "Bạn đã chi %d%% ngân sách %s (%s/%s). Hãy cân nhắc chi tiêu!",
                percent, budgetLabel, CurrencyUtils.formatVND(spent), CurrencyUtils.formatVND(total));
        return new NotificationContent(title, content);
    }

    /**
     * Đã chi >= 100% ngân sách (vượt ngân sách).
     * Dùng khi: BudgetScheduler.checkAndNotify() → percent >= 100%.
     */
    public static NotificationContent budgetExceeded(String budgetLabel,
                                                     int percent,
                                                     BigDecimal spent,
                                                     BigDecimal total) {
        String title = "Vượt ngân sách! 🚨";
        String content = String.format(
                "Bạn đã vượt %d%% ngân sách %s. Tổng chi: %s / hạn mức %s.",
                percent, budgetLabel, CurrencyUtils.formatVND(spent), CurrencyUtils.formatVND(total));
        return new NotificationContent(title, content);
    }

    /**
     * Ngân sách đã được tự động gia hạn sang kỳ mới.
     * Dùng khi: BudgetScheduler.renewBudget() hoàn thành.
     */
    public static NotificationContent budgetRenewed(LocalDate newStart, LocalDate newEnd) {
        String title = "Ngân sách đã được gia hạn 🔄";
        String content = String.format(
                "Ngân sách của bạn đã được tự động tạo mới cho kỳ %s đến %s.",
                newStart.format(VN_DATE), newEnd.format(VN_DATE));
        return new NotificationContent(title, content);
    }

    /**
     * Gợi ý phân bổ chi tiêu theo ngày (tính toán Java thuần — KHÔNG phải AI).
     * Công thức: dailyAllowance = remaining / daysLeft
     * Dùng khi: BudgetScheduler.checkAndNotify() → percent >= 60 VÀ còn > 5 ngày.
     */
    public static NotificationContent budgetDailyAllowance(String label,
                                                           BigDecimal remaining,
                                                           long daysLeft,
                                                           BigDecimal dailyAllowance) {
        String title = "💡 Gợi ý chi tiêu hôm nay";
        String content = String.format(
                "Ngân sách %s còn %s cho %d ngày tới. Mỗi ngày bạn chỉ nên chi tối đa %s để đảm bảo đủ tháng.",
                label, CurrencyUtils.formatVND(remaining),
                daysLeft, CurrencyUtils.formatVND(dailyAllowance));
        return new NotificationContent(title, content);
    }

    /**
     * Dự báo ngày vượt ngân sách dựa trên tốc độ chi tiêu hiện tại (tính toán Java thuần — KHÔNG phải AI).
     * Công thức: daysUntilOverrun = remainingBudget / dailyBurnRate
     * Dùng khi: BudgetScheduler.checkAndNotify() → percent >= 50 VÀ forecastDate trước endDate.
     */
    public static NotificationContent budgetOverrunForecast(String label,
                                                            LocalDate forecastDate,
                                                            long daysUntilOverrun) {
        String title = "🔮 Dự báo vượt ngân sách";
        String content = String.format(
                "Với tốc độ chi tiêu hiện tại, ngân sách %s của bạn sẽ cạn vào khoảng %s (còn %d ngày). " +
                "Hãy điều chỉnh chi tiêu ngay hôm nay!",
                label, forecastDate.format(VN_DATE), daysUntilOverrun);
        return new NotificationContent(title, content);
    }

    /**
     * So sánh chi tiêu với tháng trước (tính toán Java thuần — KHÔNG phải AI).
     * Công thức: increasePercent = (spent - lastMonthSpent) / lastMonthSpent * 100
     * Dùng khi: BudgetScheduler.checkAndNotify() → chi tăng >= 30% so với cùng kỳ tháng trước.
     */
    public static NotificationContent budgetComparedToLastMonth(String label,
                                                                int increasePercent,
                                                                BigDecimal lastMonthAmount) {
        String title = "📈 Chi tiêu tăng so với tháng trước";
        String content = String.format(
                "Bạn đang chi %s nhiều hơn %d%% so với cùng kỳ tháng trước (%s). " +
                "Hãy kiểm tra lại thói quen chi tiêu!",
                label, increasePercent, CurrencyUtils.formatVND(lastMonthAmount));
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 4 — SYSTEM
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Người dùng mới đăng ký — thông báo cho Admin.
     * Dùng khi: AuthServiceImp.register() thành công.
     */
    public static NotificationContent newUserRegistered(String userName) {
        String title = "Người dùng mới đăng ký";
        String content = String.format("Người dùng mới \"%s\" vừa đăng ký tài khoản.", userName);
        return new NotificationContent(title, content);
    }

    /**
     * Phát hiện đăng nhập từ thiết bị lạ.
     * Dùng khi: AuthService phát hiện device mới chưa từng đăng nhập.
     * (Để sẵn — khi implement tính năng bảo mật nâng cao)
     */
    public static NotificationContent suspiciousLogin(String deviceName, String time) {
        String title = "Bảo mật tài khoản ⚠️";
        String content = String.format(
                "Phát hiện đăng nhập mới từ thiết bị \"%s\" lúc %s. Nếu không phải bạn, hãy đổi mật khẩu ngay!",
                deviceName, time);
        return new NotificationContent(title, content);
    }

    /**
     * Thông báo cập nhật hệ thống.
     * Dùng khi: Admin broadcast thông báo hệ thống.
     */
    public static NotificationContent systemUpdate(String version, String features) {
        String title = "Cập nhật hệ thống 🆕";
        String content = String.format("SmartMoney %s vừa ra mắt! %s", version, features);
        return new NotificationContent(title, content);
    }

    /**
     * Tài khoản bị khóa bởi Admin.
     * Dùng khi: AdminServiceImp.lockAccount().
     */
    public static NotificationContent accountLocked() {
        String title = "Tài khoản bị khóa 🔒";
        String content = "Tài khoản của bạn đã bị khóa bởi quản trị viên. Vui lòng liên hệ hỗ trợ để biết thêm chi tiết.";
        return new NotificationContent(title, content);
    }

    /**
     * Tài khoản được mở khóa bởi Admin.
     * Dùng khi: AdminServiceImp.unlockAccount().
     */
    public static NotificationContent accountUnlocked() {
        String title = "Tài khoản được mở khóa 🔓";
        String content = "Tài khoản của bạn đã được mở khóa. Bạn có thể tiếp tục sử dụng dịch vụ.";
        return new NotificationContent(title, content);
    }
    /**
            * Thông báo cập nhật thông tin cá nhân.
            */
    public static NotificationContent profileUpdated() {
        String title = "Cập nhật thông tin 📝";
        String content = "Thông tin tài khoản của bạn đã được thay đổi thành công.";
        return new NotificationContent(title, content);
    }
    /**
     * Thông báo cập nhật ảnh đại diện thành công.
     */
    public static NotificationContent avatarUpdated() {
        String title = "Cập nhật hồ sơ ✨";
        String content = "Ảnh đại diện của bạn đã được cập nhật thành công.";
        return new NotificationContent(title, content);
    }
    /**
     * Thông báo cho Admin khi người dùng thực hiện khóa khẩn cấp.
     */
    public static NotificationContent userEmergencyLockAlert(String email, String phone) {
        String title = "YÊU CẦU KHÓA KHẨN CẤP 🚨";
        String content = String.format(
                "Người dùng %s đã yêu cầu khóa tài khoản khẩn cấp qua gmail xác minh: %s.",
                email, phone);
        return new NotificationContent(title, content);
    }
    /**
     * Thông báo xác nhận khóa khẩn cấp cho người dùng.
     */
    public static NotificationContent accountEmergencyLockedConfirm() {
        String title = "Tài khoản đã được khóa khẩn cấp 🔒";
        String content = "Mọi quyền truy cập đã bị vô hiệu hóa để bảo vệ tài sản của bạn. Vui lòng liên hệ hỗ trợ để mở lại.";
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 5 — CHAT_AI
    // ════════════════════════════════════════════════════════════════════════

    /**
     * AI hoàn thành phân tích chi tiêu.
     * Dùng khi: AI conversation xử lý xong yêu cầu phân tích dài.
     */
    public static NotificationContent aiAnalysisDone(String summary) {
        String title = "Phân tích AI hoàn tất 🤖";
        String content = String.format("AI đã phân tích xong: %s", summary);
        return new NotificationContent(title, content);
    }

    /**
     * AI tạo transaction/budget thành công từ chat.
     * Dùng khi: AI nhận lệnh tạo giao dịch từ chat và xử lý xong.
     */
    public static NotificationContent aiActionCompleted(String actionDescription) {
        String title = "AI đã thực hiện xong";
        String content = String.format("Trợ lý AI đã: %s", actionDescription);
        return new NotificationContent(title, content);
    }

    /**
     * AI nhắc nhở theo lịch do user đặt qua chat.
     * Dùng khi: AI tạo scheduled reminder từ chat (VD: "nhắc tôi trả nợ anh Tuấn ngày mai").
     */
    public static NotificationContent aiScheduledReminder(String reminderContent) {
        String title = "AI nhắc nhở 🔔";
        return new NotificationContent(title, reminderContent);
    }


    // ════════════════════════════════════════════════════════════════════════
    // TYPE 6 — WALLETS
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Số dư ví xuống thấp dưới ngưỡng cảnh báo.
     * Dùng khi: Sau mỗi transaction → kiểm tra balance của wallet.
     * (Scheduler hoặc inline trong TransactionService)
     */
    public static NotificationContent walletLowBalance(String walletName,
                                                       BigDecimal balance,
                                                       BigDecimal threshold) {
        String title = "Số dư ví thấp 💳";
        String content = String.format(
                "Ví \"%s\" còn %s - dưới mức cảnh báo %s. Hãy nạp thêm tiền!",
                walletName, CurrencyUtils.formatVND(balance), CurrencyUtils.formatVND(threshold));
        return new NotificationContent(title, content);
    }

    /**
     * Số dư ví âm (chi vượt quá số dư).
     * Dùng khi: wallet.balance < 0 sau khi trừ tiền.
     */
    public static NotificationContent walletNegativeBalance(String walletName,
                                                            BigDecimal balance) {
        String title = "Số dư ví âm ⚠️";
        String content = String.format(
                "Ví \"%s\" đang âm %s. Hãy kiểm tra lại các giao dịch!",
                walletName, CurrencyUtils.formatVND(balance.abs()));
        return new NotificationContent(title, content);
    }
    /**
     * Cảnh báo hoạt động chi tiêu bất thường trên ví.
     */
    public static NotificationContent abnormalWalletActivity(String walletName, int count, BigDecimal totalAmount) {
        String title = "Cảnh báo chi tiêu bất thường 🚩";
        String content = String.format(
                "Ví '%s' phát sinh %d giao dịch chi tiêu với tổng %s trong 24h qua. Hãy kiểm tra lại!",
                walletName, count, CurrencyUtils.formatVND(totalAmount));
        return new NotificationContent(title, content);
    }

    /**
     * Thông báo cho Admin về rủi ro ví người dùng.
     */
    public static NotificationContent adminWalletRiskAlert(String userEmail, String walletName, int count, BigDecimal totalAmount) {
        String title = "Cảnh báo rủi ro ví người dùng 🚨";
        String content = String.format(
                "Người dùng [%s] tại ví '%s' phát sinh %d giao dịch bất thường (%s).",
                userEmail, walletName, count, CurrencyUtils.formatVND(totalAmount));
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 7 — EVENTS
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Nhắc sự kiện sắp tới (còn X ngày).
     * Dùng khi: EventScheduler quét events có endDate = today + 7 ngày.
     */
    public static NotificationContent eventReminder(String eventName,
                                                    int daysLeft,
                                                    LocalDate eventDate,
                                                    BigDecimal budget) {
        String title = "Sự kiện sắp tới 📅";
        String budgetInfo = budget != null
                ? String.format(" Ngân sách dự kiến: %s.", CurrencyUtils.formatVND(budget))
                : "";
        String content = String.format(
                "\"%s\" còn %d ngày nữa (%s).%s Đừng quên lên kế hoạch!",
                eventName, daysLeft, eventDate.format(VN_DATE), budgetInfo);
        return new NotificationContent(title, content);
    }

    /**
     * Sự kiện đã hoàn thành (user bấm thủ công).
     * Dùng khi: EventService.updateEventStatus() → finished=true.
     */
    public static NotificationContent eventCompleted(String eventName,
                                                     BigDecimal totalSpent) {
        String title = "Sự kiện đã kết thúc ✅";
        String content = String.format(
                "Sự kiện \"%s\" đã hoàn thành. Tổng chi tiêu: %s.",
                eventName, CurrencyUtils.formatVND(totalSpent));
        return new NotificationContent(title, content);
    }

    /**
     * Sự kiện đã quá hạn và được hệ thống tự động hoàn tất.
     * Dùng khi: EventScheduler quét events có endDate < today AND finished=false → auto-complete.
     */
    public static NotificationContent eventAutoCompleted(String eventName,
                                                         LocalDate endDate,
                                                         BigDecimal totalSpent) {
        String title = "Sự kiện đã kết thúc tự động ✅";
        String content = String.format(
                "Sự kiện \"%s\" đã hết hạn vào %s và được tự động kết thúc. Tổng chi tiêu: %s.",
                eventName, endDate.format(VN_DATE), CurrencyUtils.formatVND(totalSpent));
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 8 — DEBT_LOAN
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Nhắc khoản phải trả (Đi vay) — sắp đến hạn (3 ngày hoặc đúng ngày).
     * Dùng khi: DebtScheduler quét debts sắp đến hạn.
     */
    public static NotificationContent debtPayableReminder(String personName,
                                                          BigDecimal remainAmount,
                                                          LocalDate dueDate) {
        String title = "Nhắc khoản nợ 💸";
        String content = String.format(
                "Bạn còn nợ %s số tiền %s. Hạn thanh toán: %s.",
                personName, CurrencyUtils.formatVND(remainAmount), dueDate.format(VN_DATE));
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc khoản phải thu (Cho vay) — sắp đến hạn (3 ngày hoặc đúng ngày).
     * Dùng khi: DebtScheduler quét receivable debts sắp đến hạn.
     */
    public static NotificationContent debtReceivableReminder(String personName,
                                                             BigDecimal remainAmount,
                                                             LocalDate dueDate) {
        String title = "Nhắc khoản thu 💰";
        String content = String.format(
                "Khoản cho %s vay %s đến hạn thu vào %s. Hãy liên hệ!",
                personName, CurrencyUtils.formatVND(remainAmount), dueDate.format(VN_DATE));
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc sớm khoản nợ trước 10 ngày — nhắc lần đầu xa hạn.
     * Dùng khi: DebtScheduler quét debts có due_date = today + 10 ngày.
     * Phân loại: isPayable=true → Đi vay (cần trả), isPayable=false → Cho vay (cần thu).
     */
    public static NotificationContent debtEarlyReminder(String personName,
                                                        BigDecimal remainAmount,
                                                        LocalDate dueDate,
                                                        int daysLeft,
                                                        boolean isPayable) {
        String title = isPayable ? "Nhắc nợ sắp đến hạn 📋" : "Nhắc thu nợ sắp đến hạn 📋";
        String action = isPayable
                ? String.format("Bạn còn nợ %s số tiền %s", personName, CurrencyUtils.formatVND(remainAmount))
                : String.format("Khoản cho %s vay %s", personName, CurrencyUtils.formatVND(remainAmount));
        String content = String.format(
                "%s. Còn %d ngày nữa đến hạn (%s). Hãy chuẩn bị!",
                action, daysLeft, dueDate.format(VN_DATE));
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc khoản nợ đã quá hạn (chưa thanh toán xong).
     * Dùng khi: DebtScheduler quét debts có due_date < today AND finished=false.
     * Phân loại: isPayable=true → Đi vay (cần trả), isPayable=false → Cho vay (cần thu).
     */
    public static NotificationContent debtOverdue(String personName,
                                                  BigDecimal remainAmount,
                                                  LocalDate dueDate,
                                                  boolean isPayable) {
        String title = isPayable ? "Khoản nợ quá hạn ⚠️" : "Khoản thu quá hạn ⚠️";
        String action = isPayable
                ? String.format("Bạn còn nợ %s số tiền %s", personName, CurrencyUtils.formatVND(remainAmount))
                : String.format("Khoản cho %s vay %s", personName, CurrencyUtils.formatVND(remainAmount));
        String content = String.format(
                "%s đã quá hạn từ %s. Hãy xử lý ngay!",
                action, dueDate.format(VN_DATE));
        return new NotificationContent(title, content);
    }

    /**
     * Khoản nợ đã được thanh toán xong.
     * Dùng khi: recalculateDebt() → debt.finished = true.
     */
    public static NotificationContent debtFullyPaid(String personName,
                                                    BigDecimal totalAmount,
                                                    boolean isPayable) {
        String title = isPayable ? "Đã trả hết nợ ✅" : "Đã thu hết nợ ✅";
        String action = isPayable ? "trả hết" : "thu đủ";
        String content = String.format(
                "Bạn đã %s khoản %s với %s. Sổ nợ đã được cập nhật!",
                action, isPayable ? "nợ của " + personName : "cho " + personName + " vay",
                CurrencyUtils.formatVND(totalAmount));
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 9 — REMINDER
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Hóa đơn (Bill) đến hạn thanh toán.
     * Dùng khi: PlannedTransactionScheduler.processBill() — khi nextDueDate == today.
     * Scheduler CHỈ nhắc, KHÔNG tạo transaction và KHÔNG advance nextDueDate.
     */
    public static NotificationContent billDue(String billName, BigDecimal amount) {
        String title = "Hóa đơn đến hạn! 📋";
        String content = String.format(
                "Hóa đơn \"%s\" trị giá %s đã đến hạn thanh toán. Nhấn để thanh toán ngay!",
                billName, CurrencyUtils.formatVND(amount));
        return new NotificationContent(title, content);
    }

    /**
     * Hóa đơn (Bill) đã quá hạn thanh toán (chưa trả, nextDueDate đã qua).
     * Dùng khi: PlannedTransactionScheduler.processBill() — khi nextDueDate < today.
     * Scheduler gửi nhắc nhở MỖI NGÀY cho đến khi user bấm "Trả tiền" (payBill).
     * Scheduler vẫn CHỈ nhắc, KHÔNG tạo transaction và KHÔNG advance nextDueDate.
     *
     * Ví dụ output:
     *   Title  : "Hóa đơn quá hạn! ⏰"
     *   Content: "Hóa đơn \"Tiền điện\" trị giá 800.000 ₫ đã quá hạn 3 ngày. Hãy thanh toán ngay!"
     */
    public static NotificationContent billOverdue(String billName, BigDecimal amount, long daysOverdue) {
        String title = "Hóa đơn quá hạn! ⏰";
        String content = String.format(
                "Hóa đơn \"%s\" trị giá %s đã quá hạn %d ngày. Hãy thanh toán ngay!",
                billName, CurrencyUtils.formatVND(amount), daysOverdue);
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc ghi chép hàng ngày.
     * Dùng khi: ReminderScheduler (chưa có) chạy mỗi tối.
     */
    public static NotificationContent dailyRecordReminder() {
        String title = "Nhắc ghi chép 📝";
        String content = "Bạn chưa ghi chép chi tiêu hôm nay! Hãy dành 2 phút cập nhật sổ chi tiêu.";
        return new NotificationContent(title, content);
    }

    /**
     * Tổng kết tuần.
     * Dùng khi: ReminderScheduler chạy cuối tuần.
     */
    public static NotificationContent weeklyDigest(BigDecimal totalSpent,
                                                   String topCategoryName,
                                                   BigDecimal topCategoryAmount) {
        String title = "Tổng kết tuần 📊";
        String content = String.format(
                "Tuần này bạn đã chi %s. Danh mục chi nhiều nhất: %s (%s).",
                CurrencyUtils.formatVND(totalSpent),
                topCategoryName,
                CurrencyUtils.formatVND(topCategoryAmount));
        return new NotificationContent(title, content);
    }

    /**
     * Giao dịch định kỳ bị bỏ qua do số dư ví không đủ.
     * Dùng khi: PlannedTransactionScheduler.processRecurring() — ví không đủ tiền tự động chi.
     * Scheduler sẽ tiến lịch sang kỳ sau (không retry kỳ này).
     *
     * Thông báo tạo ra: Title="Giao dịch định kỳ bị bỏ qua ⚠️"
     * Content="Giao dịch định kỳ \"Tiền nhà\" không thể thực hiện: Ví \"MoMo\" chỉ còn 50.000 ₫,
     *          cần 5.000.000 ₫. Kỳ này đã bị bỏ qua — vui lòng nạp thêm tiền vào ví."
     */
    public static NotificationContent recurringInsufficientBalance(String label,
                                                                    BigDecimal amount,
                                                                    String walletName,
                                                                    BigDecimal walletBalance) {
        String title = "Giao dịch định kỳ bị bỏ qua ⚠️";
        // Chỉ báo số dư hiện tại (theo yêu cầu: không hiển thị số tiền cần thêm)
        String content = String.format(
                "Giao dịch định kỳ \"%s\" không thể thực hiện: Ví \"%s\" chỉ còn %s (không đủ để thực hiện giao dịch). " +
                "Kỳ này đã bị bỏ qua — vui lòng nạp thêm tiền vào ví.",
                label, walletName, CurrencyUtils.formatVND(walletBalance));
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc giao dịch định kỳ đã được tự động tạo.
     * Dùng khi: PlannedTransactionScheduler.processRecurring() tạo transaction thành công.
     */
    public static NotificationContent recurringExecuted(String note,
                                                        BigDecimal amount,
                                                        boolean isIncome) {
        String title = "Giao dịch định kỳ đã thực hiện 🔄";
        String type = isIncome ? "thu" : "chi";
        String content = String.format(
                "Giao dịch định kỳ \"%s\" đã tự động %s %s.",
                note, type, CurrencyUtils.formatVND(amount));
        return new NotificationContent(title, content);
    }
}
