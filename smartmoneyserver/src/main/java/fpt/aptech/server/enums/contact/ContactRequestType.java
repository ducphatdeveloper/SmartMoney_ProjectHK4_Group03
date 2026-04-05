package fpt.aptech.server.enums.contact;

/**
 * Loại yêu cầu liên hệ hỗ trợ.
 * Map với cột request_type (NVARCHAR) trong tContactRequests.
 * Cần login    : ACCOUNT_LOCK, SUSPICIOUS_TX
 * Không login  : ACCOUNT_UNLOCK, FORGOT_PASSWORD, EMERGENCY
 * Cả hai       : BUG_REPORT, DATA_RECOVERY, DATA_LOSS, GENERAL
 */
public enum ContactRequestType {
    ACCOUNT_LOCK,       // Cần login    — tự khóa tài khoản
    SUSPICIOUS_TX,      // Cần login    — hệ thống tự tạo khi phát hiện giao dịch bất thường
    ACCOUNT_UNLOCK,     // Không login  — mở khóa tài khoản đang bị khóa
    FORGOT_PASSWORD,    // Không login  — quên mật khẩu
    EMERGENCY,          // Không login  — khẩn cấp khi bị hack / giao dịch lạ
    BUG_REPORT,         // Cả hai       — báo lỗi phần mềm
    DATA_RECOVERY,      // Cả hai       — yêu cầu khôi phục dữ liệu
    DATA_LOSS,          // Cả hai       — báo mất dữ liệu
    GENERAL             // Cả hai       — góp ý / câu hỏi chung
}
