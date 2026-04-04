package fpt.aptech.server.api.contact;

import fpt.aptech.server.dto.contact.ContactRequestCreateRequest;
import fpt.aptech.server.dto.contact.ContactRequestResolveRequest;
import fpt.aptech.server.dto.contact.ContactRequestResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.contact.ContactRequestService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * API quản lý yêu cầu hỗ trợ / liên hệ.
 * Base path: /api/contact-requests
 */
@RestController
@RequestMapping("/api/contact-requests")
@RequiredArgsConstructor
public class ContactRequestController {

    private final ContactRequestService contactRequestService;

    // =================================================================================
    // [1] USER — Gửi yêu cầu hỗ trợ mới
    // POST /api/contact-requests
    // =================================================================================
    @PostMapping
    @PreAuthorize("hasAnyRole('USER','ADMIN')")
    public ResponseEntity<ApiResponse<ContactRequestResponse>> createRequest(
            @Valid @RequestBody ContactRequestCreateRequest request,
            @AuthenticationPrincipal Account currentUser) {

        ContactRequestResponse response = contactRequestService.createRequest(
                currentUser.getId(), request);

        return ResponseEntity.ok(
                ApiResponse.success(response, "Gửi yêu cầu hỗ trợ thành công."));
    }

    // =================================================================================
    // [2] USER — Xem lịch sử yêu cầu của mình
    // GET /api/contact-requests/my
    // =================================================================================
    @GetMapping("/my")
    @PreAuthorize("hasAnyRole('ROLE_USER','ROLE_ADMIN')")
    public ResponseEntity<ApiResponse<List<ContactRequestResponse>>> getMyRequests(
            @AuthenticationPrincipal Account currentUser) {

        List<ContactRequestResponse> responses = contactRequestService.getMyRequests(
                currentUser.getId());

        return ResponseEntity.ok(ApiResponse.success(responses));
    }

    // =================================================================================
    // [3] ADMIN — Xem tất cả yêu cầu (filter ?status=PENDING&type=ACCOUNT_LOCK)
    // GET /api/contact-requests
    // =================================================================================
    @GetMapping
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<ContactRequestResponse>>> getAllRequests(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String type) {

        List<ContactRequestResponse> responses = contactRequestService.getAllRequests(status, type);

        return ResponseEntity.ok(ApiResponse.success(responses));
    }

    // =================================================================================
    // [4] ADMIN — Duyệt hoặc từ chối yêu cầu
    // PATCH /api/contact-requests/{id}/resolve
    // =================================================================================
    @PatchMapping("/{id}/resolve")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<ContactRequestResponse>> resolveRequest(
            @PathVariable Integer id,
            @Valid @RequestBody ContactRequestResolveRequest request,
            @AuthenticationPrincipal Account currentUser) {

        ContactRequestResponse response = contactRequestService.resolveRequest(
                currentUser.getId(), id, request);

        return ResponseEntity.ok(
                ApiResponse.success(response, "Cập nhật yêu cầu hỗ trợ thành công."));
    }
}

