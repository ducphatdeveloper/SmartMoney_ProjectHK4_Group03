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
    
    @NotBlank(message = "Tên danh mục không được để trống")
    @Size(max = 100, message = "Tên danh mục tối đa 100 ký tự")
    String ctgName,

    @NotNull(message = "Loại danh mục không được để trống")
    Boolean ctgType, // true: Thu nhập, false: Chi tiêu

    @Size(max = 2048, message = "URL icon quá dài")
    String ctgIconUrl,

    // ID danh mục cha (nếu tạo danh mục con). Null nếu tạo danh mục gốc.
    Integer parentId
) {}