package fpt.aptech.server.enums.contact;

/**
 * Mức độ ưu tiên yêu cầu liên hệ.
 * Map với cột request_priority (NVARCHAR) trong tContactRequests.
 */
public enum ContactRequestPriority {
    URGENT,     // Khẩn cấp (tự động set cho SUSPICIOUS_TX)
    HIGH,       // Cao
    NORMAL      // Bình thường (mặc định)
}

