package fpt.aptech.server.dto.contact;

import fpt.aptech.server.enums.contact.ContactRequestType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTO cho User gửi yêu cầu hỗ trợ mới.
 * KHÔNG chứa acc_id, processed_by, resolved_by — lấy từ JWT.
 */
public record ContactRequestCreateRequest(

        @NotNull(message = "Loại yêu cầu không được để trống.")
        ContactRequestType requestType,

        @NotBlank(message = "Tiêu đề không được để trống.")
        @Size(max = 200, message = "Tiêu đề không được vượt quá 200 ký tự.")
        String title,

        @Size(max = 2000, message = "Mô tả không được vượt quá 2000 ký tự.")
        String requestDescription,

        // Bắt buộc nếu type là ACCOUNT_LOCK hoặc ACCOUNT_UNLOCK (validate trong Service)
        @Size(max = 20, message = "Số điện thoại không được vượt quá 20 ký tự.")
        String contactPhone
) {}

