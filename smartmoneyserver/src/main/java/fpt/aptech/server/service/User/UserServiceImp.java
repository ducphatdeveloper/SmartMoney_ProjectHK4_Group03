package fpt.aptech.server.service.User;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;
import java.util.Objects;

@Slf4j
@Service
@RequiredArgsConstructor
public class
UserServiceImp implements UserService {

    private final AccountRepository accountRepository;
    private final NotificationService notificationService;
    private final Cloudinary cloudinary;

    @Override
    @Transactional(readOnly = true)
    public AccountDto getProfile(String email) {
        Account account = accountRepository.findByAccEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return new AccountDto(account);
    }

    @Override
    @Transactional
    public String updateAvatar(Integer accId, MultipartFile file) {
        log.info("Bắt đầu quy trình cập nhật avatar cho User ID: {}", accId);

        Account account = accountRepository.findById(accId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        try {
            // 1. Xử lý xóa ảnh cũ trên Cloudinary để tiết kiệm dung lượng
            String oldUrl = account.getAvatarUrl();
            if (oldUrl != null && oldUrl.contains("/avatars/")) {
                try {
                    // Trích xuất public_id từ URL (ví dụ: avatars/abcxyz)
                    // URL thường có dạng: .../upload/v12345/avatars/filename.jpg
                    int startIndex = oldUrl.lastIndexOf("avatars/");
                    int endIndex = oldUrl.lastIndexOf(".");
                    if (startIndex != -1 && endIndex > startIndex) {
                        String publicId = oldUrl.substring(startIndex, endIndex);
                        cloudinary.uploader().destroy(publicId, ObjectUtils.emptyMap());
                        log.info("Đã xóa thành công ảnh cũ trên Cloudinary: {}", publicId);
                    }
                } catch (Exception e) {
                    log.warn("Không thể xóa ảnh cũ trên Cloudinary (có thể file đã bị xóa trước đó): {}", e.getMessage());
                }
            }

            // 2. Upload file mới vào folder 'avatars' (ngang hàng với 'icons')
            log.info("Đang tải file lên thư mục 'avatars'...");
            Map uploadResult = cloudinary.uploader().upload(file.getBytes(),
                    ObjectUtils.asMap("folder", "avatars"));

            String fileUrl = (String) uploadResult.get("secure_url");
            if (fileUrl == null) {
                throw new IOException("Tải lên thất bại: Không nhận được URL từ Cloudinary");
            }

            // 3. Cập nhật URL vào database
            account.setAvatarUrl(fileUrl);
            accountRepository.save(account);
            log.info("Cập nhật Database thành công cho User {}. URL mới: {}", accId, fileUrl);

            // 4. Gửi thông báo hệ thống xác nhận cập nhật thành công
            var msg = NotificationMessages.avatarUpdated();
            notificationService.createNotification(
                    account,
                    msg.title(),
                    msg.content(),
                    NotificationType.SYSTEM,
                    null,
                    null
            );

            return fileUrl;
        } catch (Exception e) {
            log.error("Lỗi nghiêm trọng khi cập nhật avatar cho User {}: {}", accId, e.getMessage(), e);
            throw new RuntimeException("Lỗi trong quá trình xử lý ảnh đại diện: " + e.getMessage());
        }
    }
}