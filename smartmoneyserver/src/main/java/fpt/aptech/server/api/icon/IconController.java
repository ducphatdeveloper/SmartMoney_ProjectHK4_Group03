package fpt.aptech.server.api.icon;

import fpt.aptech.server.dto.icon.IconDto;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.service.icon.IconService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/icons")
@RequiredArgsConstructor
public class IconController {

    private final IconService iconService;

    /**
     * Lấy danh sách thông tin của tất cả các icon để hiển thị trong Icon Picker.
     * - Endpoint này được bảo vệ, yêu cầu người dùng phải đăng nhập.
     * - Kết quả được cache ở tầng service để tăng tốc độ phản hồi.
     *
     * @return Danh sách các đối tượng IconDto (chứa tên file và URL).
     */
    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<IconDto>>> getAllIcons() {
        List<IconDto> iconDtos = iconService.getAllIconsFromCloudinary();
        return ResponseEntity.ok(ApiResponse.success(iconDtos));
    }
}
