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
        message.setSubject("OTP Verification Code");
        message.setText("Your OTP code is: " + otp);
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
            log.error("Error sending HTML email: ", e);
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
            log.error("Error sending email with attachment: ", e);
        }
    }

    @Override
    public void sendEmergencyLockOtp(String to, String fullname, String otp) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromEmail);
            helper.setTo(to);
            helper.setSubject("[SmartMoney] Emergency Account Lock Verification Code");

            String htmlBody = "<h3>Emergency Account Lock Request</h3>" +
                    "<p>Hello " + fullname + ",</p>" +
                    "<p>You have requested an emergency account lock. Your verification code is:</p>" +
                    "<h2 style='color:red;'>" + otp + "</h2>" +
                    "<p>This code is valid for 5 minutes. If you did not make this request, please change your password immediately.</p>";

            helper.setText(htmlBody, true);
            mailSender.send(message);
            log.info("Emergency OTP sent successfully to: {}", to);
        } catch (MessagingException e) {
            log.error("Error sending emergency OTP email: ", e);
        }
    }
}