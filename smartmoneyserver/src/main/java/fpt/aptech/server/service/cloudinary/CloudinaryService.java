package fpt.aptech.server.service.cloudinary;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

/**
 * Service upload & xóa hình ảnh trên Cloudinary.
 *
 * Folder trên Cloudinary:
 *   - smartmoney/icons      → Icon danh mục, ví, sự kiện, mục tiêu tiết kiệm
 *   - smartmoney/avatars    → Avatar người dùng
 *   - smartmoney/receipts   → Hóa đơn (OCR)
 *   - smartmoney/ai         → File đính kèm từ AI chat
 *
 * Phương thức:
 *   1. uploadImage(file, folder)  — Upload file → trả về URL HTTPS
 *   2. deleteImage(publicId)      — Xóa file theo publicId
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CloudinaryService {

    private final Cloudinary cloudinary;

    // =================================================================================
    // 1. UPLOAD ẢNH LÊN CLOUDINARY
    // =================================================================================

    /**
     * [1.1] Upload ảnh lên Cloudinary.
     *
     * @param file   File ảnh từ request (MultipartFile)
     * @param folder Tên folder trên Cloudinary (VD: "smartmoney/icons")
     * @return URL HTTPS của ảnh đã upload
     * @throws IOException nếu upload thất bại
     */
    @SuppressWarnings("unchecked")
    public String uploadImage(MultipartFile file, String folder) throws IOException {
        // 1. Validate file
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("File ảnh không được để trống.");
        }

        // 2. Validate loại file (chỉ cho phép ảnh)
        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            throw new IllegalArgumentException("Chỉ chấp nhận file ảnh (jpg, png, svg, webp...).");
        }

        // 3. Upload lên Cloudinary
        Map<String, Object> uploadResult = cloudinary.uploader().upload(
                file.getBytes(),
                ObjectUtils.asMap(
                        "folder", folder,                  // Folder trên cloud
                        "resource_type", "image",          // Loại resource
                        "overwrite", true,                 // Ghi đè nếu trùng
                        "transformation", "q_auto,f_auto"  // Tự động nén & chọn format tốt nhất
                )
        );

        // 4. Trả về URL HTTPS (secure_url)
        String secureUrl = (String) uploadResult.get("secure_url");
        log.info("✅ Upload ảnh thành công: {}", secureUrl);
        return secureUrl;
    }

    // =================================================================================
    // 2. XÓA ẢNH TRÊN CLOUDINARY
    // =================================================================================

    /**
     * [2.1] Xóa ảnh trên Cloudinary theo publicId.
     *
     * @param publicId Public ID của ảnh (VD: "smartmoney/icons/abc123")
     * @return true nếu xóa thành công, false nếu thất bại
     */
    @SuppressWarnings("unchecked")
    public boolean deleteImage(String publicId) {
        try {
            Map<String, Object> result = cloudinary.uploader().destroy(
                    publicId, ObjectUtils.emptyMap());

            String status = (String) result.get("result");
            boolean success = "ok".equals(status);

            if (success) {
                log.info("✅ Xóa ảnh thành công: {}", publicId);
            } else {
                log.warn("⚠️ Xóa ảnh thất bại (publicId không tồn tại): {}", publicId);
            }

            return success;
        } catch (IOException e) {
            log.error("❌ Lỗi xóa ảnh trên Cloudinary: {}", e.getMessage());
            return false;
        }
    }

    // =================================================================================
    // 3. TIỆN ÍCH
    // =================================================================================

    /**
     * [3.1] Trích xuất publicId từ URL Cloudinary.
     * VD: "https://res.cloudinary.com/xxx/image/upload/v123/smartmoney/icons/abc.png"
     *  → "smartmoney/icons/abc"
     */
    public String extractPublicId(String cloudinaryUrl) {
        if (cloudinaryUrl == null || cloudinaryUrl.isEmpty()) return null;

        try {
            // URL format: .../upload/v{version}/{publicId}.{ext}
            String[] parts = cloudinaryUrl.split("/upload/");
            if (parts.length < 2) return null;

            String afterUpload = parts[1]; // v123/smartmoney/icons/abc.png
            // Bỏ version prefix (v123/)
            String withoutVersion = afterUpload.replaceFirst("v\\d+/", "");
            // Bỏ extension (.png, .jpg, ...)
            int lastDot = withoutVersion.lastIndexOf('.');
            if (lastDot > 0) {
                return withoutVersion.substring(0, lastDot);
            }
            return withoutVersion;
        } catch (Exception e) {
            log.warn("Không thể trích xuất publicId từ URL: {}", cloudinaryUrl);
            return null;
        }
    }
}

