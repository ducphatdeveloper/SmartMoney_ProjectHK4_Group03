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

        // Thông tin người gửi (để Admin dễ xem, không trả password)
        Integer accId,
        String accEmail,
        String accPhone,
        String accFullname,

        // Thông tin người xử lý
        Integer processedById,
        String processedByName,
        Integer resolvedById,
        String resolvedByName,

        // Nội dung yêu cầu
        ContactRequestType requestType,
        ContactRequestPriority requestPriority,
        String title,
        String requestDescription,
        String contactPhone,

        // Trạng thái & ghi chú
        ContactRequestStatus requestStatus,
        String adminNote,

        // Thời gian
        LocalDateTime processedAt,
        LocalDateTime resolvedAt,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {}

