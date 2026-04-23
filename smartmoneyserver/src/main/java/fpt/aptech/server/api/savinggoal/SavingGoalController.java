package fpt.aptech.server.api.savinggoal;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.savinggoal.SavingGoalRequest;
import fpt.aptech.server.dto.savinggoal.SavingGoalResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.scheduler.savinggoal.SavingGoalScheduler;
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
    private final SavingGoalScheduler savingGoalScheduler; // Inject Scheduler để trigger thủ công khi test

    // =================================================================================
    // 1. TẠO MỚI (CREATE)
    // =================================================================================

    /**
     * [1.1] POST /api/saving-goals/create
     * Tạo mục tiêu tiết kiệm mới.
     * Request body: SavingGoalRequest (goalName, targetAmount, initialAmount, endDate...)
     * Response: 201 Created + SavingGoalResponse
     */
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

    // =================================================================================
    // 2. CẬP NHẬT THÔNG TIN (UPDATE)
    // =================================================================================

    /**
     * [2.1] PUT /api/saving-goals/{id}
     * Cập nhật thông tin mục tiêu (tên, target, ngày, ảnh...).
     * Chỉ cho phép khi mục tiêu đang ACTIVE.
     */
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

    // =================================================================================
    // 3. NẠP TIỀN (DEPOSIT)
    // =================================================================================

    /**
     * [3.1] POST /api/saving-goals/{id}/deposit?amount=...
     * Nạp tiền vào mục tiêu tiết kiệm.
     * Query param: amount (BigDecimal, > 0)
     * Chặn nếu: finished=true, CANCELLED, hoặc vượt quá target.
     */
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

    // =================================================================================
    // 4. RÚT TIỀN (WITHDRAW)
    // =================================================================================

    /**
     * [4.1] POST /api/saving-goals/{id}/withdraw?amount=...
     * Rút tiền từ mục tiêu tiết kiệm (giảm currentAmount).
     * Nếu rút xuống dưới 100% → tự về ACTIVE (từ COMPLETED).
     * Query param: amount (BigDecimal, > 0)
     * Chặn nếu: finished=true hoặc CANCELLED.
     */
    @PostMapping("/{id}/withdraw")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> withdraw(
            @PathVariable Integer id,
            @RequestParam BigDecimal amount,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.withdrawFromSavingGoal(id, amount, currentUser.getId()),
                "Rút tiền thành công"));
    }

    // =================================================================================
    // 5. CHỐT SỔ (COMPLETE — GIẢI NGÂN VỀ VÍ)
    // =================================================================================

    /**
     * [5.1] POST /api/saving-goals/{id}/complete?walletId=...
     * Chốt sổ mục tiêu: finished=true + đổ tiền về wallet được chọn.
     *
     * Điều kiện: Goal phải đang COMPLETED (đủ 100%) và finished=false.
     * Sau khi chốt: currentAmount=0, finished=true — KHÔNG thể hoàn tác.
     *
     * Query param: walletId (Integer, optional) — ví nhận tiền.
     *              Nếu null → chỉ đóng goal, không đổ tiền về đâu.
     */
    @PostMapping("/{id}/complete")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> complete(
            @PathVariable Integer id,
            @RequestParam(required = false) Integer walletId,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.completeSavingGoal(id, walletId, currentUser.getId()),
                "Chúc mừng! Mục tiêu đã được chốt sổ thành công 🎉"));
    }

    // =================================================================================
    // 6. HỦY MỤC TIÊU (CANCEL — GIẢI NGÂN VỀ VÍ)
    // =================================================================================

    /**
     * [6.1] POST /api/saving-goals/{id}/cancel?walletId=...
     * Hủy mục tiêu: CANCELLED + finished=true + đổ tiền còn lại về wallet.
     *
     * Khác với DELETE: Record vẫn còn trong DB (deleted=false), chỉ đổi trạng thái.
     * Sau khi hủy: currentAmount=0, goalStatus=CANCELLED, finished=true.
     *
     * Query param: walletId (Integer, optional) — ví nhận tiền hoàn trả.
     *              Nếu null → chỉ đóng goal, không đổ tiền về đâu.
     */
    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> cancel(
            @PathVariable Integer id,
            @RequestParam(required = false) Integer walletId,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.cancelSavingGoal(id, walletId, currentUser.getId()),
                "Đã hủy mục tiêu và hoàn trả tiền về ví"));
    }

    // =================================================================================
    // 7. XÓA MỤC TIÊU (SOFT DELETE)
    // =================================================================================

    /**
     * [7.1] DELETE /api/saving-goals/{id}
     * Xóa mềm mục tiêu (deleted=true) + cascade xóa mềm transactions, debts, events liên quan.
     * Khác Hủy: record bị ẩn hoàn toàn khỏi mọi query (@SQLRestriction "deleted=0").
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {

        savingGoalService.deleteSavingGoal(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Goal deleted successfully"));
    }

    // =================================================================================
    // 8. LẤY DANH SÁCH & CHI TIẾT (READ)
    // =================================================================================

    /**
     * [8.1] GET /api/saving-goals/getAll?search=...
     * Lấy danh sách tất cả mục tiêu của user hiện tại (trừ deleted=true).
     * Query param: search (String, optional) — tìm kiếm theo tên mục tiêu.
     */
    @GetMapping("/getAll")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<SavingGoalResponse>>> getAll(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Boolean isFinished,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.getSavingGoalsByAccount(currentUser.getId(), search, isFinished)));
    }

    /**
     * [8.2] GET /api/saving-goals/getDetail/{id}
     * Lấy chi tiết một mục tiêu theo ID.
     */
    @GetMapping("/getDetail/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<SavingGoalResponse>> getDetail(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {

        return ResponseEntity.ok(ApiResponse.success(
                savingGoalService.getSavingGoalDetail(id, currentUser.getId())));
    }

    // =================================================================================
    // 9. TRIGGER THỦ CÔNG SCHEDULER (CHỈ DÙNG KHI TEST)
    // =================================================================================

    /**
     * [9.1] POST /api/saving-goals/check-now
     * Trigger thủ công 2 scheduler để test mà không cần chờ cron.
     *   • checkOverdueGoals()      — chuyển ACTIVE → OVERDUE nếu quá endDate
     *   • remindNearDeadlineGoals() — nhắc các goal còn <= 7 ngày
     */
    @PostMapping("/check-now")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<String>> checkNow() {
        savingGoalScheduler.checkOverdueGoals();
        savingGoalScheduler.remindNearDeadlineGoals();
        return ResponseEntity.ok(ApiResponse.success("Saving Goal scheduler manually triggered."));
    }
}