package fpt.aptech.server.service.savinggoal;

import fpt.aptech.server.dto.savinggoal.SavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.SavingGoalResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Currency;
import fpt.aptech.server.entity.SavingGoal;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.SavingGoalRepository;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class SavingGoalServiceImpl implements SavingGoalService {

    private final SavingGoalRepository savingGoalRepository;
    private final AccountRepository accountRepository;
    private final CurrencyRepository currencyRepository;

    private static final Integer STATUS_ACTIVE = 1;
    private static final Integer STATUS_COMPLETED = 2;
    private static final Integer STATUS_CANCELLED = 3;

    // ================= CREATE =================
    @Override
    @Transactional
    public SavingGoalResponse createSavingGoal(SavingGoalRequest request, Integer userId) {

        Account account = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy tài khoản"));

        Currency currency = currencyRepository.findById(request.getCurrencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy loại tiền"));

        // ✅ Check trùng tên theo user
        if (savingGoalRepository.existsByGoalNameAndAccount_IdAndGoalStatusNot(
                request.getGoalName(), userId, STATUS_CANCELLED)) {
            throw new IllegalArgumentException("Tên mục tiêu đã tồn tại.");
        }

        if (request.getEndDate() != null && request.getEndDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("Ngày kết thúc không hợp lệ.");
        }

        SavingGoal goal = SavingGoal.builder()
                .goalName(request.getGoalName())
                .targetAmount(request.getTargetAmount())
                .currentAmount(BigDecimal.ZERO) // ✅ Quan trọng
                .currency(currency)
                .account(account)
                .goalImageUrl(request.getGoalImageUrl())
                .endDate(request.getEndDate())
                .goalStatus(STATUS_ACTIVE) // ✅ Quan trọng
                .finished(false) // ✅ Quan trọng
                .notified(request.getNotified() != null ? request.getNotified() : true)
                .reportable(request.getReportable() != null ? request.getReportable() : true)
                .build();

        savingGoalRepository.save(goal);

        return mapToResponse(goal);
    }

    // ================= UPDATE INFO =================
    @Override
    @Transactional
    public SavingGoalResponse updateSavingGoalInfo(Integer id, SavingGoalRequest request, Integer userId) {

        SavingGoal goal = getOwnedGoal(id, userId);

        // ❌ Không cho sửa nếu đã hoàn thành
        if (goal.getGoalStatus().equals(STATUS_COMPLETED)) {
            throw new IllegalStateException("Không thể sửa mục tiêu đã hoàn thành.");
        }

        // ✅ Check trùng tên nếu tên thay đổi
        if (!Objects.equals(goal.getGoalName(), request.getGoalName())) {
            if (savingGoalRepository.existsByGoalNameAndAccount_IdAndGoalStatusNot(
                    request.getGoalName(), userId, STATUS_CANCELLED)) {
                throw new IllegalArgumentException("Tên mục tiêu đã tồn tại.");
            }
        }

        // ❌ Không cho target < current
        if (request.getTargetAmount().compareTo(goal.getCurrentAmount()) < 0) {
            throw new IllegalArgumentException("Target không được nhỏ hơn số tiền hiện tại.");
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
    @Override
    @Transactional
    public SavingGoalResponse depositToSavingGoal(Integer id, BigDecimal amount, Integer userId) {

        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Số tiền phải lớn hơn 0");
        }

        SavingGoal goal = getOwnedGoal(id, userId);

        if (!goal.getGoalStatus().equals(STATUS_ACTIVE)) {
            throw new IllegalStateException("Không thể nạp tiền vào mục tiêu này.");
        }

        BigDecimal newAmount = goal.getCurrentAmount().add(amount);
        goal.setCurrentAmount(newAmount);

        if (newAmount.compareTo(goal.getTargetAmount()) >= 0) {
            goal.setGoalStatus(STATUS_COMPLETED);
            goal.setFinished(true);
        }

        savingGoalRepository.save(goal);

        return mapToResponse(goal);
    }

    // ================= DELETE (CANCEL) =================
    @Override
    @Transactional
    public void deleteSavingGoal(Integer id, Integer userId) {

        SavingGoal goal = getOwnedGoal(id, userId);

        goal.setGoalStatus(STATUS_CANCELLED);
        goal.setFinished(true);

        savingGoalRepository.save(goal);
    }

    // ================= GET ALL =================
    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer userId, String search) {

        List<SavingGoal> goals;

        if (search != null && !search.isBlank()) {
            goals = savingGoalRepository
                    .findByAccount_IdAndGoalNameContainingIgnoreCaseAndGoalStatusNot(
                            userId, search, STATUS_CANCELLED);
        } else {
            goals = savingGoalRepository
                    .findByAccount_IdAndGoalStatusNot(userId, STATUS_CANCELLED);
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

    // ================= PRIVATE =================

    private SavingGoal getOwnedGoal(Integer id, Integer userId) {

        SavingGoal goal = savingGoalRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy mục tiêu"));

        // ✅ Check quyền sở hữu rõ ràng
        if (goal.getAccount() == null ||
                !goal.getAccount().getId().equals(userId)) {
            throw new IllegalArgumentException("Bạn không có quyền thao tác mục tiêu này.");
        }

        if (goal.getGoalStatus().equals(STATUS_CANCELLED)) {
            throw new IllegalStateException("Mục tiêu đã bị hủy.");
        }

        return goal;
    }

    private SavingGoalResponse mapToResponse(SavingGoal goal) {

        double percent = 0;

        if (goal.getTargetAmount().compareTo(BigDecimal.ZERO) > 0) {
            percent = goal.getCurrentAmount()
                    .divide(goal.getTargetAmount(), 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100))
                    .doubleValue();
        }

        percent = Math.min(percent, 100); // ✅ Không vượt 100%

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
                .progressPercent(percent)
                .build();
    }
}
