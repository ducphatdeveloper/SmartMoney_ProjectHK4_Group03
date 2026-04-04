package fpt.aptech.server.enums.contact;

/**
 * Loại yêu cầu liên hệ hỗ trợ.
 * Map với cột request_type (NVARCHAR) trong tContactRequests.
 */
public enum ContactRequestType {
    ACCOUNT_LOCK,       // Yêu cầu khóa tài khoản
    ACCOUNT_UNLOCK,     // Yêu cầu mở khóa tài khoản
    BUG_REPORT,         // Báo lỗi phần mềm
    SUSPICIOUS_TX,      // Giao dịch bất thường (hệ thống tự tạo hoặc user báo)
    DATA_RECOVERY,      // Yêu cầu khôi phục dữ liệu
    DATA_LOSS,          // Báo mất dữ liệu
    GENERAL             // Góp ý / câu hỏi chung
}

