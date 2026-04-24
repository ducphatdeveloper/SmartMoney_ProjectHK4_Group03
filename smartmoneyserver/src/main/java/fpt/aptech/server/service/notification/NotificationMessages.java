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
        String type = isIncome ? "income" : "expense";
        String title = "New Transaction";
        String content = String.format("Recorded %s %s - %s in wallet %s",
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
        String title = "Large Transaction";
        String content = String.format("Large transaction detected: %s for %s. Please review!",
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
        String type = isIncome ? "income" : "expense";

        // Bước 2: Xác định tiêu đề thông báo theo loại giao dịch
        //   isIncome = true  → khoản thu → icon 💰
        //   isIncome = false → khoản chi → icon 💸
        String title = isIncome
                ? "💰 Reminder: Your Income"
                : "💸 Reminder: Your Expense";

        // Bước 3: Format ngày giờ đầy đủ từ transDate
        //   VD: transDate = 2026-04-11T14:30:00 → "ngày 11/04/2026 lúc 14:30"
        //   %02d: đảm bảo ngày/tháng/giờ/phút luôn 2 chữ số (VD: 7 → "07")
        String dateTimeLabel = String.format("on %02d/%02d/%d at %02d:%02d",
                transDate.getDayOfMonth(),   // ngày trong tháng (1-31)
                transDate.getMonthValue(),   // tháng (1-12)
                transDate.getYear(),         // năm 4 chữ số
                transDate.getHour(),         // giờ (0-23)
                transDate.getMinute()        // phút (0-59)
        );

        // Bước 4: Ghép nội dung thông báo chính
        //   Cấu trúc: "Bạn đã [thu/chi] [số tiền] - [danh mục] [ngày giờ] vào [nguồn tiền]."
        StringBuilder content = new StringBuilder(String.format(
                "You have %s %s - %s %s in %s.",
                type,
                CurrencyUtils.formatVND(amount),
                categoryName,
                dateTimeLabel,
                sourceName
        ));

        // Bước 5: Nối các thông tin bổ sung (chỉ thêm nếu có giá trị)
        if (note != null && !note.isBlank()) {
            content.append(" Note: ").append(note.trim()).append(".");
        }
        if (eventName != null && !eventName.isBlank()) {
            content.append(" Event: ").append(eventName.trim()).append(".");
        }
        if (plannedType != null) {
            content.append(plannedType == 1 ? " Recurring Bill." : " Auto Recurring Transaction.");
        }
        if (debtPersonName != null && !debtPersonName.isBlank()) {
            content.append(" Debt: ").append(debtPersonName.trim()).append(".");
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
        String title = "Transaction Restored ♻️";
        String content = String.format("Transaction worth %s has been successfully restored by Admin. Please check your wallet balance.",
                CurrencyUtils.formatVND(amount));
        return new NotificationContent(title, content);
    }

    /**
     * Tất cả giao dịch đã xóa được khôi phục bởi Admin.
     */
    public static NotificationContent allTransactionsRestored() {
        String title = "Data Restored Successfully ♻️";
        String content = "All your deleted transactions have been restored to their original state by Admin.";
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
        String title = "Goal Progress 🎯";
        String content = String.format("You have reached %d%% of goal \"%s\". %s more to complete!",
                percent, goalName, CurrencyUtils.formatVND(remaining));
        return new NotificationContent(title, content);
    }

    /**
     * Mục tiêu hoàn thành 100%.
     * Dùng khi: depositToSavingGoal() → GoalStatus.COMPLETED.
     */
    public static NotificationContent savingCompleted(String goalName,
                                                      BigDecimal targetAmount) {
        String title = "Goal Completed 🎉";
        String content = String.format("Congratulations! You have completed goal \"%s\" with %s.",
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
        String title = "Goal Reminder ⏰";
        String content = String.format(
                "Goal \"%s\" is approaching deadline (%s). %d days and %s left to complete!",
                goalName, endDate.format(VN_DATE), daysLeft, CurrencyUtils.formatVND(remaining));
        return new NotificationContent(title, content);
    }

    /**
     * Mục tiêu đã quá hạn.
     * Dùng khi: SavingGoalScheduler → GoalStatus.OVERDUE.
     */
    public static NotificationContent savingOverdue(String goalName,
                                                    BigDecimal remaining) {
        String title = "Goal Overdue ⚠️";
        String content = String.format(
                "Saving goal \"%s\" has passed deadline but still missing %s. Do you want to extend?",
                goalName, CurrencyUtils.formatVND(remaining));
        return new NotificationContent(title, content);
    }

    /**
     * Chốt sổ mục tiêu (đã hoàn thành 100%).
     * Dùng khi: SavingGoalService.completeSavingGoal() → finished=true + chuyển tiền về ví.
     */
    public static NotificationContent savingFinalized(String goalName,
                                                      BigDecimal amount,
                                                      String walletName) {
        String title = "Goal Finalized 🎯";
        String content = String.format(
                "Goal \"%s\" has been finalized. %s has been transferred to wallet \"%s\".",
                goalName, CurrencyUtils.formatVND(amount), walletName);
        return new NotificationContent(title, content);
    }

    /**
     * Hủy mục tiêu (kết thúc sớm).
     * Dùng khi: SavingGoalService.cancelSavingGoal() → CANCELLED + hoàn trả tiền về ví.
     */
    public static NotificationContent savingCancelled(String goalName,
                                                      BigDecimal amount,
                                                      String walletName) {
        String title = "Goal Cancelled ❌";
        String content = String.format(
                "Goal \"%s\" has been cancelled. %s has been refunded to wallet \"%s\".",
                goalName, CurrencyUtils.formatVND(amount), walletName);
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
        String title = "Budget Alert 🔔";
        String content = String.format(
                "You have spent %d%% of your %s budget (%s/%s). Please consider your spending!",
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
        String title = "Budget Exceeded! 🚨";
        String content = String.format(
                "You have exceeded %d%% of your %s budget. Total spent: %s / limit %s.",
                percent, budgetLabel, CurrencyUtils.formatVND(spent), CurrencyUtils.formatVND(total));
        return new NotificationContent(title, content);
    }

    /**
     * Ngân sách đã được tự động gia hạn sang kỳ mới.
     * Dùng khi: BudgetScheduler.renewBudget() hoàn thành.
     */
    public static NotificationContent budgetRenewed(LocalDate oldBeginDate, LocalDate oldEndDate,
                                                   LocalDate newBeginDate, LocalDate newEndDate,
                                                   String categoryNames, BigDecimal amount) {
        String title = "Budget Renewed 🔄";
        String content = String.format(
                "Your %s budget (%s) has been renewed from %s - %s to new period %s - %s.",
                categoryNames, CurrencyUtils.formatVND(amount),
                oldBeginDate.format(VN_DATE), oldEndDate.format(VN_DATE),
                newBeginDate.format(VN_DATE), newEndDate.format(VN_DATE));
        return new NotificationContent(title, content);
    }

    /**
     * Phân tích phân bổ chi tiêu theo ngày (tính toán Java thuần).
     * Công thức: dailyAllowance = remaining / daysLeft
     * Dùng khi: BudgetScheduler.checkAndNotify() → percent >= 60 VÀ còn > 5 ngày.
     */
    public static NotificationContent budgetDailyAllowance(String label,
                                                           BigDecimal remaining,
                                                           long daysLeft,
                                                           BigDecimal dailyAllowance) {
        String title = "💡 Daily Spending Analysis";
        String content = String.format(
                "Your %s budget has %s left for the next %d days. You should spend no more than %s per day to stay on track.",
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
        String title = "🔮 Budget Overrun Forecast";
        String content = String.format(
                "At your current spending rate, your %s budget will run out around %s (%d days left). " +
                "Adjust your spending today!",
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
        String title = "📈 Spending Increased vs Last Month";
        String content = String.format(
                "Your %s spending is %d%% higher compared to the same period last month (%s). " +
                "Review your spending habits!",
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
        String title = "New User Registered";
        String content = String.format("New user \"%s\" has just registered an account.", userName);
        return new NotificationContent(title, content);
    }

    /**
     * Phát hiện đăng nhập từ thiết bị lạ.
     * Dùng khi: AuthService phát hiện device mới chưa từng đăng nhập.
     * (Để sẵn — khi implement tính năng bảo mật nâng cao)
     */
    public static NotificationContent suspiciousLogin(String deviceName, String time) {
        String title = "Account Security ⚠️";
        String content = String.format(
                "New login detected from device \"%s\" at %s. If this wasn't you, change your password immediately!",
                deviceName, time);
        return new NotificationContent(title, content);
    }

    /**
     * Thông báo cập nhật hệ thống.
     * Dùng khi: Admin broadcast thông báo hệ thống.
     */
    public static NotificationContent systemUpdate(String version, String features) {
        String title = "System Update 🆕";
        String content = String.format("SmartMoney %s is now available! %s", version, features);
        return new NotificationContent(title, content);
    }

    /**
     * Tài khoản bị khóa bởi Admin.
     * Dùng khi: AdminServiceImp.lockAccount().
     */
    public static NotificationContent accountLocked() {
        String title = "Account Locked 🔒";
        String content = "Your account has been locked by an administrator. Please contact support for more details.";
        return new NotificationContent(title, content);
    }

    /**
     * Tài khoản được mở khóa bởi Admin.
     * Dùng khi: AdminServiceImp.unlockAccount().
     */
    public static NotificationContent accountUnlocked() {
        String title = "Account Unlocked 🔓";
        String content = "Your account has been unlocked. You can continue using the service.";
        return new NotificationContent(title, content);
    }
    /**
            * Thông báo cập nhật thông tin cá nhân.
            */
    public static NotificationContent profileUpdated() {
        String title = "Profile Updated 📝";
        String content = "Your account information has been successfully changed.";
        return new NotificationContent(title, content);
    }
    /**
     * Thông báo cập nhật ảnh đại diện thành công.
     */
    public static NotificationContent avatarUpdated() {
        String title = "Profile Updated ✨";
        String content = "Your avatar has been successfully updated.";
        return new NotificationContent(title, content);
    }
    /**
     * Thông báo cho Admin khi người dùng thực hiện khóa khẩn cấp.
     */
    public static NotificationContent userEmergencyLockAlert(String email, String phone) {
        String title = "EMERGENCY LOCK REQUEST 🚨";
        String content = String.format(
                "User %s has requested emergency account lock via verified gmail: %s.",
                email, phone);
        return new NotificationContent(title, content);
    }
    /**
     * Thông báo xác nhận khóa khẩn cấp cho người dùng.
     */
    public static NotificationContent accountEmergencyLockedConfirm() {
        String title = "Account Emergency Locked 🔒";
        String content = "All access has been disabled to protect your assets. Please contact support to unlock.";
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
        String title = "AI Analysis Complete 🤖";
        String content = String.format("AI has completed analysis: %s", summary);
        return new NotificationContent(title, content);
    }

    /**
     * AI tạo transaction/budget thành công từ chat.
     * Dùng khi: AI nhận lệnh tạo giao dịch từ chat và xử lý xong.
     */
    public static NotificationContent aiActionCompleted(String actionDescription) {
        String title = "AI Action Completed";
        String content = String.format("AI Assistant has: %s", actionDescription);
        return new NotificationContent(title, content);
    }

    /**
     * AI nhắc nhở theo lịch do user đặt qua chat.
     * Dùng khi: AI tạo scheduled reminder từ chat (VD: "nhắc tôi trả nợ anh Tuấn ngày mai").
     */
    public static NotificationContent aiScheduledReminder(String reminderContent) {
        String title = "AI Reminder 🔔";
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
        String title = "Low Wallet Balance 💳";
        String content = String.format(
                "Wallet \"%s\" has %s - below warning threshold %s. Please top up!",
                walletName, CurrencyUtils.formatVND(balance), CurrencyUtils.formatVND(threshold));
        return new NotificationContent(title, content);
    }

    /**
     * Số dư ví âm (chi vượt quá số dư).
     * Dùng khi: wallet.balance < 0 sau khi trừ tiền.
     */
    public static NotificationContent walletNegativeBalance(String walletName,
                                                            BigDecimal balance) {
        String title = "Negative Wallet Balance ⚠️";
        String content = String.format(
                "Wallet \"%s\" is negative %s. Please review your transactions!",
                walletName, CurrencyUtils.formatVND(balance.abs()));
        return new NotificationContent(title, content);
    }
    /**
     * Cảnh báo hoạt động chi tiêu bất thường trên ví.
     */
    public static NotificationContent abnormalWalletActivity(String walletName, int count, BigDecimal totalAmount) {
        String title = "Abnormal Spending Alert 🚩";
        String content = String.format(
                "Wallet '%s' generated %d expense transactions totaling %s in the last 24h. Please review!",
                walletName, count, CurrencyUtils.formatVND(totalAmount));
        return new NotificationContent(title, content);
    }

    /**
     * Thông báo cho Admin về rủi ro ví người dùng.
     */
    public static NotificationContent adminWalletRiskAlert(String userEmail, String walletName, int count, BigDecimal totalAmount) {
        String title = "User Wallet Risk Alert 🚨";
        String content = String.format(
                "User [%s] at wallet '%s' generated %d abnormal transactions (%s).",
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
        String title = "Upcoming Event 📅";
        String budgetInfo = budget != null
                ? String.format(" Estimated budget: %s.", CurrencyUtils.formatVND(budget))
                : "";
        String content = String.format(
                "\"%s\" is %d days away (%s).%s Don't forget to plan!",
                eventName, daysLeft, eventDate.format(VN_DATE), budgetInfo);
        return new NotificationContent(title, content);
    }

    /**
     * Sự kiện đã hoàn thành (user bấm thủ công).
     * Dùng khi: EventService.updateEventStatus() → finished=true.
     */
    public static NotificationContent eventCompleted(String eventName,
                                                     BigDecimal totalSpent) {
        String title = "Event Ended ✅";
        String content = String.format(
                "Event \"%s\" has completed. Total spending: %s.",
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
        String title = "Event Auto Completed ✅";
        String content = String.format(
                "Event \"%s\" expired on %s and was automatically completed. Total spending: %s.",
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
        String title = "Debt Reminder 💸";
        String content = String.format(
                "You still owe %s amount %s. Payment due: %s.",
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
        String title = "Collection Reminder 💰";
        String content = String.format(
                "Loan to %s %s due for collection on %s. Please contact!",
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
        String title = isPayable ? "Debt Due Soon 📋" : "Collection Due Soon 📋";
        String action = isPayable
                ? String.format("You still owe %s amount %s", personName, CurrencyUtils.formatVND(remainAmount))
                : String.format("Loan to %s %s", personName, CurrencyUtils.formatVND(remainAmount));
        String content = String.format(
                "%s. %d days until due (%s). Be prepared!",
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
        String title = isPayable ? "Debt Overdue ⚠️" : "Collection Overdue ⚠️";
        String action = isPayable
                ? String.format("You still owe %s amount %s", personName, CurrencyUtils.formatVND(remainAmount))
                : String.format("Loan to %s %s", personName, CurrencyUtils.formatVND(remainAmount));
        String content = String.format(
                "%s has been overdue since %s. Handle immediately!",
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
        String title = isPayable ? "Debt Fully Paid ✅" : "Collection Fully Received ✅";
        String action = isPayable ? "paid in full" : "collected in full";
        String content = String.format(
                "You have %s %s with %s. Debt ledger has been updated!",
                action, isPayable ? "debt of " + personName : "loan to " + personName,
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
        String title = "Bill Due! 📋";
        String content = String.format(
                "Bill \"%s\" worth %s is due for payment. Click to pay now!",
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
        String title = "Bill Overdue! ⏰";
        String content = String.format(
                "Bill \"%s\" worth %s is %d days overdue. Pay immediately!",
                billName, CurrencyUtils.formatVND(amount), daysOverdue);
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc ghi chép hàng ngày.
     * Dùng khi: ReminderScheduler (chưa có) chạy mỗi tối.
     */
    public static NotificationContent dailyRecordReminder() {
        String title = "Record Reminder 📝";
        String content = "You haven't recorded expenses today! Spend 2 minutes to update your expense log.";
        return new NotificationContent(title, content);
    }

    /**
     * Tổng kết tuần.
     * Dùng khi: ReminderScheduler chạy cuối tuần.
     */
    public static NotificationContent weeklyDigest(BigDecimal totalSpent,
                                                   String topCategoryName,
                                                   BigDecimal topCategoryAmount) {
        String title = "Weekly Digest 📊";
        String content = String.format(
                "This week you spent %s. Top spending category: %s (%s).",
                CurrencyUtils.formatVND(totalSpent),
                topCategoryName,
                CurrencyUtils.formatVND(topCategoryAmount));
        return new NotificationContent(title, content);
    }

    /**
     * Giao dịch định kỳ bị hoãn do số dư ví không đủ.
     * Dùng khi: PlannedTransactionScheduler.processRecurring() — ví không đủ tiền tự động chi.
     * Scheduler GIỮ NGUYÊN nextDueDate → sẽ tự động retry kỳ này khi ví đủ tiền (không bỏ qua vĩnh viễn).
     *
     * Thông báo tạo ra: Title="Số dư không đủ — giao dịch bị hoãn ⚠️"
     * Content="Giao dịch định kỳ \"Tiền nhà\" chưa thể thực hiện: Ví \"MoMo\" chỉ còn 50.000 ₫.
     *          Giao dịch sẽ tự động thực hiện khi ví có đủ số dư."
     */
    public static NotificationContent recurringInsufficientBalance(String label,
                                                                    BigDecimal amount,
                                                                    String walletName,
                                                                    BigDecimal walletBalance) {
        String title = "Insufficient Balance — Transaction Deferred ⚠️";
        String content = String.format(
                "Recurring transaction \"%s\" cannot be executed: Wallet \"%s\" only has %s (needs %s more). " +
                "Transaction will auto-execute when wallet has sufficient balance.",
                label, walletName, CurrencyUtils.formatVND(walletBalance), CurrencyUtils.formatVND(amount));
        return new NotificationContent(title, content);
    }

    /**
     * User bấm "Trả tiền" thành công cho Hóa đơn.
     * Dùng khi: PlannedTransactionServiceImpl.payBill() hoàn thành.
     *
     * Thông báo tạo ra:
     *   - Còn kỳ tiếp: Title="Hóa đơn đã thanh toán ✅" Content="... Kỳ tiếp: dd/MM/yyyy."
     *   - Hết hạn/Kết thúc: Title="Hóa đơn đã thanh toán ✅" Content="... Hóa đơn đã kết thúc."
     */
    public static NotificationContent billPaid(String billName, BigDecimal amount, LocalDate nextDueDate) {
        String title = "Bill Paid ✅";
        String content = nextDueDate != null
                ? String.format("Bill \"%s\" %s paid successfully. Next due: %s.",
                        billName, CurrencyUtils.formatVND(amount), nextDueDate.format(VN_DATE))
                : String.format("Bill \"%s\" %s paid successfully. Bill has ended.",
                        billName, CurrencyUtils.formatVND(amount));
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc giao dịch định kỳ đã được tự động tạo.
     * Dùng khi: PlannedTransactionScheduler.processRecurring() tạo transaction thành công.
     */
    public static NotificationContent recurringExecuted(String note,
                                                        BigDecimal amount,
                                                        boolean isIncome) {
        String title = "Recurring Transaction Executed 🔄";
        String type = isIncome ? "income" : "expense";
        String content = String.format(
                "Recurring transaction \"%s\" automatically %s %s.",
                note, type, CurrencyUtils.formatVND(amount));
        return new NotificationContent(title, content);
    }

    // ════════════════════════════════════════════════════════════════════════
    // TYPE 1.5 — TRANSACTION SCHEDULER
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Cảnh báo chi tiêu hôm nay tăng quá 50% so với hôm qua.
     * Dùng khi: TransactionScheduler.analyzeDailySpending() phát hiện tăng chi tiêu.
     *
     * Thông báo tạo ra: Title="Daily Spending Spike ⚠️"
     * Content="Today you spent 500,000 ₫, up 100% from yesterday (250,000 ₫)."
     */
    public static NotificationContent dailySpendingSpike(BigDecimal todaySpent,
                                                         BigDecimal yesterdaySpent,
                                                         BigDecimal increaseRate) {
        String title = "Daily Spending Spike ⚠️";
        String content = String.format(
                "Today you spent %s, up %s%% from yesterday (%s).",
                CurrencyUtils.formatVND(todaySpent),
                increaseRate.multiply(BigDecimal.valueOf(100)).intValue(),
                CurrencyUtils.formatVND(yesterdaySpent));
        return new NotificationContent(title, content);
    }

    /**
     * Tổng kết chi tiêu hàng ngày.
     * Dùng khi: TransactionScheduler.dailyTransactionDigest() tổng kết chi tiêu.
     *
     * Thông báo tạo ra: Title="Daily Digest 📊"
     * Content="Today you spent 500,000 ₫. Top: Food (200,000 ₫), Transport (150,000 ₫)."
     */
    public static NotificationContent dailyDigest(BigDecimal todaySpent,
                                                  java.util.List<Object[]> topCategories) {
        String title = "Daily Digest 📊";
        StringBuilder topCats = new StringBuilder();
        if (topCategories != null && !topCategories.isEmpty()) {
            int limit = Math.min(3, topCategories.size());
            for (int i = 0; i < limit; i++) {
                Object[] cat = topCategories.get(i);
                String catName = (String) cat[0];
                BigDecimal amount = (BigDecimal) cat[1];
                if (i > 0) topCats.append(", ");
                topCats.append(catName).append(" (").append(CurrencyUtils.formatVND(amount)).append(")");
            }
        }
        String content = String.format(
                "Today you spent %s. Top: %s.",
                CurrencyUtils.formatVND(todaySpent),
                !topCats.isEmpty() ? topCats : "No data");
        return new NotificationContent(title, content);
    }

    /**
     * Nhắc nếu không có giao dịch trong X ngày.
     * Dùng khi: TransactionScheduler.remindNoTransaction() phát hiện không có giao dịch.
     *
     * Thông báo tạo ra: Title="No Transaction Reminder 📝"
     * Content="You haven't recorded transactions in 3 days. Update to track spending."
     */
    public static NotificationContent noTransactionReminder(int days) {
        String title = "No Transaction Reminder 📝";
        String content = String.format(
                "You haven't recorded transactions in %d days. Update to track spending.",
                days);
        return new NotificationContent(title, content);
    }

    /**
     * Cảnh báo xu hướng chi tiêu tuần.
     * Dùng khi: TransactionScheduler.analyzeWeeklyTrend() phát hiện tăng chi tiêu tuần.
     *
     * Thông báo tạo ra: Title="Weekly Trend Alert 📈"
     * Content="This week you spent 2,000,000 ₫, up 50% from last week (1,333,333 ₫)."
     */
    public static NotificationContent weeklyTrendAlert(BigDecimal thisWeekSpent,
                                                       BigDecimal lastWeekSpent,
                                                       BigDecimal increaseRate) {
        String title = "Weekly Trend Alert 📈";
        String content = String.format(
                "This week you spent %s, up %s%% from last week (%s).",
                CurrencyUtils.formatVND(thisWeekSpent),
                increaseRate.multiply(BigDecimal.valueOf(100)).intValue(),
                CurrencyUtils.formatVND(lastWeekSpent));
        return new NotificationContent(title, content);
    }

    /**
     * Cảnh báo xu hướng chi tiêu tháng.
     * Dùng khi: TransactionScheduler.analyzeMonthlyTrend() phát hiện tăng chi tiêu tháng.
     *
     * Thông báo tạo ra: Title="Monthly Trend Alert 📈"
     * Content="This month you spent 10,000,000 ₫, up 50% from last month (6,666,667 ₫)."
     */
    public static NotificationContent monthlyTrendAlert(BigDecimal thisMonthSpent,
                                                        BigDecimal lastMonthSpent,
                                                        BigDecimal increaseRate) {
        String title = "Monthly Trend Alert 📈";
        String content = String.format(
                "This month you spent %s, up %s%% from last month (%s).",
                CurrencyUtils.formatVND(thisMonthSpent),
                increaseRate.multiply(BigDecimal.valueOf(100)).intValue(),
                CurrencyUtils.formatVND(lastMonthSpent));
        return new NotificationContent(title, content);
    }

    /**
     * Tổng kết chi tiêu tháng.
     * Dùng khi: TransactionScheduler.monthlyDigest() tổng kết chi tiêu tháng.
     *
     * Thông báo tạo ra: Title="Monthly Digest 📊"
     * Content="This month you spent 10,000,000 ₫. Top: Food (4,000,000 ₫), Transport (2,000,000 ₫)."
     */
    public static NotificationContent monthlyDigest(BigDecimal thisMonthSpent,
                                                   java.util.List<Object[]> topCategories) {
        String title = "Monthly Digest 📊";
        StringBuilder topCats = new StringBuilder();
        if (topCategories != null && !topCategories.isEmpty()) {
            int limit = Math.min(3, topCategories.size());
            for (int i = 0; i < limit; i++) {
                Object[] cat = topCategories.get(i);
                String catName = (String) cat[0];
                BigDecimal amount = (BigDecimal) cat[1];
                if (i > 0) topCats.append(", ");
                topCats.append(catName).append(" (").append(CurrencyUtils.formatVND(amount)).append(")");
            }
        }
        String content = String.format(
                "This month you spent %s. Top: %s.",
                CurrencyUtils.formatVND(thisMonthSpent),
                !topCats.isEmpty() ? topCats : "No data");
        return new NotificationContent(title, content);
    }
}
