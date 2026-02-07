package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoals.request.CreateSavingGoalRequest;
import fpt.aptech.server.dto.savinggoals.request.UpdateSavingGoalRequest;

import fpt.aptech.server.dto.wallet.reponse.WalletResponse;
import fpt.aptech.server.dto.wallet.request.CreateBasicWalletRequest;
import fpt.aptech.server.dto.wallet.request.UpdateBasicWalletRequest;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.SavingGoalRepository;
import fpt.aptech.server.repos.WalletRepository;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class WalletServiceImpl implements WalletServices {

    private final WalletRepository walletRepo;
    private final AccountRepository accountRepo;
    private final CurrencyRepository currencyRepo;
    private final TransactionRepository transactionRepo;


    // ================== BASIC WALLET ==================

    @Override
    public WalletResponse createBasicWallet(CreateBasicWalletRequest req) {

        Account account = accountRepo.findById(req.getAccId())
                .orElseThrow(() -> new RuntimeException("Account not found"));

        Currency currency = currencyRepo.findById(req.getCurrencyCode())
                .orElseThrow(() -> new RuntimeException("Currency not found"));

        BigDecimal initBalance =
                req.getBalance() != null ? req.getBalance() : BigDecimal.ZERO;

        Wallet wallet = Wallet.builder()
                .account(account)
                .currency(currency)
                .walletName(req.getWalletName())
                .balance(initBalance)
                .notified(req.getNotified() != null ? req.getNotified() : true)
                .reportable(req.getReportable() != null ? req.getReportable() : true)
                .goalImageUrl(req.getGoalImageUrl())
                .build();

        Wallet savedWallet = walletRepo.save(wallet);

        // ================= INIT TRANSACTION =================
        if (initBalance.compareTo(BigDecimal.ZERO) > 0) {

            Transaction initTransaction = Transaction.builder()
                    .account(account)
                    .wallet(savedWallet)
                    .amount(initBalance)
                    .note("Initial balance")
                    .reportable(false)     // ❗ không tính báo cáo
                    .sourceType(1)         // system/manual
                    .transDate(LocalDateTime.now())
                    .deleted(false)
                    .build();

            transactionRepo.save(initTransaction);
        }

        return mapWallet(savedWallet);
    }


    @Override
    public WalletResponse updateBasicWallet(Integer id, UpdateBasicWalletRequest req) {

        Wallet wallet = walletRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Wallet not found"));

        if (req.getWalletName() != null)
            wallet.setWalletName(req.getWalletName());

        if (req.getNotified() != null)
            wallet.setNotified(req.getNotified());

        if (req.getReportable() != null)
            wallet.setReportable(req.getReportable());

        if (req.getGoalImageUrl() != null)
            wallet.setGoalImageUrl(req.getGoalImageUrl());


        return mapWallet(walletRepo.save(wallet));
    }

    @Override
    public void deleteBasicWallet(Integer id) {

        Wallet wallet = walletRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Wallet not found"));

        if (wallet.getBalance().compareTo(BigDecimal.ZERO) != 0) {
            throw new RuntimeException("Cannot delete wallet with balance");
        }

        walletRepo.delete(wallet);
    }








    public List<WalletResponse> getWalletsByAccount(Integer accId) {
        return walletRepo.findByAccount_Id(accId)
                .stream()
                .map(this::mapWallet)
                .toList();
    }


    // =================List Basic Wallet
    @Override
    public List<WalletResponse> getBasicWallets(Integer accId) {
        return walletRepo.findByAccount_IdAndReportableTrue(accId)
                .stream()
                .map(this::mapWallet)
                .toList();
    }


    // ================= Total Runtime ==============
//    @Override
//    public TotalWalletResponse getTotalWallet(Integer accId) {
//
//        // 1. Check account
//        accountRepo.findById(accId)
//                .orElseThrow(() -> new RuntimeException("Account not found"));
//
//        // 2. Lấy các ví được tính vào tổng
//        var wallets = walletRepo.findByAccount_IdAndReportableTrue(accId);
//
//        if (wallets.isEmpty()) {
//            return TotalWalletResponse.builder()
//                    .accId(accId)
//                    .walletName("Ví tổng")
//                    .totalBalance(BigDecimal.ZERO)
//                    .currencyCode(null)
//                    .wallets(List.of())
//                    .build();
//        }
//
//        // 3. Giả sử 1 acc chỉ dùng 1 currency chính (Money Lover)
//        final String currencyCode =
//                wallets.get(0).getCurrency().getCurrencyCode();
//
//        // 4. Map danh sách ví con
//        var walletItems = wallets.stream()
//                .map(w -> TotalWalletItemResponse.builder()
//                        .walletName(w.getWalletName())
//                        .balance(w.getBalance())
//                        .currencyCode(currencyCode)
//                        .build())
//                .toList();
//
//        // 5. Tính tổng
//        BigDecimal total = wallets.stream()
//                .map(Wallet::getBalance)
//                .reduce(BigDecimal.ZERO, BigDecimal::add);
//
//        // 6. Response
//        return TotalWalletResponse.builder()
//                .accId(accId)
//                .walletName("Ví tổng")
//                .currencyCode(currencyCode)
//                .totalBalance(total)
//                .wallets(walletItems)
//                .build();
//    }




    // ================== MAPPER ==================

    private WalletResponse mapWallet(Wallet w) {
        return WalletResponse.builder()
                .id(w.getId())
                .walletName(w.getWalletName())
                .balance(w.getBalance())
                .currencyCode(w.getCurrency().getCurrencyCode())
                .notified(w.getNotified())
                .reportable(w.getReportable())
                .goalImageUrl(w.getGoalImageUrl())
                .build();
    }


}
