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
    private final WalletRepository     walletRepository;      // Để đổ tiền về ví khi chốt sổ / hủy
    private final DebtRepository       debtRepository;        // Cascade soft delete
    private final EventRepository      eventRepository;       // Cascade soft delete
    private final NotificationService  notificationService;   // Inject để gửi thông báo milestone

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
        // Bước 1: Validate tài khoản và tiền tệ
        Account account = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Account does not exist"));

        Currency currency = currencyRepository.findById(request.getCurrencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Currency type does not exist"));

        // Validate ngày kết thúc không được là ngày quá khứ
        if (request.getEndDate() != null && request.getEndDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("Invalid end date");
        }

        // Bước 2: Tạo SavingGoal — trạng thái mặc định ACTIVE, finished=false
        // currentAmount auto = 0, chỉ tăng khi có giao dịch Transfer In từ wallet/savinggoal khác
        SavingGoal goal = SavingGoal.builder()
                .goalName(request.getGoalName())
                .targetAmount(request.getTargetAmount())
                .currentAmount(BigDecimal.ZERO) // Auto = 0 khi tạo
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

        // Bước 2.5: Tính lại status sau khi tạo (nếu currentAmount >= targetAmount thì COMPLETED)
        recalculateSavingGoalStatus(savedGoal);
        savingGoalRepository.save(savedGoal);

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
     * Bước 4 — Tính lại trạng thái sau khi cập nhật.
     */
    @Override
    @Transactional
    public SavingGoalResponse updateSavingGoalInfo(Integer id, SavingGoalRequest request, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);

        // Bước 1: getOwnedGoal đã chặn finished=true và CANCELLED
        // Nên ở đây chỉ cần chặn lại nếu finished=true (đã chốt sổ)
        if (Boolean.TRUE.equals(goal.getFinished())) {
            throw new IllegalStateException("Goal has been finalized, cannot edit.");
        }

        // Validate targetAmount trước khi sử dụng
        if (request.getTargetAmount() == null) {
            throw new IllegalArgumentException("Target amount cannot be empty");
        }

        // Bước 2: Không cho phép sửa currentAmount
        // currentAmount chỉ thay đổi khi có giao dịch Transfer In từ wallet/savinggoal khác
        // Không cho phép user chỉnh sửa thủ công

        // Bước 3: Không cho target thấp hơn số tiền đã có
        if (request.getTargetAmount().compareTo(goal.getCurrentAmount()) < 0) {
            throw new IllegalArgumentException(
                    "Target amount cannot be less than current amount");
        }

        // Cập nhật các trường thông tin (chỉ update nếu client có gửi — tránh ghi null vào DB)
        if (request.getGoalName() != null)    goal.setGoalName(request.getGoalName());
        goal.setTargetAmount(request.getTargetAmount());
        if (request.getEndDate() != null)     goal.setEndDate(request.getEndDate());
        if (request.getGoalImageUrl() != null) goal.setGoalImageUrl(request.getGoalImageUrl());
        if (request.getNotified() != null)    goal.setNotified(request.getNotified());
        if (request.getReportable() != null)  goal.setReportable(request.getReportable());

        // Bước 4: Tính lại trạng thái sau khi cập nhật
        recalculateSavingGoalStatus(goal);

        savingGoalRepository.save(goal);
        return mapToResponse(goal);
    }

    // =================================================================================
    // 3. NẠP TIỀN (DEPOSIT)
    // =================================================================================

    /**
     * [3.1] Nạp tiền vào mục tiêu tiết kiệm.
     * Bước 1 — Validate số tiền và trạng thái mục tiêu.
     * Bước 2 — Cộng tiền, tính lại trạng thái.
     * Bước 3 — Tạo giao dịch ghi nhận dòng tiền.
     * Bước 4 — Gửi thông báo milestone (25%, 50%, 75%) hoặc hoàn thành (100%).
     */
    @Override
    @Transactional
    public SavingGoalResponse depositToSavingGoal(Integer id, BigDecimal amount, Integer userId) {
        // Bước 1: Validate số tiền
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Deposit amount must be greater than 0");
        }

        // Lấy goal — dùng getOwnedGoal (chặn CANCELLED và finished=true bên trong)
        SavingGoal goal = getOwnedGoal(id, userId);

        // Guard: không cho nạp quá target (theo DB constraint current_amount <= target_amount)
        BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
        if (amount.compareTo(remaining) > 0) {
            throw new IllegalArgumentException(
                    String.format("Deposit amount exceeds target '%s'. Amount that can still be deposited: %s VND.",
                            goal.getGoalName(), remaining.toPlainString()));
        }

        // Bước 2: Tính % trước khi nạp (để detect milestone vừa vượt qua)
        double percentBefore = calcPercent(goal.getCurrentAmount(), goal.getTargetAmount());

        // Cộng tiền vào goal
        goal.setCurrentAmount(goal.getCurrentAmount().add(amount));

        // Tính % sau khi nạp
        double percentAfter = calcPercent(goal.getCurrentAmount(), goal.getTargetAmount());

        // Flag: vừa đạt 100%? (để gửi đúng loại notification)
        boolean wasCompleted = goal.getGoalStatus().equals(GoalStatus.COMPLETED.getValue());

        // Tính lại trạng thái — dùng hàm chuẩn (không tự set CANCELLED)
        recalculateSavingGoalStatus(goal);

        boolean isNowCompleted = goal.getGoalStatus().equals(GoalStatus.COMPLETED.getValue());
        boolean justCompleted = !wasCompleted && isNowCompleted; // vừa mới đạt 100%

        savingGoalRepository.save(goal);

        // Bước 3: Tạo giao dịch ghi nhận dòng tiền nạp vào
        Category category = categoryRepository.findById(SystemCategory.INCOME_TRANSFER.getId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "System category 'Transfer Income' not found"));

        Transaction depositTransaction = Transaction.builder()
                .account(goal.getAccount())
                .savingGoal(goal)
                .category(category)
                .amount(amount)
                .note("Deposit to saving goal: " + goal.getGoalName())
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
    // 4. RÚT TIỀN (WITHDRAW)
    // =================================================================================

    /**
     * [4.1] Rút tiền từ mục tiêu tiết kiệm (giảm currentAmount).
     *
     * Cho phép rút kể cả khi COMPLETED → tự về ACTIVE (chưa chốt sổ).
     * Không cho phép rút nếu finished=true (đã chốt sổ).
     *
     * Bước 1 — Validate số tiền và trạng thái.
     * Bước 2 — Trừ tiền + tính lại trạng thái.
     * Bước 3 — Tạo giao dịch ghi nhận dòng tiền rút ra.
     */
    @Override
    @Transactional
    public SavingGoalResponse withdrawFromSavingGoal(Integer id, BigDecimal amount, Integer userId) {
        // Bước 1: Validate số tiền
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Withdrawal amount must be greater than 0");
        }

        // Lấy goal — dùng getOwnedGoal (chặn finished=true và CANCELLED bên trong)
        SavingGoal goal = getOwnedGoal(id, userId);

        // Không cho rút nhiều hơn số dư hiện có
        if (amount.compareTo(goal.getCurrentAmount()) > 0) {
            throw new IllegalArgumentException(
                    "Withdrawal amount exceeds current balance of the goal");
        }

        // Bước 2: Trừ tiền và tính lại trạng thái
        // VD: COMPLETED (100%) → rút xuống < 100% → recalculate → ACTIVE lại
        goal.setCurrentAmount(goal.getCurrentAmount().subtract(amount));
        recalculateSavingGoalStatus(goal); // Có thể từ COMPLETED về ACTIVE hoặc OVERDUE
        savingGoalRepository.save(goal);

        // Bước 3: Tạo giao dịch ghi nhận dòng tiền rút ra
        Category category = categoryRepository.findById(SystemCategory.OTHER_EXPENSE.getId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "System category 'Other Expense' not found"));

        Transaction withdrawTransaction = Transaction.builder()
                .account(goal.getAccount())
                .savingGoal(goal)
                .category(category)
                .amount(amount)
                .note("Withdraw from saving goal: " + goal.getGoalName())
                .reportable(true) // Rút tiền tính vào báo cáo
                .sourceType(TransactionSourceType.MANUAL.getValue())
                .transDate(LocalDateTime.now())
                .build();

        transactionRepository.save(withdrawTransaction);

        return mapToResponse(goal);
    }

    // =================================================================================
    // 5. CHỐT SỔ (COMPLETE — GIẢI NGÂN VỀ VÍ)
    // =================================================================================

    /**
     * [5.1] Chốt sổ mục tiêu: finished=true + đổ toàn bộ tiền về wallet được chọn.
     *
     * Điều kiện:
     *   • Goal phải đang COMPLETED (đủ 100%) mới cho chốt sổ.
     *   • finished phải đang là false (chưa chốt).
     *
     * Luồng Atomic (tất cả hoặc không có gì):
     *   B1 — Cộng currentAmount vào balance của wallet đích.
     *   B2 — Tạo transaction ghi nhận dòng tiền từ goal → wallet.
     *   B3 — Set goal: currentAmount=0, finished=true.
     *
     * @param id       ID của saving goal cần chốt sổ
     * @param walletId ID của wallet nhận tiền (null = không đổ về đâu, chỉ đóng goal)
     * @param userId   ID người dùng hiện tại (kiểm tra quyền sở hữu)
     */
    @Override
    @Transactional
    public SavingGoalResponse completeSavingGoal(Integer id, Integer walletId, Integer userId) {
        // Lấy goal — getOwnedGoalForAction cho phép cả COMPLETED (không bị chặn bởi getOwnedGoal)
        SavingGoal goal = getOwnedGoalForAction(id, userId);

        // Validate: chỉ chốt sổ được khi đủ 100% (check actual percentage thay vì chỉ check status)
        // Status có thể COMPLETED nhưng sau khi xóa giao dịch, currentAmount có thể giảm xuống dưới 100%
        if (goal.getCurrentAmount().compareTo(goal.getTargetAmount()) < 0) {
            throw new IllegalStateException(
                    "Can only finalize when goal has reached 100%. " +
                            "Current: " + goal.getCurrentAmount() + "/" + goal.getTargetAmount());
        }

        // Validate: chưa chốt sổ trước đó
        if (Boolean.TRUE.equals(goal.getFinished())) {
            throw new IllegalStateException("Goal has already been finalized, cannot execute again.");
        }

        BigDecimal amountToTransfer = goal.getCurrentAmount(); // Số tiền sẽ chuyển về wallet

        // Bước 1: Đổ tiền về wallet nếu có chọn ví và có tiền
        if (walletId != null && amountToTransfer.compareTo(BigDecimal.ZERO) > 0) {
            Wallet wallet = walletRepository.findById(walletId)
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Wallet not found with ID: " + walletId));

            // Kiểm tra quyền sở hữu ví
            if (!wallet.getAccount().getId().equals(userId)) {
                throw new SecurityException("You do not have permission to use this wallet.");
            }

            // Cộng tiền vào ví đích
            wallet.setBalance(wallet.getBalance().add(amountToTransfer));
            walletRepository.save(wallet);

            // Bước 2: Tạo transaction ghi nhận dòng tiền goal → wallet
            Category category = categoryRepository.findById(SystemCategory.INCOME_TRANSFER.getId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "System category 'Transfer Income' not found"));

            Transaction disbursementTx = Transaction.builder()
                    .account(goal.getAccount())
                    .wallet(wallet) // Đích đến là wallet được chọn
                    .category(category)
                    .amount(amountToTransfer)
                    .note("Finalize saving goal: " + goal.getGoalName() + " → transfer to wallet " + wallet.getWalletName())
                    .reportable(false) // Chuyển nội bộ — không tính vào báo cáo thu/chi
                    .sourceType(TransactionSourceType.MANUAL.getValue())
                    .transDate(LocalDateTime.now())
                    .build();

            transactionRepository.save(disbursementTx);

            // Bước 2a: Gửi thông báo chốt sổ
            NotificationContent msg = NotificationMessages.savingFinalized(
                    goal.getGoalName(), amountToTransfer, wallet.getWalletName());
            notificationService.createNotification(
                    goal.getAccount(),
                    msg.title(), msg.content(),
                    NotificationType.SAVING,
                    goal.getId().longValue(),
                    null // gửi ngay
            );
        }

        // Bước 3: Chốt sổ goal — đóng hoàn toàn
        goal.setCurrentAmount(BigDecimal.ZERO); // Tiền đã chuyển đi hết
        goal.setFinished(true);                 // Đánh dấu đã chốt sổ — KHÔNG thể hoàn tác
        goal.setGoalStatus(GoalStatus.COMPLETED.getValue()); // Giữ nguyên COMPLETED
        savingGoalRepository.save(goal);

        return mapToResponse(goal);
    }

    // =================================================================================
    // 6. HỦY MỤC TIÊU (CANCEL — GIẢI NGÂN VỀ VÍ)
    // =================================================================================

    /**
     * [6.1] Hủy mục tiêu: CANCELLED + finished=true + đổ tiền còn lại về wallet.
     *
     * Khác với Soft Delete (deleteSavingGoal):
     *   • Hủy (cancel): Đổi trạng thái + giải ngân → record vẫn còn trong DB (deleted=false).
     *   • Xóa (delete): Soft delete (deleted=true) → ẩn khỏi toàn bộ query.
     *
     * Luồng Atomic:
     *   B1 — Cộng currentAmount vào balance của wallet đích (nếu có chọn ví).
     *   B2 — Tạo transaction ghi nhận dòng tiền hoàn trả.
     *   B3 — Set goal: currentAmount=0, goalStatus=CANCELLED, finished=true.
     *
     * @param id       ID của saving goal cần hủy
     * @param walletId ID của wallet nhận tiền hoàn trả (null = không đổ về đâu)
     * @param userId   ID người dùng hiện tại (kiểm tra quyền sở hữu)
     */
    @Override
    @Transactional
    public SavingGoalResponse cancelSavingGoal(Integer id, Integer walletId, Integer userId) {
        // Lấy goal — cho phép hủy ở mọi trạng thái trừ finished=true
        SavingGoal goal = getOwnedGoalForAction(id, userId);

        // Validate: đã chốt/hủy rồi thì không làm gì nữa
        if (Boolean.TRUE.equals(goal.getFinished())) {
            throw new IllegalStateException("Goal has been closed, cannot cancel.");
        }

        BigDecimal amountToReturn = goal.getCurrentAmount(); // Số tiền sẽ hoàn trả về wallet

        // Bước 1: Đổ tiền về wallet nếu có chọn ví và còn tiền
        if (walletId != null && amountToReturn.compareTo(BigDecimal.ZERO) > 0) {
            Wallet wallet = walletRepository.findById(walletId)
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Wallet not found with ID: " + walletId));

            // Kiểm tra quyền sở hữu ví
            if (!wallet.getAccount().getId().equals(userId)) {
                throw new SecurityException("You do not have permission to use this wallet.");
            }

            // Cộng tiền hoàn trả vào ví đích
            wallet.setBalance(wallet.getBalance().add(amountToReturn));
            walletRepository.save(wallet);

            // Bước 2: Tạo transaction ghi nhận dòng tiền hoàn trả
            Category category = categoryRepository.findById(SystemCategory.INCOME_TRANSFER.getId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "System category 'Transfer Income' not found"));

            Transaction refundTx = Transaction.builder()
                    .account(goal.getAccount())
                    .wallet(wallet)
                    .category(category)
                    .amount(amountToReturn)
                    .note("Cancel saving goal: " + goal.getGoalName() + " → refund to wallet " + wallet.getWalletName())
                    .reportable(false) // Chuyển nội bộ — không tính vào báo cáo thu/chi
                    .sourceType(TransactionSourceType.MANUAL.getValue())
                    .transDate(LocalDateTime.now())
                    .build();

            transactionRepository.save(refundTx);

            // Bước 2a: Gửi thông báo hủy mục tiêu
            NotificationContent msg = NotificationMessages.savingCancelled(
                    goal.getGoalName(), amountToReturn, wallet.getWalletName());
            notificationService.createNotification(
                    goal.getAccount(),
                    msg.title(), msg.content(),
                    NotificationType.SAVING,
                    goal.getId().longValue(),
                    null // gửi ngay
            );
        }

        // Bước 3: Đóng goal hoàn toàn
        goal.setCurrentAmount(BigDecimal.ZERO);              // Tiền đã hoàn trả
        goal.setGoalStatus(GoalStatus.CANCELLED.getValue()); // Trạng thái CANCELLED
        goal.setFinished(true);                              // KHÔNG thể hoàn tác
        savingGoalRepository.save(goal);

        return mapToResponse(goal);
    }

    // =================================================================================
    // 7. XÓA MỤC TIÊU (SOFT DELETE)
    // =================================================================================

    /**
     * [7.1] Xóa mục tiêu (Soft delete — deleted=true).
     *
     * Phân biệt với "Hủy" (cancelSavingGoal):
     *   • Hủy (cancel): Đổi trạng thái CANCELLED + giải ngân → vẫn còn trong DB.
     *   • Xóa (delete): Soft delete (deleted=true) → @SQLRestriction ẩn hẳn khỏi mọi query.
     *
     * KHÔNG set CANCELLED hay finished ở đây — chỉ đánh dấu deleted.
     * Mục tiêu đã finished=true vẫn có thể xóa (ẩn khỏi UI).
     *
     * Cascade xóa mềm toàn bộ dữ liệu liên kết:
     *   • Transactions thuộc goal_id
     *   • Debts có giao dịch trong mục tiêu này
     *   • Events có giao dịch trong mục tiêu này
     */
    @Override
    @Transactional
    public void deleteSavingGoal(Integer id, Integer userId) {
        // Dùng getOwnedGoalForAction vì cho phép xóa mọi trạng thái (kể cả CANCELLED, COMPLETED)
        SavingGoal goal = getOwnedGoalForAction(id, userId);

        // Soft delete cascade — ẩn vĩnh viễn khỏi mọi query (@SQLRestriction "deleted=0")
        goal.setDeleted(true);
        goal.setDeletedAt(LocalDateTime.now());
        // LƯU Ý: KHÔNG set CANCELLED hay finished ở đây
        //   → CANCELLED chỉ từ cancelSavingGoal()
        //   → finished=true chỉ từ completeSavingGoal() hoặc cancelSavingGoal()

        // Cascade xóa mềm các bảng liên quan
        transactionRepository.softDeleteAllBySavingGoalId(id);  // Giao dịch thuộc mục tiêu
        debtRepository.softDeleteAllBySavingGoalId(id);         // Khoản nợ liên quan
        eventRepository.softDeleteAllBySavingGoalId(id);        // Sự kiện liên quan

        savingGoalRepository.save(goal);
    }

    // =================================================================================
    // 8. LẤY DANH SÁCH & CHI TIẾT (READ)
    // =================================================================================

    /**
     * [8.1] Lấy tất cả mục tiêu của user, hỗ trợ tìm kiếm theo tên.
     * Mục tiêu đã xóa (deleted=true) tự động bị ẩn bởi @SQLRestriction("deleted=0").
     */
    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search, Boolean isFinished) {
        // Lấy tất cả goal chưa bị xóa (kể cả CANCELLED, COMPLETED, OVERDUE)
        List<SavingGoal> goals;

        if (isFinished != null) {
            goals = savingGoalRepository.findByAccount_IdAndFinished(userId, isFinished);
        } else {
            goals = savingGoalRepository.findByAccount_Id(userId);
        }

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
     * [8.2] Lấy chi tiết một mục tiêu theo ID + kiểm tra quyền sở hữu.
     */
    @Override
    public SavingGoalResponse getSavingGoalDetail(Integer id, Integer userId) {
        return mapToResponse(getOwnedGoalForAction(id, userId));
    }

    // =================================================================================
    // 9. PRIVATE HELPERS
    // =================================================================================

    /**
     * [9.1] Tính lại trạng thái goal sau mỗi biến động số tiền.
     *
     * Quy tắc:
     *   • CANCELLED + finished=true  → Trạng thái cuối, KHÔNG đụng vào.
     *   • finished=true              → Đã chốt sổ, KHÔNG đụng vào.
     *   • current == target          → COMPLETED (finished vẫn false — chưa chốt sổ).
     *   • current < target + quá hạn → OVERDUE.
     *   • current < target + còn hạn → ACTIVE (kể cả khi đang COMPLETED bị rút xuống).
     *
     * QUAN TRỌNG: KHÔNG bao giờ tự set CANCELLED ở đây.
     * CANCELLED chỉ được set từ cancelSavingGoal() hoặc deleteSavingGoal().
     *
     * Gọi ở: depositToSavingGoal(), withdrawFromSavingGoal(), updateSavingGoalInfo().
     */
    private void recalculateSavingGoalStatus(SavingGoal goal) {
        // Trường hợp 1: Trạng thái cuối — không đụng vào
        if (goal.getGoalStatus().equals(GoalStatus.CANCELLED.getValue())
                || Boolean.TRUE.equals(goal.getFinished())) {
            return;
        }

        BigDecimal current = goal.getCurrentAmount(); // Số tiền hiện có
        BigDecimal target  = goal.getTargetAmount();  // Số tiền mục tiêu
        LocalDate  today   = LocalDate.now();          // Ngày hôm nay

        if (current.compareTo(target) == 0) {
            // Đúng bằng target → COMPLETED (finished vẫn false — user chưa chốt sổ)
            goal.setGoalStatus(GoalStatus.COMPLETED.getValue());
        } else if (goal.getEndDate() != null && goal.getEndDate().isBefore(today)) {
            // Chưa đủ tiền + đã quá hạn → OVERDUE
            goal.setGoalStatus(GoalStatus.OVERDUE.getValue());
        } else {
            // Chưa đủ tiền + còn hạn → ACTIVE
            // (kể cả khi trước đó là COMPLETED mà bị rút tiền xuống < 100%)
            goal.setGoalStatus(GoalStatus.ACTIVE.getValue());
        }
    }

    /**
     * [9.2] Tìm mục tiêu và kiểm tra quyền sở hữu.
     *
     * Dùng cho: depositToSavingGoal(), withdrawFromSavingGoal(), updateSavingGoalInfo().
     * Chặn thêm: finished=true và CANCELLED — không cho thao tác trên goal đã đóng.
     */
    private SavingGoal getOwnedGoal(Integer id, Integer userId) {
        // @SQLRestriction("deleted=0") → goal deleted=true sẽ không tìm thấy → orElseThrow đúng
        SavingGoal goal = savingGoalRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Goal not found with ID: " + id));

        // Kiểm tra quyền sở hữu
        if (goal.getAccount() == null || !goal.getAccount().getId().equals(userId)) {
            throw new SecurityException("You do not have permission to operate on this goal.");
        }

        // Chặn nếu đã chốt sổ hoàn toàn (finished=true)
        if (Boolean.TRUE.equals(goal.getFinished())) {
            throw new IllegalStateException(
                    "Goal has been fully finalized. Cannot perform operation.");
        }

        // Chặn nếu đã CANCELLED (hủy giữa chừng mà chưa xóa)
        if (goal.getGoalStatus().equals(GoalStatus.CANCELLED.getValue())) {
            throw new IllegalStateException(
                    "Goal has been cancelled. Cannot deposit/withdraw/edit this goal.");
        }

        return goal;
    }

    /**
     * [9.3] Tìm mục tiêu cho các thao tác KHÔNG bị chặn bởi trạng thái.
     *
     * Dùng cho: completeSavingGoal(), cancelSavingGoal(), deleteSavingGoal(),
     *           getSavingGoalDetail() — cần xem được mọi trạng thái.
     *
     * Khác getOwnedGoal(): KHÔNG chặn CANCELLED hay finished=true.
     * Hàm gọi tự xử lý logic validate trạng thái riêng.
     */
    private SavingGoal getOwnedGoalForAction(Integer id, Integer userId) {
        SavingGoal goal = savingGoalRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Goal not found with ID: " + id));

        // Kiểm tra quyền sở hữu
        if (goal.getAccount() == null || !goal.getAccount().getId().equals(userId)) {
            throw new SecurityException("You do not have permission to operate on this goal.");
        }

        return goal;
    }

    /**
     * [9.4] Chuyển đổi SavingGoal → SavingGoalResponse.
     * Tính thêm remainingAmount và progressPercent.
     */
    private SavingGoalResponse mapToResponse(SavingGoal goal) {
        // Tính số tiền còn thiếu (không âm)
        BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
        if (remaining.compareTo(BigDecimal.ZERO) < 0) remaining = BigDecimal.ZERO;

        // Tính phần trăm hoàn thành (giới hạn tối đa 100%)
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
     * [9.5] Tính phần trăm hoàn thành. Tránh chia cho 0.
     */
    private double calcPercent(BigDecimal current, BigDecimal target) {
        // Tránh NullPointerException và chia cho 0
        if (target == null || target.compareTo(BigDecimal.ZERO) == 0) return 0.0;
        return current
                .divide(target, 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100))
                .doubleValue();
    }

    /**
     * [9.6] Gửi thông báo milestone khi nạp tiền.
     *   • Vừa đạt 100% → thông báo hoàn thành (savingCompleted).
     *   • Vừa vượt qua mốc 25/50/75% → thông báo tiến độ (savingMilestone).
     *   • Chỉ gửi 1 thông báo cho mốc cao nhất vừa đạt được.
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
            return; // Chỉ gửi 1 thông báo — không gửi thêm milestone
        }

        // Trường hợp 2: Kiểm tra từng mốc từ cao xuống thấp (75 → 50 → 25)
        // Gửi thông báo cho mốc cao nhất vừa vượt qua
        for (int i = MILESTONE_PERCENTS.length - 1; i >= 0; i--) {
            int milestone = MILESTONE_PERCENTS[i]; // Mốc đang xét: 75, 50, hoặc 25

            // Kiểm tra: trước khi nạp chưa đạt mốc, sau khi nạp đã đạt hoặc vượt
            if (percentBefore < milestone && percentAfter >= milestone) {
                // Tính số tiền còn lại sau khi đạt mốc
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
