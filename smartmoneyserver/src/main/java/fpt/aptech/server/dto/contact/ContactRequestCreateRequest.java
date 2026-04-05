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

        @NotNull(message = "Loại yêu cầu không được để trống.")
        ContactRequestType requestType,

        @NotBlank(message = "Tiêu đề không được để trống.")
        @Size(max = 200, message = "Tiêu đề không được vượt quá 200 ký tự.")
        String title,

        @Size(max = 2000, message = "Mô tả không được vượt quá 2000 ký tự.")
        String requestDescription,

        // Họ tên — tùy chọn cho user đã login (backend tự gán nếu null); bắt buộc cho guest
        @Size(max = 60, message = "Họ tên không được vượt quá 60 ký tự.")
        String fullname,

        // Phải có ít nhất phone HOẶC email (validate trong Service)
        @Size(max = 20, message = "Số điện thoại không được vượt quá 20 ký tự.")
        String contactPhone,

        @Size(max = 100, message = "Email liên hệ không được vượt quá 100 ký tự.")
        String contactEmail
) {}
