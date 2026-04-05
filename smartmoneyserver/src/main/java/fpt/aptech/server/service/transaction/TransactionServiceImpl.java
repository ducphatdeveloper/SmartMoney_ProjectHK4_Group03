package fpt.aptech.server.service.transaction;

import fpt.aptech.server.dto.transaction.report.CategoryReportDTO;
import fpt.aptech.server.dto.transaction.report.DailyTrendDTO;
import fpt.aptech.server.dto.transaction.report.FinancialReportResponse;
import fpt.aptech.server.dto.transaction.report.TransactionReportResponse;
import fpt.aptech.server.dto.transaction.request.TransactionRequest;
import fpt.aptech.server.dto.transaction.request.TransactionSearchRequest;
import fpt.aptech.server.dto.transaction.view.CategoryTransactionGroup;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.enums.transaction.TransactionSourceType;
import fpt.aptech.server.mapper.transaction.TransactionMapper;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.contact.ContactRequestService;
import fpt.aptech.server.service.debt.DebtCalculationService;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.utils.currency.CurrencyUtils;
import fpt.aptech.server.utils.date.DateUtils;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.Collator;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TransactionServiceImpl implements TransactionService {

    private final TransactionRepository        transactionRepository;
    private final AccountRepository            accountRepository;
    private final WalletRepository             walletRepository;
    private final CategoryRepository           categoryRepository;
    private final EventRepository              eventRepository;
    private final DebtRepository               debtRepository;
    private final SavingGoalRepository         savingGoalRepository;
    private final AIConversationRepository     aiConversationRepository;
    private final DebtCalculationService       debtCalculationService;
    private final NotificationService          notificationService;
    private final TransactionMapper            transactionMapper;

    // [NOTE] Inject @Lazy để tránh circular dependency (ContactRequestService ↔ TransactionService) — thêm 4/2026
    private ContactRequestService contactRequestService;
    @Lazy
    @org.springframework.beans.factory.annotation.Autowired
    public void setContactRequestService(ContactRequestService contactRequestService) {
        this.contactRequestService = contactRequestService;
    }

    // =================================================================================
    // 1. TẠO MỚI (CREATE)
    // =================================================================================

    /**
     * [1.1] Tạo một giao dịch mới (Chi tiêu, Thu nhập, Chuyển khoản, Nợ/Vay).
     * Bước 1 — Lấy User hiện tại.
     * Bước 2 — Map DTO → Entity.
     * Bước 3 — Validate: phải có Ví hoặc Mục tiêu (không được cả hai).
     * Bước 4 — Validate và gán Danh mục.
     * Bước 5 — Xử lý cộng/trừ số dư Ví hoặc Mục tiêu.
     * Bước 6 — Gán Sự kiện (nếu có).
     * Bước 7 — Xử lý logic Sổ nợ (nếu là category nợ/vay).
     * Bước 8 — Lưu giao dịch.
     * Bước 9 — Tính lại Debt (nếu có).
     * Bước 10 — Gửi thông báo (nhắc lịch + xác nhận giao dịch).
     */
    @Override
    @Transactional
    public TransactionResponse createTransaction(TransactionRequest request, Integer accountId) {
        // Bước 1: Lấy thông tin User hiện tại
        Account currentUser = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));

        // Bước 2: Map dữ liệu từ DTO sang Entity
        Transaction transaction = transactionMapper.toEntity(request);
        transaction.setAccount(currentUser);

        // Gán sourceType tường minh là MANUAL (vì đây là flow nhập tay từ API)
        transaction.setSourceType(TransactionSourceType.MANUAL.getValue());

        // Hỗ trợ AI flow: nếu request truyền sourceType → override (2=chat, 3=voice, 4=receipt, 5=planned)
        if (request.sourceType() != null && request.sourceType() >= 2 && request.sourceType() <= 5) {
            transaction.setSourceType(request.sourceType());
        }

        // Gán AI Conversation nếu có (bắt buộc khi sourceType = 2, 3, 4)
        if (request.aiChatId() != null) {
            AIConversation aiConversation = aiConversationRepository.findById(request.aiChatId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Cuộc hội thoại AI không tồn tại với ID: " + request.aiChatId()));
            transaction.setAiConversation(aiConversation);
        }

        // Bước 3: Validate nguồn tiền
        if (request.walletId() == null && request.goalId() == null) {
            throw new IllegalArgumentException("Vui lòng chọn Ví hoặc Mục tiêu tiết kiệm.");
        }
        if (request.walletId() != null && request.goalId() != null) {
            throw new IllegalArgumentException(
                    "Giao dịch chỉ được thuộc về Ví hoặc Mục tiêu, không được thuộc về cả hai.");
        }

        // Bước 4: Validate và lấy Danh mục
        Category category = categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Danh mục không tồn tại với ID: " + request.categoryId()));
        if (category.getAccount() != null
                && !category.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng danh mục này.");
        }
        transaction.setCategory(category);

        // Bước 5: Cộng/trừ số dư Ví hoặc Mục tiêu
        if (request.goalId() != null) {
            processSavingGoalTransaction(
                    transaction, request.goalId(), accountId,
                    category.getCtgType(), request.amount());
        } else {
            processWalletTransaction(
                    transaction, request.walletId(), accountId,
                    category.getCtgType(), request.amount());
        }

        // Bước 6: Gán Sự kiện (nếu có)
        if (request.eventId() != null) {
            Event event = eventRepository.findById(request.eventId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Sự kiện không tồn tại với ID: " + request.eventId()));
            if (!event.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Bạn không có quyền sử dụng sự kiện này.");
            }
            transaction.setEvent(event);
        }

        // Bước 7: Xử lý logic Sổ nợ
        processDebtTransaction(transaction, request, currentUser, category.getId(), accountId);

        // Bước 8: Lưu giao dịch
        Transaction savedTransaction = transactionRepository.save(transaction);

        // Bước 9: Tính lại Debt nếu giao dịch liên quan đến nợ
        if (savedTransaction.getDebt() != null) {
            debtCalculationService.recalculateDebt(savedTransaction.getDebt().getId(), currentUser);
        }

        // Bước 10a: Nếu user đặt ngày nhắc nhở → tạo thông báo hẹn giờ
        if (request.reminderDate() != null) {
            notificationService.createNotification(
                    currentUser,
                    "Nhắc nhở giao dịch",
                    "Bạn có nhắc nhở cho giao dịch: "
                            + (request.note() != null ? request.note() : "Không có ghi chú"),
                    NotificationType.REMINDER,
                    savedTransaction.getId(),
                    request.reminderDate()
            );
        }

        // Bước 10b: Gửi thông báo xác nhận giao dịch (chỉ các giao dịch có reportable=true)
        if (Boolean.TRUE.equals(request.reportable())) {
            NotificationContent msg = NotificationMessages.transactionCreated(
                    Boolean.TRUE.equals(category.getCtgType()),
                    request.amount(),
                    category.getCtgName(),
                    savedTransaction.getWallet() != null
                            ? savedTransaction.getWallet().getWalletName()
                            : "Mục tiêu tiết kiệm"
            );
            notificationService.createNotification(
                    currentUser,
                    msg.title(), msg.content(),
                    NotificationType.TRANSACTION,
                    savedTransaction.getId(),
                    null
            );
        }

        // [NOTE] Bước 11: Phát hiện giao dịch bất thường — thêm 4/2026
        // 3 kịch bản được kiểm tra theo thứ tự (chỉ ném cảnh báo cho kịch bản đầu tiên phát hiện được):
        //   (1) Vượt ngưỡng : khoản CHI > 50.000.000đ
        //   (2) Spam         : cùng số tiền xuất hiện ≥ 3 lần trong 10 phút (dựa theo created_at)
        //   (3) Lặp ngày     : cùng số tiền, cùng khung giờ ±30 phút, trong 3 ngày liên tiếp
        checkSuspiciousTransaction(savedTransaction, currentUser, accountId);

        return transactionMapper.toDto(savedTransaction);
    }

    // =================================================================================
    // 2. XEM & CHI TIẾT (READ)
    // =================================================================================

    /**
     * [2.1] Lấy danh sách giao dịch cho màn hình Nhật ký, gom nhóm theo ngày.
     */
    @Override
    @Transactional(readOnly = true)
    public List<DailyTransactionGroup> getJournalTransactions(Integer accountId,
                                                              LocalDateTime startDate, LocalDateTime endDate,
                                                              Integer walletId, Integer savingGoalId) {

        List<Transaction> transactions = transactionRepository.findAllByFilters(
                accountId, startDate, endDate, walletId, savingGoalId);

        // Gom nhóm theo ngày
        Map<LocalDate, List<Transaction>> groupedByDate = transactions.stream()
                .collect(Collectors.groupingBy(t -> t.getTransDate().toLocalDate()));

        return groupedByDate.entrySet().stream()
                .map(entry -> {
                    LocalDate date = entry.getKey();
                    List<Transaction> transInDay = entry.getValue();

                    // Tính thu/chi ròng của ngày đó
                    BigDecimal netAmount = transInDay.stream()
                            .map(t -> Boolean.TRUE.equals(t.getCategory().getCtgType())
                                    ? t.getAmount()
                                    : t.getAmount().negate())
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    return DailyTransactionGroup.builder()
                            .date(date)
                            .displayDateLabel(DateUtils.formatDisplayDate(date))
                            .netAmount(netAmount)
                            .transactions(transactionMapper.toDtoList(transInDay))
                            .build();
                })
                .sorted(Comparator.comparing(DailyTransactionGroup::date).reversed())
                .collect(Collectors.toList());
    }

    /**
     * [2.2] Lấy danh sách giao dịch gom nhóm theo Danh mục.
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryTransactionGroup> getGroupedTransactions(Integer accountId,
                                                                 LocalDateTime startDate, LocalDateTime endDate,
                                                                 Integer walletId, Integer savingGoalId) {

        List<Transaction> transactions = transactionRepository.findAllByFilters(
                accountId, startDate, endDate, walletId, savingGoalId);

        Map<Category, List<Transaction>> groupedByCat = transactions.stream()
                .collect(Collectors.groupingBy(Transaction::getCategory));

        Collator collator = Collator.getInstance(new Locale("vi", "VN"));

        return groupedByCat.entrySet().stream()
                .map(entry -> {
                    Category cat = entry.getKey();
                    List<Transaction> transInGroup = entry.getValue();

                    BigDecimal totalAmount = transInGroup.stream()
                            .map(Transaction::getAmount)
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    return CategoryTransactionGroup.builder()
                            .categoryId(cat.getId())
                            .categoryName(cat.getCtgName())
                            .categoryIconUrl(cat.getCtgIconUrl())
                            .categoryType(cat.getCtgType())
                            .totalAmount(totalAmount)
                            .transactionCount(transInGroup.size())
                            .transactions(transactionMapper.toDtoList(transInGroup))
                            .build();
                })
                .sorted(Comparator.comparing(CategoryTransactionGroup::categoryName, collator))
                .collect(Collectors.toList());
    }

    /**
     * [2.3] Xem chi tiết một giao dịch theo ID + kiểm tra quyền sở hữu.
     */
    @Override
    @Transactional(readOnly = true)
    public TransactionResponse getTransactionById(Long transactionId, Integer accountId) {
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy giao dịch với ID: " + transactionId));

        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xem giao dịch này.");
        }
        return transactionMapper.toDto(transaction);
    }

    // =================================================================================
    // 3. TÌM KIẾM & BÁO CÁO (SEARCH & REPORT)
    // =================================================================================

    /**
     * [3.1] Tìm kiếm giao dịch nâng cao theo nhiều tiêu chí.
     */
    @Override
    @Transactional(readOnly = true)
    public List<TransactionResponse> searchTransactions(Integer accountId,
                                                        TransactionSearchRequest request) {
        Specification<Transaction> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("account").get("id"), accountId));
            predicates.add(cb.equal(root.get("deleted"), false)); // Chỉ lấy giao dịch chưa bị xóa mềm

            // Wallet / SavingGoal (giữ nguyên logic cũ)
            if (request.walletId() != null) {
                predicates.add(cb.equal(root.get("wallet").get("id"), request.walletId()));
            } else if (request.savingGoalId() != null) {
                predicates.add(cb.equal(root.get("savingGoal").get("id"), request.savingGoalId()));
            }

            // Note (tìm kiếm tương đối)
            if (request.note() != null) {
                predicates.add(cb.like(root.get("note"), "%" + request.note() + "%"));
            }

            // WithPerson (tìm kiếm tương đối)
            if (request.withPerson() != null) {
                predicates.add(cb.like(root.get("withPerson"), "%" + request.withPerson() + "%"));
            }

            // Khoảng thời gian
            if (request.startDate() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("transDate"), request.startDate()));
            }
            if (request.endDate() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("transDate"), request.endDate()));
            }

            // Danh mục
            if (request.categoryIds() != null && !request.categoryIds().isEmpty()) {
                predicates.add(root.get("category").get("id").in(request.categoryIds()));
            }

            // Khoảng tiền
            if (request.minAmount() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("amount"), request.minAmount()));
            }
            if (request.maxAmount() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("amount"), request.maxAmount()));
            }

            // Sắp xếp theo ngày giảm dần
            if (query != null) {
                query.orderBy(cb.desc(root.get("transDate")));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };

        return transactionMapper.toDtoList(transactionRepository.findAll(spec));
    }

    /**
     * [3.2] Lấy báo cáo tài chính tổng quan (Số dư đầu/cuối kỳ, Tổng thu/chi).
     */
    @Override
    @Transactional(readOnly = true)
    public TransactionReportResponse getTransactionReport(Integer accountId,
                                                          LocalDateTime startDate, LocalDateTime endDate,
                                                          Integer walletId, Integer savingGoalId) {

        // Bước 1: Tính số dư đầu kỳ
        BigDecimal balanceBefore = transactionRepository.calculateBalanceBeforeDate(
                accountId, startDate, walletId, savingGoalId);
        BigDecimal openingBalance = balanceBefore != null ? balanceBefore : BigDecimal.ZERO;

        // Bước 2: Lấy giao dịch trong kỳ
        List<Transaction> transactions = transactionRepository.findAllByFilters(
                accountId, startDate, endDate, walletId, savingGoalId);

        // Bước 3: Tính các chỉ số
        BigDecimal totalIncome  = BigDecimal.ZERO;
        BigDecimal totalExpense = BigDecimal.ZERO;
        int debtCount = 0;
        int loanCount = 0;

        List<Integer> debtCategoryIds = List.of(
                SystemCategory.DEBT_BORROWING.getId(),
                SystemCategory.DEBT_REPAYMENT.getId()
        );
        List<Integer> loanCategoryIds = List.of(
                SystemCategory.DEBT_LENDING.getId(),
                SystemCategory.DEBT_COLLECTION.getId()
        );

        for (Transaction t : transactions) {
            Integer ctgId = t.getCategory().getId();

            // Đếm giao dịch liên quan nợ/vay
            if (debtCategoryIds.contains(ctgId)
                    || (t.getDebt() != null && !t.getDebt().getDebtType())) {
                debtCount++;
            } else if (loanCategoryIds.contains(ctgId)
                    || (t.getDebt() != null && t.getDebt().getDebtType())) {
                loanCount++;
            }

            // Chỉ tính thu/chi cho giao dịch reportable=true
            if (!Boolean.TRUE.equals(t.getReportable())) continue;
            if (Boolean.TRUE.equals(t.getCategory().getCtgType())) {
                totalIncome = totalIncome.add(t.getAmount());
            } else {
                totalExpense = totalExpense.add(t.getAmount());
            }
        }

        // Bước 4: Tính số dư cuối kỳ
        BigDecimal netIncome      = totalIncome.subtract(totalExpense);
        BigDecimal closingBalance = openingBalance.add(netIncome);

        return TransactionReportResponse.builder()
                .openingBalance(openingBalance)
                .closingBalance(closingBalance)
                .totalIncome(totalIncome)
                .totalExpense(totalExpense)
                .netIncome(netIncome)
                .debtTransactionCount(debtCount)
                .loanTransactionCount(loanCount)
                .build();
    }

    /**
     * [3.3] Lấy báo cáo chi tiết theo danh mục (biểu đồ tròn).
     * Tính thêm dailyAverage và percentage.
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryReportDTO> getCategoryReport(Integer accountId,
                                                     LocalDateTime startDate, LocalDateTime endDate,
                                                     Integer walletId, Integer savingGoalId) {

        List<CategoryReportDTO> reports = transactionRepository.getReportByCategory(
                accountId, startDate, endDate, walletId, savingGoalId);

        // Tính tổng Thu và Chi riêng để tính % đúng theo từng loại
        BigDecimal totalIncome = reports.stream()
                .filter(r -> Boolean.TRUE.equals(r.categoryType()))
                .map(CategoryReportDTO::totalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalExpense = reports.stream()
                .filter(r -> Boolean.FALSE.equals(r.categoryType()))
                .map(CategoryReportDTO::totalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        long daysBetween = Math.max(1,
                ChronoUnit.DAYS.between(startDate.toLocalDate(), endDate.toLocalDate()) + 1);

        return reports.stream().map(report -> {
            // Tính trung bình ngày
            BigDecimal dailyAvg = report.totalAmount()
                    .divide(BigDecimal.valueOf(daysBetween), 2, RoundingMode.HALF_UP);

            // Tính % theo đúng loại (Thu/Chi tách nhau)
            BigDecimal totalForType = Boolean.TRUE.equals(report.categoryType())
                    ? totalIncome : totalExpense;
            double percentage = totalForType.compareTo(BigDecimal.ZERO) == 0 ? 0.0
                    : report.totalAmount()
                    .divide(totalForType, 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100))
                    .doubleValue();

            return new CategoryReportDTO(
                    report.categoryName(), report.totalAmount(),
                    report.categoryType(), report.categoryIcon(),
                    dailyAvg, percentage);
        }).collect(Collectors.toList());
    }

    /**
     * [3.4] Lấy báo cáo tài chính toàn diện — All-in-One Dashboard.
     */
    @Override
    @Transactional(readOnly = true)
    public FinancialReportResponse getFinancialReport(Integer accountId,
                                                      LocalDateTime startDate, LocalDateTime endDate,
                                                      Integer walletId, Integer savingGoalId) {

        // Bước 1: Tổng quan (Summary)
        TransactionReportResponse summary = this.getTransactionReport(
                accountId, startDate, endDate, walletId, savingGoalId);

        // Bước 2: Tổng tài sản hiện tại
        BigDecimal totalBalance = walletRepository.sumBalanceByAccountIdAndReportableTrue(accountId);
        if (totalBalance == null) totalBalance = BigDecimal.ZERO;

        // Bước 3: Báo cáo theo danh mục + phân loại Thu/Chi
        List<CategoryReportDTO> allCategories = this.getCategoryReport(
                accountId, startDate, endDate, walletId, savingGoalId);

        List<CategoryReportDTO> expenseCategories = allCategories.stream()
                .filter(cat -> Boolean.FALSE.equals(cat.categoryType()))
                .collect(Collectors.toList());
        List<CategoryReportDTO> incomeCategories = allCategories.stream()
                .filter(cat -> Boolean.TRUE.equals(cat.categoryType()))
                .collect(Collectors.toList());

        return FinancialReportResponse.builder()
                .summary(summary)
                .totalCurrentBalance(totalBalance)
                .expenseCategories(expenseCategories)
                .incomeCategories(incomeCategories)
                .build();
    }

    /**
     * [3.5] Lấy dữ liệu xu hướng thu/chi theo từng ngày (biểu đồ cột/đường).
     */
    @Override
    @Transactional(readOnly = true)
    public List<DailyTrendDTO> getDailyTrend(Integer accountId,
                                             LocalDateTime startDate, LocalDateTime endDate,
                                             Integer walletId, Integer savingGoalId, Integer categoryId) {
        return transactionRepository.getDailyTrend(
                accountId, startDate, endDate, walletId, savingGoalId, categoryId);
    }

    // =================================================================================
    // 4. CẬP NHẬT & XÓA (UPDATE & DELETE)
    // =================================================================================

    /**
     * [4.1] Cập nhật một giao dịch đã có.
     * Bước 1 — Tìm và kiểm tra quyền.
     * Bước 2 — Hoàn tiền giao dịch cũ (revert balance).
     * Bước 3 — Cập nhật thông tin cơ bản.
     * Bước 4 — Xử lý thay đổi Danh mục.
     * Bước 5 — Xử lý thay đổi Sự kiện.
     * Bước 6 — Apply số dư mới.
     */
    @Override
    @Transactional
    public TransactionResponse updateTransaction(Long transactionId,
                                                 TransactionRequest request,
                                                 Integer accountId) {
        // Bước 1: Tìm và kiểm tra quyền
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy giao dịch với ID: " + transactionId));
        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sửa giao dịch này.");
        }
        if (request.walletId() != null && request.goalId() != null) {
            throw new IllegalArgumentException(
                    "Giao dịch chỉ được thuộc về Ví hoặc Mục tiêu, không được thuộc về cả hai.");
        }

        // [FIX-DEBT-WALLET-LOCK-UPDATE] Kiểm tra: Nếu giao dịch thuộc debt (có debt link HOẶC có category debt)
        // → Không được phép đổi ví hoặc savinggoal
        // BUG CŨ: chỉ check transaction.getDebt() != null — bỏ sót trường hợp Thu nợ/Trả nợ
        //         tạo không chọn debt (debtId=null) → transaction.debt=null → check bị bypass
        // FIX MỚI: check thêm categoryId thuộc nhóm debt (19=Cho vay, 20=Đi vay, 21=Thu nợ, 22=Trả nợ)
        Integer currentCatId = transaction.getCategory().getId();
        boolean isDebtRelatedCategory = currentCatId.equals(SystemCategory.DEBT_LENDING.getId())
                || currentCatId.equals(SystemCategory.DEBT_BORROWING.getId())
                || currentCatId.equals(SystemCategory.DEBT_COLLECTION.getId())
                || currentCatId.equals(SystemCategory.DEBT_REPAYMENT.getId());

        if (transaction.getDebt() != null || isDebtRelatedCategory) {
            boolean walletChanged = (request.walletId() != null
                    && !request.walletId().equals(transaction.getWallet() != null ? transaction.getWallet().getId() : null))
                    || (request.walletId() == null && transaction.getWallet() != null);

            boolean goalChanged = (request.goalId() != null
                    && !request.goalId().equals(transaction.getSavingGoal() != null ? transaction.getSavingGoal().getId() : null))
                    || (request.goalId() == null && transaction.getSavingGoal() != null);

            if (walletChanged || goalChanged) {
                throw new IllegalArgumentException(
                        "Không thể đổi ví hoặc mục tiêu cho giao dịch vay/nợ. Ví/Mục tiêu đã được xác định bởi khoản nợ liên kết.");
            }
        }

        // Bước 2: Hoàn tiền giao dịch cũ
        revertTransactionBalance(transaction);

        // Bước 3: Cập nhật thông tin cơ bản
        transaction.setAmount(request.amount());
        transaction.setNote(request.note());
        transaction.setTransDate(request.transDate());
        transaction.setWithPerson(request.withPerson());
        transaction.setReportable(request.reportable());

        // Cập nhật sourceType nếu có
        if (request.sourceType() != null && request.sourceType() >= 1 && request.sourceType() <= 5) {
            transaction.setSourceType(request.sourceType());
        }

        // Cập nhật AI Conversation nếu có
        if (request.aiChatId() != null) {
            AIConversation aiConversation = aiConversationRepository.findById(request.aiChatId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Cuộc hội thoại AI không tồn tại với ID: " + request.aiChatId()));
            transaction.setAiConversation(aiConversation);
        } else {
            transaction.setAiConversation(null);
        }

        // Bước 4: Xử lý thay đổi Danh mục
        Category targetCategory = transaction.getCategory();
        if (!Objects.equals(transaction.getCategory().getId(), request.categoryId())) {
            targetCategory = categoryRepository.findById(request.categoryId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Danh mục mới không tồn tại với ID: " + request.categoryId()));
            if (targetCategory.getAccount() != null
                    && !targetCategory.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Bạn không có quyền sử dụng danh mục mới này.");
            }
            transaction.setCategory(targetCategory);
        }

        // Bước 5: Xử lý thay đổi Sự kiện
        if (request.eventId() != null) {
            if (transaction.getEvent() == null
                    || !Objects.equals(transaction.getEvent().getId(), request.eventId())) {
                Event newEvent = eventRepository.findById(request.eventId())
                        .orElseThrow(() -> new IllegalArgumentException(
                                "Sự kiện mới không tồn tại với ID: " + request.eventId()));
                if (!newEvent.getAccount().getId().equals(accountId)) {
                    throw new SecurityException("Bạn không có quyền sử dụng sự kiện mới này.");
                }
                transaction.setEvent(newEvent);
            }
        } else {
            transaction.setEvent(null);
        }

        // Bước 6: Apply số dư mới
        if (request.goalId() != null) {
            processSavingGoalTransaction(transaction, request.goalId(), accountId,
                    targetCategory.getCtgType(), request.amount());
        } else if (request.walletId() != null) {
            processWalletTransaction(transaction, request.walletId(), accountId,
                    targetCategory.getCtgType(), request.amount());
        } else {
            throw new IllegalArgumentException(
                    "Vui lòng chọn Ví hoặc Mục tiêu tiết kiệm khi cập nhật.");
        }

        Transaction updated = transactionRepository.save(transaction);
        if (updated.getDebt() != null) {
            Account account = accountRepository.findById(accountId).orElse(null);
            debtCalculationService.recalculateDebt(updated.getDebt().getId(), account);
        }

        return transactionMapper.toDto(updated);
    }

    /**
     * [4.2] Xóa mềm một giao dịch.
     * Bước 1 — Tìm và kiểm tra quyền.
     * Bước 2 — Hoàn tiền vào Ví/Mục tiêu.
     * Bước 3 — Soft delete giao dịch.
     * Bước 4 — Tính lại Debt nếu có.
     */
    @Override
    @Transactional
    public void deleteTransaction(Long transactionId, Integer accountId) {
        // Bước 1: Tìm và kiểm tra quyền
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy giao dịch với ID: " + transactionId));
        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xóa giao dịch này.");
        }

        // Lưu debtId và categoryId TRƯỚC khi xóa mềm
        Integer debtId     = transaction.getDebt()     != null ? transaction.getDebt().getId()     : null;
        Integer categoryId = transaction.getCategory() != null ? transaction.getCategory().getId() : null;

        // Bước 2: Hoàn tiền
        revertTransactionBalance(transaction);

        // Bước 3: Soft delete (thay vì xóa cứng)
        transaction.setDeleted(true);
        transaction.setDeletedAt(LocalDateTime.now());
        transactionRepository.save(transaction);

        // Bước 4: Xử lý Debt SAU khi xóa mềm
        if (debtId != null) {
            Account account = accountRepository.findById(accountId).orElse(null);

            // Nếu giao dịch vừa xóa là giao dịch GỐC (Cho vay / Đi vay):
            //   → Kiểm tra xem còn giao dịch gốc nào khác không.
            //   → Nếu không còn → xóa mềm Debt (deleteDebtIfOrphaned).
            //   → Nếu còn         → chỉ tính lại số liệu (recalculateDebt).
            // Nếu là giao dịch trả/thu nợ: chỉ cần tính lại.
            boolean isOriginTransaction = categoryId != null && (
                    categoryId.equals(SystemCategory.DEBT_LENDING.getId()) ||
                    categoryId.equals(SystemCategory.DEBT_BORROWING.getId()));

            if (isOriginTransaction) {
                debtCalculationService.deleteDebtIfOrphaned(debtId);
            }

            debtCalculationService.recalculateDebt(debtId, account);
        }
    }

    // =================================================================================
    // 5. HỖ TRỢ HÀM (HELPER)
    // =================================================================================

    /**
     * [5.1] Hoàn tiền về ví hoặc mục tiêu khi xóa/gộp giao dịch.
     * - Một giao dịch chỉ thuộc về 1 loại: Ví HOẶC Mục tiêu (không phải cả 2).
     * - Xác định hướng hoàn tiền dựa trên category.ctgType.
     */
    @Override
    @Transactional
    public void revertTransactionBalance(Transaction transaction) {
        if (transaction == null) {
            return;
        }

        // 1. Xác định hướng hoàn tiền (tùy vào loại danh mục: thu hay chi)
        // Dùng Boolean.TRUE.equals() để xử lý null-safe (tránh NullPointerException)
        boolean isIncome = transaction.getCategory() != null
                && Boolean.TRUE.equals(transaction.getCategory().getCtgType());

        // 2. Nếu giao dịch liên kết Ví
        if (transaction.getWallet() != null) {
            Wallet wallet = transaction.getWallet();

            // 3. Hoàn tiền về ví
            if (isIncome) {
                // Giao dịch là THU → hoàn tiền = trừ số dư ví
                wallet.setBalance(wallet.getBalance().subtract(transaction.getAmount()));
            } else {
                // Giao dịch là CHI → hoàn tiền = cộng số dư ví
                wallet.setBalance(wallet.getBalance().add(transaction.getAmount()));
            }

            walletRepository.save(wallet);
        }
        // 4. ELSE IF: Nếu giao dịch liên kết Mục tiêu tiết kiệm (không xử lý cả Wallet+Goal)
        else if (transaction.getSavingGoal() != null) {
            SavingGoal goal = transaction.getSavingGoal();

            // 5. Hoàn tiền về mục tiêu (linh hoạt theo isIncome)
            if (isIncome) {
                // Nạp vào mục tiêu (THU) → hoàn tiền = trừ số tiền mục tiêu
                goal.setCurrentAmount(goal.getCurrentAmount().subtract(transaction.getAmount()));
            } else {
                // Rút từ mục tiêu (CHI) → hoàn tiền = cộng số tiền mục tiêu
                goal.setCurrentAmount(goal.getCurrentAmount().add(transaction.getAmount()));
            }

            savingGoalRepository.save(goal);
        }
    }

    /**
     * [5.2] Xử lý giao dịch liên quan đến Ví.
     * Bước 1 — Tìm ví và kiểm tra quyền sở hữu.
     * Bước 2 — Gán ví vào transaction.
     * Bước 3 — Cộng/trừ số dư.
     * Bước 4 — Gửi thông báo nếu số dư âm.
     */
    private void processWalletTransaction(Transaction transaction, Integer walletId,
                                          Integer accountId, Boolean isIncome, BigDecimal amount) {
        // Bước 1: Tìm ví
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Ví không tồn tại với ID: " + walletId));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng ví này.");
        }

        // Bước 2: Gán ví
        transaction.setWallet(wallet);
        transaction.setSavingGoal(null); // Đảm bảo không link với SavingGoal

        // Bước 3: Cộng/trừ số dư
        if (Boolean.TRUE.equals(isIncome)) {
            wallet.setBalance(wallet.getBalance().add(amount));      // Thu → Cộng
        } else {
            // 3.1 Kiểm tra số dư trước khi trừ (Chặn đứng nếu là Chi tiêu và số dư không đủ)
            if (wallet.getBalance().compareTo(amount) < 0) {
                throw new IllegalArgumentException(
                        String.format("Số dư trong ví '%s' không đủ để thực hiện giao dịch này (Hiện có: %s đ).",
                                wallet.getWalletName(), wallet.getBalance().toPlainString()));
            }
            wallet.setBalance(wallet.getBalance().subtract(amount)); // Chi → Trừ
        }
        walletRepository.save(wallet);

        // Bước 4: Cảnh báo nếu số dư âm (chỉ khi ví bật notified)
        if (Boolean.TRUE.equals(wallet.getNotified())
                && wallet.getBalance().compareTo(BigDecimal.ZERO) < 0) {
            NotificationContent msg = NotificationMessages.walletNegativeBalance(
                    wallet.getWalletName(), wallet.getBalance());
            notificationService.createNotification(
                    wallet.getAccount(),
                    msg.title(), msg.content(),
                    NotificationType.WALLETS,
                    Long.valueOf(wallet.getId()),
                    null
            );
        }
    }

    /**
     * [5.3] Xử lý giao dịch liên quan đến Mục tiêu tiết kiệm.
     * Bước 1 — Tìm mục tiêu và kiểm tra quyền.
     * Bước 2 — Gán mục tiêu vào transaction.
     * Bước 3 — Cộng/trừ currentAmount.
     */
    private void processSavingGoalTransaction(Transaction transaction, Integer goalId,
                                              Integer accountId, Boolean isIncome, BigDecimal amount) {
        // Bước 1: Tìm mục tiêu
        SavingGoal goal = savingGoalRepository.findById(goalId)
                .orElseThrow(() -> new IllegalArgumentException("Mục tiêu tiết kiệm không tồn tại."));
        if (!goal.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng mục tiêu này.");
        }

        // Bước 2: Gán mục tiêu
        transaction.setSavingGoal(goal);
        transaction.setWallet(null); // Đảm bảo không link với Wallet

        // Bước 3: Cộng/trừ currentAmount
        if (Boolean.TRUE.equals(isIncome)) {
            // Kiểm tra: Số tiền nạp vào không được vượt quá target_amount
            BigDecimal newAmount = goal.getCurrentAmount().add(amount);
            if (newAmount.compareTo(goal.getTargetAmount()) > 0) {
                throw new IllegalArgumentException(
                        String.format("Số tiền nạp vào mục tiêu '%s' sẽ vượt quá số tiền mục tiêu (Mục tiêu: %s đ, Hiện có: %s đ).",
                                goal.getGoalName(), goal.getTargetAmount().toPlainString(), goal.getCurrentAmount().toPlainString()));
            }
            goal.setCurrentAmount(newAmount); // Nạp → Cộng
        } else {
            // 3.1 Kiểm tra số dư Mục tiêu (Rút tiền không được vượt quá số hiện có)
            if (goal.getCurrentAmount().compareTo(amount) < 0) {
                throw new IllegalArgumentException(
                        String.format("Số dư trong mục tiêu '%s' không đủ (Hiện có: %s đ).",
                                goal.getGoalName(), goal.getCurrentAmount().toPlainString()));
            }
            goal.setCurrentAmount(goal.getCurrentAmount().subtract(amount)); // Rút → Trừ
        }
        savingGoalRepository.save(goal);
    }

    /**
     * [5.4] Xử lý logic Sổ nợ khi tạo giao dịch.
     * - Đi vay / Cho vay → INSERT Debt mới hoặc gắn vào Debt cũ.
     * - Trả nợ / Thu nợ  → Gắn debtId nếu user chọn (optional).
     */
    private void processDebtTransaction(Transaction transaction, TransactionRequest request,
                                        Account currentUser, Integer categoryId, Integer accountId) {
        boolean isBorrowing  = categoryId.equals(SystemCategory.DEBT_BORROWING.getId());  // Đi vay
        boolean isLending    = categoryId.equals(SystemCategory.DEBT_LENDING.getId());    // Cho vay
        boolean isRepayment  = categoryId.equals(SystemCategory.DEBT_REPAYMENT.getId());  // Trả nợ
        boolean isCollection = categoryId.equals(SystemCategory.DEBT_COLLECTION.getId()); // Thu nợ

        if (isBorrowing || isLending) {
            if (request.debtId() != null) {
                // Vay thêm vào khoản nợ cũ — gắn debt_id, recalculate sẽ tính lại
                Debt debt = debtRepository.findByIdAndAccount_Id(request.debtId(), accountId)
                        .orElseThrow(() -> new IllegalArgumentException(
                                "Khoản nợ không tồn tại hoặc không có quyền."));
                transaction.setDebt(debt);
            } else {
                // Tạo khoản nợ mới — bắt buộc có personName
                if (request.personName() == null || request.personName().isBlank()) {
                    throw new IllegalArgumentException(isBorrowing
                            ? "Vui lòng nhập tên người cho vay."
                            : "Vui lòng nhập tên người vay.");
                }
                Debt debt = Debt.builder()
                        .account(currentUser)
                        .debtType(isLending)          // false=Đi vay/CẦN TRẢ, true=Cho vay/CẦN THU
                        .personName(request.personName())
                        .totalAmount(request.amount())  // recalculate sẽ tính lại
                        .remainAmount(request.amount()) // remain = total khi mới tạo
                        .dueDate(request.dueDate())
                        .note(request.note())
                        .finished(false)
                        .build();
                transaction.setDebt(debtRepository.save(debt));
            }
        } else if (isRepayment || isCollection) {
            // Trả nợ / Thu nợ — gắn debtId nếu user chọn (null = giao dịch bình thường)
            if (request.debtId() != null) {
                Debt debt = debtRepository.findByIdAndAccount_Id(request.debtId(), accountId)
                        .orElseThrow(() -> new IllegalArgumentException(
                                "Khoản nợ không tồn tại hoặc không có quyền."));
                // Validate that the payment type matches the debtType:
                // - Debt.debtType == true  => Cho vay / CẦN THU  (should use Thu nợ)
                // - Debt.debtType == false => Đi vay / CẦN TRẢ  (should use Trả nợ)
                if (isCollection && Boolean.FALSE.equals(debt.getDebtType())) {
                    throw new SecurityException("Khoản nợ này là 'Cần trả' nên không thể thực hiện 'Thu nợ'.");
                }
                if (isRepayment && Boolean.TRUE.equals(debt.getDebtType())) {
                    throw new SecurityException("Khoản nợ này là 'Cần thu' nên không thể thực hiện 'Trả nợ'.");
                }
                transaction.setDebt(debt);
            }
        }
    }

    /**
     * [5.5] TRIỂN KHAI: Hoàn tiền hàng loạt trực tiếp dưới Database.
     * Logic: Quét toàn bộ tTransactions -> Phân loại Thu/Chi -> SUM amount theo từng Wallet/Goal
     * -> Cập nhật trực tiếp vào tWallets và tSavingGoals.
     * * ƯU ĐIỂM:
     * - Hiệu năng cực cao (1 lệnh SQL thay vì vòng lặp N lệnh).
     * - An toàn tuyệt đối với cơ chế quản lý Entity của Hibernate (No Detached/Transient error).
     */
    @Override
    @Transactional
    public void revertAllTransactionBalancesForCategoryNoFetch(Integer categoryId, Integer accountId) {
        // Cập nhật lại số dư ví (Xử lý cả 2 loại danh mục: Thu và Chi)
        transactionRepository.revertWalletBalanceForIncomeCategory(categoryId, accountId);
        transactionRepository.revertWalletBalanceForExpenseCategory(categoryId, accountId);

        // Cập nhật lại số tiền mục tiêu tiết kiệm
        transactionRepository.revertGoalBalanceForIncomeCategory(categoryId, accountId);
        transactionRepository.revertGoalBalanceForExpenseCategory(categoryId, accountId);
    }

    /**
     * [5.6] Phát hiện giao dịch bất thường và tạo cảnh báo cho User + tất cả Admin.
     *
     * Kịch bản 1 — Vượt ngưỡng: khoản CHI > 50.000.000đ.
     * Kịch bản 2 — Spam       : cùng số tiền xuất hiện ≥ 3 lần trong 10 phút (theo created_at).
     * Kịch bản 3 — Lặp ngày   : cùng số tiền, cùng khung giờ ±30 phút, trong 3 ngày liên tiếp.
     *
     * Luồng khi phát hiện:
     *   A. Tạo ticket tContactRequests (SUSPICIOUS_TX | URGENT | PENDING) → lấy ticket.id
     *   B. Notify User   — related_id = giao dịch bất thường (để Flutter navigate đến chi tiết giao dịch)
     *   C. Notify N Admin — related_id = ticket.id (để Admin navigate đến ticket cần xử lý)
     *
     * CHÚ Ý: Chỉ kiểm tra kịch bản đầu tiên phát hiện được → 1 ticket / 1 giao dịch.
     */
    private void checkSuspiciousTransaction(Transaction tx, Account currentUser, Integer accountId) {
        String reason = null;
        BigDecimal amount  = tx.getAmount();
        LocalDateTime transDate = tx.getTransDate();
        boolean isExpense  = Boolean.FALSE.equals(tx.getCategory().getCtgType());

        // [KB-1] Vượt ngưỡng: chỉ áp dụng cho khoản CHI > 50.000.000đ
        if (reason == null && isExpense && amount.compareTo(new BigDecimal("50000000")) > 0) {
            reason = String.format(
                    "Giao dịch chi %s vượt ngưỡng cảnh báo 50.000.000đ. Không phải bạn thực hiện? Liên hệ hỗ trợ ngay.",
                    CurrencyUtils.formatVND(amount));
        }

        // [KB-2] Spam: cùng số tiền ≥ 3 lần trong 10 phút (dùng created_at để tránh false-positive)
        if (reason == null) {
            LocalDateTime tenMinsAgo = LocalDateTime.now().minusMinutes(10);
            long spamCount = transactionRepository.countSameAmountCreatedAfter(accountId, amount, tenMinsAgo);
            if (spamCount >= 3) {
                reason = String.format(
                        "Phát hiện %d giao dịch %s xuất hiện liên tiếp trong vòng 10 phút. Vui lòng kiểm tra tài khoản.",
                        spamCount, CurrencyUtils.formatVND(amount));
            }
        }

        // [KB-3] Lặp ngày: cùng số tiền, cùng khung giờ ±30 phút, trong 3 ngày liên tiếp
        if (reason == null) {
            int currentHour   = transDate.getHour();
            int currentMinute = transDate.getMinute();

            // Xây dựng cửa sổ thời gian hôm qua và hôm kia (±30 phút cùng giờ phút)
            LocalDateTime baseYesterday   = transDate.minusDays(1)
                    .withHour(currentHour).withMinute(currentMinute).withSecond(0).withNano(0);
            LocalDateTime base2DaysAgo    = transDate.minusDays(2)
                    .withHour(currentHour).withMinute(currentMinute).withSecond(0).withNano(0);

            boolean hadYesterday  = transactionRepository.existsSameAmountInWindow(
                    accountId, amount, baseYesterday.minusMinutes(30), baseYesterday.plusMinutes(30));
            boolean had2DaysAgo   = transactionRepository.existsSameAmountInWindow(
                    accountId, amount, base2DaysAgo.minusMinutes(30),  base2DaysAgo.plusMinutes(30));

            if (hadYesterday && had2DaysAgo) {
                reason = String.format(
                        "Phát hiện giao dịch %s xuất hiện vào cùng khung giờ %dh trong 3 ngày liên tiếp. Vui lòng kiểm tra tài khoản.",
                        CurrencyUtils.formatVND(amount), currentHour);
            }
        }

        // Không phát hiện bất thường → kết thúc
        if (reason == null) return;

        // [A] Tạo 1 ticket duy nhất (SUSPICIOUS_TX | URGENT | PENDING)
        ContactRequest ticket = contactRequestService.createSuspiciousRequest(accountId, reason);

        // [B] Thông báo USER — related_id = id giao dịch để Flutter navigate đến chi tiết
        // Dùng TRANSACTION (type=1) vì related_id = tTransactions.id → Flutter mở chi tiết giao dịch đó
        notificationService.createNotification(
                currentUser,
                "⚠️ Cảnh báo giao dịch bất thường",
                reason,
                NotificationType.TRANSACTION,
                tx.getId(),
                null
        );

        // [C] Thông báo TẤT CẢ ADMIN — related_id = ticket.id để Admin navigate đến ContactRequest
        String displayName = currentUser.getFullname() != null
                ? currentUser.getFullname() : currentUser.getAccEmail();
        String displayPhone = currentUser.getAccPhone() != null
                ? currentUser.getAccPhone() : "N/A";
        String adminContent = String.format(
                "%s (%s): %s Ticket #%d.",
                displayName, displayPhone, reason, ticket.getId());

        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");
        for (Account admin : admins) {
            notificationService.createNotification(
                    admin,
                    "🚨 [URGENT] Giao dịch bất thường cần xử lý",
                    adminContent,
                    NotificationType.SYSTEM,
                    ticket.getId().longValue(),
                    null
            );
        }
    }
}
