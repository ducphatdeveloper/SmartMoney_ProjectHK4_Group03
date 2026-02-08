package fpt.aptech.server.api.savinggoal;

import fpt.aptech.server.dto.savinggoal.reponse.SavingGoalResponse;
import fpt.aptech.server.dto.savinggoal.request.CreateSavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.request.UpdateSavingGoalRequest;
import fpt.aptech.server.service.savinggoal.SavingGoalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.GetMapping;



import java.util.List;

@RestController
@RequestMapping("/api/saving-goals")
@RequiredArgsConstructor
public class SavingGoalController {

    private final SavingGoalService savingGoalService;

    // ================= CREATE SAVING GOAL =================(tạo ví )
    @PostMapping
    public SavingGoalResponse createSavingGoal(
            @Valid @RequestBody CreateSavingGoalRequest request
    ) {
        return savingGoalService.createSavingGoal(request);
    }

    // ================= UPDATE THÔNG TIN  =================
    @PutMapping("/{goalId}")
    public SavingGoalResponse updateSavingGoal(
            @PathVariable Integer goalId,
            @RequestBody UpdateSavingGoalRequest request
    ) {
        return savingGoalService.updateSavingGoal(goalId, request);
    }

    // ============== Nạp tiền vao ví tiết kiệm ===========//
    @PostMapping("/{goalId}/deposit")
    public SavingGoalResponse deposit(
            @PathVariable Integer goalId,
            @RequestBody UpdateSavingGoalRequest request
    ) {
        return savingGoalService.updateSavingGoal(goalId, request);
    }


    // ================= DELETE SAVING GOAL =================
    @DeleteMapping("/{goalId}")
    public void deleteSavingGoal(
            @PathVariable Integer goalId,
            @RequestParam Integer accId
    ) {
        savingGoalService.deleteSavingGoal(goalId, accId);
    }

    // ================= GET BY ACCOUNT =================
    @GetMapping("/account/{accId}")
    public List<SavingGoalResponse> getByAccount(
            @PathVariable Integer accId
    ) {
        return savingGoalService.getSavingGoalsByAccount(accId);
    }

}
