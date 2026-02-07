package fpt.aptech.server.service.savinggoals;

import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoals.request.*;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Currency;

import fpt.aptech.server.entity.SavingGoal;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.SavingGoalRepository;
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

        return mapSavingGoal(savedGoal);
    }

    // ================= UPDATE SAVING GOAL =================

    @Override
    public SavingGoalResponse updateSavingGoal(Integer id, UpdateSavingGoalRequest req) {

        SavingGoal goal = savingGoalRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Saving goal not found"));

        if (!goal.getAccount().getId().equals(req.getAccId())) {
            throw new RuntimeException("No permission");
        }

        // ===== UPDATE INFO MODE =====
        if (req.getGoalName() != null) goal.setGoalName(req.getGoalName());
        if (req.getTargetAmount() != null) goal.setTargetAmount(req.getTargetAmount());
        if (req.getEndDate() != null) goal.setEndDate(req.getEndDate());
        if (req.getGoalImageUrl() != null) goal.setGoalImageUrl(req.getGoalImageUrl());
        if (req.getNotified() != null) goal.setNotified(req.getNotified());
        if (req.getReportable() != null) goal.setReportable(req.getReportable());

        if (req.getCategoryId() != null) {
            Category category = categoryRepo.findById(req.getCategoryId())
                    .orElseThrow(() -> new RuntimeException("Category not found"));
            goal.setCategory(category);
        }

        if (req.getCurrencyCode() != null) {
            Currency currency = currencyRepo.findById(req.getCurrencyCode())
                    .orElseThrow(() -> new RuntimeException("Currency not found"));
            goal.setCurrency(currency);
        }

        // ===== DEPOSIT MODE =====
        if (req.getAmount() != null) {

            if (goal.getFinished()) {
                throw new RuntimeException("Saving goal already finished");
            }

            BigDecimal newAmount = goal.getCurrentAmount().add(req.getAmount());
            goal.setCurrentAmount(newAmount);

            if (newAmount.compareTo(goal.getTargetAmount()) >= 0) {
                goal.setGoalStatus(2); // COMPLETED
                goal.setFinished(true);
            }
        }

        // ===== AUTO EXPIRE =====
        if (!goal.getFinished() && LocalDate.now().isAfter(goal.getEndDate())) {
            goal.setFinished(true);
            goal.setGoalStatus(3); // CANCELLED
        }

        return mapSavingGoal(savingGoalRepo.save(goal));
    }



    @Override
    public void deleteSavingGoal(Integer id, Integer accId) {

        SavingGoal goal = savingGoalRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Saving goal not found"));

        if (!goal.getAccount().getId().equals(accId)) {
            throw new RuntimeException("No permission to delete this saving goal");
        }

        goal.setGoalStatus(3); // CANCELLED
        goal.setFinished(true);

        savingGoalRepo.save(goal);
    }


    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer accId) {
        return savingGoalRepo.findByAccount_Id(accId)
                .stream()
                .map(this::mapSavingGoal)
                .collect(Collectors.toList());
    }


    // ================= DELETE SAVING GOAL =================



    // ================= LIST BY ACCOUNT =================


    // ================= MAPPER =================

    private SavingGoalResponse mapSavingGoal(SavingGoal g)
    {
        boolean finished = g.getFinished();

        if (!finished && LocalDate.now().isAfter(g.getEndDate())) {
            finished = true;
        }
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
