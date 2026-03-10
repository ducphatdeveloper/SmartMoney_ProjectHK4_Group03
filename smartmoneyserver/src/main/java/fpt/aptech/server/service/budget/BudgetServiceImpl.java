package fpt.aptech.server.service.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.dto.budget.BudgetResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Budget;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.mapper.budget.BudgetMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.BudgetRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;

@Service
@RequiredArgsConstructor
public class BudgetServiceImpl implements BudgetService {

    private final BudgetRepository budgetRepository;
    private final AccountRepository accountRepository;
    private final WalletRepository walletRepository;
    private final CategoryRepository categoryRepository;
    private final BudgetMapper budgetMapper;

    @Override
    @Transactional(readOnly = true)
    public List<BudgetResponse> getBudgets(Integer userId) {
        List<Budget> budgets = budgetRepository.findByAccount_Id(userId);
        return budgetMapper.toDtoList(budgets);
    }

    @Override
    @Transactional(readOnly = true)
    public BudgetResponse getBudgetById(Integer budgetId, Integer userId) {
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy ngân sách"));
        if (!budget.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền xem ngân sách này");
        }
        return budgetMapper.toDto(budget);
    }

    @Override
    @Transactional
    public BudgetResponse createBudget(BudgetRequest request, Integer userId) {
        Account currentUser = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));

        Budget budget = budgetMapper.toEntity(request);
        budget.setAccount(currentUser);

        // Gán Wallet (nếu có)
        if (request.walletId() != null) {
            Wallet wallet = walletRepository.findById(request.walletId())
                    .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
            if (!wallet.getAccount().getId().equals(userId)) {
                throw new SecurityException("Không có quyền sử dụng ví này");
            }
            budget.setWallet(wallet);
        }

        // Gán Categories (nếu không phải allCategories)
        if (Boolean.FALSE.equals(request.allCategories()) && request.categoryIds() != null) {
            List<Category> categories = categoryRepository.findAllById(request.categoryIds());
            // Validate quyền sở hữu categories
            for (Category cat : categories) {
                if (cat.getAccount() != null && !cat.getAccount().getId().equals(userId)) {
                    throw new SecurityException("Không có quyền sử dụng danh mục: " + cat.getCtgName());
                }
            }
            budget.setCategories(new HashSet<>(categories));
        }

        Budget savedBudget = budgetRepository.save(budget);
        return budgetMapper.toDto(savedBudget);
    }

    @Override
    @Transactional
    public BudgetResponse updateBudget(Integer budgetId, BudgetRequest request, Integer userId) {
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy ngân sách"));
        if (!budget.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền sửa ngân sách này");
        }

        budgetMapper.updateEntityFromRequest(request, budget);

        // Cập nhật lại Wallet và Categories
        if (request.walletId() != null) {
            Wallet wallet = walletRepository.findById(request.walletId())
                    .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
            if (!wallet.getAccount().getId().equals(userId)) {
                throw new SecurityException("Không có quyền sử dụng ví này");
            }
            budget.setWallet(wallet);
        } else {
            budget.setWallet(null);
        }

        if (Boolean.FALSE.equals(request.allCategories()) && request.categoryIds() != null) {
            List<Category> categories = categoryRepository.findAllById(request.categoryIds());
            budget.setCategories(new HashSet<>(categories));
        } else {
            budget.getCategories().clear(); // Xóa các category cũ nếu chuyển sang allCategories
        }

        Budget updatedBudget = budgetRepository.save(budget);
        return budgetMapper.toDto(updatedBudget);
    }

    @Override
    @Transactional
    public void deleteBudget(Integer budgetId, Integer userId) {
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy ngân sách"));
        if (!budget.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền xóa ngân sách này");
        }
        budgetRepository.delete(budget);
    }
}