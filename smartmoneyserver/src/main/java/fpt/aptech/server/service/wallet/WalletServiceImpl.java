package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoals.request.CreateSavingGoalRequest;
import fpt.aptech.server.dto.savinggoals.request.UpdateSavingGoalRequest;

import fpt.aptech.server.dto.wallet.reponse.TotalWalletItemResponse;
import fpt.aptech.server.dto.wallet.reponse.TotalWalletResponse;
import fpt.aptech.server.dto.wallet.reponse.WalletResponse;
import fpt.aptech.server.dto.wallet.request.CreateBasicWalletRequest;
import fpt.aptech.server.dto.wallet.request.UpdateBasicWalletRequest;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Currency;
import fpt.aptech.server.entity.Savinggoals.SavingGoal;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.Currency.CurrencyRepository;
import fpt.aptech.server.repos.savinggoals.SavingGoalRepository;
import fpt.aptech.server.repos.wallet.WalletRepository;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class WalletServiceImpl implements WalletServices {

    private final WalletRepository walletRepo;
    private final SavingGoalRepository savingRepo;
    private final AccountRepository accountRepo;
    private final CurrencyRepository currencyRepo;

    // ================== BASIC WALLET ==================

    @Override
    public WalletResponse createBasicWallet(CreateBasicWalletRequest req) {

        Account account = accountRepo.findById(req.getAccId())
                .orElseThrow(() -> new RuntimeException("Account not found"));

        Currency currency = currencyRepo.findById(req.getCurrencyCode())
                .orElseThrow(() -> new RuntimeException("Currency not found"));

        Wallet wallet = Wallet.builder()
                .account(account)
                .currency(currency)
                .walletName(req.getWalletName())
                .balance(req.getBalance() != null ? req.getBalance() : BigDecimal.ZERO)
                .notified(req.getNotified() != null ? req.getNotified() : true)
                .reportable(req.getReportable() != null ? req.getReportable() : true)
                .goalImageUrl(req.getGoalImageUrl())
                .build();

        Wallet saved = walletRepo.save(wallet);

        return mapWallet(saved);
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
        walletRepo.deleteById(id);
    }

    // ================== SAVING GOAL ==================

    @Override
    public SavingGoalResponse createSavingGoal(CreateSavingGoalRequest req) {

        Account account = accountRepo.findById(req.getAccId())
                .orElseThrow(() -> new RuntimeException("Account not found"));

        Currency currency = currencyRepo.findById(req.getCurrencyCode())
                .orElseThrow(() -> new RuntimeException("Currency not found"));

        SavingGoal goal = SavingGoal.builder()
                .account(account)
                .currency(currency)
                .goalName(req.getGoalName())
                .targetAmount(req.getTargetAmount())
                .currentAmount(BigDecimal.ZERO)
                .endDate(req.getEndDate())
                .goalImageUrl(req.getGoalImageUrl())
                .goalStatus(1)
                .finished(false)
                .notified(true)
                .reportable(true)
                .build();

        return mapSavingGoal(savingRepo.save(goal));
    }

    @Override
    public SavingGoalResponse updateSavingGoal(Integer id, UpdateSavingGoalRequest req) {

        SavingGoal goal = savingRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Saving goal not found"));

        if (req.getGoalName() != null)
            goal.setGoalName(req.getGoalName());

        if (req.getTargetAmount() != null)
            goal.setTargetAmount(req.getTargetAmount());

        if (req.getEndDate() != null)
            goal.setEndDate(req.getEndDate());

        if (req.getNotified() != null)
            goal.setNotified(req.getNotified());

        if (req.getReportable() != null)
            goal.setReportable(req.getReportable());

        if (req.getGoalImageUrl() != null)
            goal.setGoalImageUrl(req.getGoalImageUrl());



        return mapSavingGoal(savingRepo.save(goal));
    }

    @Override
    public void deleteSavingGoal(Integer id) {
        savingRepo.deleteById(id);
    }

    public List<WalletResponse> getWalletsByAccount(Integer accId) {
        return walletRepo.findByAccount_Id(accId)
                .stream()
                .map(this::mapWallet)
                .toList();
    }

    @Override
    public List<SavingGoalResponse> getSavingGoalsByAccount(Integer accId) {
        return List.of();
    }

    // =================List Basic Wallet
    @Override
    public List<WalletResponse> getBasicWallets(Integer accId) {
        return walletRepo.findByAccount_Id(accId)
                .stream()
                .map(this::mapWallet)
                .toList();
    }


    // ================= Total Runtime ==============
    @Override
    public TotalWalletResponse getTotalWallet(Integer accId) {

        // 1. Check account
        accountRepo.findById(accId)
                .orElseThrow(() -> new RuntimeException("Account not found"));

        // 2. Lấy các ví được tính vào tổng
        var wallets = walletRepo.findByAccount_IdAndReportableTrue(accId);

        if (wallets.isEmpty()) {
            return TotalWalletResponse.builder()
                    .accId(accId)
                    .walletName("Ví tổng")
                    .totalBalance(BigDecimal.ZERO)
                    .currencyCode(null)
                    .wallets(List.of())
                    .build();
        }

        // 3. Giả sử 1 acc chỉ dùng 1 currency chính (Money Lover)
        final String currencyCode =
                wallets.get(0).getCurrency().getCurrencyCode();

        // 4. Map danh sách ví con
        var walletItems = wallets.stream()
                .map(w -> TotalWalletItemResponse.builder()
                        .walletName(w.getWalletName())
                        .balance(w.getBalance())
                        .currencyCode(currencyCode)
                        .build())
                .toList();

        // 5. Tính tổng
        BigDecimal total = wallets.stream()
                .map(Wallet::getBalance)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // 6. Response
        return TotalWalletResponse.builder()
                .accId(accId)
                .walletName("Ví tổng")
                .currencyCode(currencyCode)
                .totalBalance(total)
                .wallets(walletItems)
                .build();
    }




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

    private SavingGoalResponse mapSavingGoal(SavingGoal g) {
        return SavingGoalResponse.builder()
                .id(g.getId())
                .goalName(g.getGoalName())
                .targetAmount(g.getTargetAmount())
                .currentAmount(g.getCurrentAmount())
                .endDate(g.getEndDate())
                .goalStatus(g.getGoalStatus())
                .notified(g.getNotified())
                .reportable(g.getReportable())
                .finished(g.getFinished())
                .currencyCode(g.getCurrency().getCurrencyCode())
                .imageUrl(g.getGoalImageUrl())
                .build();
    }
}
