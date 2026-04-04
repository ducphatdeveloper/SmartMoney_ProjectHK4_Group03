package fpt.aptech.server.service.emailsender;

public interface EmailService {
    // 1. Gửi OTP (Text đơn giản)
    void sendOtp(String to, String otp);

    // 2. Gửi báo cáo chi tiêu (HTML)
    void sendHtmlReport(String to, String subject, String htmlBody);

    // 3. Gửi hóa đơn kèm ảnh giao dịch (Attachment)
    void sendMailWithAttachment(String to, String subject, String content, String pathToAttachment);
    // 4. Gửi OTP khóa tài khoản khẩn cấp (HTML & Asynchronous)
    void sendEmergencyLockOtp(String to, String fullname, String otp);
}
