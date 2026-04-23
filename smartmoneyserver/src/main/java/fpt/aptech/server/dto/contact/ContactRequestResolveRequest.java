package fpt.aptech.server.dto.contact;

import fpt.aptech.server.enums.contact.ContactRequestStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTO cho Admin duyệt / từ chối yêu cầu hỗ trợ.
 * Chỉ chấp nhận: PROCESSING | APPROVED | REJECTED
 */
public record ContactRequestResolveRequest(

        @NotNull(message = "Processing status cannot be empty.")
        ContactRequestStatus requestStatus,

        @Size(max = 1000, message = "Note must not exceed 1000 characters.")
        String adminNote
) {}

