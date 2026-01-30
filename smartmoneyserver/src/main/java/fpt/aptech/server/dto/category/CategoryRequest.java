package fpt.aptech.server.dto.category;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CategoryRequest {

    @NotBlank(message = "Tên danh mục không được để trống")
    @Size(max = 100, message = "Tên danh mục tối đa 100 ký tự")
    private String ctgName;

    @NotNull(message = "Loại danh mục không được để trống")
    private Boolean ctgType; // true: Thu nhập, false: Chi tiêu

    @Size(max = 2048, message = "URL icon quá dài")
    private String ctgIconUrl;

    // ID danh mục cha (nếu tạo danh mục con). Null nếu tạo danh mục gốc.
    private Integer parentId;
}