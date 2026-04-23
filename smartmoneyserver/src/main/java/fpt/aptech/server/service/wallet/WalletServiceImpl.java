package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.budget.BudgetResponse;
import fpt.aptech.server.dto.wallet.TotalBalanceResponse;
import fpt.aptech.server.dto.wallet.TransferRequest;
import fpt.aptech.server.dto.wallet.TransferResponse;
import fpt.aptech.server.dto.wallet.WalletDeletePreviewResponse;
import fpt.aptech.server.dto.wallet.WalletRequest;
import fpt.aptech.server.dto.wallet.WalletResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class WalletServiceImpl implements WalletService {

    private final WalletRepository walletRepository;
    private final AccountRepository accountRepository;
    private final CurrencyRepository currencyRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;
    private final SavingGoalRepository savingGoalRepository;
    private final BudgetRepository budgetRepository; // Cascade soft delete
    private final PlannedTransactionRepository plannedTransactionRepository; // Cascade soft delete
    private final DebtRepository debtRepository; // Cascade soft delete
    private final EventRepository eventRepository; // Cascade soft delete
    private final NotificationService notificationService; // Inject để cảnh báo số dư thấp

    // Ngưỡng số dư thấp mặc định (500,000đ) — gửi cảnh báo khi số dư xuống dưới mức
    // này
    // Lưu ý: Đây là ngưỡng chung, tương lai có thể config riêng theo từng ví
    private static final BigDecimal LOW_BALANCE_THRESHOLD = new BigDecimal("500000");

    // =================================================================================
    // 1. TẠO MỚI (CREATE)
    // =================================================================================

    /**
     * [1.1] Tạo ví mới.
     * Bước 1 — Validate dữ liệu đầu vào.
     * Bước 2 — Tạo Entity Wallet và lưu vào DB.
     * Bước 3 — Tạo giao dịch khởi tạo nếu có số dư ban đầu (reportable=false).
     */
    @Override
    @Transactional
    public WalletResponse createWallet(Integer accountId, WalletRequest request) {

        if (accountId == null) {
            throw new IllegalArgumentException("Invalid account");
        }

        // ===== Normalize =====
        String walletName = request.getWalletName() != null
                ? request.getWalletName().trim()
                : null;

        String currencyCode = request.getCurrencyCode() != null
                ? request.getCurrencyCode().trim().toUpperCase()
                : null;

        BigDecimal initBalance = request.getBalance() != null
                ? request.getBalance()
                : BigDecimal.ZERO;

        // ===== Validate =====
        if (walletName == null || walletName.isBlank()) {
            throw new IllegalArgumentException("Invalid wallet name");
        }

        if (currencyCode == null || currencyCode.isBlank()) {
            throw new IllegalArgumentException("Invalid currency");
        }

        if (initBalance.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Balance cannot be negative");
        }

        boolean exists = walletRepository
                .existsByAccountIdAndWalletNameIgnoreCase(accountId, walletName);

        if (exists) {
            throw new IllegalArgumentException("Wallet name already exists");
        }

        // ===== Fetch =====
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Account does not exist"));

        Currency currency = currencyRepository.findById(currencyCode)
                .orElseThrow(() -> new IllegalArgumentException("Currency does not exist"));

        // ===== Create =====
        Wallet wallet = new Wallet();
        wallet.setAccount(account);
        wallet.setCurrency(currency);
        wallet.setWalletName(walletName);
        wallet.setBalance(initBalance);
        wallet.setNotified(request.getNotified() != null ? request.getNotified() : true);
        wallet.setReportable(request.getReportable() != null ? request.getReportable() : true);
        wallet.setGoalImageUrl(request.getGoalImageUrl());

        Wallet savedWallet = walletRepository.save(wallet);

        // ===== Init Transaction =====
        if (initBalance.compareTo(BigDecimal.ZERO) > 0) {
            Category category = categoryRepository.findById(SystemCategory.INCOME_OTHER.getId())
                    .orElseThrow(() -> new IllegalArgumentException("System category 'Other Income' not found"));

            Transaction initTransaction = Transaction.builder()
                    .account(account)
                    .wallet(savedWallet)
                    .category(category)
                    .amount(initBalance)
                    .note("Initial balance")
                    .reportable(false) // Không tính vào báo cáo
                    .transDate(LocalDateTime.now())
                    .build();

            transactionRepository.save(initTransaction);
        }

        return mapToResponse(savedWallet);
    }

    // =================================================================================
    // 2. CẬP NHẬT (UPDATE)
    // =================================================================================

    /**
     * [2.1] Cập nhật thông tin ví.
     * - So sánh số dư cũ và mới để tạo giao dịch "Điều chỉnh số dư" nếu cần.
     * - Cập nhật các thông tin khác của ví.
     */
    @Override
    @Transactional
    public WalletResponse updateWallet(Integer accountId, Integer walletId, WalletRequest request) {
        // Bước 1: Tìm ví và kiểm tra quyền
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Wallet does not exist"));

        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("You do not have permission to edit this wallet");
        }

        // Bước 2: Xử lý điều chỉnh số dư
        // ===== walletName =====
        if (request.getWalletName() != null) {
            String name = request.getWalletName().trim();

            if (name.isBlank()) {
                throw new IllegalArgumentException("Invalid wallet name");
            }


            wallet.setWalletName(name);
        }

        // ===== balance =====
        if (request.getBalance() != null) {

            BigDecimal newBalance = request.getBalance();

            if (newBalance.compareTo(BigDecimal.ZERO) < 0) {
                throw new IllegalArgumentException("Balance cannot be negative");
            }

            BigDecimal currentBalance = wallet.getBalance();
            int comparison = newBalance.compareTo(currentBalance);

            if (comparison != 0) { // Chỉ tạo giao dịch khi số dư thay đổi

                BigDecimal adjustmentAmount = newBalance.subtract(currentBalance).abs();
                boolean isIncome = comparison > 0; // true nếu số dư mới > số dư cũ (THU)

                 // Xác định category tương ứng
                SystemCategory systemCategory = isIncome
                        ? SystemCategory.INCOME_OTHER
                        : SystemCategory.OTHER_EXPENSE;
                
                Category category = categoryRepository.findById(systemCategory.getId())
                        .orElseThrow(() -> new IllegalStateException("System category not found: " + systemCategory.name()));

                // Tạo giao dịch điều chỉnh
                Transaction adjustmentTransaction = Transaction.builder()
                        .account(wallet.getAccount())
                        .wallet(wallet)
                        .category(category)
                        .amount(adjustmentAmount)
                        .note("Balance adjustment")
                        .reportable(false)  //Giao dịch điều chỉnh không tính vào báo cáo
                        .transDate(LocalDateTime.now())
                        .build();

                transactionRepository.save(adjustmentTransaction);

                // Cập nhật số dư mới cho ví
                wallet.setBalance(newBalance);

                // ===== 🔥 LOW BALANCE ALERT =====
                // [B] Thông báo USER — related_id = wallet.getId() để Flutter navigate đến ví
                // Dùng WALLETS (type=6) vì liên quan ví + số dư
                if (wallet.getNotified()
                        && newBalance.compareTo(LOW_BALANCE_THRESHOLD) < 0) {

                    // [NOTE] Build notification message using NotificationMessages.walletLowBalance()
                    // Parameters:
                    //   - wallet.getWalletName()        : Name of wallet (e.g., "Ví tiền mặt")
                    //   - newBalance                    : Current balance that's below threshold (e.g., 300,000đ)
                    //   - LOW_BALANCE_THRESHOLD         : Threshold constant (500,000đ)
                    NotificationContent msg = NotificationMessages
                            .walletLowBalance(wallet.getWalletName(), newBalance, LOW_BALANCE_THRESHOLD);

                    // Send notification using template values from NotificationMessages
                    notificationService.createNotification(
                            wallet.getAccount(),
                            msg.title(),
                            msg.content(),
                            NotificationType.WALLETS,
                            wallet.getId().longValue(),
                            null);
                }
            }
        }

        // Bước 3: Cập nhật các thông tin khác
        // ===== currency =====
        if (request.getCurrencyCode() != null) {
            Currency currency = currencyRepository.findById(request.getCurrencyCode())            
                    .orElseThrow(() -> new IllegalArgumentException("Currency does not exist"));

            wallet.setCurrency(currency);
        }

        // ===== others =====
        if (request.getNotified() != null) {
            wallet.setNotified(request.getNotified());
        }

        if (request.getReportable() != null) {
            wallet.setReportable(request.getReportable());
        }

        if (request.getGoalImageUrl() != null) {
            wallet.setGoalImageUrl(request.getGoalImageUrl());
        }

        walletRepository.save(wallet);
        return mapToResponse(wallet);
    }

    // =================================================================================
    // 3. CHUYỂN TIỀN (TRANSFER MONEY)
    // =================================================================================

    /**
     * [3.1] Chuyển tiền từ ví này sang ví khác.
     * Bước 1 — Validate dữ liệu đầu vào.
     * Bước 2 — Tìm ví nguồn và ví đích, kiểm tra quyền sở hữu.
     * Bước 3 — Kiểm tra số dư ví nguồn đủ để chuyển.
     * Bước 4 — Cập nhật số dư cả 2 ví.
     * Bước 5 — Tạo giao dịch ghi nhận chuyển tiền.
     */
    @Override
    @Transactional
    public TransferResponse transferMoney(Integer accountId, TransferRequest request) {
        // ===== Validate =====
        if (request.getFromWalletId().equals(request.getToWalletId())) {
            throw new IllegalArgumentException("Source wallet and destination wallet cannot be the same");
        }

        // ===== Fetch ví nguồn =====
        Wallet fromWallet = walletRepository.findById(request.getFromWalletId())
                .orElseThrow(() -> new IllegalArgumentException("Source wallet does not exist"));
        if (!fromWallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("You do not have permission to transfer money from this wallet");
        }

        // ===== Fetch ví đích =====
        Wallet toWallet = walletRepository.findById(request.getToWalletId())
                .orElseThrow(() -> new IllegalArgumentException("Destination wallet does not exist"));
        if (!toWallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("You do not have permission to transfer money to this wallet");
        }

        // ===== Kiểm tra số dư =====
        if (fromWallet.getBalance().compareTo(request.getAmount()) < 0) {
            throw new IllegalArgumentException("Insufficient balance in source wallet");
        }

        // ===== Kiểm tra currency =====
        if (!fromWallet.getCurrency().getCurrencyCode().equals(toWallet.getCurrency().getCurrencyCode())) {
            throw new IllegalArgumentException("Only transfers between wallets with the same currency are supported");
        }

        // ===== Cập nhật số dư =====
        fromWallet.setBalance(fromWallet.getBalance().subtract(request.getAmount()));
        toWallet.setBalance(toWallet.getBalance().add(request.getAmount()));

        walletRepository.save(fromWallet);
        walletRepository.save(toWallet);

        // ===== Tạo giao dịch ghi nhận chuyển tiền =====
        Category transferCategory = categoryRepository.findById(SystemCategory.OTHER_EXPENSE.getId())
                .orElseThrow(() -> new IllegalArgumentException("System category not found"));

        // Giao dịch từ ví nguồn (chi)
        Transaction fromTransaction = Transaction.builder()
                .account(fromWallet.getAccount())
                .wallet(fromWallet)
                .category(transferCategory)
                .amount(request.getAmount())
                .note(request.getNote() != null ? request.getNote() : "Transfer to wallet " + toWallet.getWalletName())
                .reportable(true)
                .transDate(LocalDateTime.now())
                .build();

        transactionRepository.save(fromTransaction);

        // Giao dịch vào ví đích (thu)
        Category incomeCategory = categoryRepository.findById(SystemCategory.INCOME_OTHER.getId())
                .orElseThrow(() -> new IllegalArgumentException("System category not found"));

        Transaction toTransaction = Transaction.builder()
                .account(toWallet.getAccount())
                .wallet(toWallet)
                .category(incomeCategory)
                .amount(request.getAmount())
                .note(request.getNote() != null ? request.getNote() : "Receive money from wallet " + fromWallet.getWalletName())
                .reportable(true)
                .transDate(LocalDateTime.now())
                .build();

        transactionRepository.save(toTransaction);

        // ===== Xóa ví nguồn sau khi chuyển tiền =====
        // Bước 1: Update wallet_id của tất cả transactions thuộc ví nguồn sang ví đích
        transactionRepository.updateWalletIdByFromWalletId(request.getFromWalletId(), request.getToWalletId());

        // Bước 2: Update wallet_id của budgets, plannedTransactions thuộc ví nguồn sang ví đích
        // (Event và Debt không liên kết trực tiếp với ví, nên không cần update)
        budgetRepository.updateWalletIdByFromWalletId(request.getFromWalletId(), request.getToWalletId());
        plannedTransactionRepository.updateWalletIdByFromWalletId(request.getFromWalletId(), request.getToWalletId());

        // Bước 3: Soft delete ví nguồn (chỉ xóa ví, không xóa transactions, budgets, plannedTransactions)
        fromWallet.setDeleted(true);
        fromWallet.setDeletedAt(LocalDateTime.now());
        walletRepository.save(fromWallet);

        return TransferResponse.builder()
                .message("Transfer money and delete wallet successfully")
                .transferredAmount(request.getAmount())
                .fromWalletBalance(fromWallet.getBalance())
                .toWalletBalance(toWallet.getBalance())
                .build();
    }

    // =================================================================================
    // 4. PREVIEW XÓA VÍ (DELETE PREVIEW)
    // =================================================================================

    /**
     * [4.1] Lấy thông tin preview trước khi xóa ví.
     * Bước 1 — Tìm ví và kiểm tra quyền sở hữu.
     * Bước 2 — Lấy danh sách ngân sách liên quan.
     * Bước 3 — Đếm số lượng giao dịch thuộc ví.
     * Bước 4 — Lấy danh sách ví khác của user.
     * Bước 5 — Trả về thông tin tổng hợp.
     */
    @Override
    public WalletDeletePreviewResponse getDeletePreview(Integer accountId, Integer walletId) {
        // ===== Tìm ví và kiểm tra quyền =====
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Wallet does not exist"));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("You do not have permission to view this wallet");
        }

        // ===== Lấy danh sách ngân sách liên quan =====
        List<Budget> relatedBudgets = budgetRepository.findByWalletId(walletId);
        List<BudgetResponse> budgetResponses = relatedBudgets.stream()
                .map(this::mapToSimpleBudgetResponse)
                .collect(Collectors.toList());

        // ===== Đếm số lượng giao dịch thuộc ví =====
        long transactionCount = transactionRepository.countByWalletId(walletId);

        // ===== Lấy danh sách ví khác của user =====
        List<Wallet> otherWallets = walletRepository.findByAccountId(accountId)
                .stream()
                .filter(w -> !w.getId().equals(walletId))
                .collect(Collectors.toList());
        List<WalletResponse> otherWalletResponses = otherWallets.stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());

        return WalletDeletePreviewResponse.builder()
                .wallet(mapToResponse(wallet))
                .relatedBudgets(budgetResponses)
                .transactionCount(transactionCount)
                .otherWallets(otherWalletResponses)
                .currentBalance(wallet.getBalance())
                .build();
    }

    /**
     * [4.2] Chuyển đổi Budget Entity → BudgetResponse DTO (phiên bản đơn giản).
     * Chỉ lấy thông tin cơ bản, không tính toán chi tiêu.
     */
    private BudgetResponse mapToSimpleBudgetResponse(Budget budget) {
        return BudgetResponse.builder()
                .id(budget.getId())
                .amount(budget.getAmount())
                .beginDate(budget.getBeginDate())
                .endDate(budget.getEndDate())
                .walletId(budget.getWallet() != null ? budget.getWallet().getId() : null)
                .walletName(budget.getWallet() != null ? budget.getWallet().getWalletName() : null)
                .allCategories(budget.getAllCategories())
                .repeating(budget.getRepeating())
                .budgetType(budget.getBudgetType())
                .build();
    }

    // =================================================================================
    // 5. XÓA (DELETE)
    // =================================================================================

    /**
     * [5.1] Xóa mềm ví.
     * Bước 1 — Tìm ví và kiểm tra quyền sở hữu.
     * Bước 2 — Kiểm tra số dư ví (phải = 0 mới được xóa).
     * Bước 3 — Soft delete cascade (ví là NGUỒN TIỀN → xóa toàn bộ dữ liệu liên
     * kết):
     * • Transactions thuộc wallet_id
     * • Budgets thuộc wallet_id
     * • PlannedTransactions thuộc wallet_id
     * • Debts có giao dịch trong ví này (qua subquery tTransactions)
     * • Events có giao dịch trong ví này (qua subquery tTransactions)
     * Bước 4 — Soft delete chính ví.
     */
    @Override
    @Transactional
    public void deleteWallet(Integer accountId, Integer walletId) {
        // Bước 1: Tìm ví và kiểm tra quyền
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Wallet does not exist"));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("You do not have permission to delete this wallet");
        }

        // Bước 2: Kiểm tra số dư ví (phải = 0 mới được xóa)
        if (wallet.getBalance().compareTo(BigDecimal.ZERO) > 0) {
            throw new IllegalArgumentException(
                    "Wallet still has money. Please transfer money to another wallet before deleting. " +
                    "Current balance: " + wallet.getBalance() + " " + wallet.getCurrency().getCurrencyCode()
            );
        }

        // Bước 3: Soft delete cascade — xóa mềm các bản ghi liên kết
        transactionRepository.softDeleteAllByWalletId(walletId); // Giao dịch thuộc ví
        budgetRepository.softDeleteAllByWalletId(walletId); // Ngân sách thuộc ví
        plannedTransactionRepository.softDeleteAllByWalletId(walletId); // Giao dịch định kỳ/hóa đơn thuộc ví
        debtRepository.softDeleteAllByWalletId(walletId); // Khoản nợ có giao dịch thuộc ví
        eventRepository.softDeleteAllByWalletId(walletId); // Sự kiện có giao dịch thuộc ví

        // Bước 4: Soft delete chính ví
        wallet.setDeleted(true);
        wallet.setDeletedAt(LocalDateTime.now());
        walletRepository.save(wallet);
    }

    // =================================================================================
    // 4. LẤY CHI TIẾT & DANH SÁCH (READ)
    // =================================================================================

    /**
     * [4.1] Lấy chi tiết một ví theo ID + kiểm tra quyền sở hữu.
     */
    @Override
    public WalletResponse getWalletById(Integer accountId, Integer walletId) {
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Wallet does not exist"));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("You do not have permission to view this wallet");
        }
        return mapToResponse(wallet);
    }

    /**
     * [4.2] Lấy tất cả ví của user, hỗ trợ tìm kiếm theo tên.
     */
    @Override
    public List<WalletResponse> getAllWallets(Integer accountId, String search) {
        List<Wallet> wallets = (search != null && !search.isBlank())
                ? walletRepository.findByAccountIdAndWalletNameContainingIgnoreCase(accountId, search)
                : walletRepository.findByAccountId(accountId);

        return wallets.stream().map(this::mapToResponse).toList();
    }

    // =================================================================================
    // 5. TỔNG SỐ DƯ (TOTAL BALANCE)
    // =================================================================================

    /**
     * [5.1] Tính tổng tài sản của user = Tổng các ví + Tổng mục tiêu tiết kiệm.
     * Chỉ tính các ví và mục tiêu có reportable=true.
     */
    @Override
    public TotalBalanceResponse getTotalBalance(Integer accountId) {
        // Tổng tiền trong các Ví (reportable=true)
        BigDecimal walletsTotal = walletRepository.sumBalanceByAccountIdAndReportableTrue(accountId);
        if (walletsTotal == null)
            walletsTotal = BigDecimal.ZERO;

        // Tổng tiền trong các Mục tiêu tiết kiệm (reportable=true, không CANCELLED)
        BigDecimal savingsTotal = savingGoalRepository.sumActiveCurrentAmountByAccountId(accountId);
        if (savingsTotal == null)
            savingsTotal = BigDecimal.ZERO;

        return new TotalBalanceResponse(walletsTotal.add(savingsTotal));
    }

    // =================================================================================
    // 6. PRIVATE HELPERS
    // =================================================================================

    /**
     * [6.1] Chuyển đổi Wallet Entity → WalletResponse DTO.
     */
    private WalletResponse mapToResponse(Wallet wallet) {
        return WalletResponse.builder()
                .id(wallet.getId())
                .walletName(wallet.getWalletName())
                .balance(wallet.getBalance())
                .currencyCode(wallet.getCurrency().getCurrencyCode())
                .notified(wallet.getNotified())
                .reportable(wallet.getReportable())
                .goalImageUrl(wallet.getGoalImageUrl())
                .build();
    }
}
