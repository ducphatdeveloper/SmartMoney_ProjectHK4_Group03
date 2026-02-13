package fpt.aptech.server.service.wallet;

import fpt.aptech.server.dto.wallet.WalletResponse;
import fpt.aptech.server.dto.wallet.WalletRequest;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Currency;
import fpt.aptech.server.entity.Wallet;

import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;


@Service
@RequiredArgsConstructor
public class WalletServiceImpl implements WalletService {

    private final WalletRepository walletRepository;
    private final AccountRepository accountRepository;
    private final CurrencyRepository currencyRepository;

    // ================= CREATE =================

    @Override
    public WalletResponse createWallet(Integer accountId, WalletRequest request) {

        if (request.getWalletName() == null || request.getWalletName().isBlank()) {
            throw new RuntimeException("Wallet name is required");
        }

        if (request.getCurrencyCode() == null || request.getCurrencyCode().isBlank()) {
            throw new RuntimeException("Currency code is required");
        }

        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Account not found"));

        Currency currency = currencyRepository.findById(request.getCurrencyCode())
                .orElseThrow(() -> new RuntimeException("Currency not found"));

        Wallet wallet = new Wallet();
        wallet.setAccount(account);
        wallet.setCurrency(currency);
        wallet.setWalletName(request.getWalletName());
        wallet.setBalance(request.getBalance() != null ? request.getBalance() : BigDecimal.ZERO);
        wallet.setNotified(request.getNotified() != null ? request.getNotified() : true);
        wallet.setReportable(request.getReportable() != null ? request.getReportable() : true);
        wallet.setGoalImageUrl(request.getGoalImageUrl());

        walletRepository.save(wallet);

        return mapToResponse(wallet);
    }

    // ================= UPDATE =================

    @Override
    public WalletResponse updateWallet(Integer accountId, Integer walletId, WalletRequest request) {

        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new RuntimeException("Wallet not found"));

        // 🔐 CHECK QUYỀN
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new RuntimeException("You do not have permission");
        }

        if (request.getWalletName() != null) {
            wallet.setWalletName(request.getWalletName());
        }

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
                    .orElseThrow(() -> new RuntimeException("Currency not found"));
            wallet.setCurrency(currency);
        }

        walletRepository.save(wallet);

        return mapToResponse(wallet);
    }

    // ================= DELETE =================

    @Override
    public void deleteWallet(Integer accountId, Integer walletId) {

        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new RuntimeException("Wallet not found"));

        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new RuntimeException("You do not have permission");
        }

        if (wallet.getBalance().compareTo(BigDecimal.ZERO) != 0) {
            throw new RuntimeException("Cannot delete wallet with balance");
        }

        walletRepository.delete(wallet);
    }

    // ================= GET BY ID =================

    @Override
    public WalletResponse getWalletById(Integer accountId, Integer walletId) {

        Wallet wallet = walletRepository.findById(walletId)
                .orElseThrow(() -> new RuntimeException("Wallet not found"));

        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new RuntimeException("You do not have permission");
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
