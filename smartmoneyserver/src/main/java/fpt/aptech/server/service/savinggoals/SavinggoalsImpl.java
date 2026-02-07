package fpt.aptech.server.service.savinggoals;

import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoals.request.*;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Currency;

import fpt.aptech.server.entity.Savinggoals.SavingGoal;
import fpt.aptech.server.entity.Savinggoals.SavingGoalMember;
import fpt.aptech.server.entity.Savinggoals.SavingGoalTransaction;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.Currency.CurrencyRepository;
import fpt.aptech.server.repos.savinggoals.*;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class SavinggoalsImpl implements SavinggoalsServices {

    // ===== REPOSITORIES =====
    private final SavingGoalRepository savingGoalRepo;
    private final SavingGoalMemberRepository memberRepo;
    private final SavingGoalTransactionRepository transactionRepo;
    private final CategoryRepository categoryRepo;
    private final AccountRepository accountRepo;
    private final CurrencyRepository currencyRepo;

    // ================= CREATE SAVING GOAL =================

    @Override
    public SavingGoalResponse createSavingGoal(CreateSavingGoalRequest req) {

        Account account = accountRepo.findById(req.getAccId())
                .orElseThrow(() -> new RuntimeException("Account not found"));

        Currency currency = currencyRepo.findById(req.getCurrencyCode())
                .orElseThrow(() -> new RuntimeException("Currency not found"));
        Category category = categoryRepo.findById(req.getCategoryId())
                .orElseThrow(() -> new RuntimeException("Category not found"));
        SavingGoal goal = SavingGoal.builder()
                .account(account)
                .currency(currency)
                .category(category)
                .goalName(req.getGoalName())
                .targetAmount(req.getTargetAmount())
                .currentAmount(BigDecimal.ZERO)
                .goalImageUrl(req.getGoalImageUrl())
                .beginDate(LocalDate.now())
                .endDate(req.getEndDate())
                .goalStatus(1) // ACTIVE
                .finished(false)
                .notified(true)
                .reportable(true)
                .build();

        SavingGoal savedGoal = savingGoalRepo.save(goal);

        // Auto add OWNER
        memberRepo.save(
                SavingGoalMember.builder()
                        .savingGoal(savedGoal)
                        .account(account)
                        .role("OWNER")
                        .build()
        );

        return mapSavingGoal(savedGoal);
    }

    // ================= UPDATE SAVING GOAL =================

    @Override
    public SavingGoalResponse updateSavingGoal(Integer id, UpdateSavingGoalRequest req) {

        SavingGoal goal = savingGoalRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Saving goal not found"));

        if (req.getGoalName() != null) goal.setGoalName(req.getGoalName());
        if (req.getTargetAmount() != null) goal.setTargetAmount(req.getTargetAmount());
        if (req.getEndDate() != null) goal.setEndDate(req.getEndDate());
        if (req.getGoalImageUrl() != null) goal.setGoalImageUrl(req.getGoalImageUrl());
        if (req.getNotified() != null) goal.setNotified(req.getNotified());
        if (req.getReportable() != null) goal.setReportable(req.getReportable());

        return mapSavingGoal(savingGoalRepo.save(goal));
    }

    // ================= DELETE SAVING GOAL =================

    @Override
    public void deleteSavingGoal(Integer goalId, Integer accId) {

        SavingGoalMember member =
                memberRepo.findBySavingGoal_IdAndAccount_Id(goalId, accId);

        if (member == null || !"OWNER".equals(member.getRole())) {
            throw new RuntimeException("Only OWNER can delete saving goal");
        }

        savingGoalRepo.deleteById(goalId);
    }

    // ================= LIST BY ACCOUNT =================

    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer accId) {

        return memberRepo.findByAccount_Id(accId)
                .stream()
                .map(SavingGoalMember::getSavingGoal)
                .map(this::mapSavingGoal)
                .collect(Collectors.toList());
    }

    // ================= ADD MEMBER =================

    @Override
    public void addMember(Integer goalId, Integer ownerId, AddSavingMemberRequest req) {

        SavingGoalMember owner =
                memberRepo.findBySavingGoal_IdAndAccount_Id(goalId, ownerId);

        if (owner == null || !"OWNER".equals(owner.getRole())) {
            throw new RuntimeException("Only OWNER can add member");
        }

        if (memberRepo.existsBySavingGoal_IdAndAccount_Id(goalId, req.getAccId())) {
            throw new RuntimeException("User already joined");
        }

        Account acc = accountRepo.findById(req.getAccId())
                .orElseThrow(() -> new RuntimeException("Account not found"));

        memberRepo.save(
                SavingGoalMember.builder()
                        .savingGoal(owner.getSavingGoal())
                        .account(acc)
                        .role(req.getRole())
                        .build()
        );
    }

    // ================= DEPOSIT MONEY =================

    @Override
    public SavingGoalResponse deposit(Integer goalId, DepositSavingRequest req) {

        SavingGoalMember member =
                memberRepo.findBySavingGoal_IdAndAccount_Id(goalId, req.getAccId());

        if (member == null) {
            throw new RuntimeException("Not a member of this saving goal");
        }

        SavingGoal goal = member.getSavingGoal();

        // Update current amount
        goal.setCurrentAmount(
                goal.getCurrentAmount().add(req.getAmount())
        );

        // Check completed
        if (goal.getCurrentAmount().compareTo(goal.getTargetAmount()) >= 0) {
            goal.setGoalStatus(2); // COMPLETED
            goal.setFinished(true);
        }

        // ✅ SAVE TRANSACTION (ĐÚNG REPO – FIX LỖI CỦA BẠN)
        SavingGoalTransaction transaction = SavingGoalTransaction.builder()
                .savingGoal(goal)
                .account(member.getAccount())
                .amount(req.getAmount())
                .createdAt(LocalDateTime.now())
                .build();

        transactionRepo.save(transaction);

        // Save updated goal
        savingGoalRepo.save(goal);

        return mapSavingGoal(goal);
    }

    // ================= MAPPER =================

    private SavingGoalResponse mapSavingGoal(SavingGoal g) {
        return SavingGoalResponse.builder()
                .id(g.getId())
                .goalName(g.getGoalName())
                .targetAmount(g.getTargetAmount())
                .currentAmount(g.getCurrentAmount())
                .endDate(g.getEndDate())
                .goalStatus(g.getGoalStatus())
                .notified(g.getNotified())
                .reportable(g.getReportable())
                .finished(g.getFinished())
                .currencyCode(g.getCurrency().getCurrencyCode())
                .imageUrl(g.getGoalImageUrl())
                // category (THEO ENTITY THẬT)
                .categoryId(g.getCategory().getId())
                .categoryName(g.getCategory().getCtgName())
                .categoryIconUrl(g.getCategory().getCtgIconUrl())
                .build();
    }
}
