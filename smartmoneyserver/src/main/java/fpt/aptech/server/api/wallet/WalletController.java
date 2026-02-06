    package fpt.aptech.server.api.wallet;

    import fpt.aptech.server.dto.savinggoals.request.CreateSavingGoalRequest;
    import fpt.aptech.server.dto.savinggoals.request.UpdateSavingGoalRequest;
    import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
    import fpt.aptech.server.dto.wallet.reponse.TotalWalletResponse;
    import fpt.aptech.server.dto.wallet.reponse.WalletResponse;
    import fpt.aptech.server.dto.wallet.request.CreateBasicWalletRequest;
    import fpt.aptech.server.dto.wallet.request.UpdateBasicWalletRequest;
    import fpt.aptech.server.service.wallet.WalletServices;
    import jakarta.validation.Valid;
    import lombok.RequiredArgsConstructor;
    import org.springframework.web.bind.annotation.*;

    import java.util.List;

    @RestController
    @RequestMapping("/api/wallets")
    @RequiredArgsConstructor
    public class WalletController {

        private final WalletServices walletService;

        // ================== BASIC WALLET ==================

        @PostMapping("/basic")
        public WalletResponse createBasic(
              @Valid @RequestBody CreateBasicWalletRequest req) {
            return walletService.createBasicWallet(req);
        }

        @PutMapping("/basic/{id}")
        public WalletResponse updateBasic(
                @PathVariable Integer id,
                @RequestBody UpdateBasicWalletRequest req) {
            return walletService.updateBasicWallet(id, req);
        }

        @DeleteMapping("/basic/{id}")
        public void deleteBasic(@PathVariable Integer id) {
            walletService.deleteBasicWallet(id);
        }

        // =================Lấy danh sách ví theo account
        @GetMapping("/account/{accId}")
        public List<WalletResponse> getWallets(@PathVariable Integer accId) {
            return walletService.getWalletsByAccount(accId);
        }

        // ================== SAVING GOAL ==================

        @PostMapping("/saving")
        public SavingGoalResponse createSaving(
              @Valid @RequestBody CreateSavingGoalRequest req) {
            return walletService.createSavingGoal(req);
        }

        @PutMapping("/saving/{id}")
        public SavingGoalResponse updateSaving(
                @PathVariable Integer id,
                @RequestBody UpdateSavingGoalRequest req) {
            return walletService.updateSavingGoal(id, req);
        }

        @DeleteMapping("/saving/{id}")
        public void deleteSaving(@PathVariable Integer id) {
            walletService.deleteSavingGoal(id);
        }

        //=========================Lấy danh sách saving goals
        @GetMapping("/saving/account/{accId}")
        public List<SavingGoalResponse> getSavingGoals(@PathVariable Integer accId) {
            return walletService.getSavingGoalsByAccount(accId);
        }
        // Danh sách ví cơ bản
        @GetMapping("/basic/{accId}")
        public List<WalletResponse> getBasic(@PathVariable Integer accId) {
            return walletService.getBasicWallets(accId);
        }


        // Ví tổng (runtime)
        @GetMapping("/total/{accId}")
        public TotalWalletResponse getTotalWallet( @PathVariable Integer accId) {
            return walletService.getTotalWallet(accId);
        }


    }



