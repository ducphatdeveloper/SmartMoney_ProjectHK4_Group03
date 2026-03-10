package fpt.aptech.server.service.savinggoal;

import fpt.aptech.server.dto.savinggoal.SavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.SavingGoalResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Currency;
import fpt.aptech.server.entity.SavingGoal;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.savinggoal.GoalStatus;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.SavingGoalRepository;
import fpt.aptech.server.repos.TransactionRepository;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class SavingGoalServiceImpl implements SavingGoalService {

    private final SavingGoalRepository savingGoalRepository;
    private final AccountRepository accountRepository;
    private final CurrencyRepository currencyRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;

    // ================= CREATE =================

    /**
     * Tạo mục tiêu tiết kiệm mới.
     */
    @Override
    @Transactional
    public SavingGoalResponse createSavingGoal(SavingGoalRequest request, Integer userId) {

        Account account = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));

        Currency currency = currencyRepository.findById(request.getCurrencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Loại tiền tệ không tồn tại"));

        if (request.getEndDate() != null && request.getEndDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("Ngày kết thúc không hợp lệ");
        }

        BigDecimal initialAmount = request.getInitialAmount() != null ? request.getInitialAmount() : BigDecimal.ZERO;

        SavingGoal goal = SavingGoal.builder()
                .goalName(request.getGoalName())
                .targetAmount(request.getTargetAmount())
                .currentAmount(initialAmount)
                .currency(currency)
                .account(account)
                .goalImageUrl(request.getGoalImageUrl())
                .endDate(request.getEndDate())
                .goalStatus(GoalStatus.ACTIVE.getValue()) // Mặc định là "Đang hoạt động"
                .finished(false)
                .notified(request.getNotified() != null ? request.getNotified() : true)
                .reportable(request.getReportable() != null ? request.getReportable() : true)
                .build();

        SavingGoal savedGoal = savingGoalRepository.save(goal);

        // Nếu có số tiền ban đầu, tạo một giao dịch "khởi tạo" để ghi nhận dòng tiền
        if (initialAmount.compareTo(BigDecimal.ZERO) > 0) {
            // Lấy danh mục hệ thống "Tiền chuyển đến" để ghi nhận giao dịch này
            Category category = categoryRepository.findById(SystemCategory.INCOME_TRANSFER.getId())
                    .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục hệ thống 'Tiền chuyển đến'"));

            Transaction initTransaction = Transaction.builder()
                    .account(account)
                    .savingGoal(savedGoal) // Gán giao dịch này cho mục tiêu vừa tạo
                    .category(category)
                    .amount(initialAmount)
                    .note("Số dư ban đầu cho mục tiêu tiết kiệm")
                    .reportable(false) // Giao dịch này không tính vào báo cáo thu/chi thông thường
                    .transDate(LocalDateTime.now())
                    .build();

            transactionRepository.save(initTransaction);
        }

        return mapToResponse(savedGoal);
    }

    // ================= UPDATE INFO =================

    /**
     * Cập nhật thông tin của một mục tiêu.
     */
    @Override
    @Transactional
    public SavingGoalResponse updateSavingGoalInfo(Integer id, SavingGoalRequest request, Integer userId) {

        SavingGoal goal = getOwnedGoal(id, userId);

        // Chỉ cho phép sửa khi mục tiêu đang hoạt động
        if (!goal.getGoalStatus().equals(GoalStatus.ACTIVE.getValue())) {
            throw new IllegalStateException("Chỉ có thể sửa mục tiêu đang hoạt động.");
        }

        // Không cho phép đặt mục tiêu thấp hơn số tiền đã có
        if (request.getTargetAmount().compareTo(goal.getCurrentAmount()) < 0) {
            throw new IllegalArgumentException("Số tiền mục tiêu không được nhỏ hơn số tiền hiện tại");
        }

        goal.setGoalName(request.getGoalName());
        goal.setTargetAmount(request.getTargetAmount());
        goal.setEndDate(request.getEndDate());
        goal.setGoalImageUrl(request.getGoalImageUrl());
        goal.setNotified(request.getNotified());
        goal.setReportable(request.getReportable());

        savingGoalRepository.save(goal);

        return mapToResponse(goal);
    }

    // ================= DEPOSIT =================

    /**
     * Nạp tiền vào một mục tiêu tiết kiệm.
     */
    @Override
    @Transactional
    public SavingGoalResponse depositToSavingGoal(Integer id, BigDecimal amount, Integer userId) {

        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Số tiền nạp phải lớn hơn 0");
        }

        SavingGoal goal = getOwnedGoal(id, userId);

        // Chỉ cho phép nạp tiền khi mục tiêu đang hoạt động
        if (!goal.getGoalStatus().equals(GoalStatus.ACTIVE.getValue())) {
            throw new IllegalStateException("Không thể nạp tiền vào mục tiêu đã hoàn thành hoặc bị hủy.");
        }

        // 1. Cập nhật số tiền hiện tại của mục tiêu
        BigDecimal newAmount = goal.getCurrentAmount().add(amount);
        goal.setCurrentAmount(newAmount);

        // 2. Kiểm tra xem đã đạt mục tiêu chưa
        if (newAmount.compareTo(goal.getTargetAmount()) >= 0) {
            goal.setGoalStatus(GoalStatus.COMPLETED.getValue()); // Chuyển trạng thái sang "Hoàn thành"
            goal.setFinished(true);
        }

        savingGoalRepository.save(goal);

        // 3. Tạo giao dịch tương ứng để ghi nhận dòng tiền
        Category category = categoryRepository.findById(SystemCategory.INCOME_TRANSFER.getId())
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục hệ thống 'Tiền chuyển đến'"));

        Transaction depositTransaction = Transaction.builder()
                .account(goal.getAccount())
                .savingGoal(goal)
                .category(category)
                .amount(amount)
                .note("Nạp tiền vào mục tiêu: " + goal.getGoalName())
                .reportable(true) // Giao dịch nạp tiền này có thể tính vào báo cáo
                .transDate(LocalDateTime.now())
                .build();

        transactionRepository.save(depositTransaction);

        return mapToResponse(goal);
    }

    // ================= DELETE (CANCEL) =================

    /**
     * Hủy một mục tiêu (chuyển trạng thái sang CANCELLED).
     */
    @Override
    @Transactional
    public void deleteSavingGoal(Integer id, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);

        // Chuyển trạng thái, không xóa cứng
        goal.setGoalStatus(GoalStatus.CANCELLED.getValue());
        goal.setFinished(true);

        savingGoalRepository.save(goal);
    }

    // ================= GET ALL =================

    /**
     * Lấy tất cả các mục tiêu của một người dùng (trừ những mục đã hủy).
     */
    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search) {
        List<SavingGoal> goals;

        // Lọc các mục tiêu không bị hủy
        Integer statusToExclude = GoalStatus.CANCELLED.getValue();

        if (search != null && !search.isBlank()) {
            goals = savingGoalRepository
                    .findByAccount_IdAndGoalNameContainingIgnoreCaseAndGoalStatusNot(
                            userId, search, statusToExclude);
        } else {
            goals = savingGoalRepository
                    .findByAccount_IdAndGoalStatusNot(userId, statusToExclude);
        }

        return goals.stream()
                .map(this::mapToResponse)
                .toList();
    }

    // ================= DETAIL =================

    @Override
    public SavingGoalResponse getSavingGoalDetail(Integer id, Integer userId) {
        SavingGoal goal = getOwnedGoal(id, userId);
        return mapToResponse(goal);
    }

    // ================= PRIVATE HELPERS =================

    /**
     * Lấy một mục tiêu và kiểm tra quyền sở hữu.
     * Đồng thời, không cho phép thao tác trên mục tiêu đã bị hủy.
     */
    private SavingGoal getOwnedGoal(Integer id, Integer userId) {
        SavingGoal goal = savingGoalRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy mục tiêu với ID: " + id));

        // Kiểm tra quyền sở hữu
        if (goal.getAccount() == null || !goal.getAccount().getId().equals(userId)) {
            throw new SecurityException("Bạn không có quyền thao tác trên mục tiêu này.");
        }

        // Không cho phép thao tác trên mục tiêu đã bị hủy (trừ khi là xem chi tiết)
        if (goal.getGoalStatus().equals(GoalStatus.CANCELLED.getValue())) {
            throw new IllegalStateException("Mục tiêu này đã bị hủy và không thể thao tác.");
        }

        return goal;
    }

    /**
     * Chuyển đổi từ Entity SavingGoal sang DTO SavingGoalResponse để trả về cho client.
     */
    private SavingGoalResponse mapToResponse(SavingGoal goal) {
        // Tính toán số tiền còn thiếu
        BigDecimal remainingAmount = goal.getTargetAmount().subtract(goal.getCurrentAmount());
        if (remainingAmount.compareTo(BigDecimal.ZERO) < 0) {
            remainingAmount = BigDecimal.ZERO; // Không hiển thị số âm
        }

        double percent = 0;
        // Tính toán phần trăm hoàn thành, tránh chia cho 0
        if (goal.getTargetAmount() != null && goal.getTargetAmount().compareTo(BigDecimal.ZERO) > 0) {
            percent = goal.getCurrentAmount()
                    .divide(goal.getTargetAmount(), 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100))
                    .doubleValue();
        }
        // Đảm bảo phần trăm không vượt quá 100%
        percent = Math.min(percent, 100);

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
                .remainingAmount(remainingAmount) // Thêm trường còn thiếu
                .progressPercent(percent)
                .build();
    }
}