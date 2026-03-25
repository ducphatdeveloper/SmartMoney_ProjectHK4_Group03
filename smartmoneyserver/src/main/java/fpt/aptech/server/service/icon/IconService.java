package fpt.aptech.server.service.icon;

import com.cloudinary.Cloudinary;
import fpt.aptech.server.dto.icon.IconDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@Slf4j
@RequiredArgsConstructor
public class IconService {

    private final Cloudinary cloudinary;

    /**
     * Lấy danh sách URL của tất cả các icon từ folder "icons" trên Cloudinary.
     * - Sử dụng Search API để có hiệu suất cao.
     * - Kết quả được cache lại trong cache "icons" để tránh gọi API nhiều lần.
     *
     * @return Danh sách các DTO chứa tên file và URL của icon.
     */
    @Cacheable("icons")
    public List<IconDto> getAllIconsFromCloudinary() {
        log.info("Đang lấy danh sách icon từ Cloudinary bằng Search API (không có cache)...");
        try {
            // Sử dụng Search API để tìm kiếm
            Map result = cloudinary.search()
                    .expression("folder:icons/*")
                    .maxResults(500)
                    .execute();

            List<Map> resources = (List<Map>) result.get("resources");

            if (resources == null || resources.isEmpty()) {
                log.warn("Search API không tìm thấy icon nào trong folder 'icons'.");
                return List.of();
            }

            log.info("Tìm thấy {} icons trên Cloudinary.", resources.size());
            return resources.stream()
                    .map(r -> {
                        String secureUrl = (String) r.get("secure_url");
                        // Lấy tên file từ cuối URL
                        String fileName = secureUrl.substring(secureUrl.lastIndexOf('/') + 1);
                        return new IconDto(fileName, secureUrl);
                    })
                    .collect(Collectors.toList());
        } catch (Exception e) {
            log.error("Lỗi khi lấy icon từ Cloudinary bằng Search API: {}", e.getMessage(), e);
            // Trả về danh sách rỗng nếu có lỗi để tránh sập ứng dụng
            return List.of();
        }
    }
}
