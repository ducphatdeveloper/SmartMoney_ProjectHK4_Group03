package fpt.aptech.server.api.util;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.service.cloudinary.CloudinaryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

/**
 * Controller xử lý upload hình ảnh lên Cloudinary.
 *
 * Endpoints:
 * 1. POST /api/upload/image  — Upload ảnh → trả URL
 * 2. DELETE /api/upload/image — Xóa ảnh theo URL
 *
 * Folder mapping:
 *   - type=icon    → smartmoney/icons
 *   - type=avatar  → smartmoney/avatars
 *   - type=receipt → smartmoney/receipts
 *   - type=ai      → smartmoney/ai
 */
@RestController
@RequestMapping("/api/upload")
@RequiredArgsConstructor
public class UploadController {

    private final CloudinaryService cloudinaryService;

    // =========================================================================
    // 1. UPLOAD ẢNH
    // =========================================================================

    /**
     * [1.1] Upload ảnh lên Cloudinary.
     *
     * @param file File ảnh (multipart/form-data)
     * @param type Loại ảnh: icon | avatar | receipt | ai (quyết định folder trên cloud)
     * @return URL HTTPS của ảnh đã upload
     */
    @PostMapping("/image")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadImage(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "type", defaultValue = "icon") String type) throws IOException {

        // 1. Map type → folder trên Cloudinary
        String folder = mapTypeToFolder(type);

        // 2. Upload
        String imageUrl = cloudinaryService.uploadImage(file, folder);

        // 3. Trả URL cho client lưu vào DB
        Map<String, String> result = Map.of("imageUrl", imageUrl);
        return ResponseEntity.ok(ApiResponse.success(result, "Upload ảnh thành công."));
    }

    // =========================================================================
    // 2. XÓA ẢNH
    // =========================================================================

    /**
     * [2.1] Xóa ảnh trên Cloudinary theo URL.
     *
     * @param imageUrl URL của ảnh cần xóa
     */
    @DeleteMapping("/image")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> deleteImage(
            @RequestParam("imageUrl") String imageUrl) {

        String publicId = cloudinaryService.extractPublicId(imageUrl);
        if (publicId == null) {
            throw new IllegalArgumentException("URL ảnh không hợp lệ.");
        }

        boolean deleted = cloudinaryService.deleteImage(publicId);
        if (!deleted) {
            throw new IllegalArgumentException("Không thể xóa ảnh. Có thể ảnh đã bị xóa trước đó.");
        }

        return ResponseEntity.ok(ApiResponse.success("Xóa ảnh thành công."));
    }

    // =========================================================================
    // 3. TIỆN ÍCH
    // =========================================================================

    /**
     * Map loại ảnh → folder trên Cloudinary.
     */
    private String mapTypeToFolder(String type) {
        return switch (type.toLowerCase()) {
            case "icon"    -> "smartmoney/icons";
            case "avatar"  -> "smartmoney/avatars";
            case "receipt" -> "smartmoney/receipts";
            case "ai"      -> "smartmoney/ai";
            default        -> "smartmoney/others";
        };
    }
}

