package fpt.aptech.server.service.User;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import fpt.aptech.server.service.emailsender.EmailService;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Arrays;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserServiceImp implements UserService {

    private final AccountRepository accountRepository;
    private final UserDeviceRepository userDeviceRepository;
    private final NotificationService notificationService;
    private final Cloudinary cloudinary;
    private final EmailService emailService;

    // Cấu trúc lưu trữ OTP kèm thời gian tạo
    private static class OtpSession {
        String code;
        LocalDateTime createdAt;
        OtpSession(String code) {
            this.code = code;
            this.createdAt = LocalDateTime.now();
        }
        boolean isExpired() {
            return LocalDateTime.now().isAfter(createdAt.plusMinutes(5));
        }
    }

    private final Map<Integer, OtpSession> otpCache = new ConcurrentHashMap<>();

    @Override
    @Transactional(readOnly = true)
    public AccountDto getProfile(String email) {
        Account account = accountRepository.findByAccEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return new AccountDto(account);
    }

    @Override
    @Transactional
    public AccountDto updateProfile(Integer accId, AccountDto dto) {
        log.info("Cập nhật thông tin cá nhân cho User ID: {}", accId);
        Account account = accountRepository.findById(accId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Chỉ cập nhật các trường thông tin cá nhân, không cập nhật password/email ở đây
        account.setFullname(dto.getFullname());
        account.setGender(dto.getGender());
        account.setDateofbirth(dto.getDateofbirth());
        account.setAddress(dto.getAddress());
        account.setIdentityCard(dto.getIdentityCard());

        accountRepository.save(account);

        // Gửi thông báo cập nhật hồ sơ
        var msg = NotificationMessages.profileUpdated();
        notificationService.createNotification(account, msg.title(), msg.content(), 
                NotificationType.SYSTEM, null, LocalDateTime.now());

        return new AccountDto(account);
    }

    @Override
    @Transactional
    public String updateAvatar(Integer accId, MultipartFile file) {
        log.info("Đang bắt đầu quá trình cập nhật avatar cho User ID: {}", accId);
        Account account = accountRepository.findById(accId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (file == null || file.isEmpty()) {
            throw new RuntimeException("File không được để trống.");
        }

        try {
            String contentType = file.getContentType();
            List<String> allowedTypes = Arrays.asList("image/jpeg", "image/png", "image/webp");
            if (contentType == null || !allowedTypes.contains(contentType.toLowerCase())) {
                log.warn("Định dạng file '{}' không được hỗ trợ cho User ID: {}", contentType, accId);
                throw new RuntimeException("Chỉ hỗ trợ định dạng ảnh JPG, PNG hoặc WEBP.");
            }

            // 1. Xóa ảnh cũ trên Cloudinary nếu tồn tại
            String oldUrl = account.getAvatarUrl();
            if (oldUrl != null && oldUrl.contains("avatars/")) {
                try {
                    // Trích xuất public_id từ URL (tương tự logic xử lý chuỗi trong IconService)
                    String publicId = oldUrl.substring(oldUrl.lastIndexOf("avatars/"), oldUrl.lastIndexOf("."));
                    cloudinary.uploader().destroy(publicId, ObjectUtils.emptyMap());
                    log.info("Đã xóa thành công ảnh cũ trên Cloudinary: {}", publicId);
                } catch (Exception e) {
                    log.warn("Không thể xóa ảnh cũ (có thể đã bị xóa trước đó), bỏ qua: {}", e.getMessage());
                }
            }

            // 2. Upload ảnh mới
            Map uploadResult = cloudinary.uploader().upload(file.getBytes(),
                    ObjectUtils.asMap("folder", "avatars", "resource_type", "image"));
            String fileUrl = (String) uploadResult.get("secure_url");

            account.setAvatarUrl(fileUrl);
            accountRepository.save(account);

            var msg = NotificationMessages.avatarUpdated();
            notificationService.createNotification(account, msg.title(), msg.content(), NotificationType.SYSTEM, null, LocalDateTime.now());

            return fileUrl;
        } catch (IOException e) {
            log.error("Lỗi nghiêm trọng khi upload avatar lên Cloudinary cho User {}: {}", accId, e.getMessage(), e);
            throw new RuntimeException("Lỗi xử lý file ảnh.");
        }
    }

    @Override
    public void sendEmergencyLockOTP(Integer accId, String identityCard) {
        Account account = accountRepository.findById(accId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        // Xác minh CCCD
        if (account.getIdentityCard() == null || !account.getIdentityCard().equals(identityCard)) {
            log.warn("Yêu cầu OTP khóa khẩn cấp thất bại cho User {}: CCCD không khớp.", accId);
            throw new IllegalArgumentException("Số CCCD xác minh không chính xác.");
        }

        // Tạo mã OTP 6 số
        String otp = String.format("%06d", new Random().nextInt(999999));
        
        // 1. Lưu vào cache TRƯỚC khi gọi gửi mail để đảm bảo tính sẵn sàng
        otpCache.put(accId, new OtpSession(otp));

        // 2. Gửi Mail bất đồng bộ thông qua EmailService (Spring Proxy @Async sẽ hoạt động chuẩn ở đây)
        emailService.sendEmergencyLockOtp(account.getAccEmail(), account.getFullname(), otp);
        
        log.info("Yêu cầu gửi OTP đã được tiếp nhận cho User ID: {}", accId);
    }

    @Override
    @Transactional
    public void verifyAndLockAccount(Integer accId, String otpCode) {
        Account account = accountRepository.findById(accId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        // 1. Kiểm tra session trong cache
        OtpSession session = otpCache.get(accId);
        if (session == null) {
            log.warn("Xác thực thất bại: Không tìm thấy session OTP cho User ID {}", accId);
            throw new IllegalArgumentException("Không tìm thấy yêu cầu xác thực hoặc mã đã bị hủy.");
        }
        
        // 2. Kiểm tra hết hạn TRƯỚC
        if (session.isExpired()) {
            otpCache.remove(accId);
            log.warn("Xác thực thất bại: OTP đã hết hạn cho User ID {}", accId);
            throw new IllegalArgumentException("Mã OTP đã hết hạn (5 phút). Vui lòng yêu cầu mã mới.");
        }

        // 3. Chuẩn hóa mã nhận được từ Client (Mobile)
        String sanitizedCode = (otpCode != null) ? otpCode.trim() : "";

        // 4. Kiểm tra tính chính xác
        if (!session.code.equals(sanitizedCode)) {
            log.warn("Xác thực thất bại: Mã không khớp cho User ID {}. Nhận: [{}], Kỳ vọng: [{}]", 
                    accId, sanitizedCode, session.code);
            throw new IllegalArgumentException("Mã OTP không chính xác.");
        }

        // 5. Thực hiện khóa tài khoản
        account.setLocked(true);
        accountRepository.save(account);

        // 6. Thu hồi toàn bộ phiên đăng nhập
        List<UserDevice> devices = userDeviceRepository.findAllByAccount_Id(accId);
        devices.forEach(device -> {
            device.setRefreshToken(null);
            device.setLoggedIn(false);
        });
        userDeviceRepository.saveAll(devices);

        // 7. Gửi thông báo
        var adminMsg = NotificationMessages.userEmergencyLockAlert(account.getAccEmail(), "Xác minh qua Gmail");
        notificationService.createNotification(null, adminMsg.title(), adminMsg.content(), 
                NotificationType.SYSTEM, null, LocalDateTime.now());

        var userMsg = NotificationMessages.accountEmergencyLockedConfirm();
        notificationService.createNotification(account, userMsg.title(), userMsg.content(), 
                NotificationType.SYSTEM, null, LocalDateTime.now());

        // Xóa OTP khỏi cache sau khi dùng thành công
        otpCache.remove(accId);
        log.info("Tài khoản {} đã được khóa khẩn cấp thành công.", account.getAccEmail());
    }
}