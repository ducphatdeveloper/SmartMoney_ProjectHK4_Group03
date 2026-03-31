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
import java.time.temporal.WeekFields;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static fpt.aptech.server.enums.budget.BudgetType.MONTHLY;

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
    public List<BudgetResponse> getBudgets(Integer userId, Integer walletId) {

        List<Budget> budgets = budgetRepository
                .getBudgets(userId.longValue(), LocalDate.now(), walletId.longValue());
        if (walletId == null) {
            throw new IllegalArgumentException("Phải chọn ví");
        }

        return budgets.stream()
                .map(this::toBudgetResponse)
                .collect(Collectors.toList());
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
        //bắt lỗi
        validateDuplicateBudget(request, userId, null);
        Account currentUser = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));

        Wallet wallet = walletRepository.findById(request.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));


        Budget budget = Budget.builder()
                .account(currentUser)
                .wallet(wallet)
                .amount(request.amount())
                .beginDate(request.beginDate())
                .endDate(request.endDate())
                .allCategories(request.allCategories())
                .repeating(request.repeating())
                .categories(new HashSet<>())
                .budgetType(request.budgetType()) // thêm mới
                .build();

//        // Gán Wallet (nếu có)
//        applyWallet(budget, request.walletId(), userId);

        // Gán Categories
        applyCategories(budget, request.allCategories(), request.categoryId(), userId);

        Budget saved = budgetRepository.save(budget);
        return toBudgetResponse(saved);
    }

    @Override
    @Transactional
    public BudgetResponse updateBudget(Integer budgetId, BudgetRequest request, Integer userId) {
        validateDates(request.beginDate(), request.endDate());
        validateDuplicateBudget(request, userId, budgetId);
        Budget budget = getOwnedBudget(budgetId, userId);

        Wallet wallet = walletRepository.findById(request.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));

        budget.setAmount(request.amount());
        budget.setWallet(wallet);
        budget.setBeginDate(request.beginDate());
        budget.setEndDate(request.endDate());
        budget.setAllCategories(request.allCategories());
        budget.setRepeating(request.repeating());
        budget.setBudgetType(request.budgetType()); //thêm mới

