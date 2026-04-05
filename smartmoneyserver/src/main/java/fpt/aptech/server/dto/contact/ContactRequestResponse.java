package fpt.aptech.server.dto.contact;

import fpt.aptech.server.enums.contact.ContactRequestPriority;
import fpt.aptech.server.enums.contact.ContactRequestStatus;
import fpt.aptech.server.enums.contact.ContactRequestType;
import lombok.Builder;

import java.time.LocalDateTime;

/**
 * DTO trả về thông tin yêu cầu hỗ trợ cho cả User lẫn Admin.
 * Không trả hash_password hay thông tin nhạy cảm.
 */
@Builder(toBuilder = true)
public record ContactRequestResponse(
        Integer id,

        // Thông tin tài khoản gửi (nullable nếu guest)
        Integer accId,
        String accEmail,
        String accPhone,
        String accFullname,

        // Người duyệt cuối (Admin)
        Integer resolvedById,
        String resolvedByName,

        // Nội dung yêu cầu
        ContactRequestType requestType,
        ContactRequestPriority requestPriority,
        String title,
        String requestDescription,

        // Thông tin liên hệ người gửi (do user tự nhập hoặc backend gán)
        String fullname,
        String contactPhone,
        String contactEmail,

        // Trạng thái & ghi chú
        ContactRequestStatus requestStatus,
        String adminNote,

        // Thời gian
        LocalDateTime processedAt,
        LocalDateTime resolvedAt,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {}
