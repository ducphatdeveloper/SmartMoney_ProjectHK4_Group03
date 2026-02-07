package fpt.aptech.server.api.savinggoals;

import fpt.aptech.server.dto.savinggoals.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoals.request.*;
import fpt.aptech.server.service.savinggoals.SavinggoalsServices;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/saving-goals")
@RequiredArgsConstructor
public class SavinggoalsController {

    private final SavinggoalsServices savinggoalsServices;

    // ================= CREATE SAVING GOAL =================(tạo ví )
    @PostMapping
    public SavingGoalResponse createSavingGoal(
            @Valid @RequestBody CreateSavingGoalRequest request) {
        return savinggoalsServices.createSavingGoal(request);
    }

    // ================= UPDATE THÔNG TIN =================
    @PutMapping("/{goalId}")
    public SavingGoalResponse updateSavingGoal(
            @PathVariable Integer goalId,
            @RequestBody UpdateSavingGoalRequest request) {
        return savinggoalsServices.updateSavingGoal(goalId, request);
    }

    // ============== Nạp tiền vao ví tiết kiệm ===========//
    @PostMapping("/{goalId}/deposit")
    public SavingGoalResponse deposit(
            @PathVariable Integer goalId,
            @RequestBody UpdateSavingGoalRequest request) {
        return savinggoalsServices.updateSavingGoal(goalId, request);
    }

    // ================= DELETE SAVING GOAL =================
    @DeleteMapping("/{goalId}")
    public void deleteSavingGoal(
            @PathVariable Integer goalId,
            @RequestParam Integer accId) {
        savinggoalsServices.deleteSavingGoal(goalId, accId);
    }

    // ================= GET BY ACCOUNT =================
    @GetMapping("/account/{accId}")
    public List<SavingGoalResponse> getByAccount(
            @PathVariable Integer accId) {
        return savinggoalsServices.getSavingGoalsByAccount(accId);
    }

}