//        // Cập nhật Wallet
//        applyWallet(budget, request.walletId(), userId);

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
//    private void applyWallet(Budget budget, Integer walletId, Integer userId) {
//        if (walletId != null) {
//            Wallet wallet = walletRepository.findById(walletId)
//                    .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
//            if (!wallet.getAccount().getId().equals(userId)) {
//                throw new SecurityException("Không có quyền sử dụng ví này");
//            }
//            budget.setWallet(wallet);
//        } else {
//            budget.setWallet(null);
//        }
//    }

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

    private void validateDuplicateBudget(BudgetRequest request,
                                         Integer userId,
                                         Integer excludeId) {

        List<Budget> conflicts = budgetRepository.findConflictingBudgets(
                userId,
                request.walletId(),
                request.beginDate(),
                request.endDate(),
                excludeId
        );

        // ================================
        // 1. LẤY CATEGORY REQUEST
        // ================================
        Set<Integer> requestCategoryIds = new HashSet<>();

        boolean isAllCategory = Boolean.TRUE.equals(request.allCategories());

        if (!isAllCategory) {
            Category selected = categoryRepository.findById(request.categoryId())
                    .orElseThrow(() -> new IllegalArgumentException("Danh mục không tồn tại"));

            requestCategoryIds.add(selected.getId());

            // Nếu là category cha → lấy luôn con
            if (selected.getParent() == null) {
                List<Category> children = categoryRepository
                        .findChildrenForBudget(selected.getId(), userId);

                for (Category c : children) {
                    requestCategoryIds.add(c.getId());
                }
            }
        }

        // ================================
        // 2. CHECK CONFLICT
        // ================================
        // ================================
// 2. CHECK CONFLICT
// ================================
        for (Budget existing : conflicts) {

            boolean existingAll = Boolean.TRUE.equals(existing.getAllCategories());

            // 🚨 2.1 ALL CATEGORY (block mạnh nhất)
            if (isAllCategory || existingAll) {
                throw new IllegalArgumentException(
                        "Đã tồn tại ngân sách cho tất cả danh mục trong khoảng thời gian này"
                );
            }

            // 🚨 2.2 CHECK CATEGORY TRÙNG
            Set<Integer> existingCategoryIds = existing.getCategories().stream()
                    .map(Category::getId)
                    .collect(Collectors.toSet());

            boolean isSameCategory = requestCategoryIds.stream()
                    .anyMatch(existingCategoryIds::contains);

            if (!isSameCategory) continue;

            // ================================
            // 🔥 3. CHỈ CHECK KHI CÙNG TYPE
            // ================================
            if (request.budgetType() != existing.getBudgetType()) {
                continue; // ✅ KHÁC TYPE → CHO QUA
            }

            switch (request.budgetType()) {

                case MONTHLY:
                    if (isSameMonth(existing.getBeginDate(), request.beginDate())) {
                        throw new IllegalArgumentException(
                                "Danh mục đã có ngân sách trong tháng này"
                        );
                    }
                    break;

                case WEEKLY:
                    if (isSameWeek(existing.getBeginDate(), request.beginDate())) {
                        throw new IllegalArgumentException(
                                "Danh mục đã có ngân sách trong tuần này"
                        );
                    }
                    break;

                case YEARLY:
                    if (existing.getBeginDate().getYear() == request.beginDate().getYear()) {
                        throw new IllegalArgumentException(
                                "Danh mục đã có ngân sách trong năm này"
                        );
                    }
                    break;

                case CUSTOM:
                    throw new IllegalArgumentException(
                            "Danh mục đã có ngân sách trong khoảng thời gian này"
                    );
            }
        }
    }
    private boolean isSameMonth(LocalDate d1, LocalDate d2) {
        return d1.getMonth() == d2.getMonth()
                && d1.getYear() == d2.getYear();
    }

    private boolean isSameWeek(LocalDate d1, LocalDate d2) {
        WeekFields weekFields = WeekFields.ISO;

        return d1.get(weekFields.weekOfWeekBasedYear()) ==
                d2.get(weekFields.weekOfWeekBasedYear())
                && d1.getYear() == d2.getYear();
    }







    private BudgetResponse toBudgetResponse(Budget budget) {

        // =========================
        // 1. TIME
        // =========================
        LocalDate today   = LocalDate.now();
        LocalDate start   = budget.getBeginDate();
        LocalDate end     = budget.getEndDate();

        boolean expired = today.isAfter(end);

        // =========================
        // 2. QUERY PARAM
        // =========================
        Integer walletId = budget.getWallet().getId();

        LocalDateTime startDt = start.atStartOfDay();
        LocalDateTime endDt   = end.atTime(23, 59, 59);

        Set<Integer> categoryIds = resolveCategoryIds(budget);

        // =========================
        // 3. SPENT
        // =========================
        BigDecimal spent = transactionRepository.sumExpenseForBudget(
                budget.getAccount().getId(),
                startDt,
                endDt,
                walletId,
                budget.getAllCategories(),
                categoryIds
        );

        if (spent == null) spent = BigDecimal.ZERO;

        BigDecimal remaining = budget.getAmount().subtract(spent);

        // =========================
        // 4. DAYS CALCULATION
        // =========================
        long totalDays = ChronoUnit.DAYS.between(start, end) + 1;
        if (totalDays <= 0) totalDays = 1;

        LocalDate effectiveToday = expired ? end : today;

        long daysElapsed = ChronoUnit.DAYS.between(start, effectiveToday) + 1;
        if (daysElapsed <= 0) daysElapsed = 1;

        long daysLeft = ChronoUnit.DAYS.between(today, end);
        if (daysLeft < 0) daysLeft = 0;

        // =========================
        // 5. CALCULATIONS
        // =========================
        BigDecimal dailyActual = BigDecimal.ZERO;
        if (daysElapsed > 0) {
            dailyActual = spent.divide(
                    BigDecimal.valueOf(daysElapsed),
                    2,
                    RoundingMode.HALF_UP
            );
        }

        BigDecimal projected = dailyActual.multiply(BigDecimal.valueOf(totalDays));

        BigDecimal dailyShould = BigDecimal.ZERO;
        if (daysLeft > 0) {
            dailyShould = remaining
                    .max(BigDecimal.ZERO) // 🔥 không cho âm
                    .divide(
                            BigDecimal.valueOf(daysLeft),
                            2,
                            RoundingMode.HALF_UP
                    );
        }
        // ─────────────────────────────
        // 🚨 ALERT LOGIC (QUAN TRỌNG)
        // ─────────────────────────────

        // 1. ĐÃ VƯỢT
        boolean exceeded = spent.compareTo(budget.getAmount()) > 0;

        // 2. SẮP VƯỢT (dự đoán)
        boolean warning = false;
        if (!expired) {
            warning = projected.compareTo(budget.getAmount()) > 0;
        }

        // 3. PROGRESS %
        BigDecimal progress = BigDecimal.ZERO;

        if (budget.getAmount().compareTo(BigDecimal.ZERO) > 0) {
            progress = spent.divide(
                    budget.getAmount(),
                    2,
                    RoundingMode.HALF_UP
            ).min(BigDecimal.ONE);
        }








        // =========================
        // 6. CATEGORY RESPONSE
        // =========================
        List<CategoryResponse> catResponses =
                Boolean.TRUE.equals(budget.getAllCategories())
                        ? List.of()
                        : budget.getCategories().stream()
                        .map(categoryMapper::toDto)
                        .collect(Collectors.toList());

        // =========================
        // 7. PRIMARY CATEGORY (Flutter)
        // =========================
        Integer primaryCategoryId = null;
        String primaryCategoryIconUrl = null;

        if (!catResponses.isEmpty()) {
            CategoryResponse first = catResponses.get(0);
            primaryCategoryId = first.id();
            primaryCategoryIconUrl = first.ctgIconUrl();
        }

        // =========================
        // 8. WALLET
        // =========================
        String walletName = budget.getWallet().getWalletName();
        // =========================
        // 9. BUILD RESPONSE
        // =========================
        return BudgetResponse.builder()
                .id(budget.getId())
                .amount(budget.getAmount())
                .beginDate(start)
                .endDate(end)
                .walletId(walletId)
                .walletName(walletName)
                .allCategories(budget.getAllCategories())
                .repeating(budget.getRepeating())
                .categories(catResponses)
                .primaryCategoryId(primaryCategoryId)
                .primaryCategoryIconUrl(primaryCategoryIconUrl)
                .expired(expired)
                .spentAmount(spent)
                .remainingAmount(remaining)
                .dailyActualSpend(dailyActual)
                .projectedSpend(projected)
                .dailyShouldSpend(dailyShould)
                .exceeded(exceeded)
                .warning(warning)
                .progress(progress)

                .budgetType(budget.getBudgetType())
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
