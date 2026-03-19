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
     */
    @Override
    @Transactional
    public SavingGoalResponse updateSavingGoalInfo(Integer id, SavingGoalRequest request, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);

        // Bước 1: Chỉ sửa được khi đang ACTIVE
        if (!goal.getGoalStatus().equals(GoalStatus.ACTIVE.getValue())) {
            throw new IllegalStateException("Chỉ có thể sửa mục tiêu đang hoạt động.");
        }

        // Bước 2: Không cho target thấp hơn số tiền đã có
        if (request.getTargetAmount().compareTo(goal.getCurrentAmount()) < 0) {
            throw new IllegalArgumentException(
                    "Số tiền mục tiêu không được nhỏ hơn số tiền hiện tại");
        }

        // Bước 3: Cập nhật các trường
        goal.setGoalName(request.getGoalName());
        goal.setTargetAmount(request.getTargetAmount());
        goal.setEndDate(request.getEndDate());
        goal.setGoalImageUrl(request.getGoalImageUrl());
        goal.setNotified(request.getNotified());
        goal.setReportable(request.getReportable());

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
     * [4.1] Hủy mục tiêu (Soft delete — chuyển sang CANCELLED, không xóa cứng).
     * Giữ lại lịch sử giao dịch.
     */
    @Override
    @Transactional
    public void deleteSavingGoal(Integer id, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);

        goal.setGoalStatus(GoalStatus.CANCELLED.getValue());
        goal.setFinished(true);

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