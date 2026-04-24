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
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.time.temporal.WeekFields;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static fpt.aptech.server.enums.budget.BudgetType.MONTHLY;

@Service
@RequiredArgsConstructor
@Slf4j
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

        if (walletId == null) {
            throw new IllegalArgumentException("Wallet is required");
        }

        List<Budget> budgets = budgetRepository
                .getBudgets(userId.longValue(), LocalDate.now(), walletId.longValue());

        return budgets.stream()
                .map(this::toBudgetResponse)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<BudgetResponse> getExpiredBudgets(Integer userId, Integer walletId) {
        LocalDate today = LocalDate.now();
        List<Budget> budgets = budgetRepository.findExpiredBudgetsByAccountId(userId, today)
                .stream()
                .filter(b -> walletId == null || (b.getWallet() != null && b.getWallet().getId().equals(walletId)))
                .collect(Collectors.toList());

        return budgets.stream()
                .map(this::toBudgetResponse)
                .collect(Collectors.toList());
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

        Integer walletId = budget.getWallet() != null
                ? budget.getWallet().getId()
                : null;

        LocalDateTime start = budget.getBeginDate().atStartOfDay();
        LocalDateTime end = budget.getEndDate().atTime(23, 59, 59);

        // ✅ Dùng lại resolveCategoryIds như file cũ, KHÔNG inline lại
        Set<Integer> categoryIds = resolveCategoryIds(budget);

        List<Transaction> transactions = transactionRepository.findTransactionsForBudget(
                userId,
                start,
                end,
                walletId,
                budget.getAllCategories(),
                categoryIds);

        return transactions.stream()
                .map(transactionMapper::toDto)
                .collect(Collectors.toList());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MUTATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    @Override
    @Transactional
    public BudgetResponse createBudget(BudgetRequest request, Integer userId) {
        validateDates(request.beginDate(), request.endDate(), request.budgetType().name());
        // bắt lỗi
        validateDuplicateBudget(request, userId, null);
        Account currentUser = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Account does not exist"));

        Wallet wallet = walletRepository.findById(request.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Wallet does not exist"));

        // Validate wallet ownership - chỉ được tạo budget cho wallet của chính mình
        if (!wallet.getAccount().getId().equals(userId)) {
            throw new SecurityException("You do not have permission to use this wallet");
        }

        validateBudgetType(
                request.beginDate(),
                request.endDate(),
                request.budgetType().name());

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

        // // Gán Wallet (nếu có)
        // applyWallet(budget, request.walletId(), userId);

        // Gán Categories
        applyCategories(budget, request.allCategories(), request.categoryId(), userId);

        Budget saved = budgetRepository.save(budget);
        return toBudgetResponse(saved);
    }

    @Override
    @Transactional
    public BudgetResponse updateBudget(Integer budgetId, BudgetRequest request, Integer userId) {

        // 1. Validate ngày
        validateDates(request.beginDate(), request.endDate(), request.budgetType().name());

        // 2. Lấy budget
        Budget budget = getOwnedBudget(budgetId, userId);

        // 3. ❌ Không cho đổi wallet
        if (!budget.getWallet().getId().equals(request.walletId())) {
            throw new IllegalArgumentException("Cannot change wallet");
        }

        // 4. Validate wallet ownership - đảm bảo wallet thuộc về user
        Wallet wallet = walletRepository.findById(request.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Wallet does not exist"));
        if (!wallet.getAccount().getId().equals(userId)) {
            throw new SecurityException("You do not have permission to use this wallet");
        }

        // 4. Validate category cơ bản
        if (!Boolean.TRUE.equals(request.allCategories()) && request.categoryId() == null) {
            throw new IllegalArgumentException("Category is required");
        }

        // 5. Validate type (nếu bạn vẫn muốn giữ)
        validateBudgetType(
                request.beginDate(),
                request.endDate(),
                request.budgetType().name());

        // ✅ PHẢI GIỮ LẠI - file mới XÓA SAI
        validateDuplicateBudget(request, userId, budgetId);

        // 6. Update toàn bộ field
        budget.setAmount(request.amount());
        budget.setBeginDate(request.beginDate());
        budget.setEndDate(request.endDate());
        budget.setAllCategories(request.allCategories());
        budget.setRepeating(request.repeating());
        budget.setBudgetType(request.budgetType());

        // 7. Update categories
        budget.getCategories().clear();
        applyCategories(budget, request.allCategories(), request.categoryId(), userId);

        // 8. Save
        return toBudgetResponse(budgetRepository.saveAndFlush(budget));
    }

    private void validateBudgetType(LocalDate begin, LocalDate end, String type) {

        long days = ChronoUnit.DAYS.between(begin, end) + 1;

        switch (type) {

            case "WEEKLY":
                // phải đúng 7 ngày
                if (days != 7) {
                    throw new IllegalArgumentException("Weekly budget must be exactly 7 days");
                }
                break;

            case "MONTHLY":
                // phải từ ngày 1 đến cuối tháng
                if (!(begin.getDayOfMonth() == 1 &&
                        end.getDayOfMonth() == end.lengthOfMonth())) {
                    throw new IllegalArgumentException("Monthly budget must be from first to last day of month");
                }
                break;

            case "YEARLY":
                // phải từ 01/01 đến 31/12
                if (!(begin.getDayOfYear() == 1 &&
                        end.getDayOfYear() == end.lengthOfYear())) {
                    throw new IllegalArgumentException("Yearly budget must be from 01/01 to 12/31");
                }
                break;

            case "CUSTOM":
                // luôn hợp lệ (chỉ cần begin <= end là được)
                break;

            default:
                throw new IllegalArgumentException("Invalid budget type");
        }
    }

    @Override
    @Transactional
    public void deleteBudget(Integer budgetId, Integer userId) {
        Budget budget = getOwnedBudget(budgetId, userId);
        // Soft delete ngân sách (không xóa giao dịch vì FK budget_id ở tTransactions là nullable)
        budget.setDeleted(true);
        budget.setDeletedAt(java.time.LocalDateTime.now());
        budgetRepository.save(budget);
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
                        "Budget does not exist or you do not have access."));
    }

    /**
     * Gán Wallet cho Budget, hoặc set null nếu walletId=null (áp dụng tất cả ví).
     */
    // private void applyWallet(Budget budget, Integer walletId, Integer userId) {
    // if (walletId != null) {
    // Wallet wallet = walletRepository.findById(walletId)
    // .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
    // if (!wallet.getAccount().getId().equals(userId)) {
    // throw new SecurityException("Không có quyền sử dụng ví này");
    // }
    // budget.setWallet(wallet);
    // } else {
    // budget.setWallet(null);
    // }
    // }

    /**
     * Gán Categories cho Budget.
     * - allCategories=true → không thêm gì, bảng trung gian rỗng
     * - categoryId = cha → expand: cha + toàn bộ con
     * - categoryId = con → chỉ con đó
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
                    "Please select a category or select 'All categories'.");
        }

        Category selected = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new IllegalArgumentException("Category does not exist"));

        // Validate: chỉ được dùng category hệ thống hoặc của chính user
        if (selected.getAccount() != null && !selected.getAccount().getId().equals(userId)) {
            throw new SecurityException("You do not have permission to use this category");
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
     * 1. primaryCategoryId & primaryCategoryIconUrl: Lấy danh mục chính để Flutter
     * hiển thị icon
     * - Nếu allCategories=false: Lấy danh mục đầu tiên từ categories set
     * - Nếu allCategories=true: Set null (Flutter sẽ dùng icon mặc định)
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
                excludeId);

        // ================================
        // 1. LẤY CATEGORY REQUEST
        // ================================
        Set<Integer> requestCategoryIds = new HashSet<>();

        boolean isAllCategory = Boolean.TRUE.equals(request.allCategories());

        if (!isAllCategory) {
            Category selected = categoryRepository.findById(request.categoryId())
                    .orElseThrow(() -> new IllegalArgumentException("Category does not exist"));

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
                        "Budget already exists for all categories in this time period");
            }

            // 🚨 2.2 CHECK CATEGORY TRÙNG
            Set<Integer> existingCategoryIds = existing.getCategories().stream()
                    .map(Category::getId)
                    .collect(Collectors.toSet());

            boolean isSameCategory = requestCategoryIds.stream()
                    .anyMatch(existingCategoryIds::contains);

            if (!isSameCategory)
                continue;

            // ================================
            // 🔥 3. CHỈ CHECK KHI CÙNG TYPE
            // ================================
            // Null check cho budget cũ (trước khi có budgetType)
            // Nếu budget cũ không có budgetType → cho phép tạo budget mới (không block)
            if (existing.getBudgetType() == null) {
                continue; // ✅ BUDGET CŨ KHÔNG CÓ TYPE → CHO QUA
            }
            // Nếu khác budgetType → cho phép tạo (WEEKLY, MONTHLY, YEARLY, CUSTOM có thể tồn tại song song)
            if (request.budgetType() != existing.getBudgetType()) {
                continue; // ✅ KHÁC TYPE → CHO QUA
            }

            switch (request.budgetType()) {

                case MONTHLY:
                    if (isSameMonth(existing.getBeginDate(), request.beginDate())) {
                        throw new IllegalArgumentException(
                                "Category already has a budget in this month");
                    }
                    break;

                case WEEKLY:
                    if (isSameWeek(existing.getBeginDate(), request.beginDate())) {
                        throw new IllegalArgumentException(
                                "Category already has a budget in this week");
                    }
                    break;

                case YEARLY:
                    if (existing.getBeginDate().getYear() == request.beginDate().getYear()) {
                        throw new IllegalArgumentException(
                                "Category already has a budget in this year");
                    }
                    break;

                case CUSTOM:
                    // CUSTOM: check overlap date range
                    if (hasDateOverlap(existing.getBeginDate(), existing.getEndDate(),
                            request.beginDate(), request.endDate())) {
                        throw new IllegalArgumentException(
                                "Category already has a budget in this time period");
                    }
                    break;
            }
        }
    }

    /**
     * Kiểm tra xem 2 khoảng thời gian có overlap không
     * @param start1 Ngày bắt đầu khoảng 1
     * @param end1 Ngày kết thúc khoảng 1
     * @param start2 Ngày bắt đầu khoảng 2
     * @param end2 Ngày kết thúc khoảng 2
     * @return true nếu có overlap, false nếu không
     */
    private boolean hasDateOverlap(LocalDate start1, LocalDate end1, LocalDate start2, LocalDate end2) {
        // 2 khoảng overlap khi: start1 <= end2 && start2 <= end1
        return !start1.isAfter(end2) && !start2.isAfter(end1);
    }

    private boolean isSameMonth(LocalDate d1, LocalDate d2) {
        return d1.getMonth() == d2.getMonth()
                && d1.getYear() == d2.getYear();
    }

    private boolean isSameWeek(LocalDate d1, LocalDate d2) {
        WeekFields weekFields = WeekFields.ISO;

        return d1.get(weekFields.weekOfWeekBasedYear()) == d2.get(weekFields.weekOfWeekBasedYear())
                && d1.getYear() == d2.getYear();
    }

    private BudgetResponse toBudgetResponse(Budget budget) {

        // =========================
        // 1. TIME
        // =========================
        LocalDate today = LocalDate.now();
        LocalDate start = budget.getBeginDate();
        LocalDate end = budget.getEndDate();

        // Budget đã hết hạn chưa
        boolean expired = today.isAfter(end);

        // =========================
        // 2. QUERY PARAM
        // =========================


        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;


//        // ⚠️ Safe tránh NPE nếu sau này cho phép null wallet
//        Integer walletId = budget.getWallet() != null
//                ? budget.getWallet().getId()
//                : null;

        // Convert LocalDate -> LocalDateTime
        LocalDateTime startDt = start.atStartOfDay();

        // ✅ Chuẩn hơn 23:59:59
        LocalDateTime endDt = end.atTime(LocalTime.MAX);

        // Lấy categoryIds (null nếu ALL)
        Set<Integer> categoryIds = resolveCategoryIds(budget);

        // =========================
        // 3. SPENT (tính tất cả giao dịch trong khoảng thời gian budget, bao gồm tương lai)
        // =========================

        BigDecimal spent = transactionRepository.sumExpenseForBudget(
                budget.getAccount().getId(),
                startDt,
                endDt,
                walletId,
                budget.getAllCategories(),
                categoryIds);

        // ⚠️ tránh null từ DB
        if (spent == null) {
            spent = BigDecimal.ZERO;
        }


        // Số tiền còn lại
//        BigDecimal remaining = budget.getAmount().subtract(spent);

        BigDecimal remaining = budget.getAmount().subtract(spent).max(BigDecimal.ZERO);



        // =========================
        // 4. DAYS CALCULATION
        // =========================

        // Tổng số ngày của budget
        long totalDays = ChronoUnit.DAYS.between(start, end) + 1;
        if (totalDays <= 0)
            totalDays = 1;

        // Nếu budget chưa bắt đầu (today < start) → daysElapsed = 0
        // Nếu budget đã bắt đầu → tính số ngày đã trôi qua
        long daysElapsed;
        if (today.isBefore(start)) {
            daysElapsed = 0; // Budget chưa bắt đầu
        } else {
            LocalDate effectiveToday = expired ? end : today;
            daysElapsed = ChronoUnit.DAYS.between(start, effectiveToday) + 1;
            if (daysElapsed <= 0)
                daysElapsed = 1;
        }

        // Số ngày còn lại
        long daysLeft = ChronoUnit.DAYS.between(today, end);
        if (daysLeft < 0)
            daysLeft = 0;

        // =========================
        // 5. CALCULATIONS
        // =========================

        // Trung bình chi mỗi ngày
        BigDecimal dailyActual = BigDecimal.ZERO;
        if (daysElapsed > 0 && spent.compareTo(BigDecimal.ZERO) > 0) {
            dailyActual = spent.divide(
                    BigDecimal.valueOf(daysElapsed),
                    2,
                    RoundingMode.HALF_UP);
        }

        // Dự đoán tổng chi đến cuối kỳ = dailyActual * totalDays (chỉ tính khi còn ngày)
        BigDecimal projected = BigDecimal.ZERO;
        if (daysLeft > 0 && dailyActual.compareTo(BigDecimal.ZERO) > 0) {
            projected = dailyActual.multiply(BigDecimal.valueOf(totalDays));
        }

        // Nên chi/ngày = remainingAmount / daysLeft (chỉ tính khi còn ngày và ngân sách chưa hết hạn)
        BigDecimal dailyShould = BigDecimal.ZERO;
        if (!expired && daysLeft > 0 && remaining.compareTo(BigDecimal.ZERO) > 0) {
            dailyShould = remaining.divide(
                    BigDecimal.valueOf(daysLeft),
                    2,
                    RoundingMode.HALF_UP);
        }

        // =========================
        // 6. ALERT LOGIC
        // =========================

        // 🚨 Đã vượt ngân sách
        boolean exceeded = spent.compareTo(budget.getAmount()) > 0;

        // ⚠️ Có nguy cơ vượt (dựa trên projected)
        boolean warning = false;
        if (!expired) {
            warning = projected.compareTo(budget.getAmount()) > 0;
        }

        // % tiến độ sử dụng ngân sách
        // Có thể > 100% khi vượt ngân sách (để hiển thị chính xác như scheduler)
        BigDecimal progress = BigDecimal.ZERO;
        if (budget.getAmount().compareTo(BigDecimal.ZERO) > 0) {
            progress = spent.divide(
                    budget.getAmount(),
                    2,
                    RoundingMode.HALF_UP);
        }

        // =========================
        // 7. CATEGORY RESPONSE
        // =========================

        List<CategoryResponse> catResponses = Boolean.TRUE.equals(budget.getAllCategories())
                ? List.of()
                : budget.getCategories().stream()
                        .map(categoryMapper::toDto)
                        .sorted((c1, c2) -> Integer.compare(c1.id(), c2.id()))  // 👉 Sắp xếp theo ID để đảm bảo thứ tự ổn định
                        .collect(Collectors.toList());

        // =========================
        // 8. PRIMARY CATEGORY (cho Flutter)
        // =========================

        Integer primaryCategoryId = null;
        String primaryCategoryIconUrl = null;

        if (!catResponses.isEmpty()) {
            CategoryResponse first = catResponses.get(0);
            primaryCategoryId = first.id();
            primaryCategoryIconUrl = first.ctgIconUrl();
        }

        // =========================
        // 9. WALLET INFO
        // =========================


//        String walletName = budget.getWallet() != null
//                ? budget.getWallet().getWalletName()
//                : null;


        String walletName = budget.getWallet() != null ? budget.getWallet().getWalletName() : "Total";

        // =========================
        // 10. TÍNH TOÁN ĐỀ XUẤT DỰA TRÊN LỊCH SỬ 3 THÁNG VÀ TẦN SUẤT GIAO DỊCH
        // =========================

        // Tính toán các giá trị đề xuất dựa trên tần suất giao dịch thực tế
        BigDecimal suggestedAmount = calculateSuggestedBudget(budget);
        BigDecimal suggestedDailySpend = BigDecimal.ZERO;
        BigDecimal suggestedWeeklySpend = BigDecimal.ZERO;
        BigDecimal suggestedMonthlySpend = BigDecimal.ZERO;
        BigDecimal suggestedYearlySpend = BigDecimal.ZERO;
        BigDecimal suggestedCustomSpend = BigDecimal.ZERO;

        // Lấy các giá trị đề xuất theo từng đơn vị thời gian
        // Tính tất cả các type để user có thể tham khảo
        suggestedDailySpend = calculateSuggestedDailySpend(budget);

        // Tính suggested cho từng type dựa trên dailyAverage
        TransactionFrequencyAnalysis analysis = analyzeTransactionFrequencyForSuggestion(budget);
        if (analysis != null && analysis.dailyAverage != null) {
            // WEEKLY: dailyAverage * 7
            suggestedWeeklySpend = analysis.dailyAverage.multiply(BigDecimal.valueOf(7));
            // MONTHLY: dailyAverage * 30 (trung bình)
            suggestedMonthlySpend = analysis.dailyAverage.multiply(BigDecimal.valueOf(30));
            // YEARLY: dailyAverage * 365 (trung bình)
            suggestedYearlySpend = analysis.dailyAverage.multiply(BigDecimal.valueOf(365));
            // CUSTOM: dailyAverage * số ngày custom của budget hiện tại
            long customDays = ChronoUnit.DAYS.between(budget.getBeginDate(), budget.getEndDate()) + 1;
            suggestedCustomSpend = analysis.dailyAverage.multiply(BigDecimal.valueOf(customDays));
        }

        // suggestedAmount là giá trị theo budget type hiện tại
        if (budget.getBudgetType() != null) {
            switch (budget.getBudgetType()) {
                case WEEKLY:
                    suggestedAmount = suggestedWeeklySpend;
                    break;
                case MONTHLY:
                    suggestedAmount = suggestedMonthlySpend;
                    break;
                case YEARLY:
                    suggestedAmount = suggestedYearlySpend;
                    break;
                case CUSTOM:
                    suggestedAmount = suggestedCustomSpend;
                    break;
                default:
                    suggestedAmount = BigDecimal.ZERO;
                    break;
            }
        } else {
            // Budget cũ không có budgetType → dùng monthly làm mặc định
            suggestedAmount = suggestedMonthlySpend;
        }

        // Tính số tiền vượt ngân sách = max(0, spent - amount)
        BigDecimal overBudgetAmount = spent.compareTo(budget.getAmount()) > 0
                ? spent.subtract(budget.getAmount())
                : BigDecimal.ZERO;

        // =========================
        // 11. BUILD RESPONSE
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
                .suggestedAmount(suggestedAmount)
                .suggestedDailySpend(suggestedDailySpend)
                .suggestedWeeklySpend(suggestedWeeklySpend)
                .suggestedMonthlySpend(suggestedMonthlySpend)
                .suggestedYearlySpend(suggestedYearlySpend)
                .suggestedCustomSpend(suggestedCustomSpend)
                .overBudgetAmount(overBudgetAmount)
                .build();
    }

    /**
     * Validate ngày bắt đầu phải trước ngày kết thúc.
     * Đối với CUSTOM budget, không cho chọn ngày quá khứ.
     */
    private void validateDates(LocalDate beginDate, LocalDate endDate, String budgetType) {
        if (!beginDate.isBefore(endDate)) {
            throw new IllegalArgumentException("Start date must be before end date.");
        }

        // Chỉ kiểm tra beginDate >= today khi budgetType = CUSTOM
        if ("CUSTOM".equals(budgetType)) {
            LocalDate today = LocalDate.now();
            if (beginDate.isBefore(today)) {
                throw new IllegalArgumentException("Start date must be today or later for custom budget.");
            }
        }
    }

    /**
     * Tính toán mức chi tiêu/ngày đề xuất dựa trên lịch sử chi tiêu 3 tháng gần nhất.
     * Giá trị này là trung bình thực tế chi mỗi ngày, không phụ thuộc vào budget type.
     *
     * @param budget - Ngân sách hiện tại để lấy thông tin wallet, categories
     * @return BigDecimal - Mức chi tiêu/ngày đề xuất
     */
    private BigDecimal calculateSuggestedDailySpend(Budget budget) {
        // Query giao dịch 3 tháng gần nhất
        LocalDate today = LocalDate.now();
        LocalDate threeMonthsAgo = today.minusMonths(3);

        LocalDateTime startDate = threeMonthsAgo.atStartOfDay();
        LocalDateTime endDate = today.atTime(LocalTime.MAX);

        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        Set<Integer> categoryIds = resolveCategoryIds(budget);

        // Query danh sách giao dịch 3 tháng gần nhất
        List<Transaction> transactions = transactionRepository.findTransactionsForBudget(
                budget.getAccount().getId(),
                startDate,
                endDate,
                walletId,
                budget.getAllCategories(),
                categoryIds
        );

        // Nếu không có giao dịch nào → không đề xuất
        if (transactions == null || transactions.isEmpty()) {
            return BigDecimal.ZERO;
        }

        // Phân tích tần suất giao dịch trong 3 tháng
        TransactionFrequencyAnalysis analysis = analyzeTransactionFrequency(
                transactions,
                threeMonthsAgo,
                today
        );

        // Trả về trung bình chi mỗi ngày từ phân tích
        return analysis.dailyAverage;
    }

    /**
     * Tính toán mức ngân sách đề xuất dựa trên lịch sử chi tiêu 3 tháng gần nhất
     * và phân tích tần suất giao dịch thực tế của category.
     *
     * Logic chi tiết:
     * 1. Query giao dịch 3 tháng gần nhất theo wallet và category của budget
     * 2. Phân tích tần suất giao dịch:
     *    - Đếm số ngày có giao dịch / tổng số ngày trong 3 tháng
     *    - Đếm số tuần có giao dịch / tổng số tuần trong 3 tháng
     *    - Đếm số tháng có giao dịch / tổng số tháng trong 3 tháng
     * 3. Xác định mô hình giao dịch:
     *    - Nếu > 80% ngày có giao dịch → Giao dịch hàng ngày
     *    - Nếu > 70% tuần có giao dịch → Giao dịch hàng tuần
     *    - Nếu > 60% tháng có giao dịch → Giao dịch hàng tháng
     *    - Ngược lại → Giao dịch không đều
     * 4. Tính đề xuất theo budget type dựa trên mô hình thực tế:
     *    - WEEKLY: Nếu giao dịch hàng ngày → trung bình ngày * 7
     *              Nếu giao dịch hàng tuần → trung bình tuần
     *              Nếu giao dịch hàng tháng → trung bình tháng / 4
     *    - MONTHLY: Nếu giao dịch hàng ngày → trung bình ngày * 30
     *               Nếu giao dịch hàng tuần → trung bình tuần * 4
     *               Nếu giao dịch hàng tháng → trung bình tháng
     *    - YEARLY: Nếu giao dịch hàng ngày → trung bình ngày * 365
     *              Nếu giao dịch hàng tuần → trung bình tuần * 52
     *              Nếu giao dịch hàng tháng → trung bình tháng * 12
     *    - CUSTOM: Trung bình ngày * số ngày của budget
     *
     * @param budget - Ngân sách hiện tại để lấy thông tin wallet, categories, budget type
     * @return BigDecimal - Mức ngân sách đề xuất
     */
    private BigDecimal calculateSuggestedBudget(Budget budget) {
        // Bước 1: Query giao dịch 3 tháng gần nhất theo wallet và category
        LocalDate today = LocalDate.now();
        LocalDate threeMonthsAgo = today.minusMonths(3);

        LocalDateTime startDate = threeMonthsAgo.atStartOfDay();
        LocalDateTime endDate = today.atTime(LocalTime.MAX);

        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        Set<Integer> categoryIds = resolveCategoryIds(budget);

        // Nếu budgetType là null (ngân sách cũ) → không đề xuất
        if (budget.getBudgetType() == null) {
            return BigDecimal.ZERO;
        }

        // Bước 2: Query danh sách giao dịch 3 tháng gần nhất
        List<Transaction> transactions = transactionRepository.findTransactionsForBudget(
                budget.getAccount().getId(),
                startDate,
                endDate,
                walletId,
                budget.getAllCategories(),
                categoryIds
        );

        // Nếu không có giao dịch nào → không đề xuất
        if (transactions == null || transactions.isEmpty()) {
            return BigDecimal.ZERO;
        }

        // Bước 3: Phân tích tần suất giao dịch trong 3 tháng
        TransactionFrequencyAnalysis analysis = analyzeTransactionFrequency(
                transactions,
                threeMonthsAgo,
                today
        );

        // Bước 4: Tính số ngày có giao dịch để kiểm tra dữ liệu ít/nhiều
        Set<LocalDate> transactionDates = new java.util.HashSet<>();
        for (Transaction t : transactions) {
            transactionDates.add(t.getTransDate().toLocalDate());
        }
        long daysWithTransactions = transactionDates.size();

        // Bước 5: Tính gợi ý theo budget type dựa trên phân tích tần suất
        return calculateBudgetByTypeWithFrequency(
                budget.getBudgetType(),
                budget.getBeginDate(),
                budget.getEndDate(),
                analysis,
                daysWithTransactions
        );
    }

    /**
     * Phân tích tần suất giao dịch từ danh sách giao dịch 3 tháng gần nhất.
     *
     * Logic chi tiết:
     * - Tính tổng số ngày/tuần/tháng trong khoảng thời gian 3 tháng
     * - Tính các giá trị trung bình: chia tổng số tiền cho tổng số ngày/tuần/tháng
     * - Xác định mô hình giao dịch dựa trên tỷ lệ tần suất
     *
     * @param transactions - List<Transaction> danh sách giao dịch
     * @param startDate - Ngày bắt đầu khoảng thời gian (3 tháng trước)
     * @param endDate - Ngày kết thúc khoảng thời gian (hôm nay)
     * @return TransactionFrequencyAnalysis - Kết quả phân tích tần suất
     */
    private TransactionFrequencyAnalysis analyzeTransactionFrequency(
            List<Transaction> transactions,
            LocalDate startDate,
            LocalDate endDate) {

        // Tính tổng số ngày trong khoảng thời gian
        long totalDays = ChronoUnit.DAYS.between(startDate, endDate) + 1;

        // Tính tổng số tuần trong khoảng thời gian (dùng ISO week)
        long totalWeeks = ChronoUnit.WEEKS.between(startDate, endDate) + 1;

        // Tính tổng số tháng trong khoảng thời gian
        long totalMonths = ChronoUnit.MONTHS.between(startDate, endDate) + 1;

        // Đếm số ngày có giao dịch và tổng tiề.n
        Set<LocalDate> transactionDates = new java.util.HashSet<>();
        BigDecimal totalAmount = BigDecimal.ZERO;

        for (Transaction t : transactions) {
            LocalDate date = t.getTransDate().toLocalDate();
            transactionDates.add(date);
            totalAmount = totalAmount.add(t.getAmount());
        }

        long daysWithTransactions = transactionDates.size();

        // Đếm số tuần có giao dịch - dùng cả year + weekNumber để tránh lỗi khi giao dịch qua năm
        Set<String> weeksWithTransactions = new java.util.HashSet<>();
        for (LocalDate date : transactionDates) {
            int weekNumber = date.get(java.time.temporal.WeekFields.ISO.weekOfWeekBasedYear());
            int year = date.getYear();
            weeksWithTransactions.add(year + "-" + weekNumber);
        }
        long weeksWithTransactionsCount = weeksWithTransactions.size();

        // Đếm số tháng có giao dịch
        Set<java.time.YearMonth> monthsWithTransactions = new java.util.HashSet<>();
        for (LocalDate date : transactionDates) {
            monthsWithTransactions.add(java.time.YearMonth.from(date));
        }
        long monthsWithTransactionsCount = monthsWithTransactions.size();

        // Tính tỷ lệ tần suất
        double dailyFrequency = totalDays > 0 ? (double) daysWithTransactions / totalDays : 0;
        double weeklyFrequency = totalWeeks > 0 ? (double) weeksWithTransactionsCount / totalWeeks : 0;
        double monthlyFrequency = totalMonths > 0 ? (double) monthsWithTransactionsCount / totalMonths : 0;

        // Tính các giá trị trung bình - chia cho tổng số ngày/tuần/tháng trong khoảng thời gian
        // Ví dụ: Nếu chi 150k/tuần trong 4 tuần → weeklyAverage = 600k / 12 tuần = 50k (đúng)
        // chứ không phải 600k / 4 tuần = 150k (sai!)
        BigDecimal dailyAverage = totalDays > 0
                ? totalAmount.divide(BigDecimal.valueOf(totalDays), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal weeklyAverage = totalWeeks > 0
                ? totalAmount.divide(BigDecimal.valueOf(totalWeeks), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal monthlyAverage = totalMonths > 0
                ? totalAmount.divide(BigDecimal.valueOf(totalMonths), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        // Xác định mô hình giao dịch
        TransactionPattern pattern = TransactionPattern.IRREGULAR;

        if (dailyFrequency > 0.8) {
            // Nếu > 80% ngày có giao dịch → Giao dịch hàng ngày
            pattern = TransactionPattern.DAILY;
        } else if (weeklyFrequency > 0.7) {
            // Nếu > 70% tuần có giao dịch → Giao dịch hàng tuần
            pattern = TransactionPattern.WEEKLY;
        } else if (monthlyFrequency > 0.6) {
            // Nếu > 60% tháng có giao dịch → Giao dịch hàng tháng
            pattern = TransactionPattern.MONTHLY;
        }

        return new TransactionFrequencyAnalysis(
                pattern,
                totalAmount,
                dailyAverage,
                weeklyAverage,
                monthlyAverage,
                dailyFrequency,
                weeklyFrequency,
                monthlyFrequency
        );
    }

    /**
     * Phân tích tần suất giao dịch để tính suggested amount (đơn giản hóa).
     * Chỉ cần dailyAverage để tính suggested cho các type khác nhau.
     *
     * @param budget - Ngân sách hiện tại
     * @return TransactionFrequencyAnalysis - Kết quả phân tích (chỉ dùng dailyAverage)
     */
    private TransactionFrequencyAnalysis analyzeTransactionFrequencyForSuggestion(Budget budget) {
        // Query giao dịch 3 tháng gần nhất
        LocalDate today = LocalDate.now();
        LocalDate threeMonthsAgo = today.minusMonths(3);

        LocalDateTime startDate = threeMonthsAgo.atStartOfDay();
        LocalDateTime endDate = today.atTime(LocalTime.MAX);

        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        Set<Integer> categoryIds = resolveCategoryIds(budget);

        // Query danh sách giao dịch 3 tháng gần nhất
        List<Transaction> transactions = transactionRepository.findTransactionsForBudget(
                budget.getAccount().getId(),
                startDate,
                endDate,
                walletId,
                budget.getAllCategories(),
                categoryIds
        );

        // Nếu không có giao dịch nào → trả về null
        if (transactions == null || transactions.isEmpty()) {
            return null;
        }

        // Phân tích tần suất giao dịch trong 3 tháng
        return analyzeTransactionFrequency(
                transactions,
                threeMonthsAgo,
                today
        );
    }

    /**
     * Tính toán ngân sách đề xuất theo budget type dựa trên phân tích tần suất giao dịch.
     *
     * Logic chi tiết:
     * - WEEKLY: dailyAverage * 7 ngày
     * - MONTHLY: dailyAverage * số ngày thực tế của tháng từ beginDate (28, 30, 31 ngày)
     * - YEARLY: dailyAverage * số ngày thực tế của năm từ beginDate (365 hoặc 366 ngày)
     * - CUSTOM: dailyAverage * số ngày custom (từ beginDate đến endDate)
     *
     * @param budgetType - Loại ngân sách (WEEKLY, MONTHLY, YEARLY, CUSTOM)
     * @param beginDate - Ngày bắt đầu của ngân sách (dùng cho CUSTOM, MONTHLY, YEARLY)
     * @param endDate - Ngày kết thúc của ngân sách (dùng cho CUSTOM)
     * @param analysis - Kết quả phân tích tần suất giao dịch
     * @param daysWithTransactions - Số ngày có giao dịch (để kiểm tra dữ liệu ít/nhiều)
     * @return BigDecimal - Mức ngân sách đề xuất
     */
    private BigDecimal calculateBudgetByTypeWithFrequency(
            fpt.aptech.server.enums.budget.BudgetType budgetType,
            LocalDate beginDate,
            LocalDate endDate,
            TransactionFrequencyAnalysis analysis,
            long daysWithTransactions) {

        // Giải pháp đơn giản: luôn dùng dailyAverage * số ngày theo budget type
        // Tránh conversion pattern sai khi pattern không khớp với budget type

        switch (budgetType) {
            case WEEKLY:
                // WEEKLY: trung bình ngày * 7 ngày
                return analysis.dailyAverage.multiply(BigDecimal.valueOf(7));

            case MONTHLY:
                // MONTHLY: trung bình ngày * số ngày thực tế của tháng từ beginDate
                int daysInMonth = YearMonth.from(beginDate).lengthOfMonth();
                return analysis.dailyAverage.multiply(BigDecimal.valueOf(daysInMonth));

            case YEARLY:
                // YEARLY: trung bình ngày * số ngày thực tế của năm từ beginDate (365 hoặc 366)
                int daysInYear = beginDate.lengthOfYear();
                return analysis.dailyAverage.multiply(BigDecimal.valueOf(daysInYear));

            case CUSTOM:
                // CUSTOM: trung bình ngày * số ngày custom
                long customDays = ChronoUnit.DAYS.between(beginDate, endDate) + 1;
                return analysis.dailyAverage.multiply(BigDecimal.valueOf(customDays));

            default:
                return BigDecimal.ZERO;
        }
    }

    /**
     * Inner class để lưu kết quả phân tích tần suất giao dịch.
     */
    private static class TransactionFrequencyAnalysis {
        final TransactionPattern pattern;           // Mô hình giao dịch
        final BigDecimal totalAmount;              // Tổng số tiền trong 3 tháng
        final BigDecimal dailyAverage;             // Trung bình chi mỗi ngày
        final BigDecimal weeklyAverage;            // Trung bình chi mỗi tuần
        final BigDecimal monthlyAverage;           // Trung bình chi mỗi tháng
        final double dailyFrequency;               // Tỷ lệ ngày có giao dịch
        final double weeklyFrequency;              // Tỷ lệ tuần có giao dịch
        final double monthlyFrequency;             // Tỷ lệ tháng có giao dịch

        TransactionFrequencyAnalysis(
                TransactionPattern pattern,
                BigDecimal totalAmount,
                BigDecimal dailyAverage,
                BigDecimal weeklyAverage,
                BigDecimal monthlyAverage,
                double dailyFrequency,
                double weeklyFrequency,
                double monthlyFrequency) {
            this.pattern = pattern;
            this.totalAmount = totalAmount;
            this.dailyAverage = dailyAverage;
            this.weeklyAverage = weeklyAverage;
            this.monthlyAverage = monthlyAverage;
            this.dailyFrequency = dailyFrequency;
            this.weeklyFrequency = weeklyFrequency;
            this.monthlyFrequency = monthlyFrequency;
        }
    }

    /**
     * Enum mô hình tần suất giao dịch.
     */
    private enum TransactionPattern {
        DAILY,       // Giao dịch hàng ngày (> 80% ngày có giao dịch)
        WEEKLY,      // Giao dịch hàng tuần (> 70% tuần có giao dịch)
        MONTHLY,     // Giao dịch hàng tháng (> 60% tháng có giao dịch)
        IRREGULAR    // Giao dịch không đều
    }

    /**
     * Tính toán dự đoán tổng chi đến cuối kỳ dựa trên pattern giao dịch từ lịch sử 3 tháng.
     * Logic cải thiện: Dự đoán chính xác hơn với WEEKLY/MONTHLY/IRREGULAR pattern.
     *
     * @param budget - Ngân sách hiện tại
     * @param totalDays - Tổng số ngày của budget
     * @return BigDecimal - Dự đoán tổng chi đến cuối kỳ
     */
    private BigDecimal calculateProjectedSpendByPattern(Budget budget, long totalDays) {
        // Query giao dịch 3 tháng gần nhất
        LocalDate today = LocalDate.now();
        LocalDate threeMonthsAgo = today.minusMonths(3);

        LocalDateTime startDate = threeMonthsAgo.atStartOfDay();
        LocalDateTime endDate = today.atTime(LocalTime.MAX);

        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        Set<Integer> categoryIds = resolveCategoryIds(budget);

        // Query danh sách giao dịch 3 tháng gần nhất
        List<Transaction> transactions = transactionRepository.findTransactionsForBudget(
                budget.getAccount().getId(),
                startDate,
                endDate,
                walletId,
                budget.getAllCategories(),
                categoryIds
        );

        // Nếu không có giao dịch nào → dự đoán = 0
        if (transactions == null || transactions.isEmpty()) {
            return BigDecimal.ZERO;
        }

        // Phân tích tần suất giao dịch trong 3 tháng
        TransactionFrequencyAnalysis analysis = analyzeTransactionFrequency(
                transactions,
                threeMonthsAgo,
                today
        );

        // Dự đoán dựa trên pattern giao dịch
        switch (analysis.pattern) {
            case DAILY:
                // Giao dịch hàng ngày → trung bình ngày * tổng số ngày
                return analysis.dailyAverage.multiply(BigDecimal.valueOf(totalDays));

            case WEEKLY:
                // Giao dịch hàng tuần → trung bình tuần * (tổng số ngày / 7)
                long weeksCount = totalDays / 7;
                if (totalDays % 7 > 0) weeksCount++; // Làm tròn lên nếu dư
                return analysis.weeklyAverage.multiply(BigDecimal.valueOf(weeksCount));

            case MONTHLY:
                // Giao dịch hàng tháng → trung bình tháng * (tổng số ngày / 30)
                long monthsCount = totalDays / 30;
                if (totalDays % 30 > 0) monthsCount++; // Làm tròn lên nếu dư
                return analysis.monthlyAverage.multiply(BigDecimal.valueOf(monthsCount));

            default: // IRREGULAR
                // Giao dịch không đều → dùng trung bình ngày * tổng số ngày (an toàn nhất)
                return analysis.dailyAverage.multiply(BigDecimal.valueOf(totalDays));
        }
    }

    /**
     * Tính toán mức chi/ngày nên chi dựa trên pattern giao dịch từ lịch sử 3 tháng.
     * Logic cải thiện: Dựa trên pattern giao dịch thực tế thay vì chia đều.
     *
     * @param budget - Ngân sách hiện tại
     * @return BigDecimal - Mức chi/ngày nên chi
     */
    private BigDecimal calculateDailyShouldSpendByPattern(Budget budget) {
        // Query giao dịch 3 tháng gần nhất
        LocalDate today = LocalDate.now();
        LocalDate threeMonthsAgo = today.minusMonths(3);

        LocalDateTime startDate = threeMonthsAgo.atStartOfDay();
        LocalDateTime endDate = today.atTime(LocalTime.MAX);

        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        Set<Integer> categoryIds = resolveCategoryIds(budget);

        // Query danh sách giao dịch 3 tháng gần nhất
        List<Transaction> transactions = transactionRepository.findTransactionsForBudget(
                budget.getAccount().getId(),
                startDate,
                endDate,
                walletId,
                budget.getAllCategories(),
                categoryIds
        );

        // Nếu không có giao dịch nào → không đề xuất
        if (transactions == null || transactions.isEmpty()) {
            return BigDecimal.ZERO;
        }

        // Phân tích tần suất giao dịch trong 3 tháng
        TransactionFrequencyAnalysis analysis = analyzeTransactionFrequency(
                transactions,
                threeMonthsAgo,
                today
        );

        // Tính toán dựa trên pattern giao dịch
        switch (analysis.pattern) {
            case DAILY:
                // Giao dịch hàng ngày → dùng trực tiếp trung bình ngày
                return analysis.dailyAverage;

            case WEEKLY:
                // Giao dịch hàng tuần → trung bình tuần / 7
                return analysis.weeklyAverage.divide(BigDecimal.valueOf(7), 2, RoundingMode.HALF_UP);

            case MONTHLY:
                // Giao dịch hàng tháng → trung bình tháng / 30
                return analysis.monthlyAverage.divide(BigDecimal.valueOf(30), 2, RoundingMode.HALF_UP);

            default: // IRREGULAR
                // Giao dịch không đều → dùng trung bình ngày
                return analysis.dailyAverage;
        }
    }
}
