package fpt.aptech.server.service.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.dto.budget.BudgetResponse;
import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Budget;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.mapper.category.CategoryMapper;
import fpt.aptech.server.mapper.transaction.TransactionMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.BudgetRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class BudgetServiceImpl implements BudgetService {

    private final BudgetRepository budgetRepository;
    private final AccountRepository accountRepository;
    private final WalletRepository walletRepository;
    private final CategoryRepository categoryRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryMapper categoryMapper;
    private final TransactionMapper transactionMapper;

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERIES
    // ═══════════════════════════════════════════════════════════════════════════

    @Override
    @Transactional(readOnly = true)
    public List<BudgetResponse> getBudgets(Integer userId) {
        List<Budget> budgets = budgetRepository.findActiveBudgetsByAccountId(userId, LocalDate.now());
        return budgets.stream().map(this::toBudgetResponse).collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<BudgetResponse> getExpiredBudgets(Integer userId) {
        List<Budget> budgets = budgetRepository.findExpiredBudgetsByAccountId(userId, LocalDate.now());
        return budgets.stream().map(this::toBudgetResponse).collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public BudgetResponse getBudgetById(Integer budgetId, Integer userId) {
        Budget budget = getOwnedBudget(budgetId, userId);
        return toBudgetResponse(budget);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TransactionResponse> getBudgetTransactions(Integer budgetId, Integer userId) {
        Budget budget = getOwnedBudget(budgetId, userId);

        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        LocalDateTime start = budget.getBeginDate().atStartOfDay();
        LocalDateTime end   = budget.getEndDate().atTime(23, 59, 59);

        Set<Integer> categoryIds = resolveCategoryIds(budget);

        List<Transaction> transactions = transactionRepository.findTransactionsForBudget(
                userId, start, end, walletId, budget.getAllCategories(), categoryIds);

        return transactions.stream().map(transactionMapper::toDto).collect(Collectors.toList());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MUTATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    @Override
    @Transactional
    public BudgetResponse createBudget(BudgetRequest request, Integer userId) {
        validateDates(request.beginDate(), request.endDate());

        Account currentUser = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));

        Budget budget = Budget.builder()
                .account(currentUser)
                .amount(request.amount())
                .beginDate(request.beginDate())
                .endDate(request.endDate())
                .allCategories(request.allCategories())
                .repeating(request.repeating())
                .categories(new HashSet<>())
                .build();

        // Gán Wallet (nếu có)
        applyWallet(budget, request.walletId(), userId);

        // Gán Categories
        applyCategories(budget, request.allCategories(), request.categoryId(), userId);

        Budget saved = budgetRepository.save(budget);
        return toBudgetResponse(saved);
    }

    @Override
    @Transactional
    public BudgetResponse updateBudget(Integer budgetId, BudgetRequest request, Integer userId) {
        validateDates(request.beginDate(), request.endDate());

        Budget budget = getOwnedBudget(budgetId, userId);

        budget.setAmount(request.amount());
        budget.setBeginDate(request.beginDate());
        budget.setEndDate(request.endDate());
        budget.setAllCategories(request.allCategories());
        budget.setRepeating(request.repeating());

        // Cập nhật Wallet
        applyWallet(budget, request.walletId(), userId);

        // Cập nhật Categories
        budget.getCategories().clear();
        applyCategories(budget, request.allCategories(), request.categoryId(), userId);

        Budget saved = budgetRepository.save(budget);
        return toBudgetResponse(saved);
    }

    @Override
    @Transactional
    public void deleteBudget(Integer budgetId, Integer userId) {
        Budget budget = getOwnedBudget(budgetId, userId);
        // Chỉ xóa ngân sách, không xóa giao dịch (FK budget_id ở tTransactions là nullable)
        budgetRepository.delete(budget);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPERS PRIVATE
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Ownership check — dùng ở mọi endpoint có budgetId.
     */
    private Budget getOwnedBudget(Integer budgetId, Integer userId) {
        return budgetRepository.findByIdAndAccount_Id(budgetId, userId)
                .orElseThrow(() -> new SecurityException(
                        "Ngân sách không tồn tại hoặc bạn không có quyền truy cập."));
    }

    /**
     * Gán Wallet cho Budget, hoặc set null nếu walletId=null (áp dụng tất cả ví).
     */
    private void applyWallet(Budget budget, Integer walletId, Integer userId) {
        if (walletId != null) {
            Wallet wallet = walletRepository.findById(walletId)
                    .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
            if (!wallet.getAccount().getId().equals(userId)) {
                throw new SecurityException("Không có quyền sử dụng ví này");
            }
            budget.setWallet(wallet);
        } else {
            budget.setWallet(null);
        }
    }

    /**
     * Gán Categories cho Budget.
     * - allCategories=true   → không thêm gì, bảng trung gian rỗng
     * - categoryId = cha     → expand: cha + toàn bộ con
     * - categoryId = con     → chỉ con đó
     * - categoryId = null + allCategories=false → throw validation error
     */
    private void applyCategories(Budget budget, Boolean allCategories,
                                 Integer categoryId, Integer userId) {
        if (Boolean.TRUE.equals(allCategories)) {
            // Không cần làm gì — categories set rỗng, allCategories=true
            return;
        }

        if (categoryId == null) {
            throw new IllegalArgumentException(
                    "Vui lòng chọn một danh mục hoặc chọn 'Tất cả danh mục'.");
        }

        Category selected = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new IllegalArgumentException("Danh mục không tồn tại"));

        // Validate: chỉ được dùng category hệ thống hoặc của chính user
        if (selected.getAccount() != null && !selected.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền sử dụng danh mục này");
        }

        Set<Category> categories = new HashSet<>();
        categories.add(selected);

        // Nếu là danh mục GỐC (cha) → expand toàn bộ con
        if (selected.getParent() == null) {
            List<Category> children = categoryRepository.findChildrenForBudget(selected.getId(), userId);
            categories.addAll(children);
        }

        budget.setCategories(categories);
    }

    /**
     * Lấy Set<Integer> categoryIds từ budget để dùng trong TransactionRepository.
     * Nếu allCategories=true → trả về set rỗng (query sẽ bỏ qua điều kiện IN).
     */
    private Set<Integer> resolveCategoryIds(Budget budget) {
        if (Boolean.TRUE.equals(budget.getAllCategories())) {
            return Set.of(); // Không dùng đến
        }
        return budget.getCategories().stream()
                .map(Category::getId)
                .collect(Collectors.toSet());
    }

    /**
     * Build BudgetResponse đầy đủ với các chỉ số tính toán.
     * 
     * 1. primaryCategoryId & primaryCategoryIconUrl: Lấy danh mục chính để Flutter hiển thị icon
     *    - Nếu allCategories=false: Lấy danh mục đầu tiên từ categories set
     *    - Nếu allCategories=true: Set null (Flutter sẽ dùng icon mặc định)
     * 2. Tính tổng chi tiêu, số dư, và các chỉ số dự đoán
     */
    private BudgetResponse toBudgetResponse(Budget budget) {
        LocalDate today    = LocalDate.now();
        LocalDate start    = budget.getBeginDate();
        LocalDate end      = budget.getEndDate();
        boolean   expired  = today.isAfter(end);

        // ── Tính tổng chi ─────────────────────────────────────────────────────
        Integer       walletId    = budget.getWallet() != null ? budget.getWallet().getId() : null;
        LocalDateTime startDt     = start.atStartOfDay();
        LocalDateTime endDt       = end.atTime(23, 59, 59);
        Set<Integer>  categoryIds = resolveCategoryIds(budget);

        BigDecimal spent = transactionRepository.sumExpenseForBudget(
                budget.getAccount().getId(), startDt, endDt,
                walletId, budget.getAllCategories(), categoryIds);
        if (spent == null) spent = BigDecimal.ZERO;

        BigDecimal remaining = budget.getAmount().subtract(spent);

        // ── Tính ngày ─────────────────────────────────────────────────────────
        long totalDays   = Math.max(1, ChronoUnit.DAYS.between(start, end) + 1);
        // Số ngày đã trôi qua (tính đến hôm nay hoặc ngày kết thúc nếu đã hết hạn)
        LocalDate effectiveToday = expired ? end : today;
        long daysElapsed = Math.max(1, ChronoUnit.DAYS.between(start, effectiveToday) + 1);
        long daysLeft    = Math.max(0, ChronoUnit.DAYS.between(today, end));

        // ── Chỉ số dự đoán ────────────────────────────────────────────────────
        BigDecimal dailyActual  = spent.divide(BigDecimal.valueOf(daysElapsed), 0, RoundingMode.HALF_UP);
        BigDecimal projected    = dailyActual.multiply(BigDecimal.valueOf(totalDays));
        BigDecimal dailyShould  = daysLeft > 0
                ? remaining.max(BigDecimal.ZERO).divide(BigDecimal.valueOf(daysLeft), 0, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        // ── Map categories ────────────────────────────────────────────────────
        List<CategoryResponse> catResponses = budget.getCategories().stream()
                .map(categoryMapper::toDto)
                .collect(Collectors.toList());

        // ── Lấy icon danh mục chính cho Flutter ────────────────────────────────
        // 1. Nếu allCategories=false: Lấy danh mục đầu tiên
        // 2. Nếu allCategories=true: Set null
        Integer primaryCategoryId = null;
        String primaryCategoryIconUrl = null;

        if (!catResponses.isEmpty() && !Boolean.TRUE.equals(budget.getAllCategories())) {
            CategoryResponse firstCategory = catResponses.get(0);
            primaryCategoryId = firstCategory.id();
            primaryCategoryIconUrl = firstCategory.ctgIconUrl();
        }

        return BudgetResponse.builder()
                .id(budget.getId())
                .amount(budget.getAmount())
                .beginDate(budget.getBeginDate())
                .endDate(budget.getEndDate())
                .walletId(walletId)
                .walletName(budget.getWallet() != null ? budget.getWallet().getWalletName() : null)
                .allCategories(budget.getAllCategories())
                .repeating(budget.getRepeating())
                .primaryCategoryId(primaryCategoryId)           // ← 1. ID danh mục chính
                .primaryCategoryIconUrl(primaryCategoryIconUrl) // ← 2. Icon danh mục chính
                .categories(catResponses)
                .expired(expired)
                .spentAmount(spent)
                .remainingAmount(remaining)
                .dailyActualSpend(dailyActual)
                .projectedSpend(projected)
                .dailyShouldSpend(dailyShould)
                .build();
    }

    /**
     * Validate ngày bắt đầu phải trước ngày kết thúc.
     */
    private void validateDates(LocalDate beginDate, LocalDate endDate) {
        if (!beginDate.isBefore(endDate)) {
            throw new IllegalArgumentException("Ngày bắt đầu phải trước ngày kết thúc.");
        }
    }
}

