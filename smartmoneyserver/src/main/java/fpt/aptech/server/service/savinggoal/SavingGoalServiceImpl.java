package fpt.aptech.server.service.savinggoal;

import fpt.aptech.server.dto.savinggoal.SavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.SavingGoalResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.enums.savinggoal.GoalStatus;
import fpt.aptech.server.enums.transaction.TransactionSourceType;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SavingGoalServiceImpl implements SavingGoalService {

    private final SavingGoalRepository savingGoalRepository;
    private final AccountRepository    accountRepository;
    private final CurrencyRepository   currencyRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryRepository   categoryRepository;
    private final DebtRepository       debtRepository;   // Cascade soft delete
    private final EventRepository      eventRepository;  // Cascade soft delete
    private final NotificationService  notificationService; // Inject để gửi thông báo milestone

    // Các mốc % cần gửi thông báo khi nạp tiền
    private static final int[] MILESTONE_PERCENTS = {25, 50, 75};

    // =================================================================================
    // 1. TẠO MỚI (CREATE)
    // =================================================================================

    /**
     * [1.1] Tạo mục tiêu tiết kiệm mới.
     * Bước 1 — Validate dữ liệu đầu vào (tài khoản, tiền tệ, ngày kết thúc).
     * Bước 2 — Tạo và lưu SavingGoal.
     * Bước 3 — Tạo giao dịch khởi tạo nếu có số tiền ban đầu (reportable=false).
     */
    @Override
    @Transactional
    public SavingGoalResponse createSavingGoal(SavingGoalRequest request, Integer userId) {
        // Bước 1: Validate
        Account account = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));

        Currency currency = currencyRepository.findById(request.getCurrencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Loại tiền tệ không tồn tại"));

        if (request.getEndDate() != null && request.getEndDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("Ngày kết thúc không hợp lệ");
        }

        BigDecimal initialAmount = request.getInitialAmount() != null
                ? request.getInitialAmount()
                : BigDecimal.ZERO;

        // Bước 2: Tạo SavingGoal
        SavingGoal goal = SavingGoal.builder()
                .goalName(request.getGoalName())
                .targetAmount(request.getTargetAmount())
                .currentAmount(initialAmount)
                .currency(currency)
                .account(account)
                .goalImageUrl(request.getGoalImageUrl())
                .endDate(request.getEndDate())
                .goalStatus(GoalStatus.ACTIVE.getValue())
                .finished(false)
                .notified(request.getNotified() != null ? request.getNotified() : true)
                .reportable(request.getReportable() != null ? request.getReportable() : true)
                .build();

        SavingGoal savedGoal = savingGoalRepository.save(goal);

        // Bước 3: Tạo giao dịch khởi tạo (không tính vào báo cáo thu/chi)
        if (initialAmount.compareTo(BigDecimal.ZERO) > 0) {
            Category category = categoryRepository.findById(SystemCategory.INCOME_TRANSFER.getId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Không tìm thấy danh mục hệ thống 'Tiền chuyển đến'"));

            Transaction initTransaction = Transaction.builder()
                    .account(account)
                    .savingGoal(savedGoal)
                    .category(category)
                    .amount(initialAmount)
                    .note("Số dư ban đầu cho mục tiêu tiết kiệm")
                    .reportable(false) // Không tính vào báo cáo thu/chi thông thường
                    .sourceType(TransactionSourceType.MANUAL.getValue())
                    .transDate(LocalDateTime.now())
                    .build();

            transactionRepository.save(initTransaction);
        }

        return mapToResponse(savedGoal);
    }

    // =================================================================================
    // 2. CẬP NHẬT THÔNG TIN (UPDATE INFO)
    // =================================================================================

    /**
     * [2.1] Cập nhật thông tin mục tiêu (tên, số tiền mục tiêu, ngày kết thúc, ảnh...).
     * Chỉ cho phép sửa khi mục tiêu đang ACTIVE.
     * Không cho phép đặt target thấp hơn số tiền hiện tại.
     *
     * Bước 1 — Validate trạng thái và dữ liệu đầu vào.
     * Bước 2 — Xử lý điều chỉnh currentAmount (nếu có) bằng cách tạo giao dịch ghi nhận chênh lệch.
     * Bước 3 — Cập nhật thông tin mục tiêu.
     * Bước 4 — Kiểm tra tự động hoàn thành nếu đạt mục tiêu.
     */
    @Override
    @Transactional
    public SavingGoalResponse updateSavingGoalInfo(Integer id, SavingGoalRequest request, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);

        // Bước 1: Chỉ sửa được khi đang ACTIVE
        if (!goal.getGoalStatus().equals(GoalStatus.ACTIVE.getValue())) {
            throw new IllegalStateException("Chỉ có thể sửa mục tiêu đang hoạt động.");
        }

        // Validate targetAmount trước khi sử dụng
        if (request.getTargetAmount() == null) {
            throw new IllegalArgumentException("Số tiền mục tiêu không được để trống");
        }

        // Bước 2: Xử lý điều chỉnh currentAmount (nếu request có truyền lên)
        // Tham khảo logic WalletServiceImpl.updateWallet() — tạo giao dịch ghi nhận chênh lệch
        if (request.getInitialAmount() != null) {
            BigDecimal oldAmount = goal.getCurrentAmount();
            BigDecimal newAmount = request.getInitialAmount();

            // 2.1: Validate số tiền không được âm
            if (newAmount.compareTo(BigDecimal.ZERO) < 0) {
                throw new IllegalArgumentException("Số tiền hiện tại không được âm");
            }

            // 2.2: Nếu có thay đổi → tạo giao dịch ghi nhận chênh lệch
            int comparison = newAmount.compareTo(oldAmount);
            if (comparison != 0) {
                BigDecimal diff = newAmount.subtract(oldAmount).abs();
                boolean isIncrease = comparison > 0;

                // Tăng số tiền → Thu nhập khác | Giảm số tiền → Các chi phí khác
                SystemCategory systemCategory = isIncrease
                        ? SystemCategory.INCOME_OTHER
                        : SystemCategory.OTHER_EXPENSE;
                Category category = categoryRepository.findById(systemCategory.getId())
                        .orElseThrow(() -> new IllegalStateException(
                                "Không tìm thấy danh mục hệ thống: " + systemCategory.name()));

                Transaction adjustTransaction = Transaction.builder()
                        .account(goal.getAccount())
                        .savingGoal(goal)
                        .category(category)
                        .amount(diff)
                        .note("Điều chỉnh số dư mục tiêu: " + goal.getGoalName())
                        .reportable(false) // Không tính vào báo cáo thu/chi thông thường
                        .sourceType(TransactionSourceType.MANUAL.getValue())
                        .transDate(LocalDateTime.now())
                        .build();

                transactionRepository.save(adjustTransaction);
                goal.setCurrentAmount(newAmount);
            }
        }

        // Bước 3: Không cho target thấp hơn số tiền đã có
        if (request.getTargetAmount().compareTo(goal.getCurrentAmount()) < 0) {
            throw new IllegalArgumentException(
                    "Số tiền mục tiêu không được nhỏ hơn số tiền hiện tại");
        }

        // Bước 4: Cập nhật các trường thông tin
        goal.setGoalName(request.getGoalName());
        goal.setTargetAmount(request.getTargetAmount());
        goal.setEndDate(request.getEndDate());
        goal.setGoalImageUrl(request.getGoalImageUrl());
        goal.setNotified(request.getNotified());
        goal.setReportable(request.getReportable());

        // Bước 5: Kiểm tra tự động hoàn thành nếu số tiền hiện tại đạt hoặc vượt mục tiêu
        if (goal.getCurrentAmount().compareTo(goal.getTargetAmount()) >= 0) {
            goal.setGoalStatus(GoalStatus.COMPLETED.getValue());
            goal.setFinished(true);
        }

        savingGoalRepository.save(goal);
        return mapToResponse(goal);
    }

    // =================================================================================
    // 3. NẠP TIỀN (DEPOSIT)
    // =================================================================================

    /**
     * [3.1] Nạp tiền vào mục tiêu tiết kiệm.
     * Bước 1 — Validate số tiền và trạng thái mục tiêu.
     * Bước 2 — Cộng tiền, kiểm tra đạt mục tiêu chưa.
     * Bước 3 — Tạo giao dịch ghi nhận dòng tiền.
     * Bước 4 — Gửi thông báo milestone (25%, 50%, 75%) hoặc hoàn thành (100%).
     */
    @Override
    @Transactional
    public SavingGoalResponse depositToSavingGoal(Integer id, BigDecimal amount, Integer userId) {
        // Bước 1: Validate
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Số tiền nạp phải lớn hơn 0");
        }

        SavingGoal goal = getOwnedGoal(id, userId);

        if (!goal.getGoalStatus().equals(GoalStatus.ACTIVE.getValue())) {
            throw new IllegalStateException(
                    "Không thể nạp tiền vào mục tiêu đã hoàn thành hoặc bị hủy.");
        }

        // Bước 2: Tính % trước và sau khi nạp (để detect milestone vừa vượt qua)
        double percentBefore = calcPercent(goal.getCurrentAmount(), goal.getTargetAmount());

        BigDecimal newAmount = goal.getCurrentAmount().add(amount);
        goal.setCurrentAmount(newAmount);

        double percentAfter = calcPercent(newAmount, goal.getTargetAmount());

        // Kiểm tra đạt mục tiêu 100%
        boolean justCompleted = false;
        if (newAmount.compareTo(goal.getTargetAmount()) >= 0) {
            goal.setGoalStatus(GoalStatus.COMPLETED.getValue());
            goal.setFinished(true);
            justCompleted = true;
        }

        savingGoalRepository.save(goal);

        // Bước 3: Tạo giao dịch ghi nhận dòng tiền
        Category category = categoryRepository.findById(SystemCategory.INCOME_TRANSFER.getId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy danh mục hệ thống 'Tiền chuyển đến'"));

        Transaction depositTransaction = Transaction.builder()
                .account(goal.getAccount())
                .savingGoal(goal)
                .category(category)
                .amount(amount)
                .note("Nạp tiền vào mục tiêu: " + goal.getGoalName())
                .reportable(true) // Nạp tiền tính vào báo cáo
                .sourceType(TransactionSourceType.MANUAL.getValue())
                .transDate(LocalDateTime.now())
                .build();

        transactionRepository.save(depositTransaction);

        // Bước 4: Gửi thông báo milestone hoặc hoàn thành
        if (Boolean.TRUE.equals(goal.getNotified())) {
            sendMilestoneNotification(goal, percentBefore, percentAfter, justCompleted);
        }

        return mapToResponse(goal);
    }

    // =================================================================================
    // 4. HỦY MỤC TIÊU (DELETE / CANCEL)
    // =================================================================================

    /**
     * [4.1] Hủy mục tiêu (Soft delete — chuyển sang CANCELLED + đánh dấu deleted).
     * Mục tiêu tiết kiệm là NGUỒN TIỀN → cascade xóa mềm toàn bộ dữ liệu liên kết:
     *   • Transactions thuộc goal_id
     *   • Debts có giao dịch trong mục tiêu này (qua subquery tTransactions)
     *   • Events có giao dịch trong mục tiêu này (qua subquery tTransactions)
     * Sau đó soft-delete chính SavingGoal (status = CANCELLED).
     */
    @Override
    @Transactional
    public void deleteSavingGoal(Integer id, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);

        goal.setGoalStatus(GoalStatus.CANCELLED.getValue());
        goal.setFinished(true);

        // Soft delete cascade — xóa mềm mục tiêu + các bản ghi liên kết
        goal.setDeleted(true);
        goal.setDeletedAt(java.time.LocalDateTime.now());
        transactionRepository.softDeleteAllBySavingGoalId(id);   // Giao dịch thuộc mục tiêu
        debtRepository.softDeleteAllBySavingGoalId(id);          // Khoản nợ có giao dịch thuộc mục tiêu
        eventRepository.softDeleteAllBySavingGoalId(id);         // Sự kiện có giao dịch thuộc mục tiêu

        savingGoalRepository.save(goal);
    }

    // =================================================================================
    // 5. LẤY DANH SÁCH & CHI TIẾT (READ)
    // =================================================================================

    /**
     * [5.1] Lấy tất cả mục tiêu của user (trừ CANCELLED), hỗ trợ tìm kiếm theo tên.
     */
    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search) {
        Integer statusToExclude = GoalStatus.CANCELLED.getValue();

        List<SavingGoal> goals = (search != null && !search.isBlank())
                ? savingGoalRepository
                .findByAccount_IdAndGoalNameContainingIgnoreCaseAndGoalStatusNot(
                        userId, search, statusToExclude)
                : savingGoalRepository
                .findByAccount_IdAndGoalStatusNot(userId, statusToExclude);

        return goals.stream().map(this::mapToResponse).toList();
    }

    /**
     * [5.2] Lấy chi tiết một mục tiêu theo ID + kiểm tra quyền sở hữu.
     */
    @Override
    public SavingGoalResponse getSavingGoalDetail(Integer id, Integer userId) {
        return mapToResponse(getOwnedGoal(id, userId));
    }

    // =================================================================================
    // 6. PRIVATE HELPERS
    // =================================================================================

    /**
     * [6.1] Tìm mục tiêu và kiểm tra quyền sở hữu.
     * Không cho thao tác trên mục tiêu đã CANCELLED.
     */
    private SavingGoal getOwnedGoal(Integer id, Integer userId) {
        SavingGoal goal = savingGoalRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy mục tiêu với ID: " + id));

        // Kiểm tra quyền sở hữu
        if (goal.getAccount() == null || !goal.getAccount().getId().equals(userId)) {
            throw new SecurityException("Bạn không có quyền thao tác trên mục tiêu này.");
        }

        // Không cho thao tác trên mục tiêu đã hủy
        if (goal.getGoalStatus().equals(GoalStatus.CANCELLED.getValue())) {
            throw new IllegalStateException("Mục tiêu này đã bị hủy và không thể thao tác.");
        }

        return goal;
    }

    /**
     * [6.2] Chuyển đổi SavingGoal → SavingGoalResponse.
     * Tính thêm remainingAmount và progressPercent.
     */
    private SavingGoalResponse mapToResponse(SavingGoal goal) {
        // Tính số tiền còn thiếu (không âm)
        BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
        if (remaining.compareTo(BigDecimal.ZERO) < 0) remaining = BigDecimal.ZERO;

        // Tính phần trăm hoàn thành (không vượt 100%)
        double percent = calcPercent(goal.getCurrentAmount(), goal.getTargetAmount());
        percent = Math.min(percent, 100.0);

        return SavingGoalResponse.builder()
                .id(goal.getId())
                .goalName(goal.getGoalName())
                .targetAmount(goal.getTargetAmount())
                .currentAmount(goal.getCurrentAmount())
                .beginDate(goal.getBeginDate())
                .endDate(goal.getEndDate())
                .goalStatus(goal.getGoalStatus())
                .notified(goal.getNotified())
                .reportable(goal.getReportable())
                .finished(goal.getFinished())
                .currencyCode(goal.getCurrency().getCurrencyCode())
                .imageUrl(goal.getGoalImageUrl())
                .remainingAmount(remaining)
                .progressPercent(percent)
                .build();
    }

    /**
     * [6.3] Tính phần trăm hoàn thành. Tránh chia cho 0.
     */
    private double calcPercent(BigDecimal current, BigDecimal target) {
        if (target == null || target.compareTo(BigDecimal.ZERO) == 0) return 0.0;
        return current
                .divide(target, 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100))
                .doubleValue();
    }

    /**
     * [6.4] Gửi thông báo milestone khi nạp tiền.
     * - Kiểm tra xem có vừa vượt mốc 25%, 50%, 75% không.
     * - Nếu hoàn thành 100% → gửi thông báo hoàn thành.
     * - Chỉ gửi 1 thông báo cho mốc cao nhất vừa đạt được.
     */
    private void sendMilestoneNotification(SavingGoal goal,
                                           double percentBefore,
                                           double percentAfter,
                                           boolean justCompleted) {
        // Trường hợp 1: Vừa đạt 100% → thông báo hoàn thành
        if (justCompleted) {
            NotificationContent msg = NotificationMessages.savingCompleted(
                    goal.getGoalName(), goal.getTargetAmount());
            notificationService.createNotification(
                    goal.getAccount(),
                    msg.title(), msg.content(),
                    NotificationType.SAVING,
                    goal.getId().longValue(),
                    null
            );
            return; // Chỉ gửi 1 thông báo
        }

        // Trường hợp 2: Kiểm tra từng mốc từ cao xuống thấp
        // Gửi thông báo cho mốc cao nhất vừa vượt qua
        for (int i = MILESTONE_PERCENTS.length - 1; i >= 0; i--) {
            int milestone = MILESTONE_PERCENTS[i];
            if (percentBefore < milestone && percentAfter >= milestone) {
                // Tính số tiền còn lại tại thời điểm đạt mốc
                BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
                if (remaining.compareTo(BigDecimal.ZERO) < 0) remaining = BigDecimal.ZERO;

                NotificationContent msg = NotificationMessages.savingMilestone(
                        goal.getGoalName(), milestone, remaining);
                notificationService.createNotification(
                        goal.getAccount(),
                        msg.title(), msg.content(),
                        NotificationType.SAVING,
                        goal.getId().longValue(),
                        null
                );
                break; // Chỉ gửi 1 thông báo cho mốc cao nhất
            }
        }
    }
}