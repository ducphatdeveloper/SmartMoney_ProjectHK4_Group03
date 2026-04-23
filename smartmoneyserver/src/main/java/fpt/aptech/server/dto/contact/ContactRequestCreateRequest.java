package fpt.aptech.server.dto.contact;

import fpt.aptech.server.enums.contact.ContactRequestType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTO cho User gửi yêu cầu hỗ trợ mới.
 * KHÔNG chứa acc_id, resolvedBy — lấy từ JWT.
 * fullname: tự gán từ account nếu user login và không truyền lên; guest bắt buộc truyền.
 * Phải có ít nhất contactPhone HOẶC contactEmail (validate trong Service).
 */
public record ContactRequestCreateRequest(

        @NotNull(message = "Request type cannot be empty.")
        ContactRequestType requestType,

        @NotBlank(message = "Title cannot be empty.")
        @Size(max = 200, message = "Title must not exceed 200 characters.")
        String title,

        @Size(max = 2000, message = "Description must not exceed 2000 characters.")
        String requestDescription,

        // Họ tên — tùy chọn cho user đã login (backend tự gán nếu null); bắt buộc cho guest
        @Size(max = 60, message = "Full name must not exceed 60 characters.")
        String fullname,

        // Phải có ít nhất phone HOẶC email (validate trong Service)
        @Size(max = 20, message = "Phone number must not exceed 20 characters.")
        String contactPhone,

        @Size(max = 100, message = "Contact email must not exceed 100 characters.")
        String contactEmail
) {}
