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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
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
                    throw new IllegalArgumentException(
                            "Category already has a budget in this time period");
            }
        }
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
        // 3. SPENT
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

        // Dự đoán tổng chi đến cuối kỳ
        // Nếu dailyActual = 0 (chưa có giao dịch) → projected = 0
        // Nếu dailyActual > 0 → projected = dailyActual * totalDays
        BigDecimal projected = BigDecimal.ZERO;
        if (dailyActual.compareTo(BigDecimal.ZERO) > 0) {
            projected = dailyActual.multiply(BigDecimal.valueOf(totalDays));
        }

        // Mỗi ngày nên chi bao nhiêu để không vượt budget
        BigDecimal dailyShould = BigDecimal.ZERO;
        if (daysLeft > 0) {
            dailyShould = remaining
                    .max(BigDecimal.ZERO) // 🔥 không cho âm
                    .divide(
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

        // Tính toán ngân sách đề xuất dựa trên tần suất giao dịch thực tế
        BigDecimal suggestedAmount = calculateSuggestedBudget(budget);
        BigDecimal suggestedDailySpend = BigDecimal.ZERO;

        // Tính số tiền nên chi hàng ngày theo đề xuất
        if (suggestedAmount.compareTo(BigDecimal.ZERO) > 0 && totalDays > 0) {
            suggestedDailySpend = suggestedAmount.divide(
                    BigDecimal.valueOf(totalDays),
                    2,
                    RoundingMode.HALF_UP);
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

        // Đếm số ngày có giao dịch và tổng tiền
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

        // Tính các giá trị trung bình - CHỈ tính trên các ngày/tuần/tháng CÓ giao dịch
        // Ví dụ: Nếu chi 150k/tuần trong 4 tuần → weeklyAverage = 600k / 4 = 150k (đúng)
        // chứ không phải 600k / 13 tuần = 46k (sai!)
        BigDecimal dailyAverage = daysWithTransactions > 0
                ? totalAmount.divide(BigDecimal.valueOf(daysWithTransactions), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal weeklyAverage = weeksWithTransactionsCount > 0
                ? totalAmount.divide(BigDecimal.valueOf(weeksWithTransactionsCount), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        BigDecimal monthlyAverage = monthsWithTransactionsCount > 0
                ? totalAmount.divide(BigDecimal.valueOf(monthsWithTransactionsCount), 2, RoundingMode.HALF_UP)
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
     * Tính toán ngân sách đề xuất theo budget type dựa trên phân tích tần suất giao dịch.
     *
     * @param budgetType - Loại ngân sách (WEEKLY, MONTHLY, YEARLY, CUSTOM)
     * @param beginDate - Ngày bắt đầu của ngân sách (dùng cho CUSTOM)
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

        // Kiểm tra dữ liệu ít hay nhiều
        boolean insufficientData = daysWithTransactions < 7;

        switch (budgetType) {
            case WEEKLY:
                // WEEKLY: Dựa trên mô hình giao dịch thực tế
                switch (analysis.pattern) {
                    case DAILY:
                        // Giao dịch hàng ngày → trung bình ngày * 7
                        return analysis.dailyAverage.multiply(BigDecimal.valueOf(7));
                    case WEEKLY:
                        // Giao dịch hàng tuần → dùng trực tiếp trung bình tuần
                        return analysis.weeklyAverage;
                    case MONTHLY:
                        // Giao dịch hàng tháng → trung bình tháng / 4
                        return analysis.monthlyAverage.divide(BigDecimal.valueOf(4), 2, RoundingMode.HALF_UP);
                    default:
                        // IRREGULAR → dùng trung bình ngày * 7 (an toàn nhất, phản ánh thực tế)
                        return analysis.dailyAverage.multiply(BigDecimal.valueOf(7));
                }

            case MONTHLY:
                if (insufficientData) {
                    // Dữ liệu ít: dùng trung bình ngày * 30
                    return analysis.dailyAverage.multiply(BigDecimal.valueOf(30));
                }
                // Dữ liệu nhiều: giữ nguyên logic hiện tại
                switch (analysis.pattern) {
                    case DAILY:
                        // Giao dịch hàng ngày → trung bình ngày * 30
                        return analysis.dailyAverage.multiply(BigDecimal.valueOf(30));
                    case WEEKLY:
                        // Giao dịch hàng tuần → trung bình tuần * 4
                        return analysis.weeklyAverage.multiply(BigDecimal.valueOf(4));
                    case MONTHLY:
                        // Giao dịch hàng tháng → dùng trực tiếp trung bình tháng
                        return analysis.monthlyAverage;
                    default:
                        // IRREGULAR → dùng trung bình tháng
                        return analysis.monthlyAverage;
                }

            case YEARLY:
                // YEARLY: Dựa trên mô hình giao dịch thực tế
                switch (analysis.pattern) {
                    case DAILY:
                        // Giao dịch hàng ngày → trung bình ngày * 365
                        return analysis.dailyAverage.multiply(BigDecimal.valueOf(365));
                    case WEEKLY:
                        // Giao dịch hàng tuần → trung bình tuần * 52
                        return analysis.weeklyAverage.multiply(BigDecimal.valueOf(52));
                    case MONTHLY:
                        // Giao dịch hàng tháng → trung bình tháng * 12
                        return analysis.monthlyAverage.multiply(BigDecimal.valueOf(12));
                    default:
                        // IRREGULAR → dùng trung bình ngày * 365 (an toàn nhất, phản ánh thực tế)
                        return analysis.dailyAverage.multiply(BigDecimal.valueOf(365));
                }

            case CUSTOM:
                // CUSTOM: Dựa trên mô hình giao dịch thực tế
                long customDays = ChronoUnit.DAYS.between(beginDate, endDate) + 1;
                switch (analysis.pattern) {
                    case DAILY:
                        // Giao dịch hàng ngày → trung bình ngày * số ngày
                        return analysis.dailyAverage.multiply(BigDecimal.valueOf(customDays));
                    case WEEKLY:
                        // Giao dịch hàng tuần → trung bình tuần * (số ngày / 7)
                        long customWeeks = customDays / 7;
                        if (customDays % 7 > 0) customWeeks++; // Làm tròn lên nếu dư
                        return analysis.weeklyAverage.multiply(BigDecimal.valueOf(customWeeks));
                    case MONTHLY:
                        // Giao dịch hàng tháng → trung bình tháng * (số ngày / 30)
                        long customMonths = customDays / 30;
                        if (customDays % 30 > 0) customMonths++; // Làm tròn lên nếu dư
                        return analysis.monthlyAverage.multiply(BigDecimal.valueOf(customMonths));
                    default:
                        // IRREGULAR → dùng trung bình ngày
                        return analysis.dailyAverage.multiply(BigDecimal.valueOf(customDays));
                }

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
}
