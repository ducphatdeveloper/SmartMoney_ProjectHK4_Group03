package fpt.aptech.server.api.savinggoal;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.savinggoal.SavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.SavingGoalResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.savinggoal.SavingGoalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
@RestController
@RequestMapping("/api/saving-goals")
@RequiredArgsConstructor
public class SavingGoalController {

    private final SavingGoalService savingGoalService;

    // CREATE
    @PostMapping("/create")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> create(
            @Valid @RequestBody SavingGoalRequest request,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(
                        savingGoalService.createSavingGoal(request, currentUser.getId()),
                        "Tạo mục tiêu thành công"));
    }

    // UPDATE INFO
    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> updateInfo(
            @PathVariable Integer id,
            @Valid @RequestBody SavingGoalRequest request,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.updateSavingGoalInfo(id, request, currentUser.getId()),
                "Cập nhật thành công"));
    }

    // DEPOSIT
    @PostMapping("/{id}/deposit")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> deposit(
            @PathVariable Integer id,
            @RequestParam BigDecimal amount,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.depositToSavingGoal(id, amount, currentUser.getId()),
                "Nạp tiền thành công"));
    }

    // DELETE
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {

        savingGoalService.deleteSavingGoal(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Hủy mục tiêu thành công"));
    }

    // GET ALL
    @GetMapping("/getAll")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<SavingGoalResponse>>> getAll(
            @RequestParam(required = false) String search,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.getSavingGoalsByAccount(currentUser.getId(), search)));
    }

    // DETAIL
    @GetMapping("/getDetail/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> getDetail(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.getSavingGoalDetail(id, currentUser.getId())));
    }
}
