package fpt.aptech.server.service.transaction;

import fpt.aptech.server.dto.transaction.report.DailyTrendDTO;
import fpt.aptech.server.dto.transaction.report.FinancialReportResponse;
import fpt.aptech.server.dto.transaction.report.CategoryReportDTO;
import fpt.aptech.server.dto.transaction.report.TransactionReportResponse;
import fpt.aptech.server.dto.transaction.request.TransactionRequest;
import fpt.aptech.server.dto.transaction.request.TransactionSearchRequest;
import fpt.aptech.server.dto.transaction.view.CategoryTransactionGroup;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Event;
import fpt.aptech.server.entity.SavingGoal;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.mapper.transaction.TransactionMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.EventRepository;
import fpt.aptech.server.repos.SavingGoalRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.WalletRepository;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.utils.date.DateUtils;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
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

    private final TransactionRepository transactionRepository;
    private final AccountRepository accountRepository;
    private final WalletRepository walletRepository;
    private final CategoryRepository categoryRepository;
    private final EventRepository eventRepository;
    private final SavingGoalRepository savingGoalRepository;
    private final NotificationService notificationService;
    private final TransactionMapper transactionMapper;

    // ================= 1. TẠO MỚI (CREATE) =================

    /**
     * Tạo một giao dịch mới (Chi tiêu, Thu nhập, Chuyển khoản).
     * Đây là một trong những phương thức cốt lõi của hệ thống.
     */
    @Override
    @Transactional
    public TransactionResponse createTransaction(TransactionRequest request, Integer accountId) {
        // 1. Lấy thông tin User hiện tại
        Account currentUser = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));

        // 2. Map dữ liệu từ DTO sang Entity
        Transaction transaction = transactionMapper.toEntity(request);
        transaction.setAccount(currentUser);

        // 3. Validate: Giao dịch phải thuộc về một Ví hoặc một Mục tiêu tiết kiệm
        if (request.walletId() == null && request.goalId() == null) {
            throw new IllegalArgumentException("Vui lòng chọn Ví hoặc Mục tiêu tiết kiệm.");
        }
        // Validate: Không được thuộc về cả hai
        if (request.walletId() != null && request.goalId() != null) {
            throw new IllegalArgumentException("Giao dịch chỉ được thuộc về Ví hoặc Mục tiêu, không được thuộc về cả hai.");
        }

        // 4. Validate và lấy thông tin Danh mục (Category)
        Category category = categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> new IllegalArgumentException("Danh mục không tồn tại với ID: " + request.categoryId()));

        // Kiểm tra quyền sở hữu danh mục (nếu là danh mục của riêng user)
        if (category.getAccount() != null && !category.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng danh mục này.");
        }
        transaction.setCategory(category);

        // 5. Xử lý logic nghiệp vụ cho nguồn tiền (Wallet hoặc SavingGoal) và cập nhật số dư
        if (request.goalId() != null) {
            processSavingGoalTransaction(transaction, request.goalId(), accountId, category.getCtgType(), request.amount());
        } else {
            processWalletTransaction(transaction, request.walletId(), accountId, category.getCtgType(), request.amount());
        }

        // 6. Validate và lấy thông tin Sự kiện (Event) nếu có
        if (request.eventId() != null) {
            Event event = eventRepository.findById(request.eventId())
                    .orElseThrow(() -> new IllegalArgumentException("Sự kiện không tồn tại với ID: " + request.eventId()));

            if (!event.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Bạn không có quyền sử dụng sự kiện này.");
            }
            transaction.setEvent(event);
        }

        // 7. Lưu giao dịch vào Database
        Transaction savedTransaction = transactionRepository.save(transaction);

        // 8. Nếu người dùng có đặt ngày nhắc nhở, tạo một thông báo
        if (request.reminderDate() != null) {
            notificationService.createNotification(
                    currentUser,
                    "Nhắc nhở giao dịch",
                    "Bạn có nhắc nhở cho giao dịch: " + (request.note() != null ? request.note() : "Không có ghi chú"),
                    NotificationType.REMINDER, // Dùng Enum để code rõ ràng hơn
                    savedTransaction.getId(),
                    request.reminderDate()
            );
        }

        return transactionMapper.toDto(savedTransaction);
    }

    // ================= 2. XEM & CHI TIẾT (READ) =================

    /**
     * Lấy danh sách giao dịch cho màn hình Nhật ký, đã được gom nhóm theo ngày.
     */
    @Override
    @Transactional(readOnly = true)
    public List<DailyTransactionGroup> getJournalTransactions(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId) {
        List<Transaction> transactions = transactionRepository.findAllByFilters(
                accountId, startDate, endDate, walletId, savingGoalId);

        // Gom nhóm các giao dịch theo ngày
        Map<LocalDate, List<Transaction>> groupedByDate = transactions.stream()
                .collect(Collectors.groupingBy(t -> t.getTransDate().toLocalDate()));

        // Chuyển đổi Map sang List DTO để trả về
        return groupedByDate.entrySet().stream()
                .map(entry -> {
                    LocalDate date = entry.getKey();
                    List<Transaction> transInDay = entry.getValue();

                    // Tính tổng thu/chi ròng của ngày đó
                    BigDecimal netAmount = transInDay.stream()
                            .map(t -> t.getCategory().getCtgType() ? t.getAmount() : t.getAmount().negate())
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    return DailyTransactionGroup.builder()
                            .date(date)
                            .displayDateLabel(DateUtils.formatDisplayDate(date)) // Gọi từ DateUtils
                            .netAmount(netAmount)
                            .transactions(transactionMapper.toDtoList(transInDay))
                            .build();
                })
                .sorted(Comparator.comparing(DailyTransactionGroup::date).reversed()) // Sắp xếp ngày mới nhất lên đầu
                .collect(Collectors.toList());
    }

    /**
     * Lấy danh sách giao dịch đã gom nhóm theo Danh mục.
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryTransactionGroup> getGroupedTransactions(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId) {
        List<Transaction> transactions = transactionRepository.findAllByFilters(
                accountId, startDate, endDate, walletId, savingGoalId);

        // Gom nhóm các giao dịch theo đối tượng Category
        Map<Category, List<Transaction>> groupedByCat = transactions.stream()
                .collect(Collectors.groupingBy(Transaction::getCategory));

        Collator collator = Collator.getInstance(new Locale("vi", "VN")); // Dùng để sắp xếp tiếng Việt

        return groupedByCat.entrySet().stream()
                .map(entry -> {
                    Category category = entry.getKey();
                    List<Transaction> transInGroup = entry.getValue();

                    // Tính tổng tiền cho nhóm danh mục này
                    BigDecimal totalAmount = transInGroup.stream()
                            .map(Transaction::getAmount)
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    return CategoryTransactionGroup.builder()
                            .categoryName(category.getCtgName())
                            .categoryIconUrl(category.getCtgIconUrl())
                            .categoryType(category.getCtgType())
                            .totalAmount(totalAmount)
                            .transactionCount(transInGroup.size())
                            .transactions(transactionMapper.toDtoList(transInGroup))
                            .build();
                })
                .sorted(Comparator.comparing(CategoryTransactionGroup::categoryName, collator)) // Sắp xếp theo tên danh mục
                .collect(Collectors.toList());
    }

    /**
     * Xem chi tiết một giao dịch theo ID.
     */
    @Override
    @Transactional(readOnly = true)
    public TransactionResponse getTransactionById(Long transactionId, Integer accountId) {
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy giao dịch với ID: " + transactionId));

        // Kiểm tra quyền sở hữu
        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xem giao dịch này.");
        }

        return transactionMapper.toDto(transaction);
    }

    // ================= 3. TÌM KIẾM & BÁO CÁO (SEARCH & REPORT) =================

    /**
     * Tìm kiếm giao dịch nâng cao theo nhiều tiêu chí.
     */
    @Override
    @Transactional(readOnly = true)
    public List<TransactionResponse> searchTransactions(Integer accountId, TransactionSearchRequest request) {
        Specification<Transaction> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            predicates.add(cb.equal(root.get("account").get("id"), accountId));

            if (request.walletId() != null) {
                predicates.add(cb.equal(root.get("wallet").get("id"), request.walletId()));
            } else if (request.savingGoalId() != null) {
                predicates.add(cb.equal(root.get("savingGoal").get("id"), request.savingGoalId()));
            }
            // ... các điều kiện lọc khác
            // ...
            return cb.and(predicates.toArray(new Predicate[0]));
        };

        List<Transaction> transactions = transactionRepository.findAll(spec);
        return transactionMapper.toDtoList(transactions);
    }

    /**
     * Lấy báo cáo tài chính tổng quan (Số dư đầu/cuối, Tổng thu/chi).
     */
    @Override
    @Transactional(readOnly = true)
    public TransactionReportResponse getTransactionReport(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId) {
        // 1. Tính số dư đầu kỳ: tổng thu/chi của tất cả giao dịch TRƯỚC ngày bắt đầu
        BigDecimal balanceChangeBefore = transactionRepository.calculateBalanceBeforeDate(accountId, startDate, walletId, savingGoalId);
        BigDecimal openingBalance = (balanceChangeBefore != null) ? balanceChangeBefore : BigDecimal.ZERO;

        // 2. Lấy tất cả giao dịch TRONG khoảng thời gian đã chọn
        List<Transaction> transactions = transactionRepository.findAllByFilters(
                accountId, startDate, endDate, walletId, savingGoalId);

        // 3. Tính toán các chỉ số
        BigDecimal totalIncome = BigDecimal.ZERO;
        BigDecimal totalExpense = BigDecimal.ZERO;
        int debtCount = 0;
        int loanCount = 0;

        // Dùng Enum để định nghĩa các ID danh mục liên quan đến Nợ/Vay
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

            // Đếm số lượng giao dịch liên quan đến Nợ/Vay
            if (debtCategoryIds.contains(ctgId) || (t.getDebt() != null && !t.getDebt().getDebtType())) {
                debtCount++;
            } else if (loanCategoryIds.contains(ctgId) || (t.getDebt() != null && t.getDebt().getDebtType())) {
                loanCount++;
            }

            // Chỉ tính tổng Thu/Chi cho các giao dịch được đánh dấu là "tính vào báo cáo"
            if (!Boolean.TRUE.equals(t.getReportable())) continue;

            if (Boolean.TRUE.equals(t.getCategory().getCtgType())) {
                totalIncome = totalIncome.add(t.getAmount());
            } else {
                totalExpense = totalExpense.add(t.getAmount());
            }
        }

        // 4. Tính các chỉ số cuối cùng
        BigDecimal netIncome = totalIncome.subtract(totalExpense);
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
     * Lấy báo cáo chi tiết theo danh mục (dùng cho biểu đồ tròn).
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryReportDTO> getCategoryReport(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId) {
        List<CategoryReportDTO> reports = transactionRepository.getReportByCategory(
                accountId, startDate, endDate, walletId, savingGoalId);

        // Tính tổng riêng Thu và Chi để tính % đúng theo từng loại
        BigDecimal totalIncome = reports.stream()
                .filter(r -> Boolean.TRUE.equals(r.categoryType()))
                .map(CategoryReportDTO::totalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal totalExpense = reports.stream()
                .filter(r -> Boolean.FALSE.equals(r.categoryType()))
                .map(CategoryReportDTO::totalAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        long daysBetween = ChronoUnit.DAYS.between(startDate.toLocalDate(), endDate.toLocalDate()) + 1;
        if (daysBetween <= 0) daysBetween = 1;

        long finalDays = daysBetween;
        return reports.stream().map(report -> {
            // Tính trung bình ngày
            BigDecimal dailyAvg = report.totalAmount()
                    .divide(BigDecimal.valueOf(finalDays), 2, RoundingMode.HALF_UP);

            // Tính % theo đúng loại (Thu tính trên tổng Thu, Chi tính trên tổng Chi)
            BigDecimal totalForType = Boolean.TRUE.equals(report.categoryType()) ? totalIncome : totalExpense;
            double percentage = totalForType.compareTo(BigDecimal.ZERO) == 0 ? 0.0
                    : report.totalAmount()
                    .divide(totalForType, 4, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100))
                    .doubleValue();

            return new CategoryReportDTO(
                    report.categoryName(),
                    report.totalAmount(),
                    report.categoryType(),
                    report.categoryIcon(),
                    dailyAvg,
                    percentage
            );
        }).collect(Collectors.toList());
    }

    /**
     * Lấy báo cáo tài chính toàn diện (All-in-One Dashboard).
     */
    @Override
    @Transactional(readOnly = true)
    public FinancialReportResponse getFinancialReport(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId) {
        // 1. Tổng quan (Summary)
        TransactionReportResponse summary = this.getTransactionReport(
                accountId, startDate, endDate, walletId, savingGoalId);

        // 2. Tổng tài sản hiện tại
        BigDecimal totalBalance = walletRepository.sumBalanceByAccountIdAndReportableTrue(accountId);
        if (totalBalance == null) totalBalance = BigDecimal.ZERO;

        // 3. Báo cáo theo danh mục
        List<CategoryReportDTO> allCategories = this.getCategoryReport(
                accountId, startDate, endDate, walletId, savingGoalId);

        // 4. Phân loại Thu / Chi
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
     * Lấy dữ liệu xu hướng thu/chi theo từng ngày (dùng cho biểu đồ cột/đường).
     */
    @Override
    @Transactional(readOnly = true)
    public List<DailyTrendDTO> getDailyTrend(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId, Integer categoryId) {
        return transactionRepository.getDailyTrend(accountId, startDate, endDate, walletId, savingGoalId, categoryId);
    }

    // ================= 4. CẬP NHẬT & XÓA (UPDATE & DELETE) =================

    /**
     * Cập nhật một giao dịch đã có.
     */
    @Override
    @Transactional
    public TransactionResponse updateTransaction(Long transactionId, TransactionRequest request, Integer accountId) {
        // 1. Tìm giao dịch và kiểm tra quyền
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy giao dịch với ID: " + transactionId));

        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sửa giao dịch này.");
        }

        // Validate: Không được thuộc về cả hai
        if (request.walletId() != null && request.goalId() != null) {
            throw new IllegalArgumentException("Giao dịch chỉ được thuộc về Ví hoặc Mục tiêu, không được thuộc về cả hai.");
        }

        // 2. Hoàn tiền giao dịch cũ
        revertTransactionBalance(transaction);

        // 3. Cập nhật thông tin cơ bản
        transaction.setAmount(request.amount());
        transaction.setNote(request.note());
        transaction.setTransDate(request.transDate());
        transaction.setWithPerson(request.withPerson());
        transaction.setReportable(request.reportable());

        // 4. Xử lý thay đổi Danh mục
        Category targetCategory = transaction.getCategory();
        if (!Objects.equals(transaction.getCategory().getId(), request.categoryId())) {
            targetCategory = categoryRepository.findById(request.categoryId())
                    .orElseThrow(() -> new IllegalArgumentException("Danh mục mới không tồn tại với ID: " + request.categoryId()));

            if (targetCategory.getAccount() != null && !targetCategory.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Bạn không có quyền sử dụng danh mục mới này.");
            }
            transaction.setCategory(targetCategory);
        }

        // 5. Xử lý thay đổi Sự kiện
        if (request.eventId() != null) {
            if (transaction.getEvent() == null || !Objects.equals(transaction.getEvent().getId(), request.eventId())) {
                Event newEvent = eventRepository.findById(request.eventId())
                        .orElseThrow(() -> new IllegalArgumentException("Sự kiện mới không tồn tại với ID: " + request.eventId()));

                if (!newEvent.getAccount().getId().equals(accountId)) {
                    throw new SecurityException("Bạn không có quyền sử dụng sự kiện mới này.");
                }
                transaction.setEvent(newEvent);
            }
        } else {
            transaction.setEvent(null);
        }

        // 6. Cập nhật số dư mới
        if (request.goalId() != null) {
            processSavingGoalTransaction(transaction, request.goalId(), accountId, targetCategory.getCtgType(), request.amount());
        } else if (request.walletId() != null) {
            processWalletTransaction(transaction, request.walletId(), accountId, targetCategory.getCtgType(), request.amount());
        } else {
            throw new IllegalArgumentException("Vui lòng chọn Ví hoặc Mục tiêu tiết kiệm khi cập nhật.");
        }

        Transaction updatedTransaction = transactionRepository.save(transaction);
        return transactionMapper.toDto(updatedTransaction);
    }

    /**
     * Xóa (mềm) một giao dịch.
     */
    @Override
    @Transactional
    public void deleteTransaction(Long transactionId, Integer accountId) {
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy giao dịch với ID: " + transactionId));

        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xóa giao dịch này.");
        }

        // Hoàn tiền và xóa mềm
        revertTransactionBalance(transaction);
        transactionRepository.delete(transaction); // Dùng delete() thay vì save()
    }

    // ================= 5. PHƯƠNG THỨC PHỤ (PRIVATE HELPERS) =================

    /**
     * Xử lý logic giao dịch liên quan đến Ví (Wallet).
     * - Tìm ví, check quyền.
     * - Cộng/Trừ số dư ví.
     */
    private void processWalletTransaction(Transaction transaction, Integer walletId, Integer accountId, Boolean isIncome, BigDecimal amount) {
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại với ID: " + walletId));

        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng ví này.");
        }
        transaction.setWallet(wallet);
        transaction.setSavingGoal(null); // Đảm bảo không link với SavingGoal

        if (Boolean.TRUE.equals(isIncome)) {
            // Nếu là Thu -> Cộng tiền vào ví
            wallet.setBalance(wallet.getBalance().add(amount));
        } else {
            // Nếu là Chi -> Trừ tiền khỏi ví
            wallet.setBalance(wallet.getBalance().subtract(amount));
        }
        walletRepository.save(wallet);
    }

    /**
     * Xử lý logic giao dịch liên quan đến Mục tiêu tiết kiệm (SavingGoal).
     * - Tìm mục tiêu, check quyền.
     * - Cộng/Trừ số tiền hiện tại của mục tiêu.
     */
    private void processSavingGoalTransaction(Transaction transaction, Integer goalId, Integer accountId, Boolean isIncome, BigDecimal amount) {
        SavingGoal goal = savingGoalRepository.findById(goalId)
                .orElseThrow(() -> new IllegalArgumentException("Mục tiêu tiết kiệm không tồn tại."));

        if (!goal.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng mục tiêu này.");
        }
        transaction.setSavingGoal(goal);
        transaction.setWallet(null); // Đảm bảo không link với Wallet

        if (Boolean.TRUE.equals(isIncome)) {
            // Nếu là Thu (Nạp tiền) -> Cộng vào mục tiêu
            goal.setCurrentAmount(goal.getCurrentAmount().add(amount));
        } else {
            // Nếu là Chi (Rút tiền) -> Trừ khỏi mục tiêu
            goal.setCurrentAmount(goal.getCurrentAmount().subtract(amount));
        }
        savingGoalRepository.save(goal);
    }

    /**
     * Hoàn lại số tiền của giao dịch cũ vào Ví hoặc Mục tiêu tiết kiệm.
     * - Dùng khi Update (trước khi apply cái mới) hoặc Delete.
     */
    private void revertTransactionBalance(Transaction transaction) {
        BigDecimal amount = transaction.getAmount();
        Boolean isIncome = transaction.getCategory().getCtgType();

        if (transaction.getWallet() != null) {
            Wallet wallet = transaction.getWallet();
            if (Boolean.TRUE.equals(isIncome)) {
                // Nếu là Thu -> Trừ lại tiền (Hoàn tác cộng)
                wallet.setBalance(wallet.getBalance().subtract(amount));
            } else {
                // Nếu là Chi -> Cộng lại tiền (Hoàn tác trừ)
                wallet.setBalance(wallet.getBalance().add(amount));
            }
            walletRepository.save(wallet);
        } else if (transaction.getSavingGoal() != null) {
            SavingGoal goal = transaction.getSavingGoal();
            if (Boolean.TRUE.equals(isIncome)) {
                // Nếu là Thu -> Trừ lại tiền
                goal.setCurrentAmount(goal.getCurrentAmount().subtract(amount));
            } else {
                // Nếu là Chi -> Cộng lại tiền
                goal.setCurrentAmount(goal.getCurrentAmount().add(amount));
            }
            savingGoalRepository.save(goal);
        }
    }
}