package fpt.aptech.server.service.emailsender;

import java.io.File;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailServiceImpl implements EmailService {

    @Autowired
    private JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Override
    public void sendOtp(String to, String otp) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(fromEmail);
        message.setTo(to);
        message.setSubject("Mã OTP xác thực");
        message.setText("Mã OTP của bạn là: " + otp);
        mailSender.send(message);
    }

    @Override
    public void sendHtmlReport(String to, String subject, String htmlBody) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            // Tham số true ở đây có nghĩa là message này hỗ trợ multipart (nhiều phần)
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromEmail);
            helper.setTo(to);
            helper.setSubject(subject);
            // Tham số true ở đây báo hiệu nội dung là HTML
            helper.setText(htmlBody, true);

            mailSender.send(message);
        } catch (MessagingException e) {
            // Xử lý lỗi khi không gửi được mail
            log.error("Lỗi khi gửi HTML email: ", e);
        }
    }

    @Override
    public void sendMailWithAttachment(String to, String subject, String content, String pathToAttachment) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromEmail);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(content);

            FileSystemResource file = new FileSystemResource(new File(pathToAttachment));
            helper.addAttachment(file.getFilename(), file);

            mailSender.send(message);
        } catch (MessagingException e) {
            log.error("Lỗi khi gửi mail đính kèm: ", e);
        }
    }

    @Override
    public void sendEmergencyLockOtp(String to, String fullname, String otp) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromEmail);
            helper.setTo(to);
            helper.setSubject("[SmartMoney] Mã xác nhận khóa tài khoản khẩn cấp");

            String htmlBody = "<h3>Yêu cầu khóa tài khoản khẩn cấp</h3>" +
                    "<p>Chào " + fullname + ",</p>" +
                    "<p>Bạn vừa yêu cầu khóa tài khoản khẩn cấp. Mã xác nhận của bạn là:</p>" +
                    "<h2 style='color:red;'>" + otp + "</h2>" +
                    "<p>Mã này có hiệu lực trong 5 phút. Nếu không phải bạn thực hiện, hãy đổi mật khẩu ngay.</p>";

            helper.setText(htmlBody, true);
            mailSender.send(message);
            log.info("Đã gửi OTP khẩn cấp bất đồng bộ thành công đến: {}", to);
        } catch (MessagingException e) {
            log.error("Lỗi khi gửi email OTP khẩn cấp: ", e);
        }
    }
}