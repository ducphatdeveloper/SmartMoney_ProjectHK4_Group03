package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.wallet.TotalBalanceResponse;
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
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class WalletServiceImpl implements WalletService {

    private final WalletRepository      walletRepository;
    private final AccountRepository     accountRepository;
    private final CurrencyRepository    currencyRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryRepository    categoryRepository;
    private final SavingGoalRepository  savingGoalRepository;
    private final NotificationService   notificationService; // Inject để cảnh báo số dư thấp

    // Ngưỡng số dư thấp mặc định (500,000đ) — gửi cảnh báo khi số dư xuống dưới mức này
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
        // Bước 1: Validate
        if (request.getWalletName() == null || request.getWalletName().isBlank()) {
            throw new IllegalArgumentException("Tên ví không được để trống");
        }
        if (request.getCurrencyCode() == null || request.getCurrencyCode().isBlank()) {
            throw new IllegalArgumentException("Mã tiền tệ không được để trống");
        }

        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));
        Currency currency = currencyRepository.findById(request.getCurrencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Loại tiền tệ không tồn tại"));

        BigDecimal initBalance = request.getBalance() != null
                ? request.getBalance() : BigDecimal.ZERO;

        // Bước 2: Tạo Wallet
        Wallet wallet = new Wallet();
        wallet.setAccount(account);
        wallet.setCurrency(currency);
        wallet.setWalletName(request.getWalletName());
        wallet.setBalance(initBalance);
        wallet.setNotified(request.getNotified() != null ? request.getNotified() : true);
        wallet.setReportable(request.getReportable() != null ? request.getReportable() : true);
        wallet.setGoalImageUrl(request.getGoalImageUrl());

        Wallet savedWallet = walletRepository.save(wallet);

        // Bước 3: Tạo giao dịch khởi tạo để số dư đầu kỳ chính xác
        // reportable=false → không tính vào báo cáo thu/chi thông thường
        if (initBalance.compareTo(BigDecimal.ZERO) > 0) {
            Category category = categoryRepository.findById(SystemCategory.INCOME_OTHER.getId())
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Không tìm thấy danh mục hệ thống 'Thu nhập khác'"));

            Transaction initTransaction = Transaction.builder()
                    .account(account)
                    .wallet(savedWallet)
                    .category(category)
                    .amount(initBalance)
                    .note("Số dư ban đầu")
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
     * Bước 1 — Tìm ví và kiểm tra quyền sở hữu.
     * Bước 2 — Cập nhật các trường được phép sửa.
     *
     * Lưu ý: balance được update thẳng ở đây (không tạo transaction điều chỉnh).
     * Nếu sau này muốn đảm bảo toàn vẹn dữ liệu, cần tạo transaction điều chỉnh tương ứng.
     */
    @Override
    public WalletResponse updateWallet(Integer accountId, Integer walletId, WalletRequest request) {
        // Bước 1: Tìm ví và kiểm tra quyền
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sửa ví này");
        }

        // Bước 2: Cập nhật các trường
        if (request.getWalletName() != null)  wallet.setWalletName(request.getWalletName());
        if (request.getBalance()    != null)  wallet.setBalance(request.getBalance());
        if (request.getNotified()   != null)  wallet.setNotified(request.getNotified());
        if (request.getReportable() != null)  wallet.setReportable(request.getReportable());
        if (request.getGoalImageUrl() != null) wallet.setGoalImageUrl(request.getGoalImageUrl());
        if (request.getCurrencyCode() != null) {
            Currency currency = currencyRepository.findById(request.getCurrencyCode())
                    .orElseThrow(() -> new IllegalArgumentException("Loại tiền tệ không tồn tại"));
            wallet.setCurrency(currency);
        }

        walletRepository.save(wallet);
        return mapToResponse(wallet);
    }

    // =================================================================================
    // 3. XÓA (DELETE)
    // =================================================================================

    /**
     * [3.1] Xóa ví.
     * Bước 1 — Tìm ví và kiểm tra quyền sở hữu.
     * Bước 2 — Xóa ví. DB ON DELETE CASCADE tự xóa: Transactions, Budgets, PlannedTransactions liên kết.
     */
    @Override
    public void deleteWallet(Integer accountId, Integer walletId) {
        // Bước 1: Tìm ví và kiểm tra quyền
        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xóa ví này");
        }

        // Bước 2: Xóa ví
        walletRepository.delete(wallet);
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
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xem ví này");
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
        if (walletsTotal == null) walletsTotal = BigDecimal.ZERO;

        // Tổng tiền trong các Mục tiêu tiết kiệm (reportable=true, không CANCELLED)
        BigDecimal savingsTotal = savingGoalRepository.sumCurrentAmountByAccountId(accountId);
        if (savingsTotal == null) savingsTotal = BigDecimal.ZERO;

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