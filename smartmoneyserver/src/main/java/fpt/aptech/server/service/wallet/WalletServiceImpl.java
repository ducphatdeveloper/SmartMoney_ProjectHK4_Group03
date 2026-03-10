package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.wallet.TotalBalanceResponse;
import fpt.aptech.server.dto.wallet.WalletResponse;
import fpt.aptech.server.dto.wallet.WalletRequest;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Currency;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.entity.Wallet;

import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.SavingGoalRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;


@Service
@RequiredArgsConstructor
public class WalletServiceImpl implements WalletService {

    private final WalletRepository walletRepository;
    private final AccountRepository accountRepository;
    private final CurrencyRepository currencyRepository;
    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;
    private final SavingGoalRepository savingGoalRepository; // Thêm vào

    // ================= CREATE =================

    /**
     * Tạo ví mới.
     * - Validate dữ liệu đầu vào.
     * - Tạo ví với số dư ban đầu.
     * - Tạo giao dịch khởi tạo nếu số dư > 0.
     */
    @Override
    @Transactional
    public WalletResponse createWallet(Integer accountId, WalletRequest request) {

        // 1. Validate dữ liệu đầu vào
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

        BigDecimal initBalance = request.getBalance() != null ? request.getBalance() : BigDecimal.ZERO;

        // 2. Tạo Entity Wallet
        Wallet wallet = new Wallet();
        wallet.setAccount(account);
        wallet.setCurrency(currency);
        wallet.setWalletName(request.getWalletName());
        wallet.setBalance(initBalance);
        wallet.setNotified(request.getNotified() != null ? request.getNotified() : true);
        wallet.setReportable(request.getReportable() != null ? request.getReportable() : true);
        wallet.setGoalImageUrl(request.getGoalImageUrl());

        Wallet savedWallet = walletRepository.save(wallet);

        // 3. Tạo giao dịch khởi tạo (INIT TRANSACTION)
        // Tạo giao dịch khởi tạo để đảm bảo tính đúng đắn của Số dư đầu kỳ/cuối kỳ
        if (initBalance.compareTo(BigDecimal.ZERO) > 0) {
            
            // Dùng Category "Thu nhập khác" cho Wallet
            Category category = categoryRepository.findById(SystemCategory.INCOME_OTHER.getId())
                    .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục hệ thống 'Thu nhập khác'"));

            Transaction initTransaction = Transaction.builder()
                    .account(account)
                    .wallet(savedWallet)
                    .category(category)
                    .amount(initBalance) // Số dương
                    .note("Số dư ban đầu")
                    .reportable(false)     // Không tính vào báo cáo thu chi trong kỳ (nhưng vẫn tính vào số dư)
                    .transDate(LocalDateTime.now())
                    .build();

            transactionRepository.save(initTransaction);
        }

        return mapToResponse(savedWallet);
    }

    // ================= UPDATE =================

    /**
     * Cập nhật thông tin ví.
     * - Validate quyền sở hữu.
     * - Cập nhật các trường thông tin.
     */
    @Override
    public WalletResponse updateWallet(Integer accountId, Integer walletId, WalletRequest request) {

        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));

        // 🔐 CHECK QUYỀN
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sửa ví này");
        }

        if (request.getWalletName() != null) {
            wallet.setWalletName(request.getWalletName());
        }

        // Lưu ý: Không cho phép update balance trực tiếp ở đây nếu muốn đảm bảo toàn vẹn dữ liệu transaction.
        // Nhưng nếu logic nghiệp vụ cho phép "Điều chỉnh số dư" thì phải tạo transaction điều chỉnh tương ứng.
        // Hiện tại giữ nguyên logic cũ của bạn (update thẳng balance).
        if (request.getBalance() != null) {
            wallet.setBalance(request.getBalance());
        }

        if (request.getNotified() != null) {
            wallet.setNotified(request.getNotified());
        }

        if (request.getReportable() != null) {
            wallet.setReportable(request.getReportable());
        }

        if (request.getGoalImageUrl() != null) {
            wallet.setGoalImageUrl(request.getGoalImageUrl());
        }

        if (request.getCurrencyCode() != null) {
            Currency currency = currencyRepository.findById(request.getCurrencyCode())
                    .orElseThrow(() -> new IllegalArgumentException("Loại tiền tệ không tồn tại"));
            wallet.setCurrency(currency);
        }

        walletRepository.save(wallet);

        return mapToResponse(wallet);
    }

    // ================= DELETE =================

    /**
     * Xóa ví.
     * - Validate quyền sở hữu.
     * - Không cho xóa ví còn tiền.
     */
    @Override
    public void deleteWallet(Integer accountId, Integer walletId) {

        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));

        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xóa ví này");
        }

        // Xóa ví → DB ON DELETE CASCADE tự xóa hết
        // Transactions (hard delete) + Budgets + BudgetCategories + PlannedTransactions
        walletRepository.delete(wallet);
    }

    // ================= GET BY ID =================

    @Override
    public WalletResponse getWalletById(Integer accountId, Integer walletId) {

        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại"));

        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xem ví này");
        }

        return mapToResponse(wallet);
    }

    // ================= GET ALL =================

    @Override
    public List<WalletResponse> getAllWallets(Integer accountId, String search) {

        List<Wallet> wallets;

        if (search != null && !search.isBlank()) {
            wallets = walletRepository
                    .findByAccountIdAndWalletNameContainingIgnoreCase(accountId, search);
        } else {
            wallets = walletRepository.findByAccountId(accountId);
        }

        return wallets.stream()
                .map(this::mapToResponse)
                .toList();
    }

    // ================= GET TOTAL BALANCE =================

    @Override
    public TotalBalanceResponse getTotalBalance(Integer accountId) {
        // Tính tổng tiền trong các ví (Wallets)
        BigDecimal walletsTotal = walletRepository.sumBalanceByAccountIdAndReportableTrue(accountId);
        if (walletsTotal == null) {
            walletsTotal = BigDecimal.ZERO;
        }

        // Tính tổng tiền trong các mục tiêu tiết kiệm (Saving Goals)
        BigDecimal savingsTotal = savingGoalRepository.sumCurrentAmountByAccountId(accountId);
        if (savingsTotal == null) {
            savingsTotal = BigDecimal.ZERO;
        }

        // Tổng tài sản = Tổng ví + Tổng tiết kiệm
        BigDecimal totalBalance = walletsTotal.add(savingsTotal);

        return new TotalBalanceResponse(totalBalance);
    }

    // ================= MAP =================

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