package fpt.aptech.server.dto.category;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Builder;

/**
 * DTO nhận dữ liệu tạo/sửa danh mục từ Client.
 * Sử dụng Java Record kết hợp Validation.
 */
@Builder
public record CategoryRequest(
    
    @NotBlank(message = "Category name cannot be empty")
    @Size(max = 100, message = "Category name must be at most 100 characters")
    String ctgName,

    @NotNull(message = "Category type cannot be empty")
    Boolean ctgType, // true: Thu nhập, false: Chi tiêu

    @Size(max = 2048, message = "Icon URL is too long")
    String ctgIconUrl,

    // ID danh mục cha (nếu tạo danh mục con). Null nếu tạo danh mục gốc.
    Integer parentId
) {}