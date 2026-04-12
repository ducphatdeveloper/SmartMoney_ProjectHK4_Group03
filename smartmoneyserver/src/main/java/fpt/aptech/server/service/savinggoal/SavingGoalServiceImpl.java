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

        // Service-level guard (DTO đã có @PositiveOrZero nhưng cần guard thêm nếu gọi internal)
        if (initialAmount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Số tiền ban đầu không được âm");
        }

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

        // Bước 4: Cập nhật các trường thông tin (chỉ update nếu client có gửi — tránh ghi null vào DB)
        if (request.getGoalName() != null) goal.setGoalName(request.getGoalName());
        goal.setTargetAmount(request.getTargetAmount());
        if (request.getEndDate() != null) goal.setEndDate(request.getEndDate());
        if (request.getGoalImageUrl() != null) goal.setGoalImageUrl(request.getGoalImageUrl());
        if (request.getNotified() != null)   goal.setNotified(request.getNotified());
        if (request.getReportable() != null) goal.setReportable(request.getReportable());

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

        // Guard: không cho nạp vượt quá số tiền mục tiêu
        if (newAmount.compareTo(goal.getTargetAmount()) > 0) {
            BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
            throw new IllegalArgumentException(
                    String.format("Số tiền nạp vào vượt quá mục tiêu '%s'. Số tiền còn có thể nạp: %s đ.",
                            goal.getGoalName(), remaining.toPlainString()));
        }

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
    // 4. XÓA MỤC TIÊU (SOFT DELETE)
    // =================================================================================

    /**
     * [4.1] Xóa mục tiêu vĩnh viễn (Soft delete — deleted=true + CANCELLED).
     *
     * Phân biệt với "tạm dừng" (toggleActive):
     *   • Xóa: CANCELLED + deleted=true  → @SQLRestriction ẩn hẳn, KHÔNG phục hồi được
     *   • Tạm dừng: CANCELLED + deleted=false → vẫn hiển thị, CÓ THỂ kích hoạt lại
     *
     * Mục tiêu tiết kiệm là NGUỒN TIỀN → cascade xóa mềm toàn bộ dữ liệu liên kết:
     *   • Transactions thuộc goal_id
     *   • Debts có giao dịch trong mục tiêu này (qua subquery tTransactions)
     *   • Events có giao dịch trong mục tiêu này (qua subquery tTransactions)
     */
    @Override
    @Transactional
    public void deleteSavingGoal(Integer id, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);

        goal.setGoalStatus(GoalStatus.CANCELLED.getValue());
        goal.setFinished(true);

        // Soft delete cascade — ẩn vĩnh viễn khỏi mọi query (@SQLRestriction "deleted=0")
        goal.setDeleted(true);
        goal.setDeletedAt(java.time.LocalDateTime.now());
        transactionRepository.softDeleteAllBySavingGoalId(id);   // Giao dịch thuộc mục tiêu
        debtRepository.softDeleteAllBySavingGoalId(id);          // Khoản nợ có giao dịch thuộc mục tiêu
        eventRepository.softDeleteAllBySavingGoalId(id);         // Sự kiện có giao dịch thuộc mục tiêu

        savingGoalRepository.save(goal);
    }

    // =================================================================================
    // 5. BẬT / TẮT MỤC TIÊU (TOGGLE ACTIVE)
    // =================================================================================

    /**
     * [5.1] Toggle trạng thái ACTIVE ↔ CANCELLED (tạm dừng/kích hoạt lại).
     *
     * Quy tắc:
     *   • ACTIVE   → CANCELLED (finished=true)  : tạm dừng / kết thúc sớm
     *   • CANCELLED→ ACTIVE   (finished=false)  : kích hoạt lại mục tiêu đã tạm dừng
     *   • OVERDUE  → ACTIVE   (finished=false)  : kích hoạt lại mục tiêu quá hạn
     *   • COMPLETED → ném lỗi (đã hoàn thành đầy đủ, KHÔNG kích hoạt lại)
     *
     * Lưu ý: CANCELLED ở đây là deleted=false (tạm dừng).
     *        CANCELLED + deleted=true là xóa vĩnh viễn — không bao giờ vào được hàm này
     *        vì @SQLRestriction("deleted=0") lọc ra trước rồi.
     */
    @Override
    @Transactional
    public SavingGoalResponse togglePauseSavingGoal(Integer id, Integer userId) {
        // Dùng helper riêng — cho phép tìm cả goal đang CANCELLED (tạm dừng)
        SavingGoal goal = getOwnedGoalForToggle(id, userId);

        Integer currentStatus = goal.getGoalStatus();

        if (currentStatus.equals(GoalStatus.COMPLETED.getValue())) {
            throw new IllegalStateException(
                    "Mục tiêu đã hoàn thành (đủ tiền), không thể thay đổi trạng thái.");
        }

        if (currentStatus.equals(GoalStatus.ACTIVE.getValue())) {
            // ACTIVE → CANCELLED (tạm dừng)
            goal.setGoalStatus(GoalStatus.CANCELLED.getValue());
            goal.setFinished(true);
        } else if (currentStatus.equals(GoalStatus.CANCELLED.getValue())
                || currentStatus.equals(GoalStatus.OVERDUE.getValue())) {
            // CANCELLED hoặc OVERDUE → ACTIVE (kích hoạt lại)
            goal.setGoalStatus(GoalStatus.ACTIVE.getValue());
            goal.setFinished(false);
        } else {
            throw new IllegalStateException("Không thể thay đổi trạng thái mục tiêu này.");
        }

        savingGoalRepository.save(goal);
        return mapToResponse(goal);
    }

    // =================================================================================
    // 6. LẤY DANH SÁCH & CHI TIẾT (READ)
    // =================================================================================

    /**
     * [6.1] Lấy tất cả mục tiêu của user (kể cả CANCELLED=tạm dừng), hỗ trợ tìm kiếm theo tên.
     * Mục tiêu đã xóa (deleted=true) tự động bị ẩn bởi @SQLRestriction("deleted=0").
     */
    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search) {
        // Lấy tất cả goal chưa bị xóa (bao gồm CANCELLED=tạm dừng)
        List<SavingGoal> goals = savingGoalRepository.findByAccount_Id(userId);

        // Lọc theo tên nếu có từ khóa tìm kiếm
        if (search != null && !search.isBlank()) {
            String keyword = search.trim().toLowerCase();
            goals = goals.stream()
                    .filter(g -> g.getGoalName().toLowerCase().contains(keyword))
                    .toList();
        }

        return goals.stream().map(this::mapToResponse).toList();
    }

    /**
     * [6.2] Lấy chi tiết một mục tiêu theo ID + kiểm tra quyền sở hữu.
     */
    @Override
    public SavingGoalResponse getSavingGoalDetail(Integer id, Integer userId) {
        return mapToResponse(getOwnedGoalForToggle(id, userId));
    }

    // =================================================================================
    // 7. PRIVATE HELPERS
    // =================================================================================

    /**
     * [7.1] Tìm mục tiêu và kiểm tra quyền sở hữu.
     * Dùng cho: create, deposit, update, delete.
     * Chỉ cho phép thao tác khi mục tiêu ACTIVE (hoặc OVERDUE cho delete).
     * Mục tiêu CANCELLED (tạm dừng) → KHÔNG thao tác (chỉ dùng toggleActive).
     * Mục tiêu deleted=true → @SQLRestriction tự lọc, findById trả về empty.
     */
    private SavingGoal getOwnedGoal(Integer id, Integer userId) {
        // @SQLRestriction("deleted=0") → goal deleted=true sẽ không tìm thấy → orElseThrow luôn đúng
        SavingGoal goal = savingGoalRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy mục tiêu với ID: " + id));

        // Kiểm tra quyền sở hữu
        if (goal.getAccount() == null || !goal.getAccount().getId().equals(userId)) {
            throw new SecurityException("Bạn không có quyền thao tác trên mục tiêu này.");
        }

        // CANCELLED (tạm dừng) → không cho deposit/update, chỉ cho toggle hoặc delete
        if (goal.getGoalStatus().equals(GoalStatus.CANCELLED.getValue())) {
            throw new IllegalStateException(
                    "Mục tiêu đang tạm dừng. Hãy kích hoạt lại trước khi thực hiện thao tác.");
        }

        return goal;
    }

    /**
     * [7.2] Tìm mục tiêu cho toggle active (cho phép cả CANCELLED=tạm dừng).
     * Dùng riêng cho: togglePauseSavingGoal(), getSavingGoalDetail().
     */
    private SavingGoal getOwnedGoalForToggle(Integer id, Integer userId) {
        SavingGoal goal = savingGoalRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy mục tiêu với ID: " + id));

        if (goal.getAccount() == null || !goal.getAccount().getId().equals(userId)) {
            throw new SecurityException("Bạn không có quyền thao tác trên mục tiêu này.");
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