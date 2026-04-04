package fpt.aptech.server.dto.contact;

import fpt.aptech.server.enums.contact.ContactRequestStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTO cho Admin duyệt / từ chối yêu cầu hỗ trợ.
 * Chỉ chấp nhận: PROCESSING | APPROVED | REJECTED
 */
public record ContactRequestResolveRequest(

        @NotNull(message = "Trạng thái xử lý không được để trống.")
        ContactRequestStatus requestStatus,

        @Size(max = 1000, message = "Ghi chú không được vượt quá 1000 ký tự.")
        String adminNote
) {}

