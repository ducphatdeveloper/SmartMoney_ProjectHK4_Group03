package fpt.aptech.server.enums.contact;

/**
 * Trạng thái xử lý yêu cầu liên hệ.
 * Map với cột request_status (NVARCHAR) trong tContactRequests.
 * Flow: PENDING → PROCESSING → APPROVED | REJECTED
 */
public enum ContactRequestStatus {
    PENDING,        // Chờ xử lý (mặc định khi tạo)
    PROCESSING,     // Đang được staff xử lý
    APPROVED,       // Đã duyệt / chấp nhận
    REJECTED        // Đã từ chối
}

